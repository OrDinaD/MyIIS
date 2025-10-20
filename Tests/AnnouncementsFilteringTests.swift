import Foundation

struct AnnouncementsTestFailure: Error, CustomStringConvertible {
    let message: String

    var description: String { message }
}

@main
enum AnnouncementsFilteringTests {
    static func main() async {
        do {
            try await runSortingTest()
            try await runFilteringTest()
            print("Announcements filtering tests passed")
        } catch {
            fputs("Announcements filtering tests failed: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func runSortingTest() async throws {
        let now = Date()
        let categories = sampleCategories()
        let announcements = [
            Announcement(
                id: "pinned",
                title: "Пин",
                summary: nil,
                body: nil,
                author: "Отдел",
                categoryID: "important",
                categoryName: "Важно",
                publishedAt: now.addingTimeInterval(-600),
                updatedAt: nil,
                isRead: false,
                isPinned: true
            ),
            Announcement(
                id: "unread_recent",
                title: "Свежие новости",
                summary: nil,
                body: nil,
                author: "Проректор",
                categoryID: "events",
                categoryName: "События",
                publishedAt: now.addingTimeInterval(-120),
                updatedAt: nil,
                isRead: false,
                isPinned: false
            ),
            Announcement(
                id: "read_new",
                title: "Прочитанное",
                summary: nil,
                body: nil,
                author: nil,
                categoryID: "important",
                categoryName: "Важно",
                publishedAt: now.addingTimeInterval(-60),
                updatedAt: nil,
                isRead: true,
                isPinned: false
            ),
            Announcement(
                id: "unread_old",
                title: "Давнее",
                summary: nil,
                body: nil,
                author: nil,
                categoryID: "important",
                categoryName: "Важно",
                publishedAt: now.addingTimeInterval(-18_000),
                updatedAt: nil,
                isRead: false,
                isPinned: false
            )
        ]

        let suite = "AnnouncementsSortingTest.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            throw AnnouncementsTestFailure(message: "Не удалось создать UserDefaults для теста сортировки")
        }
        defer { defaults.removePersistentDomain(forName: suite) }
        let service = MockAnnouncementsTestingService(categories: categories, announcements: announcements)
        let viewModel = await MainActor.run {
            AnnouncementsViewModel(service: service, userDefaults: defaults, pageSize: 10)
        }

        await viewModel.loadInitial()

        let orderedIDs = await MainActor.run {
            viewModel.announcements.map { $0.id }
        }

        let expectedOrder = ["pinned", "unread_recent", "unread_old", "read_new"]
        guard orderedIDs == expectedOrder else {
            throw AnnouncementsTestFailure(message: "Неверная сортировка объявлений: \(orderedIDs)")
        }
    }

    private static func runFilteringTest() async throws {
        let now = Date()
        let categories = sampleCategories()
        let important = categories.first { $0.id == "important" }!
        let announcements = [
            Announcement(
                id: "pinned",
                title: "Пин",
                summary: nil,
                body: nil,
                author: nil,
                categoryID: "important",
                categoryName: "Важно",
                publishedAt: now.addingTimeInterval(-300),
                updatedAt: nil,
                isRead: false,
                isPinned: true
            ),
            Announcement(
                id: "read",
                title: "Прочитанное",
                summary: nil,
                body: nil,
                author: nil,
                categoryID: "important",
                categoryName: "Важно",
                publishedAt: now.addingTimeInterval(-200),
                updatedAt: nil,
                isRead: true,
                isPinned: false
            ),
            Announcement(
                id: "other",
                title: "Другое",
                summary: nil,
                body: nil,
                author: nil,
                categoryID: "events",
                categoryName: "События",
                publishedAt: now.addingTimeInterval(-100),
                updatedAt: nil,
                isRead: false,
                isPinned: false
            ),
            Announcement(
                id: "unread_old",
                title: "Старое",
                summary: nil,
                body: nil,
                author: nil,
                categoryID: "important",
                categoryName: "Важно",
                publishedAt: now.addingTimeInterval(-50_000),
                updatedAt: nil,
                isRead: false,
                isPinned: false
            )
        ]

        let suite = "AnnouncementsFilteringTest.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            throw AnnouncementsTestFailure(message: "Не удалось создать UserDefaults для теста фильтрации")
        }
        defer { defaults.removePersistentDomain(forName: suite) }
        let service = MockAnnouncementsTestingService(categories: categories, announcements: announcements)
        let viewModel = await MainActor.run {
            AnnouncementsViewModel(service: service, userDefaults: defaults, pageSize: 10)
        }

        await viewModel.loadInitial()
        await viewModel.selectCategory(important)

        let filteredIDs = await MainActor.run {
            viewModel.announcements.map { $0.id }
        }

        guard filteredIDs == ["pinned", "read", "unread_old"] else {
            throw AnnouncementsTestFailure(message: "Категорийный фильтр не сработал: \(filteredIDs)")
        }

        await viewModel.setShowOnlyUnread(true)

        let unreadIDs = await MainActor.run {
            viewModel.announcements.map { $0.id }
        }

        guard unreadIDs == ["pinned", "unread_old"] else {
            throw AnnouncementsTestFailure(message: "Фильтр по непрочитанным не сработал: \(unreadIDs)")
        }
    }

    private static func sampleCategories() -> [AnnouncementCategory] {
        [
            .all,
            AnnouncementCategory(id: "important", title: "Важно", iconName: "exclamationmark.circle"),
            AnnouncementCategory(id: "events", title: "События", iconName: "calendar")
        ]
    }
}

private final class MockAnnouncementsTestingService: AnnouncementsServicing {
    private let categories: [AnnouncementCategory]
    private let announcements: [Announcement]

    init(categories: [AnnouncementCategory], announcements: [Announcement]) {
        self.categories = categories
        self.announcements = announcements
    }

    func fetchCategories() async throws -> [AnnouncementCategory] {
        categories
    }

    func fetchAnnouncements(
        page: Int,
        pageSize: Int,
        categoryID: String?,
        onlyUnread: Bool,
        searchQuery: String?
    ) async throws -> AnnouncementPage {
        AnnouncementPage(
            items: announcements,
            page: page,
            pageSize: pageSize,
            totalItems: announcements.count,
            totalPages: 1
        )
    }

    func markAnnouncementsRead(ids: [String]) async throws {}

    func markAnnouncementRead(id: String) async throws {}
}
