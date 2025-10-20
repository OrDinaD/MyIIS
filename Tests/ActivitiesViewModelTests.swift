import XCTest
@testable import MyIIS

@MainActor
final class ActivitiesViewModelTests: XCTestCase {
    private let categories: [ActivityCategory] = [
        ActivityCategory(id: 1, name: "Волонтёрство", shortDescription: nil, iconSystemName: "hands.sparkles"),
        ActivityCategory(id: 2, name: "Спорт", shortDescription: nil, iconSystemName: "sportscourt"),
        ActivityCategory(id: 3, name: "Культура", shortDescription: nil, iconSystemName: "theatermasks"),
        ActivityCategory(id: 4, name: "Наука", shortDescription: nil, iconSystemName: "atom")
    ]

    func testFilteringByCategory() async {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

        let activities: [Activity] = [
            Activity(
                id: 1,
                title: "Спортивный день",
                description: "Утренняя зарядка и игры",
                category: categories[1],
                location: "Стадион",
                startDate: baseDate.addingTimeInterval(3_600),
                endDate: baseDate.addingTimeInterval(7_200),
                registrationDeadline: baseDate.addingTimeInterval(1_800),
                capacity: 30,
                registeredCount: 10
            ),
            Activity(
                id: 2,
                title: "Волонтёрский выезд",
                description: "Помощь приюту",
                category: categories[0],
                location: "Приют",
                startDate: baseDate.addingTimeInterval(86_400),
                endDate: baseDate.addingTimeInterval(90_000),
                registrationDeadline: baseDate.addingTimeInterval(43_200),
                capacity: 20,
                registeredCount: 4
            ),
            Activity(
                id: 3,
                title: "Научная дискуссия",
                description: "Обсуждаем AI",
                category: categories[3],
                location: "Лекторий",
                startDate: baseDate.addingTimeInterval(120_000),
                endDate: baseDate.addingTimeInterval(130_000),
                registrationDeadline: baseDate.addingTimeInterval(100_000),
                capacity: 50,
                registeredCount: 20
            )
        ]

        let service = ActivitiesServiceMock(activities: activities, categories: categories)
        let viewModel = ActivitiesViewModel(service: service, dateProvider: { baseDate })

        await viewModel.loadInitialDataIfNeeded()
        XCTAssertEqual(viewModel.filteredActivities.count, 3)

        viewModel.selectedCategory = categories[0]
        XCTAssertEqual(viewModel.filteredActivities.map(\.id), [2])

        viewModel.selectedCategory = nil
        viewModel.searchQuery = "Науч"
        XCTAssertEqual(viewModel.filteredActivities.map(\.id), [3])
    }

    func testStatusFiltering() async {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

        let past = Activity(
            id: 10,
            title: "Завершённая активность",
            description: "Событие прошло",
            category: categories[0],
            location: "Минск",
            startDate: baseDate.addingTimeInterval(-10_000),
            endDate: baseDate.addingTimeInterval(-5_000),
            registrationDeadline: baseDate.addingTimeInterval(-15_000),
            capacity: 10,
            registeredCount: 8
        )

        let current = Activity(
            id: 11,
            title: "Текущая активность",
            description: "Проходит сейчас",
            category: categories[1],
            location: "Минск",
            startDate: baseDate.addingTimeInterval(-1_000),
            endDate: baseDate.addingTimeInterval(3_000),
            registrationDeadline: baseDate.addingTimeInterval(-2_000),
            capacity: 10,
            registeredCount: 7
        )

        let upcoming = Activity(
            id: 12,
            title: "Будущая активность",
            description: "Состоится позже",
            category: categories[2],
            location: "Минск",
            startDate: baseDate.addingTimeInterval(10_000),
            endDate: baseDate.addingTimeInterval(12_000),
            registrationDeadline: baseDate.addingTimeInterval(5_000),
            capacity: 12,
            registeredCount: 0
        )

        let service = ActivitiesServiceMock(activities: [past, current, upcoming], categories: categories)
        let viewModel = ActivitiesViewModel(service: service, dateProvider: { baseDate })

        await viewModel.loadInitialDataIfNeeded()
        XCTAssertEqual(viewModel.filteredActivities.count, 3)

        viewModel.selectedStatus = .finished
        XCTAssertEqual(viewModel.filteredActivities.map(\.id), [10])

        viewModel.selectedStatus = .inProgress
        XCTAssertEqual(viewModel.filteredActivities.map(\.id), [11])

        viewModel.selectedStatus = .scheduled
        XCTAssertEqual(viewModel.filteredActivities.map(\.id), [12])
    }

    func testRegistrationFlow() async {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let activity = Activity(
            id: 100,
            title: "Регистрация",
            description: "Тестовая регистрация",
            category: categories[0],
            location: "Минск",
            startDate: baseDate.addingTimeInterval(3_600),
            endDate: baseDate.addingTimeInterval(7_200),
            registrationDeadline: baseDate.addingTimeInterval(1_800),
            capacity: 2,
            registeredCount: 1
        )

        let service = ActivitiesServiceMock(activities: [activity], categories: categories)
        let viewModel = ActivitiesViewModel(service: service, dateProvider: { baseDate })

        await viewModel.loadInitialDataIfNeeded()
        XCTAssertEqual(viewModel.activities.first?.userRegistration.isRegistered, false)

        await viewModel.toggleRegistration(for: activity)
        XCTAssertEqual(viewModel.activities.first?.userRegistration.isRegistered, true)
        XCTAssertEqual(viewModel.activities.first?.registeredCount, 2)

        await viewModel.toggleRegistration(for: viewModel.activities[0])
        XCTAssertEqual(viewModel.activities.first?.userRegistration.isRegistered, false)
        XCTAssertEqual(viewModel.activities.first?.registeredCount, 1)
    }
}

actor ActivitiesServiceMock: ActivitiesServiceProtocol {
    private var activities: [Activity]
    private let categories: [ActivityCategory]

    init(activities: [Activity], categories: [ActivityCategory]) {
        self.activities = activities
        self.categories = categories
    }

    func fetchCategories() async throws -> [ActivityCategory] { categories }
    func fetchActivities() async throws -> [Activity] { activities }

    func register(activityID: Activity.ID) async throws -> Activity {
        guard let index = activities.firstIndex(where: { $0.id == activityID }) else {
            throw ActivitiesServiceError.activityNotFound
        }

        var activity = activities[index]
        guard !activity.userRegistration.isRegistered else {
            throw ActivitiesServiceError.alreadyRegistered
        }

        if let capacity = activity.capacity, activity.registeredCount >= capacity {
            throw ActivitiesServiceError.capacityReached
        }

        activity.userRegistration = .registered
        activity.registeredCount += 1
        activities[index] = activity
        return activity
    }

    func unregister(activityID: Activity.ID) async throws -> Activity {
        guard let index = activities.firstIndex(where: { $0.id == activityID }) else {
            throw ActivitiesServiceError.activityNotFound
        }

        var activity = activities[index]
        guard activity.userRegistration.isRegistered else {
            throw ActivitiesServiceError.notRegistered
        }

        activity.userRegistration = .notRegistered
        activity.registeredCount = max(0, activity.registeredCount - 1)
        activities[index] = activity
        return activity
    }
}
