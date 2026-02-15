import Foundation

protocol ActivitiesServiceProtocol {
    func fetchCategories() async throws -> [ActivityCategory]
    func fetchActivities() async throws -> [Activity]
    func register(activityID: Activity.ID) async throws -> Activity
    func unregister(activityID: Activity.ID) async throws -> Activity
}

enum ActivitiesServiceError: Error, LocalizedError {
    case activityNotFound
    case registrationClosed
    case alreadyRegistered
    case notRegistered
    case capacityReached

    var errorDescription: String? {
        switch self {
        case .activityNotFound:
            return "Мероприятие не найдено"
        case .registrationClosed:
            return "Регистрация закрыта"
        case .alreadyRegistered:
            return "Вы уже зарегистрированы на мероприятие"
        case .notRegistered:
            return "Вы ещё не зарегистрированы на мероприятие"
        case .capacityReached:
            return "Свободных мест не осталось"
        }
    }
}

actor ActivitiesService: ActivitiesServiceProtocol {
    private var activitiesStorage: [Activity]
    private let categoriesStorage: [ActivityCategory]
    private let dateProvider: () -> Date
    private let responseDelay: UInt64

    init(
        activities: [Activity] = Activity.previewActivities,
        categories: [ActivityCategory] = ActivityCategory.previewCategories,
        dateProvider: @escaping () -> Date = Date.init,
        responseDelay: UInt64 = 250_000_000
    ) {
        self.activitiesStorage = activities
        self.categoriesStorage = categories
        self.dateProvider = dateProvider
        self.responseDelay = responseDelay
    }

    func fetchCategories() async throws -> [ActivityCategory] {
        try await simulateDelay()
        return categoriesStorage
    }

    func fetchActivities() async throws -> [Activity] {
        try await simulateDelay()
        return sortedActivities()
    }

    func register(activityID: Activity.ID) async throws -> Activity {
        try await simulateDelay()
        guard let index = activitiesStorage.firstIndex(where: { $0.id == activityID }) else {
            throw ActivitiesServiceError.activityNotFound
        }

        var activity = activitiesStorage[index]
        let now = dateProvider()

        guard activity.isRegistrationOpen(at: now) else {
            throw ActivitiesServiceError.registrationClosed
        }

        guard !activity.userRegistration.isRegistered else {
            throw ActivitiesServiceError.alreadyRegistered
        }

        if let capacity = activity.capacity, activity.registeredCount >= capacity {
            throw ActivitiesServiceError.capacityReached
        }

        activity.userRegistration = .registered
        activity.registeredCount += 1
        activitiesStorage[index] = activity
        return activity
    }

    func unregister(activityID: Activity.ID) async throws -> Activity {
        try await simulateDelay()
        guard let index = activitiesStorage.firstIndex(where: { $0.id == activityID }) else {
            throw ActivitiesServiceError.activityNotFound
        }

        var activity = activitiesStorage[index]

        guard activity.userRegistration.isRegistered else {
            throw ActivitiesServiceError.notRegistered
        }

        activity.userRegistration = .notRegistered
        activity.registeredCount = max(0, activity.registeredCount - 1)
        activitiesStorage[index] = activity
        return activity
    }

    private func sortedActivities() -> [Activity] {
        activitiesStorage.sorted { lhs, rhs in
            if lhs.startDate == rhs.startDate {
                return lhs.title < rhs.title
            }
            return lhs.startDate < rhs.startDate
        }
    }

    private func simulateDelay() async throws {
        guard responseDelay > 0 else { return }
        try await Task.sleep(nanoseconds: responseDelay)
    }
}

// MARK: - Previews

extension ActivitiesService {
    static let preview = ActivitiesService(responseDelay: 0)
}
