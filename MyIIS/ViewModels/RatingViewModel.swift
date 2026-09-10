import Combine
import Foundation

@Observable
@MainActor
final class RatingViewModel {

    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?
    private(set) var isLoadingSubjects: Bool = false
    private(set) var isGradebookUnavailable: Bool = false
    private(set) var isRatingPendingForNewSemester: Bool = false
    private(set) var isUsingScheduleFallback: Bool = false
    private(set) var isShowingStaleDataWarning: Bool = false
    private(set) var lastUpdateTime: Date?
    private(set) var students: [StudentRating] = []
    private(set) var checkpointNumbers: [Int] = []
    private(set) var summary: RatingSummary?
    private(set) var disciplines: [GradebookDiscipline] = []
    private(set) var subjectOmissions: [String: Int] = [:]
    private(set) var userCheckpoints: [RatingCheckpoint] = []
    private(set) var gradebookAverage: Double?
    private(set) var deadlineItems: [DisciplineDeadlineItem] = []
    private(set) var checkpointSummaries: [CheckpointSummaryItem] = []
    private(set) var percentageMarks: [PortalPercentageMark] = []

    private let apiService: APIService
    private let userDefaults: UserDefaults
    private let logService = LogService.shared
    private var currentGroup: String?
    private var currentStudentId: String?
    private var resolvedRecordBookNumber: String?
    private let isPreview: Bool
    private struct RatingCacheSnapshot: Codable {
        let students: [StudentRating]
        let checkpointNumbers: [Int]
        let disciplines: [GradebookDiscipline]
        let subjectOmissions: [String: Int]
        let userCheckpoints: [RatingCheckpoint]
        let gradebookAverage: Double?
        let isGradebookUnavailable: Bool
        let resolvedRecordBookNumber: String?
        let currentGroup: String
        let currentStudentId: String
        let updatedAt: Date
        var deadlineItems: [DisciplineDeadlineItem]? = []
        var checkpointSummaries: [CheckpointSummaryItem]? = []
        var percentageMarks: [PortalPercentageMark]? = []
    }

    private static let ratingCachePrefix = "RatingViewModel.snapshot."

    init(
        apiService: APIService? = nil,
        isPreview: Bool = false,
        userDefaults: UserDefaults = .standard
    ) {
        self.apiService = apiService ?? APIService()
        self.isPreview = isPreview
        self.userDefaults = userDefaults

        if isPreview {
            students = StudentRating.previewData
            checkpointNumbers = Self.makeCheckpointNumbers(from: students)
            summary = RatingSummary(students: students)
            disciplines = Gradebook.previewData.semesters.flatMap { $0.sortedDisciplines() }
            gradebookAverage = Gradebook.previewData.averageGrade
            userCheckpoints = students.first?.checkpoints.sorted { $0.number < $1.number } ?? []
            deadlineItems = [
                DisciplineDeadlineItem(
                    id: "САиИО",
                    discipline: "САиИО",
                    fullDisciplineName: "Системный анализ и исследование операций",
                    submitted: 2,
                    total: 8,
                    nearestDeadline: "15.10.2026",
                    nearestDeadlineTaskNumber: 3,
                    nearestDeadlineOverdue: false,
                    overdueDeadlines: [],
                    deadlinesMissing: false
                ),
                DisciplineDeadlineItem(
                    id: "ОМО",
                    discipline: "ОМО",
                    fullDisciplineName: "Основы машинного обучения",
                    submitted: 1,
                    total: 4,
                    nearestDeadline: "10.09.2026",
                    nearestDeadlineTaskNumber: 2,
                    nearestDeadlineOverdue: false,
                    overdueDeadlines: [],
                    deadlinesMissing: false
                )
            ]
            isGradebookUnavailable = false
            isUsingScheduleFallback = false
            isLoadingSubjects = false
        }
    }

    func loadRating(for user: User) async {
        await loadCombined(for: user, force: false)
    }

    func refresh(for user: User) async {
        await loadCombined(for: user, force: true)
    }

    func loadRating(forEducation education: Education) async {
        await loadByGroup(education.group, targetRecordBookNumber: nil, force: false)
    }

    func refresh(forEducation education: Education) async {
        await loadByGroup(education.group, targetRecordBookNumber: nil, force: true)
    }

    func loadRating(forGroup group: String?) async {
        await loadByGroup(group, targetRecordBookNumber: nil, force: false)
    }

    func refresh(forGroup group: String?) async {
        await loadByGroup(group, targetRecordBookNumber: nil, force: true)
    }

}

extension RatingViewModel {
    private func loadCombined(for user: User, force: Bool) async {
        guard !isPreview else { return }

        let group = user.education.group
        let studentId = String(user.id)

        guard !group.isEmpty else {
            errorMessage = "Не удалось определить номер группы"
            return
        }

        guard user.id > 0 else {
            errorMessage = "Не удалось определить идентификатор студента"
            return
        }

        if !force {
            _ = applyCachedSnapshotIfAvailable(group: group, studentId: studentId)
        }

        await loadByGroup(group, targetRecordBookNumber: studentId, force: true)

        currentStudentId = studentId
        saveCurrentStateToCache(group: group, studentId: studentId)
    }

    private func loadByGroup(_ group: String?, targetRecordBookNumber: String?, force: Bool) async {
        guard !isPreview else { return }

        guard let group, !group.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Не удалось определить номер группы"
            return
        }
        guard !isLoading else { return }

        let resolvedStudentId = normalizeRecordBookNumber(targetRecordBookNumber)
        let cacheStudentId = resolvedStudentId.isEmpty ? "_portal" : resolvedStudentId

        if !force,
           currentGroup == group,
           currentStudentId == cacheStudentId,
           !students.isEmpty || !disciplines.isEmpty {
            return
        }

        isLoading = true
        isLoadingSubjects = true
        errorMessage = nil
        isGradebookUnavailable = false
        isRatingPendingForNewSemester = false
        isUsingScheduleFallback = false
        isShowingStaleDataWarning = false

        await loadFromPortalGradeBook(targetRecordBookNumber: targetRecordBookNumber)

        guard !Task.isCancelled else {
            isLoadingSubjects = false
            isLoading = false
            return
        }

        isLoadingSubjects = false
        isLoading = false
        currentGroup = group
        currentStudentId = cacheStudentId

        if let staleMessage = errorMessage,
           applyCachedSnapshotIfAvailable(group: group, studentId: cacheStudentId) {
            errorMessage = staleMessage
            isShowingStaleDataWarning = true
        } else if errorMessage == nil {
            lastUpdateTime = Date()
            saveCurrentStateToCache(group: group, studentId: cacheStudentId)
        }
    }

    private func cacheKey(group: String, studentId: String) -> String {
        Self.ratingCachePrefix + "\(group)|\(studentId)"
    }

    private func applyCachedSnapshotIfAvailable(group: String, studentId: String) -> Bool {
        let key = cacheKey(group: group, studentId: studentId)
        guard let payload = UserDefaultsPayloadStore.load(forKey: key, from: userDefaults),
              let cached = try? JSONDecoder().decode(RatingCacheSnapshot.self, from: payload) else {
            return false
        }

        students = cached.students
        checkpointNumbers = cached.checkpointNumbers
        summary = RatingSummary(students: cached.students)
        disciplines = cached.disciplines
        subjectOmissions = cached.subjectOmissions
        userCheckpoints = cached.userCheckpoints
        gradebookAverage = cached.gradebookAverage
        deadlineItems = cached.deadlineItems ?? []
        checkpointSummaries = cached.checkpointSummaries ?? []
        percentageMarks = cached.percentageMarks ?? []
        isGradebookUnavailable = cached.isGradebookUnavailable
        isRatingPendingForNewSemester = false
        isUsingScheduleFallback = false
        resolvedRecordBookNumber = cached.resolvedRecordBookNumber
        currentGroup = cached.currentGroup
        currentStudentId = cached.currentStudentId
        lastUpdateTime = cached.updatedAt
        errorMessage = nil
        return true
    }

    private func saveCurrentStateToCache(group: String, studentId: String) {
        guard !students.isEmpty || !disciplines.isEmpty else { return }
        let snapshot = RatingCacheSnapshot(
            students: students,
            checkpointNumbers: checkpointNumbers,
            disciplines: disciplines,
            subjectOmissions: subjectOmissions,
            userCheckpoints: userCheckpoints,
            gradebookAverage: gradebookAverage,
            isGradebookUnavailable: isGradebookUnavailable,
            resolvedRecordBookNumber: resolvedRecordBookNumber,
            currentGroup: group,
            currentStudentId: studentId,
            updatedAt: lastUpdateTime ?? Date(),
            deadlineItems: deadlineItems,
            checkpointSummaries: checkpointSummaries,
            percentageMarks: percentageMarks
        )
        guard let payload = try? JSONEncoder().encode(snapshot) else { return }
        _ = UserDefaultsPayloadStore.save(payload, forKey: cacheKey(group: group, studentId: studentId), in: userDefaults)
    }

    private func loadFromPortalGradeBook(targetRecordBookNumber: String?) async {
        do {
            let student = try await apiService.getPortalGradeBookStudent()
            let lessons = student?.lessons ?? []
            percentageMarks = student?.percentageMarks ?? []

            guard !lessons.isEmpty else {
                disciplines = []
                subjectOmissions = [:]
                students = []
                userCheckpoints = []
                checkpointNumbers = []
                deadlineItems = []
                checkpointSummaries = []
                summary = nil
                gradebookAverage = nil
                isGradebookUnavailable = false
                isRatingPendingForNewSemester = true
                errorMessage = nil
                logService.log("ℹ️ grade-book returned an empty lessons list; rating is pending for the new semester.")
                return
            }

            isRatingPendingForNewSemester = false
            applyPortalGradeBookLessons(lessons)
            buildPersonalRating(from: lessons, targetRecordBookNumber: targetRecordBookNumber)
            let (deadlines, summaries) = await Task.detached(priority: .userInitiated) {
                (Self.buildDeadlineItems(from: lessons), Self.buildCheckpointSummaries(from: lessons))
            }.value
            guard !Task.isCancelled else { return }
            self.deadlineItems = deadlines
            self.checkpointSummaries = summaries
            isGradebookUnavailable = disciplines.isEmpty
            errorMessage = nil
            logService.log("✅ Rating loaded from grade-book. Lessons: \(lessons.count), disciplines: \(disciplines.count), deadlines: \(deadlineItems.count)")
        } catch is CancellationError {
            return
        } catch let error as APIError {
            logService.log("❌ grade-book API error: \(error.localizedDescription)")
            disciplines = []
            subjectOmissions = [:]
            students = []
            userCheckpoints = []
            checkpointNumbers = []
            deadlineItems = []
            checkpointSummaries = []
            summary = nil
            gradebookAverage = nil

            switch error {
            case .serverError(let statusCode, _) where statusCode == 403 || statusCode == 404:
                isGradebookUnavailable = false
                isRatingPendingForNewSemester = true
                errorMessage = nil
            default:
                isGradebookUnavailable = true
                isRatingPendingForNewSemester = false
                errorMessage = error.localizedDescription
            }
        } catch {
            logService.log("❌ Unexpected grade-book error: \(error.localizedDescription)")
            disciplines = []
            subjectOmissions = [:]
            students = []
            userCheckpoints = []
            checkpointNumbers = []
            deadlineItems = []
            checkpointSummaries = []
            summary = nil
            gradebookAverage = nil
            isGradebookUnavailable = true
            isRatingPendingForNewSemester = false
            errorMessage = error.localizedDescription
        }
    }

    private func applyPortalGradeBookLessons(_ lessons: [PortalGradeBookLesson]) {
        let grouped = Dictionary(grouping: lessons) { $0.lessonNameAbbrev }
        var omissions: [String: Int] = [:]

        disciplines = grouped.map { subject, subjectLessons in
            let mapped = makeDiscipline(for: subject, lessons: subjectLessons)
            omissions[subject] = mapped.omissionHours
            return mapped.discipline
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        subjectOmissions = omissions
        isUsingScheduleFallback = false
    }

    private func makeDiscipline(
        for subject: String,
        lessons: [PortalGradeBookLesson]
    ) -> (discipline: GradebookDiscipline, omissionHours: Int) {
        let lessonTypes = Set(lessons.map(\.lessonTypeAbbrev))
            .filter { !$0.isEmpty }
            .sorted()
        let payload = makeGradebookPayload(from: lessons)
        let omissionHours = payload.omissions.reduce(0) { $0 + $1.hours }

        return (
            GradebookDiscipline(
                code: "gradebook_\(subject)",
                name: subject,
                controlForm: lessonTypes.isEmpty ? "Занятия" : lessonTypes.joined(separator: " · "),
                teacher: nil,
                hours: omissionHours,
                attempts: payload.attempts,
                lessonOmissions: payload.omissions.isEmpty ? nil : payload.omissions
            ),
            omissionHours
        )
    }

    private func makeGradebookPayload(
        from lessons: [PortalGradeBookLesson]
    ) -> (attempts: [GradeAttempt], omissions: [GradeOmission]) {
        var attempts: [GradeAttempt] = []
        var omissions: [GradeOmission] = []

        for lesson in lessons.sorted(by: Self.portalLessonSort) {
            appendMarks(from: lesson, to: &attempts)
            appendOmission(from: lesson, to: &omissions)
        }

        return (attempts, omissions)
    }

    private func appendMarks(from lesson: PortalGradeBookLesson, to attempts: inout [GradeAttempt]) {
        for detail in lesson.markDetails {
            let taskSuffix = detail.taskNumber.map { " (№ \($0))" } ?? ""
            let typeTitle = "\(lesson.lessonTypeAbbrev)\(taskSuffix)"
            attempts.append(
                GradeAttempt(
                    attempt: attempts.count + 1,
                    type: typeTitle,
                    grade: .numeric(Double(detail.mark)),
                    date: lesson.dateString,
                    status: .passed
                )
            )
        }
    }

    private func appendOmission(from lesson: PortalGradeBookLesson, to omissions: inout [GradeOmission]) {
        guard !lesson.isRespectfulOmission, lesson.gradeBookOmissions > 0 else { return }
        omissions.append(
            GradeOmission(
                date: lesson.dateString,
                type: lesson.lessonTypeAbbrev,
                hours: lesson.gradeBookOmissions
            )
        )
    }

    private func buildPersonalRating(from lessons: [PortalGradeBookLesson], targetRecordBookNumber: String?) {
        let checkpoints = makePortalCheckpoints(from: lessons)
        let resolvedId = normalizeRecordBookNumber(targetRecordBookNumber)
        let recordBookNumber = resolvedId.isEmpty ? "portal-grade-book" : resolvedId
        let personalRating = StudentRating(
            recordBookNumber: recordBookNumber,
            studentName: nil,
            averageGrade: Self.average(lessons.flatMap { $0.marks }.map(Double.init)),
            missedHours: Self.unexcusedOmissionHours(in: lessons),
            averageShift: nil,
            checkpoints: checkpoints
        )

        students = [personalRating]
        userCheckpoints = checkpoints
        checkpointNumbers = checkpoints.map { $0.number }
        summary = RatingSummary(students: students)
        gradebookAverage = personalRating.averageGrade
        resolvedRecordBookNumber = personalRating.recordBookNumber
    }

    private func makePortalCheckpoints(from lessons: [PortalGradeBookLesson]) -> [RatingCheckpoint] {
        let groups = Dictionary(grouping: lessons.compactMap(Self.portalCheckpointPair)) { $0.0 }
        return sortedCheckpointKeys(in: groups).enumerated().map { index, key in
            let scopedLessons = groups[key]?.map { $0.1 } ?? []
            return RatingCheckpoint(
                number: Self.checkpointNumber(from: key) ?? (index + 1),
                title: key,
                averageGrade: Self.average(scopedLessons.flatMap { $0.marks }.map(Double.init)),
                missedHours: Self.unexcusedOmissionHours(in: scopedLessons)
            )
        }
    }

    private func sortedCheckpointKeys(
        in groups: [String: [(String, PortalGradeBookLesson)]]
    ) -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return groups.keys.sorted { lhs, rhs in
            let lhsDate = groups[lhs]?.compactMap { formatter.date(from: $0.1.dateString) }.min()
            let rhsDate = groups[rhs]?.compactMap { formatter.date(from: $0.1.dateString) }.min()
            return (lhsDate ?? .distantFuture) < (rhsDate ?? .distantFuture)
        }
    }

    private static func portalLessonSort(_ lhs: PortalGradeBookLesson, _ rhs: PortalGradeBookLesson) -> Bool {
        if lhs.controlPoint != rhs.controlPoint {
            return lhs.controlPoint < rhs.controlPoint
        }
        return lhs.dateString < rhs.dateString
    }

    private static func portalCheckpointPair(_ lesson: PortalGradeBookLesson) -> (String, PortalGradeBookLesson)? {
        let controlPoint = lesson.controlPoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !controlPoint.isEmpty else { return nil }
        return (controlPoint, lesson)
    }

    private static func unexcusedOmissionHours(in lessons: [PortalGradeBookLesson]) -> Int {
        lessons
            .filter { !$0.isRespectfulOmission }
            .reduce(0) { $0 + max($1.gradeBookOmissions, 0) }
    }

    private func normalizeRecordBookNumber(_ value: String?) -> String {
        guard let value else { return "" }
        return value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { $0.isNumber }
    }

    private static func checkpointNumber(from value: String) -> Int? {
        let digits = value.filter { $0.isNumber }
        guard let number = Int(digits), number > 0 else {
            return nil
        }
        return number
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func makeCheckpointNumbers(from students: [StudentRating]) -> [Int] {
        let numbers = Set(students.flatMap { $0.checkpoints.map { $0.number } })
        return numbers.filter { $0 > 0 }.sorted()
    }

    nonisolated static func buildDeadlineItems(from lessons: [PortalGradeBookLesson]) -> [DisciplineDeadlineItem] {
        var disciplinesOrder: [String] = []
        var fullNames: [String: String] = [:]
        for lesson in lessons {
            let abbrev = lesson.lessonNameAbbrev.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !abbrev.isEmpty else { continue }
            if !disciplinesOrder.contains(abbrev) {
                disciplinesOrder.append(abbrev)
            }
            if let fullName = lesson.lessonName?.trimmingCharacters(in: .whitespacesAndNewlines), !fullName.isEmpty {
                fullNames[abbrev] = fullName
            }
        }

        var items: [DisciplineDeadlineItem] = []
        for disciplineCode in disciplinesOrder {
            let discLessons = lessons.filter {
                $0.lessonNameAbbrev.trimmingCharacters(in: .whitespacesAndNewlines) == disciplineCode
            }
            let labLessons = discLessons.filter { $0.lessonTypeId == 4 }
                .sorted { $0.dateString < $1.dateString }
            guard !labLessons.isEmpty else { continue }

            if let item = buildDisciplineDeadlineItem(
                discipline: disciplineCode,
                fullName: fullNames[disciplineCode],
                labLessons: labLessons
            ) {
                items.append(item)
            }
        }

        return items.sorted(by: deadlineItemSort)
    }

    nonisolated private static func buildDisciplineDeadlineItem(
        discipline: String,
        fullName: String?,
        labLessons: [PortalGradeBookLesson]
    ) -> DisciplineDeadlineItem? {
        let total = labLessons.first?.labCount
        let submitted = labLessons.filter { !$0.marks.isEmpty }.count

        let deadlines = labLessons.filter {
            $0.marks.isEmpty && $0.deadline != nil && $0.deadlineOverdue != true
        }.sorted { (lhs, rhs) -> Bool in
            let lDate = parseDate(lhs.deadline) ?? .distantFuture
            let rDate = parseDate(rhs.deadline) ?? .distantFuture
            return lDate < rDate
        }

        let nearest = deadlines.first
        let nearestDeadline = nearest?.deadline
        let nearestTaskNumber = nearest?.deadlineTaskNumber

        var seenOverdue = Set<String>()
        var overdueItems: [OverdueDeadlineItem] = []
        for lesson in labLessons where lesson.marks.isEmpty && lesson.deadline != nil && lesson.deadlineOverdue == true {
            if let deadlineDate = lesson.deadline {
                let key = "\(deadlineDate)|\(lesson.deadlineTaskNumber ?? 0)"
                if !seenOverdue.contains(key) {
                    seenOverdue.insert(key)
                    overdueItems.append(OverdueDeadlineItem(date: deadlineDate, taskNumber: lesson.deadlineTaskNumber))
                }
            }
        }

        let deadlinesMissing = labLessons.allSatisfy { $0.deadline == nil }
        if total == 0 && deadlinesMissing && overdueItems.isEmpty {
            return nil
        }

        return DisciplineDeadlineItem(
            id: discipline,
            discipline: discipline,
            fullDisciplineName: fullName,
            submitted: submitted,
            total: total,
            nearestDeadline: nearestDeadline,
            nearestDeadlineTaskNumber: nearestTaskNumber,
            nearestDeadlineOverdue: false,
            overdueDeadlines: overdueItems,
            deadlinesMissing: deadlinesMissing
        )
    }

    nonisolated private static func deadlineItemSort(_ lhs: DisciplineDeadlineItem, _ rhs: DisciplineDeadlineItem) -> Bool {
        let lHasNearest = lhs.nearestDeadline != nil
        let rHasNearest = rhs.nearestDeadline != nil
        if lHasNearest && rHasNearest {
            let lDate = parseDate(lhs.nearestDeadline) ?? .distantFuture
            let rDate = parseDate(rhs.nearestDeadline) ?? .distantFuture
            if lDate != rDate {
                return lDate < rDate
            }
            return lhs.discipline.localizedCaseInsensitiveCompare(rhs.discipline) == .orderedAscending
        }
        if lHasNearest && !rHasNearest {
            return true
        }
        if !lHasNearest && rHasNearest {
            return false
        }
        return lhs.discipline.localizedCaseInsensitiveCompare(rhs.discipline) == .orderedAscending
    }

    nonisolated static func buildCheckpointSummaries(from lessons: [PortalGradeBookLesson]) -> [CheckpointSummaryItem] {
        var cpDates: [String] = []
        for lesson in lessons {
            let controlPointName = lesson.controlPoint.trimmingCharacters(in: .whitespacesAndNewlines)
            if !controlPointName.isEmpty && controlPointName != "Вне КТ" && !cpDates.contains(controlPointName) {
                cpDates.append(controlPointName)
            }
        }
        cpDates.sort { (lhs, rhs) -> Bool in
            let lDate = parseDate(lhs) ?? .distantFuture
            let rDate = parseDate(rhs) ?? .distantFuture
            return lDate < rDate
        }

        guard !cpDates.isEmpty else { return [] }

        var items: [CheckpointSummaryItem] = []
        var previousAverage: Double?

        for (idx, cpDate) in cpDates.enumerated() {
            let cpLessons = lessons.filter {
                $0.controlPoint.trimmingCharacters(in: .whitespacesAndNewlines) == cpDate
            }
            let marks = cpLessons.flatMap(\.marks)
            let avg: Double? = marks.isEmpty ? nil : Double(marks.reduce(0, +)) / Double(marks.count)
            let delta: Double?
            if let avg, let prev = previousAverage {
                delta = round((avg - prev) * 100.0) / 100.0
            } else {
                delta = nil
            }
            if let avg {
                previousAverage = avg
            }

            let absences = cpLessons.reduce(0) { $0 + max($1.gradeBookOmissions, 0) }
            let submittedLabs = cpLessons.filter { $0.lessonTypeId == 4 && !$0.marks.isEmpty }.count

            items.append(
                CheckpointSummaryItem(
                    id: cpDate,
                    number: idx + 1,
                    date: cpDate,
                    averageGrade: avg,
                    delta: delta,
                    absences: absences,
                    submittedLabs: submittedLabs,
                    expectedLabs: nil,
                    isTotal: false,
                    isAfterCp: false
                )
            )
        }

        let allMarks = lessons.flatMap(\.marks)
        let totalAvg: Double? = allMarks.isEmpty ? nil : Double(allMarks.reduce(0, +)) / Double(allMarks.count)
        let totalAbsences = lessons.reduce(0) { $0 + max($1.gradeBookOmissions, 0) }
        let totalLabs = lessons.filter { $0.lessonTypeId == 4 && !$0.marks.isEmpty }.count

        items.append(
            CheckpointSummaryItem(
                id: "total",
                number: nil,
                date: "Итого",
                averageGrade: totalAvg,
                delta: nil,
                absences: totalAbsences,
                submittedLabs: totalLabs,
                expectedLabs: nil,
                isTotal: true,
                isAfterCp: false
            )
        )

        return items
    }

    nonisolated private static let parsingCalendar = Calendar(identifier: .gregorian)

    nonisolated private static func parseDate(_ str: String?) -> Date? {
        guard let str, !str.isEmpty else { return nil }
        let parts = str.split(separator: ".")
        guard parts.count == 3,
              let day = Int(parts[0]),
              let month = Int(parts[1]),
              let year = Int(parts[2]) else { return nil }
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return parsingCalendar.date(from: comps)
    }
}

#if DEBUG
extension RatingViewModel {
    static var preview: RatingViewModel {
        RatingViewModel(isPreview: true)
    }
}
#endif
