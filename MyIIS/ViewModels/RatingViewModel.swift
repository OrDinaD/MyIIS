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

        var mappedDisciplines: [GradebookDiscipline] = []
        var omissions: [String: Int] = [:]

        for (subject, subjectLessons) in grouped {
            let lessonTypes = Set(subjectLessons.map(\.lessonTypeAbbrev))
                .filter { !$0.isEmpty }
                .sorted()

            let sortedLessons = subjectLessons.sorted {
                if $0.controlPoint != $1.controlPoint {
                    return $0.controlPoint < $1.controlPoint
                }
                return $0.dateString < $1.dateString
            }

            var attempts: [GradeAttempt] = []
            var attemptNumber = 1
            var lessonOmissions: [GradeOmission] = []

            for lesson in sortedLessons {
                for mark in lesson.marks {
                    attempts.append(
                        GradeAttempt(
                            attempt: attemptNumber,
                            type: lesson.lessonTypeAbbrev,
                            grade: .numeric(Double(mark)),
                            date: lesson.dateString,
                            status: .passed
                        )
                    )
                    attemptNumber += 1
                }

                if !lesson.isRespectfulOmission && lesson.gradeBookOmissions > 0 {
                    lessonOmissions.append(
                        GradeOmission(
                            date: lesson.dateString,
                            type: lesson.lessonTypeAbbrev,
                            hours: lesson.gradeBookOmissions
                        )
                    )
                }
            }

            let omissionHours = lessonOmissions.reduce(0) { $0 + $1.hours }
            omissions[subject] = omissionHours

            mappedDisciplines.append(
                GradebookDiscipline(
                    code: "gradebook_\(subject)",
                    name: subject,
                    controlForm: lessonTypes.isEmpty ? "Занятия" : lessonTypes.joined(separator: " · "),
                    teacher: nil,
                    hours: omissionHours,
                    attempts: attempts,
                    lessonOmissions: lessonOmissions.isEmpty ? nil : lessonOmissions
                )
            )
        }

        disciplines = mappedDisciplines.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        subjectOmissions = omissions
        isUsingScheduleFallback = false
    }

    private func buildPersonalRating(from lessons: [PortalGradeBookLesson], targetRecordBookNumber: String?) {
        let numericMarks = lessons.flatMap { $0.marks }.map(Double.init)
        let totalMissedHours = lessons
            .filter { !$0.isRespectfulOmission }
            .reduce(0) { $0 + max($1.gradeBookOmissions, 0) }

        let checkpointGroups = Dictionary(grouping: lessons.compactMap { lesson -> (String, PortalGradeBookLesson)? in
            let controlPoint = lesson.controlPoint.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !controlPoint.isEmpty else {
                return nil
            }
            return (controlPoint, lesson)
        }) { $0.0 }

        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        let sortedKeys = checkpointGroups.keys.sorted { key1, key2 in
            let dates1 = checkpointGroups[key1]!.compactMap { formatter.date(from: $0.1.dateString) }
            let dates2 = checkpointGroups[key2]!.compactMap { formatter.date(from: $0.1.dateString) }
            let min1 = dates1.min() ?? Date.distantFuture
            let min2 = dates2.min() ?? Date.distantFuture
            return min1 < min2
        }

        let checkpoints: [RatingCheckpoint] = sortedKeys.enumerated().map { index, key in
            let scopedLessons = (checkpointGroups[key] ?? []).map { $0.1 }
            let marks = scopedLessons.flatMap { $0.marks }.map(Double.init)
            let average = Self.average(marks)
            let missed = scopedLessons
                .filter { !$0.isRespectfulOmission }
                .reduce(0) { $0 + max($1.gradeBookOmissions, 0) }

            let number = Self.checkpointNumber(from: key) ?? (index + 1)

            return RatingCheckpoint(
                number: number,
                title: key,
                averageGrade: average,
                missedHours: missed
            )
        }

        let resolvedId = normalizeRecordBookNumber(targetRecordBookNumber)
        let recordBookNumber = resolvedId.isEmpty ? "portal-grade-book" : resolvedId

        let personalRating = StudentRating(
            recordBookNumber: recordBookNumber,
            studentName: nil,
            averageGrade: Self.average(numericMarks),
            missedHours: totalMissedHours,
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
