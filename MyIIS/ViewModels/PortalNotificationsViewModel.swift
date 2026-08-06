import Combine
import Foundation
import Observation

@MainActor
@Observable
final class PortalNotificationsViewModel {
    enum State: Equatable {
        case idle
        case loading
        case refreshing
        case loadingMore
    }

    private(set) var notifications: [PortalNotification] = []
    private(set) var unreadCount = 0
    private(set) var totalElements = 0
    private(set) var state: State = .idle
    private(set) var errorMessage: String?
    private(set) var isMarkingRead = false

    private let service: PortalNotificationsServicing
    private let pageSize: Int
    private var currentPage = 0
    private var hasMorePages = true
    private var hasLoadedInitialData = false

    init(
        service: PortalNotificationsServicing? = nil,
        pageSize: Int = 15
    ) {
        self.service = service ?? PortalNotificationsService()
        self.pageSize = pageSize
    }

    var isInitialLoading: Bool {
        state == .loading && notifications.isEmpty
    }

    var isLoadingMore: Bool {
        state == .loadingMore
    }

    var hasUnread: Bool {
        unreadCount > 0 || notifications.contains { !$0.isViewed }
    }

    func loadUnreadCount() async {
        do {
            unreadCount = try await service.fetchUnreadCount()
        } catch is CancellationError {
            return
        } catch {
            // The toolbar badge is supplementary and should not interrupt the profile screen.
        }
    }

    func loadInitial() async {
        guard !hasLoadedInitialData else {
            await loadUnreadCount()
            return
        }
        hasLoadedInitialData = true
        await refresh()
    }

    func refresh() async {
        state = notifications.isEmpty ? .loading : .refreshing
        errorMessage = nil

        do {
            let page = try await service.fetchNotifications(page: 0, pageSize: pageSize)
            notifications = page.notifications
            totalElements = page.totalElements
            currentPage = 0
            hasMorePages = page.hasNext
            unreadCount = try await unreadCountOrFallback()
            state = .idle
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .idle
            errorMessage = error.localizedDescription
        }
    }

    func loadMoreIfNeeded(current notification: PortalNotification) async {
        guard hasMorePages,
              notifications.last?.id == notification.id,
              state != .loadingMore,
              !isMarkingRead else {
            return
        }

        state = .loadingMore
        let nextPage = currentPage + 1

        do {
            let page = try await service.fetchNotifications(page: nextPage, pageSize: pageSize)
            appendUnique(page.notifications)
            totalElements = page.totalElements
            currentPage = nextPage
            hasMorePages = page.hasNext
            state = .idle
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .idle
            errorMessage = error.localizedDescription
        }
    }

    func markAsRead(_ notification: PortalNotification) async {
        guard !notification.isViewed,
              let index = notifications.firstIndex(where: { $0.id == notification.id }),
              !notifications[index].isViewed else {
            return
        }

        notifications[index].isViewed = true
        unreadCount = max(0, unreadCount - 1)

        do {
            try await service.markViewed(ids: [notification.id])
        } catch is CancellationError {
            rollbackReadState(for: notification.id)
        } catch {
            rollbackReadState(for: notification.id)
            errorMessage = error.localizedDescription
        }
    }

    func markAllAsRead() async {
        guard hasUnread, !isMarkingRead else { return }

        isMarkingRead = true
        errorMessage = nil
        defer { isMarkingRead = false }

        do {
            var unreadIDs = notifications.filter { !$0.isViewed }.map(\.id)
            var page = currentPage + 1
            var shouldLoadMore = hasMorePages

            while shouldLoadMore {
                try Task.checkCancellation()
                let response = try await service.fetchNotifications(page: page, pageSize: pageSize)
                unreadIDs.append(contentsOf: response.notifications.filter { !$0.isViewed }.map(\.id))
                shouldLoadMore = response.hasNext
                page += 1
            }

            let uniqueIDs = Array(Set(unreadIDs))
            try await service.markViewed(ids: uniqueIDs)

            for index in notifications.indices {
                notifications[index].isViewed = true
            }
            unreadCount = 0
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }
}

private extension PortalNotificationsViewModel {
    func unreadCountOrFallback() async throws -> Int {
        do {
            return try await service.fetchUnreadCount()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return notifications.filter { !$0.isViewed }.count
        }
    }

    func appendUnique(_ newNotifications: [PortalNotification]) {
        let existingIDs = Set(notifications.map(\.id))
        notifications.append(contentsOf: newNotifications.filter { !existingIDs.contains($0.id) })
    }

    func rollbackReadState(for id: Int) {
        guard let index = notifications.firstIndex(where: { $0.id == id }),
              notifications[index].isViewed else {
            return
        }

        notifications[index].isViewed = false
        unreadCount += 1
    }
}
