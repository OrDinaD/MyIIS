@testable import MyIIS
import XCTest

@MainActor
final class PortalNotificationsViewModelTests: XCTestCase {
    func testInitialLoadFetchesFirstPageAndUnreadCount() async {
        let stub = StubPortalNotificationsService(
            unreadCount: 2,
            pages: [
                0: page(
                    [
                        notification(id: 3, isViewed: false),
                        notification(id: 2, isViewed: false)
                    ],
                    total: 3,
                    hasNext: true
                )
            ]
        )
        let viewModel = PortalNotificationsViewModel(service: stub, pageSize: 2)

        await viewModel.loadInitial()

        XCTAssertEqual(viewModel.notifications.map(\.id), [3, 2])
        XCTAssertEqual(viewModel.unreadCount, 2)
        XCTAssertEqual(viewModel.totalElements, 3)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testPaginationLoadsNextPageOnceForCurrentLastItem() async {
        let stub = StubPortalNotificationsService(
            unreadCount: 0,
            pages: [
                0: page(
                    [
                        notification(id: 3, isViewed: true),
                        notification(id: 2, isViewed: true)
                    ],
                    total: 3,
                    hasNext: true
                ),
                1: page(
                    [notification(id: 1, isViewed: true)],
                    total: 3,
                    hasNext: false
                )
            ]
        )
        let viewModel = PortalNotificationsViewModel(service: stub, pageSize: 2)

        await viewModel.loadInitial()
        guard let lastItem = viewModel.notifications.last else {
            return XCTFail("Expected the first page to contain notifications")
        }
        await viewModel.loadMoreIfNeeded(current: lastItem)
        await viewModel.loadMoreIfNeeded(current: lastItem)

        let requestedPages = stub.requestedPages()
        XCTAssertEqual(viewModel.notifications.map(\.id), [3, 2, 1])
        XCTAssertEqual(requestedPages, [0, 1])
    }

    func testMarkAsReadUpdatesItemAndBadge() async {
        let stub = StubPortalNotificationsService(
            unreadCount: 1,
            pages: [
                0: page([notification(id: 7, isViewed: false)], total: 1, hasNext: false)
            ]
        )
        let viewModel = PortalNotificationsViewModel(service: stub)

        await viewModel.loadInitial()
        await viewModel.markAsRead(viewModel.notifications[0])

        let markedIDs = stub.markedNotificationIDs()
        XCTAssertTrue(viewModel.notifications[0].isViewed)
        XCTAssertEqual(viewModel.unreadCount, 0)
        XCTAssertEqual(markedIDs, [7])
    }

    func testMarkAsReadRollsBackWhenServerRejectsUpdate() async {
        let stub = StubPortalNotificationsService(
            unreadCount: 1,
            pages: [
                0: page([notification(id: 7, isViewed: false)], total: 1, hasNext: false)
            ],
            shouldFailMarking: true
        )
        let viewModel = PortalNotificationsViewModel(service: stub)

        await viewModel.loadInitial()
        await viewModel.markAsRead(viewModel.notifications[0])

        XCTAssertFalse(viewModel.notifications[0].isViewed)
        XCTAssertEqual(viewModel.unreadCount, 1)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testMarkAllReadsUnloadedPagesBeforeSendingBatch() async {
        let stub = StubPortalNotificationsService(
            unreadCount: 3,
            pages: [
                0: page(
                    [
                        notification(id: 3, isViewed: false),
                        notification(id: 2, isViewed: false)
                    ],
                    total: 3,
                    hasNext: true
                ),
                1: page(
                    [notification(id: 1, isViewed: false)],
                    total: 3,
                    hasNext: false
                )
            ]
        )
        let viewModel = PortalNotificationsViewModel(service: stub, pageSize: 2)

        await viewModel.loadInitial()
        await viewModel.markAllAsRead()

        let markedIDs = stub.markedNotificationIDs()
        XCTAssertTrue(viewModel.notifications.allSatisfy(\.isViewed))
        XCTAssertEqual(viewModel.unreadCount, 0)
        XCTAssertEqual(Set(markedIDs), Set([1, 2, 3]))
    }
}

private extension PortalNotificationsViewModelTests {
    func notification(id: Int, isViewed: Bool) -> PortalNotification {
        PortalNotification(
            id: id,
            message: "Notification \(id)",
            isViewed: isViewed,
            date: "13.07.2026 10:19:00",
            type: .info
        )
    }

    func page(
        _ notifications: [PortalNotification],
        total: Int,
        hasNext: Bool
    ) -> PortalNotificationsPage {
        PortalNotificationsPage(
            notifications: notifications,
            totalElements: total,
            hasNext: hasNext
        )
    }
}

@MainActor
private final class StubPortalNotificationsService: PortalNotificationsServicing {
    enum StubError: Error {
        case markingFailed
    }

    private let unreadCount: Int
    private let pages: [Int: PortalNotificationsPage]
    private let shouldFailMarking: Bool
    private var pageRequests: [Int] = []
    private var markedIDs: [Int] = []

    init(
        unreadCount: Int,
        pages: [Int: PortalNotificationsPage],
        shouldFailMarking: Bool = false
    ) {
        self.unreadCount = unreadCount
        self.pages = pages
        self.shouldFailMarking = shouldFailMarking
    }

    func fetchUnreadCount() async throws -> Int {
        unreadCount
    }

    func fetchNotifications(page: Int, pageSize: Int) async throws -> PortalNotificationsPage {
        pageRequests.append(page)
        return pages[page] ?? PortalNotificationsPage(
            notifications: [],
            totalElements: 0,
            hasNext: false
        )
    }

    func markViewed(ids: [Int]) async throws {
        if shouldFailMarking {
            throw StubError.markingFailed
        }
        markedIDs.append(contentsOf: ids)
    }

    func requestedPages() -> [Int] {
        pageRequests
    }

    func markedNotificationIDs() -> [Int] {
        markedIDs
    }
}
