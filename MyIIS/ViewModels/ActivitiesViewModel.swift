import Combine
import Foundation

@MainActor
final class ActivitiesViewModel: ObservableObject {
    @Published private(set) var activities: [Activity] = []
    @Published private(set) var categories: [ActivityCategory] = []
    @Published var selectedCategory: ActivityCategory?
    @Published var selectedStatus: ActivityStatus?
    @Published var showOnlyAvailable: Bool = false
    @Published var showOnlyRegistered: Bool = false
    @Published var searchQuery: String = ""
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var registrationsInProgress: Set<Activity.ID> = []
    @Published var errorMessage: String?
    @Published private(set) var lastUpdated: Date?

    private let service: ActivitiesServiceProtocol
    private let dateProvider: () -> Date
    private var hasLoaded = false

    init(
        service: ActivitiesServiceProtocol = ActivitiesService(),
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.service = service
        self.dateProvider = dateProvider
    }

    var filteredActivities: [Activity] {
        let now = dateProvider()
        return activities.filter { activity in
            if let selectedCategory, activity.category != selectedCategory {
                return false
            }

            if let selectedStatus, activity.status(at: now) != selectedStatus {
                return false
            }

            if showOnlyAvailable && !activity.isRegistrationOpen(at: now) {
                return false
            }

            if showOnlyRegistered && !activity.userRegistration.isRegistered {
                return false
            }

            if !searchQuery.isEmpty {
                let query = searchQuery.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                let haystack = [
                    activity.title,
                    activity.subtitle ?? "",
                    activity.description,
                    activity.category.name,
                    activity.location
                ].joined(separator: " ")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

                if !haystack.contains(query) {
                    return false
                }
            }

            return true
        }
        .sorted { lhs, rhs in
            if lhs.startDate == rhs.startDate {
                return lhs.title < rhs.title
            }
            return lhs.startDate < rhs.startDate
        }
    }

    var activeFiltersCount: Int {
        var count = 0
        if selectedCategory != nil { count += 1 }
        if selectedStatus != nil { count += 1 }
        if showOnlyAvailable { count += 1 }
        if showOnlyRegistered { count += 1 }
        if !searchQuery.isEmpty { count += 1 }
        return count
    }

    var currentDate: Date { dateProvider() }

    func loadInitialDataIfNeeded() async {
        guard !hasLoaded else { return }
        await reload()
    }

    func reload() async {
        if isLoading { return }
        isLoading = true
        errorMessage = nil

        do {
            async let categoriesTask = service.fetchCategories()
            async let activitiesTask = service.fetchActivities()

            let (loadedCategories, loadedActivities) = try await (categoriesTask, activitiesTask)
            categories = loadedCategories
            activities = loadedActivities
            lastUpdated = dateProvider()
            hasLoaded = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Не удалось загрузить активности"
        }

        isLoading = false
    }

    func toggleRegistration(for activity: Activity) async {
        if registrationsInProgress.contains(activity.id) {
            return
        }

        registrationsInProgress.insert(activity.id)
        defer { registrationsInProgress.remove(activity.id) }

        do {
            let updatedActivity: Activity
            if activity.userRegistration.isRegistered {
                updatedActivity = try await service.unregister(activityID: activity.id)
            } else {
                updatedActivity = try await service.register(activityID: activity.id)
            }

            updateStoredActivity(with: updatedActivity)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Не удалось обновить регистрацию"
        }
    }

    func resetFilters() {
        selectedCategory = nil
        selectedStatus = nil
        showOnlyAvailable = false
        showOnlyRegistered = false
        searchQuery = ""
    }

    private func updateStoredActivity(with activity: Activity) {
        if let index = activities.firstIndex(where: { $0.id == activity.id }) {
            activities[index] = activity
        }
    }
}
