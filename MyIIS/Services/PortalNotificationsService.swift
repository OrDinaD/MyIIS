import Foundation

protocol PortalNotificationsServicing: AnyObject {
    func fetchUnreadCount() async throws -> Int
    func fetchNotifications(page: Int, pageSize: Int) async throws -> PortalNotificationsPage
    func markViewed(ids: [Int]) async throws
}

final class PortalNotificationsService: PortalNotificationsServicing {
    private let apiService: APIService

    init(apiService: APIService = APIService()) {
        self.apiService = apiService
    }

    func fetchUnreadCount() async throws -> Int {
        if APIService.isDemoMode {
            return Self.demoNotifications.filter { !$0.isViewed }.count
        }

        let endpoint = apiService.baseURL
            .appendingPathComponent("notifications")
            .appendingPathComponent("notViewed")
            .appendingPathComponent("count")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        apiService.logRequestDetails(request)
        return try await apiService.execute(request)
    }

    func fetchNotifications(page: Int, pageSize: Int) async throws -> PortalNotificationsPage {
        if APIService.isDemoMode {
            return Self.demoPage(page: page, pageSize: pageSize)
        }

        let endpoint = apiService.baseURL.appendingPathComponent("notifications")
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "pageNumber", value: String(page)),
            URLQueryItem(name: "pageSize", value: String(pageSize))
        ]
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        apiService.logRequestDetails(request)
        return try await apiService.execute(request)
    }

    func markViewed(ids: [Int]) async throws {
        guard !ids.isEmpty, !APIService.isDemoMode else { return }

        let endpoint = apiService.baseURL.appendingPathComponent("notifications")
        let updates = ids.map { PortalNotificationReadUpdate(id: $0, isViewed: true) }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(updates)

        apiService.logRequestDetails(request)
        try await apiService.performEmptyRequest(request)
    }
}

private extension PortalNotificationsService {
    static let demoNotifications = [
        PortalNotification(
            id: 3,
            message: "Справка № 125, заказанная Вами, распечатана.",
            isViewed: false,
            date: "13.07.2026 11:20:00",
            type: .success
        ),
        PortalNotification(
            id: 2,
            message: "Ваши документы для общежития были приняты к рассмотрению.",
            isViewed: false,
            date: "12.07.2026 15:42:18",
            type: .info
        ),
        PortalNotification(
            id: 1,
            message: "Заявка отклонена. Проверьте указанные данные.",
            isViewed: true,
            date: "10.07.2026 09:05:44",
            type: .failure
        )
    ]

    static func demoPage(page: Int, pageSize: Int) -> PortalNotificationsPage {
        let safePage = max(0, page)
        let safePageSize = max(1, pageSize)
        let startIndex = min(safePage * safePageSize, demoNotifications.count)
        let endIndex = min(startIndex + safePageSize, demoNotifications.count)
        let items = Array(demoNotifications[startIndex ..< endIndex])

        return PortalNotificationsPage(
            notifications: items,
            totalElements: demoNotifications.count,
            hasNext: endIndex < demoNotifications.count
        )
    }
}
