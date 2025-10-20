import XCTest
@testable import MyIIS

@MainActor
final class AnnouncementsViewModelTests: XCTestCase {
    func testSortingKeepsPinnedAndUnreadRecentFirst() async throws {
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

        let (viewModel, defaults) = makeViewModel(categories: categories, announcements: announcements)
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        await viewModel.loadInitial()

        let orderedIDs = viewModel.announcements.map(\.id)
        XCTAssertEqual(orderedIDs, ["pinned", "unread_recent", "unread_old", "read_new"])
    }

    func testCategoryAndUnreadFiltering() async throws {
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

        let (viewModel, defaults) = makeViewModel(categories: categories, announcements: announcements)
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        await viewModel.loadInitial()
        await viewModel.selectCategory(important)
        XCTAssertEqual(viewModel.announcements.map(\.id), ["pinned", "read", "unread_old"])

        await viewModel.setShowOnlyUnread(true)
        XCTAssertEqual(viewModel.announcements.map(\.id), ["pinned", "unread_old"])
    }

    private let defaultsSuiteName = "AnnouncementsTests.\(UUID().uuidString)"

    private func makeViewModel(
        categories: [AnnouncementCategory],
        announcements: [Announcement]
    ) -> (AnnouncementsViewModel, UserDefaults) {
        let defaults = UserDefaults(suiteName: defaultsSuiteName)!
        let service = MockAnnouncementsTestingService(categories: categories, announcements: announcements)
        let viewModel = AnnouncementsViewModel(service: service, userDefaults: defaults, pageSize: 10)
        return (viewModel, defaults)
    }

    private func sampleCategories() -> [AnnouncementCategory] {
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
