import Foundation
import Combine

@MainActor
final class StudyViewModel: ObservableObject {

    @Published private(set) var plan: StudyPlan?
    @Published private(set) var daySchedules: [StudyDaySchedule] = []
    @Published private(set) var disciplineSummaries: [DisciplineSummary] = []
    @Published private(set) var availableFilters: [StudyWeekFilter] = [.all]
    @Published var selectedFilter: StudyWeekFilter = .all {
        didSet {
            guard oldValue != selectedFilter else { return }
            applyFilter()
        }
    }
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let service: StudyServiceProtocol
    private var currentGroup: String?

    private let dateIntervalFormatter: DateIntervalFormatter
    private let singleDateFormatter: DateFormatter

    init(service: StudyServiceProtocol = StudyService(), initialPlan: StudyPlan? = nil) {
        self.service = service
        let intervalFormatter = DateIntervalFormatter()
        intervalFormatter.locale = Locale(identifier: "ru_RU")
        intervalFormatter.calendar = Calendar(identifier: .gregorian)
        intervalFormatter.dateStyle = .medium
        intervalFormatter.timeStyle = .none
        self.dateIntervalFormatter = intervalFormatter

        let singleFormatter = DateFormatter()
        singleFormatter.locale = Locale(identifier: "ru_RU")
        singleFormatter.calendar = Calendar(identifier: .gregorian)
        singleFormatter.dateStyle = .medium
        singleFormatter.timeStyle = .none
        self.singleDateFormatter = singleFormatter

        if let initialPlan {
            apply(plan: initialPlan)
        }
    }

    var hasContent: Bool {
        !(plan?.isEmpty ?? true) && !daySchedules.isEmpty
    }

    var shouldShowFilters: Bool {
        availableFilters.count > 1
    }

    var groupTitle: String {
        plan?.group?.name ?? "Учебный план"
    }

    var groupSubtitle: String? {
        guard let group = plan?.group else { return nil }
        var components: [String] = []
        if let faculty = group.facultyAbbrev, !faculty.isEmpty {
            components.append(faculty)
        }
        if let speciality = group.specialityAbbrev ?? group.specialityName, !speciality.isEmpty {
            components.append(speciality)
        }
        if let course = group.course, course > 0 {
            components.append("\(course) курс")
        }
        return components.isEmpty ? nil : components.joined(separator: " · ")
    }

    var studyRangeText: String? {
        guard let start = plan?.startDate else { return nil }
        guard let end = plan?.endDate else {
            return singleDateFormatter.string(from: start)
        }
        return dateIntervalFormatter.string(from: start, to: end)
    }

    var examsRangeText: String? {
        guard let start = plan?.startExamsDate, let end = plan?.endExamsDate else { return nil }
        return dateIntervalFormatter.string(from: start, to: end)
    }

    var lessonsCountText: String? {
        let count = daySchedules.reduce(0) { $0 + $1.lessons.count }
        guard count > 0 else { return nil }
        return "Всего пар: \(count)"
    }

    var currentWeekTitle: String {
        selectedFilter.title
    }

    func load(for group: String, force: Bool = false) async {
        if isLoading { return }
        if !force, let currentGroup, currentGroup == group, hasContent { return }

        isLoading = true
        errorMessage = nil

        do {
            let plan = try await service.fetchStudyPlan(for: group)
            currentGroup = group
            apply(plan: plan)
        } catch let apiError as APIError {
            errorMessage = apiError.localizedDescription
        } catch {
            errorMessage = "Не удалось загрузить учебный план."
        }

        isLoading = false
    }

    func refresh() async {
        guard let group = currentGroup ?? plan?.group?.name else { return }
        await load(for: group, force: true)
    }

    private func apply(plan: StudyPlan) {
        self.plan = plan
        disciplineSummaries = plan.uniqueDisciplines()

        var filters: [StudyWeekFilter] = [.all]
        filters.append(contentsOf: plan.availableWeekNumbers.map(StudyWeekFilter.week))
        availableFilters = filters

        let defaultFilter = determineDefaultFilter(for: plan, filters: filters)
        if selectedFilter != defaultFilter {
            selectedFilter = defaultFilter
        } else {
            applyFilter()
        }
    }

    private func applyFilter() {
        guard let plan else {
            daySchedules = []
            return
        }
        daySchedules = plan.orderedSchedule(filter: selectedFilter)
    }

    private func determineDefaultFilter(for plan: StudyPlan, filters: [StudyWeekFilter]) -> StudyWeekFilter {
        guard filters.count > 1 else { return .all }
        if let currentWeek = plan.currentWeekNumber(), filters.contains(.week(currentWeek)) {
            return .week(currentWeek)
        }
        if let firstWeek = plan.availableWeekNumbers.first {
            return .week(firstWeek)
        }
        return .all
    }
}

#if DEBUG
extension StudyViewModel {
    static var preview: StudyViewModel {
        StudyViewModel(initialPlan: .mock)
    }
}
#endif
