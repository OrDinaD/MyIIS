import Combine
import Foundation

@MainActor
final class RatingViewModel: ObservableObject {

    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoadingSubjects: Bool = false
    @Published private(set) var isGradebookUnavailable: Bool = false
    @Published private(set) var isUsingScheduleFallback: Bool = false
    @Published private(set) var isShowingStaleDataWarning: Bool = false
    @Published private(set) var lastUpdateTime: Date?
    @Published private(set) var students: [StudentRating] = []
    @Published private(set) var checkpointNumbers: [Int] = []
    @Published private(set) var summary: RatingSummary?
    @Published private(set) var disciplines: [GradebookDiscipline] = []
    @Published private(set) var subjectOmissions: [String: Int] = [:]
    @Published private(set) var userCheckpoints: [RatingCheckpoint] = []
    @Published private(set) var gradebookAverage: Double?

    private let apiService: APIService
    private let logService = LogService.shared
    private var currentGroup: String?
    private var currentStudentId: String?
    private var resolvedRecordBookNumber: String?
    private let isPreview: Bool
    private var backgroundRefreshTask: Task<Void, Never>?

    private struct RatingCacheSnapshot {
        let students: [StudentRating]
        let checkpointNumbers: [Int]
        let summary: RatingSummary?
        let disciplines: [GradebookDiscipline]
        let subjectOmissions: [String: Int]
        let userCheckpoints: [RatingCheckpoint]
        let gradebookAverage: Double?
        let isGradebookUnavailable: Bool
        let resolvedRecordBookNumber: String?
        let currentGroup: String
        let currentStudentId: String
        let updatedAt: Date
    }

    private static var ratingCacheByKey: [String: RatingCacheSnapshot] = [:]

    init(
        apiService: APIService? = nil,
        isPreview: Bool = false
    ) {
        self.apiService = apiService ?? APIService()
        self.isPreview = isPreview

        if isPreview {
            students = StudentRating.previewData
            checkpointNumbers = Self.makeCheckpointNumbers(from: students)
            summary = RatingSummary(students: students)
            disciplines = Gradebook.previewData.semesters.flatMap { $0.sortedDisciplines() }
            gradebookAverage = Gradebook.previewData.averageGrade
            userCheckpoints = students.first?.checkpoints.sorted { $0.number < $1.number } ?? []
            isGradebookUnavailable = false
            isUsingScheduleFallback = false
            isLoadingSubjects = false
        }
    }

    deinit {
        backgroundRefreshTask?.cancel()
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

        if !force,
           currentGroup == group,
           currentStudentId == studentId,
           !students.isEmpty || !disciplines.isEmpty {
            return
        }

        if !force, applyCachedSnapshotIfAvailable(group: group, studentId: studentId) {
            scheduleBackgroundRefresh(for: user)
            return
        }

        await loadByGroup(group, targetRecordBookNumber: studentId, force: force)

        currentStudentId = studentId
        saveCurrentStateToCache(group: group, studentId: studentId)
    }

    private func loadByGroup(_ group: String?, targetRecordBookNumber: String?, force: Bool) async {
        guard !isPreview else { return }

        guard let group, !group.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Не удалось определить номер группы"
            return
        }

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
        isUsingScheduleFallback = false
        isShowingStaleDataWarning = false

        await loadFromPortalGradeBook(targetRecordBookNumber: targetRecordBookNumber)

        isLoadingSubjects = false
        isLoading = false
        currentGroup = group
        currentStudentId = cacheStudentId

        if errorMessage != nil, applyCachedSnapshotIfAvailable(group: group, studentId: cacheStudentId) {
            isShowingStaleDataWarning = true
        } else if errorMessage == nil {
            lastUpdateTime = Date()
        }
    }

    private func cacheKey(group: String, studentId: String) -> String {
        "\(group)|\(studentId)"
    }

    private func applyCachedSnapshotIfAvailable(group: String, studentId: String) -> Bool {
        let key = cacheKey(group: group, studentId: studentId)
        guard let cached = Self.ratingCacheByKey[key] else { return false }

        students = cached.students
        checkpointNumbers = cached.checkpointNumbers
        summary = cached.summary
        disciplines = cached.disciplines
        subjectOmissions = cached.subjectOmissions
        userCheckpoints = cached.userCheckpoints
        gradebookAverage = cached.gradebookAverage
        isGradebookUnavailable = cached.isGradebookUnavailable
        isUsingScheduleFallback = false
        resolvedRecordBookNumber = cached.resolvedRecordBookNumber
        currentGroup = cached.currentGroup
        currentStudentId = cached.currentStudentId
        lastUpdateTime = cached.updatedAt
        errorMessage = nil
        return true
    }

    private func saveCurrentStateToCache(group: String, studentId: String) {
        let key = cacheKey(group: group, studentId: studentId)
        Self.ratingCacheByKey[key] = RatingCacheSnapshot(
            students: students,
            checkpointNumbers: checkpointNumbers,
            summary: summary,
            disciplines: disciplines,
            subjectOmissions: subjectOmissions,
            userCheckpoints: userCheckpoints,
            gradebookAverage: gradebookAverage,
            isGradebookUnavailable: isGradebookUnavailable,
            resolvedRecordBookNumber: resolvedRecordBookNumber,
            currentGroup: group,
            currentStudentId: studentId,
            updatedAt: Date()
        )
    }

    private func scheduleBackgroundRefresh(for user: User) {
        backgroundRefreshTask?.cancel()
        backgroundRefreshTask = Task { [weak self] in
            guard let self else { return }
            await self.loadCombined(for: user, force: true)
        }
    }

    private func loadFromPortalGradeBook(targetRecordBookNumber: String?) async {
        do {
            let lessons = try await apiService.getPortalGradeBookLessons()

            guard !lessons.isEmpty else {
                disciplines = []
                subjectOmissions = [:]
                students = []
                userCheckpoints = []
                checkpointNumbers = []
                summary = nil
                gradebookAverage = nil
                isGradebookUnavailable = true
                errorMessage = "В ответе grade-book нет данных по предметам."
                return
            }

            applyPortalGradeBookLessons(lessons)
            buildPersonalRating(from: lessons, targetRecordBookNumber: targetRecordBookNumber)
            isGradebookUnavailable = disciplines.isEmpty
            errorMessage = nil
            logService.log("✅ Rating loaded from grade-book only. Lessons: \(lessons.count), disciplines: \(disciplines.count)")
        } catch let error as APIError {
            logService.log("❌ grade-book API error: \(error.localizedDescription)")
            disciplines = []
            subjectOmissions = [:]
            students = []
            userCheckpoints = []
            checkpointNumbers = []
            summary = nil
            gradebookAverage = nil
            isGradebookUnavailable = true
            errorMessage = error.localizedDescription
        } catch {
            logService.log("❌ Unexpected grade-book error: \(error.localizedDescription)")
            disciplines = []
            subjectOmissions = [:]
            students = []
            userCheckpoints = []
            checkpointNumbers = []
            summary = nil
            gradebookAverage = nil
            isGradebookUnavailable = true
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
        for mark in lesson.marks {
            attempts.append(
                GradeAttempt(
                    attempt: attempts.count + 1,
                    type: lesson.lessonTypeAbbrev,
                    grade: .numeric(Double(mark)),
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
}

#if DEBUG
extension RatingViewModel {
    static var preview: RatingViewModel {
        RatingViewModel(isPreview: true)
    }
}
#endif
