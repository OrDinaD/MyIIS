import Combine
import Foundation
import SwiftUI

@MainActor
final class HeadmanViewModel: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case byDate
        case summary
        case weekly
        case responsibles

        var id: String { rawValue }

        var title: String {
            switch self {
            case .byDate: return String(localized: "Пропуски")
            case .summary: return String(localized: "Сводная")
            case .weekly: return String(localized: "Неделя")
            case .responsibles: return String(localized: "Отмечающие")
            }
        }
    }

    @Published var mode: Mode = .byDate
    @Published var selectedDate: Date = Date()
    @Published var selectedWeekAnchorDate: Date = Date()
    @Published var isLoadingAccess = false
    @Published var isLoadingLessons = false
    @Published var isLoadingSummary = false
    @Published var isLoadingWeekly = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var lastUpdateTime: Date?
    @Published var isShowingStaleDataWarning = false
    @Published var hasAccess = false
    @Published var isGroupHead = false
    @Published var currentStudentId: Int?
    @Published var students: [HeadmanStudent] = []
    @Published var responsibleStudentIDs: Set<Int> = []
    @Published var lessonsByDate: [HeadmanLesson] = []
    @Published var subjectOptions: [HeadmanSubjectOption] = []
    @Published var selectedSubjectID: Int?
    @Published var selectedSubgroup: Int = 0
    @Published var summaryStudents: [HeadmanSummaryStudent] = []
    @Published var weeklyStudents: [HeadmanWeeklyStudentSummary] = []
    @Published private(set) var pendingOmissions: [Int: [Int: Int]] = [:]
    @Published private(set) var updatingResponsibleIDs: Set<Int> = []

    private let apiService: APIService
    private let authService: AuthenticationService
    private static var cachedSnapshot: Snapshot?

    private struct Snapshot {
        let hasAccess: Bool
        let isGroupHead: Bool
        let currentStudentId: Int?
        let students: [HeadmanStudent]
        let responsibleStudentIDs: Set<Int>
        let lessonsByDate: [HeadmanLesson]
        let subjectOptions: [HeadmanSubjectOption]
        let selectedSubjectID: Int?
        let selectedSubgroup: Int
        let summaryStudents: [HeadmanSummaryStudent]
        let weeklyStudents: [HeadmanWeeklyStudentSummary]
        let lastUpdateTime: Date?
    }

    init() {
        self.apiService = APIService()
        self.authService = .shared
        applyCachedSnapshotIfAvailable()
    }

    init(apiService: APIService, authService: AuthenticationService) {
        self.apiService = apiService
        self.authService = authService
        applyCachedSnapshotIfAvailable()
    }

    var selectedSubject: HeadmanSubjectOption? {
        subjectOptions.first { $0.id == selectedSubjectID }
    }

    var availableSubgroups: [Int] {
        selectedSubject?.lesson.subgroup.sorted() ?? []
    }

    var canManageResponsibles: Bool {
        isGroupHead
    }

    #if DEBUG
    static func resetCachedSnapshotForTesting() {
        cachedSnapshot = nil
    }
    #endif

    var selectedWeekStartDate: Date {
        Self.weekStart(for: selectedWeekAnchorDate)
    }

    var selectedWeekTitle: String {
        let calendar = Calendar(identifier: .gregorian)
        let start = selectedWeekStartDate
        guard let end = calendar.date(byAdding: .day, value: 5, to: start) else {
            return Self.weekDayFormatter.string(from: start)
        }
        return "\(Self.weekDayFormatter.string(from: start)) - \(Self.weekDayFormatter.string(from: end))"
    }

    func loadInitialData() async {
        guard !isLoadingAccess else { return }
        isLoadingAccess = true
        errorMessage = nil
        successMessage = nil
        isShowingStaleDataWarning = false

        do {
            async let groupHeadRequest = apiService.getHeadmanIsGroupHead()
            async let whoCanNoteRequest = apiService.getHeadmanWhoCanNote()
            async let studentsRequest = apiService.getHeadmanGroupStudents()
            async let subjectsRequest = apiService.getHeadmanSubjects()

            let (groupHead, responsibleIDs, loadedStudents, subjects) = try await (
                groupHeadRequest,
                whoCanNoteRequest,
                studentsRequest,
                subjectsRequest
            )
            applyAccessSnapshot(groupHead: groupHead, responsibleIDs: responsibleIDs, loadedStudents: loadedStudents)
            subjectOptions = Self.flattenSubjects(subjects)
            selectedSubjectID = selectedSubjectID ?? subjectOptions.first?.id
            selectedSubgroup = availableSubgroups.first ?? 0

            if hasAccess {
                await loadLessonsForSelectedDate()
                if selectedSubjectID != nil {
                    await loadSummary()
                }
                await loadWeeklySummary()
            }
            lastUpdateTime = Date()
            saveSnapshot()
        } catch is CancellationError {
            return
        } catch let apiError as APIError {
            handleLoadInitialError(apiError.localizedDescription)
        } catch {
            handleLoadInitialError(error.localizedDescription)
        }

        isLoadingAccess = false
    }

    func refresh() async {
        await loadInitialData()
    }

    func loadLessonsForSelectedDate() async {
        guard hasAccess else { return }
        isLoadingLessons = true
        errorMessage = nil
        pendingOmissions.removeAll()

        do {
            lessonsByDate = try await apiService.getHeadmanLessonsByDate(selectedDate)
            saveSnapshot()
        } catch let apiError as APIError {
            errorMessage = apiError.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingLessons = false
    }

    func selectSubject(_ subjectID: Int) async {
        selectedSubjectID = subjectID
        selectedSubgroup = availableSubgroups.first ?? 0
        await loadSummary()
    }

    func selectSubgroup(_ subgroup: Int) async {
        selectedSubgroup = subgroup
        await loadSummary()
    }

    func loadSummary() async {
        guard hasAccess, let selectedSubjectID else { return }
        isLoadingSummary = true
        errorMessage = nil

        do {
            summaryStudents = try await apiService.getHeadmanSummary(
                subjectId: selectedSubjectID,
                subgroup: selectedSubgroup
            )
            saveSnapshot()
        } catch let apiError as APIError {
            errorMessage = apiError.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingSummary = false
    }

    func selectWeekAnchorDate(_ date: Date) async {
        selectedWeekAnchorDate = date
        await loadWeeklySummary()
    }

    func loadWeeklySummary() async {
        guard hasAccess else { return }
        isLoadingWeekly = true
        errorMessage = nil

        do {
            let calendar = Calendar(identifier: .gregorian)
            let weekStart = Self.weekStart(for: selectedWeekAnchorDate)
            var collectedLessons: [HeadmanLesson] = []

            for dayOffset in 0..<6 {
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
                let lessons = try await apiService.getHeadmanLessonsByDate(day)
                collectedLessons.append(contentsOf: lessons)
            }

            weeklyStudents = Self.buildWeeklySummary(students: students, lessons: collectedLessons)
            saveSnapshot()
        } catch let apiError as APIError {
            errorMessage = apiError.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingWeekly = false
    }

    func setPendingOmission(lessonId: Int, studentId: Int, hours: Int?) {
        var lessonChanges = pendingOmissions[lessonId] ?? [:]
        if let hours {
            lessonChanges[studentId] = hours
        } else {
            lessonChanges.removeValue(forKey: studentId)
        }
        pendingOmissions[lessonId] = lessonChanges.isEmpty ? nil : lessonChanges
        successMessage = nil
    }

    func pendingHours(lessonId: Int, studentId: Int) -> Int? {
        pendingOmissions[lessonId]?[studentId]
    }

    func saveOmissions(for lesson: HeadmanLesson) async {
        let changes = pendingOmissions[lesson.id] ?? [:]
        guard !changes.isEmpty else { return }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let request = changes
                .sorted { $0.key < $1.key }
                .map { HeadmanStudentOmissionHours(student: $0.key, hours: $0.value) }
            let updatedStudents = try await apiService.createHeadmanOmissions(
                lessonId: lesson.id,
                omissions: request
            )
            applySavedOmissions(updatedStudents, lessonId: lesson.id)
            pendingOmissions[lesson.id] = nil
            successMessage = String(localized: "Пропуски сохранены.")
            await loadSummary()
            await loadWeeklySummary()
        } catch let apiError as APIError {
            errorMessage = apiError.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    func setResponsible(_ isResponsible: Bool, for student: HeadmanStudent) async {
        guard isGroupHead else { return }
        updatingResponsibleIDs.insert(student.id)
        errorMessage = nil
        successMessage = nil

        do {
            if isResponsible {
                try await apiService.assignHeadmanResponsible(studentId: student.id)
                responsibleStudentIDs.insert(student.id)
            } else {
                try await apiService.removeHeadmanResponsible(studentId: student.id)
                responsibleStudentIDs.remove(student.id)
            }

            students = students.map { current in
                var updated = current
                updated.isResponsible = responsibleStudentIDs.contains(current.id)
                return updated
            }
            hasAccess = isGroupHead || currentStudentId.map { responsibleStudentIDs.contains($0) } == true
        } catch let apiError as APIError {
            errorMessage = apiError.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        updatingResponsibleIDs.remove(student.id)
    }

}

private extension HeadmanViewModel {
    func applyAccessSnapshot(groupHead: Bool, responsibleIDs: [Int], loadedStudents: [HeadmanStudent]) {
        isGroupHead = groupHead
        responsibleStudentIDs = Set(responsibleIDs)
        currentStudentId = resolveCurrentStudentID(from: loadedStudents)
        students = loadedStudents.map { student in
            var updated = student
            updated.isResponsible = responsibleStudentIDs.contains(student.id)
            return updated
        }
        hasAccess = groupHead || currentStudentId.map { responsibleStudentIDs.contains($0) } == true
    }

    func applyCachedSnapshotIfAvailable() {
        guard let snapshot = Self.cachedSnapshot else { return }
        hasAccess = snapshot.hasAccess
        isGroupHead = snapshot.isGroupHead
        currentStudentId = snapshot.currentStudentId
        students = snapshot.students
        responsibleStudentIDs = snapshot.responsibleStudentIDs
        lessonsByDate = snapshot.lessonsByDate
        subjectOptions = snapshot.subjectOptions
        selectedSubjectID = snapshot.selectedSubjectID
        selectedSubgroup = snapshot.selectedSubgroup
        summaryStudents = snapshot.summaryStudents
        weeklyStudents = snapshot.weeklyStudents
        lastUpdateTime = snapshot.lastUpdateTime
    }

    func saveSnapshot() {
        Self.cachedSnapshot = Snapshot(
            hasAccess: hasAccess,
            isGroupHead: isGroupHead,
            currentStudentId: currentStudentId,
            students: students,
            responsibleStudentIDs: responsibleStudentIDs,
            lessonsByDate: lessonsByDate,
            subjectOptions: subjectOptions,
            selectedSubjectID: selectedSubjectID,
            selectedSubgroup: selectedSubgroup,
            summaryStudents: summaryStudents,
            weeklyStudents: weeklyStudents,
            lastUpdateTime: lastUpdateTime
        )
    }

    func handleLoadInitialError(_ message: String) {
        if !students.isEmpty {
            isShowingStaleDataWarning = true
        }
        errorMessage = message
    }

    func resolveCurrentStudentID(from students: [HeadmanStudent]) -> Int? {
        guard let user = authService.currentUser else { return nil }
        if let byUsername = students.first(where: { Int($0.username) == user.id }) {
            return byUsername.id
        }
        if let byName = students.first(where: { $0.fio == user.fullName }) {
            return byName.id
        }
        return nil
    }

    func applySavedOmissions(_ updatedStudents: [HeadmanLessonStudent], lessonId: Int) {
        guard !updatedStudents.isEmpty,
              let lessonIndex = lessonsByDate.firstIndex(where: { $0.id == lessonId }) else {
            return
        }

        let updatedByID = Dictionary(uniqueKeysWithValues: updatedStudents.map { ($0.id, $0) })
        lessonsByDate[lessonIndex].students = lessonsByDate[lessonIndex].students.map { student in
            var updated = student
            if let savedStudent = updatedByID[student.id] {
                updated.omission = savedStudent.omission
            }
            return updated
        }
    }

    static let weekDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM"
        return formatter
    }()

    static func weekStart(for date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }

    static func buildWeeklySummary(students: [HeadmanStudent], lessons: [HeadmanLesson]) -> [HeadmanWeeklyStudentSummary] {
        var totalsByStudent = Dictionary(uniqueKeysWithValues: students.map { ($0.id, HeadmanWeeklyTotals()) })

        for lesson in lessons {
            guard let category = HeadmanLessonCategory(lessonTypeAbbrev: lesson.lessonTypeAbbrev) else { continue }
            for lessonStudent in lesson.students {
                guard let omission = lessonStudent.omission,
                      let hours = omission.missedHours,
                      hours > 0 else {
                    continue
                }

                var totals = totalsByStudent[lessonStudent.id] ?? HeadmanWeeklyTotals()
                totals.add(hours: hours, isRespectful: omission.respectfulOmission == true, category: category)
                totalsByStudent[lessonStudent.id] = totals
            }
        }

        return students.map { student in
            HeadmanWeeklyStudentSummary(
                id: student.id,
                fio: student.fio,
                totals: totalsByStudent[student.id] ?? HeadmanWeeklyTotals()
            )
        }
    }

    static func flattenSubjects(_ subjects: [String: [HeadmanSubjectLesson]]) -> [HeadmanSubjectOption] {
        subjects
            .flatMap { subject, lessons in
                lessons.map { HeadmanSubjectOption(subjectName: subject, lesson: $0) }
            }
            .sorted {
                if $0.subjectName != $1.subjectName {
                    return $0.subjectName.localizedCaseInsensitiveCompare($1.subjectName) == .orderedAscending
                }
                return $0.lesson.lessonTypeAbbrev.localizedCaseInsensitiveCompare($1.lesson.lessonTypeAbbrev) == .orderedAscending
            }
    }
}
