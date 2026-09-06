import Combine
import Foundation

@Observable
@MainActor
final class GradebookViewModel {

    var markbook: MarkbookResponse?
    var semesterKeys: [String] = []
    var selectedSemesterKey: String?
    var currentCourse: Int?
    var isLoading: Bool = false
    var errorMessage: String?
    var lastUpdateTime: Date?
    var isShowingStaleDataWarning = false
    var isCheckingForUpdates = false

    private let apiService: APIService
    private let authService: AuthenticationService
    private var hasLoadedOnce = false
    private let staleWarningInterval: TimeInterval = 5 * 60

    init(apiService: APIService? = nil, authService: AuthenticationService = .shared) {
        self.apiService = apiService ?? APIService()
        self.authService = authService
        loadCache()
    }

    var selectedSemester: MarkbookSemester? {
        guard let key = selectedSemesterKey else { return nil }
        return markbook?.markPages[key]
    }

    var numberText: String {
        markbook?.number ?? "—"
    }

    var overallAverageText: String {
        guard let value = markbook?.averageMark else { return "—" }
        return value.formatted(.number.precision(.fractionLength(2)))
    }

    var semesterAverageText: String {
        guard let value = selectedSemester?.averageMark else { return "—" }
        return value.formatted(.number.precision(.fractionLength(2)))
    }

    var yearlyAverage: Double? {
        guard let selectedSemKey = selectedSemesterKey, let selectedSem = Int(selectedSemKey) else { return nil }

        let isOdd = selectedSem % 2 != 0
        let pairSem = isOdd ? selectedSem + 1 : selectedSem - 1

        let semKeysToAverage = [String(selectedSem), String(pairSem)]
        var totalNumericMarks = 0.0
        var numericMarksCount = 0

        for key in semKeysToAverage {
            if let sem = markbook?.markPages[key] {
                for mark in sem.marks {
                    if let numericValue = Double(mark.mark) {
                        totalNumericMarks += numericValue
                        numericMarksCount += 1
                    }
                }
            }
        }

        guard numericMarksCount > 0 else { return nil }
        return totalNumericMarks / Double(numericMarksCount)
    }

    var yearlyAverageText: String {
        guard let value = yearlyAverage else { return "—" }
        return value.formatted(.number.precision(.fractionLength(2)))
    }

    var marksForSelectedSemester: [MarkbookMark] {
        selectedSemester?.marks ?? []
    }

    func loadIfNeeded() async {
        guard !hasLoadedOnce else { return }
        hasLoadedOnce = true
        await load(showLoading: markbook == nil)
    }

    func load() async {
        await load(showLoading: markbook == nil)
    }

    func refresh() async {
        await load(showLoading: true)
    }

    private func load(showLoading: Bool) async {
        if isLoading || isCheckingForUpdates { return }

        if showLoading {
            isLoading = true
        } else {
            isCheckingForUpdates = true
        }
        defer {
            isLoading = false
            isCheckingForUpdates = false
        }

        errorMessage = nil
        isShowingStaleDataWarning = false

        do {
            async let markbookRequest = apiService.getMarkbook()
            let knownCourse = authService.currentUser?.education.course ?? currentCourse
            let resolvedCourse: Int?
            if let knownCourse {
                resolvedCourse = knownCourse
            } else {
                resolvedCourse = try? await apiService.getPersonalProfile().course
            }

            let markbook = try await markbookRequest
            let now = Date()
            apply(markbook: markbook, currentCourse: resolvedCourse)
            lastUpdateTime = now
            saveCache(markbook: markbook, currentCourse: resolvedCourse, updatedAt: now)
        } catch is CancellationError {
            return
        } catch let apiError as APIError {
            applyErrorMessage(apiError.localizedDescription)
        } catch {
            applyErrorMessage(error.localizedDescription)
        }
    }

    private func applyErrorMessage(_ message: String) {
        if markbook != nil {
            if shouldShowStaleWarning {
                isShowingStaleDataWarning = true
                errorMessage = message
            } else {
                isShowingStaleDataWarning = false
                errorMessage = nil
            }
        } else {
            errorMessage = message
        }
    }

    private var shouldShowStaleWarning: Bool {
        guard let lastUpdateTime else { return true }
        return Date().timeIntervalSince(lastUpdateTime) > staleWarningInterval
    }

    func selectSemester(_ key: String) {
        guard semesterKeys.contains(key) else { return }
        selectedSemesterKey = key
    }

    private func apply(markbook: MarkbookResponse, currentCourse: Int?) {
        self.markbook = markbook
        self.currentCourse = currentCourse
        MyIISDataStore.update(averageScore: markbook.averageMark)
        saveGradebookMessageSnapshot(markbook: markbook)

        updateSemesterSelection(with: markbook)
    }

    private func apply(markbook: MarkbookResponse, personalProfile: PersonalProfile) {
        apply(markbook: markbook, currentCourse: personalProfile.course)
    }

    private func applyCached(markbook: MarkbookResponse, currentCourse: Int?, updatedAt: Date) {
        self.markbook = markbook
        self.currentCourse = currentCourse
        self.lastUpdateTime = updatedAt
        MyIISDataStore.update(averageScore: markbook.averageMark)
        saveGradebookMessageSnapshot(markbook: markbook)

        updateSemesterSelection(with: markbook)
    }

    private func updateSemesterSelection(with markbook: MarkbookResponse) {
        let previousSelection = selectedSemesterKey
        semesterKeys = sortSemesterKeys(markbook.markPages.keys)

        if let previousSelection, semesterKeys.contains(previousSelection) {
            selectedSemesterKey = previousSelection
        } else {
            selectedSemesterKey = Self.resolveDefaultSemesterKey(
                from: semesterKeys,
                markPages: markbook.markPages,
                currentCourse: currentCourse
            )
        }
    }

    func sortSemesterKeys<S: Sequence>(_ keys: S) -> [String] where S.Element == String {
        keys.sorted { lhs, rhs in
            (Int(lhs) ?? Int.min) < (Int(rhs) ?? Int.min)
        }
    }

    static func resolveDefaultSemesterKey(
        from keys: [String],
        markPages: [String: MarkbookSemester],
        currentCourse: Int?,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        guard !keys.isEmpty else { return nil }

        if let course = currentCourse, course > 0 {
            let month = calendar.component(.month, from: referenceDate)
            let isAutumnSemester = month >= 9 || month == 1
            let expectedSemester = isAutumnSemester ? (course * 2 - 1) : (course * 2)
            let expectedKey = String(expectedSemester)
            if keys.contains(expectedKey) {
                return expectedKey
            }
        }

        if let latestWithMarks = keys.reversed().first(where: { key in
            !(markPages[key]?.marks.isEmpty ?? true)
        }) {
            return latestWithMarks
        }

        return keys.last
    }

    private func saveGradebookMessageSnapshot(markbook: MarkbookResponse) {
        let semesters = sortSemesterKeys(markbook.markPages.keys).compactMap { key -> MyIISGradebookMessageSnapshot.Semester? in
            guard let semester = markbook.markPages[key] else { return nil }
            return MyIISGradebookMessageSnapshot.Semester(
                id: key,
                averageText: formattedAverage(semester.averageMark),
                subjects: semester.marks.map(makeMessageSnapshotSubject)
            )
        }

        let snapshot = MyIISGradebookMessageSnapshot(
            number: markbook.number.nonEmptyOrDash,
            overallAverageText: formattedAverage(markbook.averageMark),
            updatedAt: Date(),
            semesters: semesters
        )
        MyIISDataStore.saveGradebookMessageSnapshot(snapshot)
    }

    private func makeMessageSnapshotSubject(from mark: MarkbookMark) -> MyIISGradebookMessageSnapshot.Subject {
        MyIISGradebookMessageSnapshot.Subject(
            id: mark.id,
            abbreviation: mark.subject.nonEmptyOrDash,
            fullName: mark.fullSubject.nonEmptyOrDash,
            controlForm: mark.formOfControl.nonEmptyOrDash,
            grade: mark.displayGrade.nonEmptyOrDash,
            averageText: mark.averageForLastFourYearsText ?? "—",
            retakesText: mark.displayRetakes.nonEmptyOrDash,
            dateText: mark.date.nonEmptyOrDash,
            teacherText: mark.teacher.nonEmptyOrDash
        )
    }

    private func formattedAverage(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }

    private func saveCache(markbook: MarkbookResponse, currentCourse: Int?, updatedAt: Date) {
        GradebookCacheStore.save(markbook: markbook, currentCourse: currentCourse, updatedAt: updatedAt)
    }

    private func loadCache() {
        guard let snapshot = GradebookCacheStore.load() else {
            return
        }

        applyCached(markbook: snapshot.markbook, currentCourse: snapshot.currentCourse, updatedAt: snapshot.updatedAt)
    }
}

private extension Optional where Wrapped == String {
    var nonEmptyOrDash: String {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return "—"
        }
        return value
    }
}

private extension String {
    var nonEmptyOrDash: String {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "—" : value
    }
}

#if DEBUG
extension GradebookViewModel {
    static var preview: GradebookViewModel {
        let viewModel = GradebookViewModel()
        viewModel.markbook = MarkbookResponse(number: "42850012", averageMark: 9.59, markPages: [
            "3": MarkbookSemester(averageMark: 10.0, marks: [
                MarkbookMark(
                    subject: "АПЭЦ", formOfControl: "Зачет",
                    fullSubject: "Автоматизированное проектирование электрических цепей",
                    hours: "108.0", credits: 3.0, mark: "зач", date: "30.12.2025",
                    teacher: "Шилин Л. Ю.", commonMark: nil, commonRetakes: nil, retakesCount: 0
                ),
                MarkbookMark(
                    subject: "ООП", formOfControl: "Курс. работа",
                    fullSubject: "Объектно-ориентированное программирование",
                    hours: "30.0", credits: 1.0, mark: "10", date: "29.12.2025",
                    teacher: "Ючков А. К.", commonMark: 7.49, commonRetakes: 0.025, retakesCount: 0
                )
            ])
        ])
        viewModel.semesterKeys = ["3"]
        viewModel.selectedSemesterKey = "3"
        viewModel.currentCourse = 3
        return viewModel
    }
}
#endif
