@testable import MyIIS
import XCTest

@MainActor
final class OfflineAndRatingSummaryTests: XCTestCase {

    func testNotificationsStayAvailableOfflineForSameAccount() async throws {
        #if DEBUG
        let previousDemoMode = APIService.isDemoMode
        APIService.isDemoMode = false
        defer { APIService.isDemoMode = previousDemoMode }
        #endif
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let id = Int.random(in: 10000000...99999999)
        defer {
            session.invalidateAndCancel()
            MockURLProtocol.requestHandler = nil
            UserDefaultsPayloadStore.clear(prefix: "portal_notifications.\(id).")
        }
        let api = APIService(session: session)
        let expected = PortalNotificationsPage(notifications: [
            PortalNotification(id: 1, message: "Saved message", isViewed: false, date: "26.09.2026", type: .info)
        ], totalElements: 1, hasNext: false)
        let data = try JSONEncoder().encode(expected)
        MockURLProtocol.requestHandler = { request in
            (try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil
            )), data)
        }
        let online = try await PortalNotificationsService(apiService: api, userID: { id })
            .fetchNotifications(page: 0, pageSize: 15)
        XCTAssertEqual(online, expected)
        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }
        let offline = try await PortalNotificationsService(apiService: api, userID: { id })
            .fetchNotifications(page: 0, pageSize: 15)
        XCTAssertEqual(offline, expected)
        do {
            _ = try await PortalNotificationsService(apiService: api, userID: { id + 1 })
                .fetchNotifications(page: 0, pageSize: 15)
            XCTFail("Another account must not receive cached notifications")
        } catch { }
    }

    func testExpiredOnlineCacheRemainsAvailableOffline() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let request = URLRequest(url: try XCTUnwrap(URL(string: "https://example.com/schedule")))
        let prefix = "offline-regression.\(UUID().uuidString)."
        defer { UserDefaultsPayloadStore.clear(prefix: prefix, from: defaults) }
        let data = Data("saved schedule".utf8)
        let now = Date()
        OfflineResponseCache.persist(
            data: data, for: request, prefix: prefix, userDefaults: defaults,
            cachedAt: now.addingTimeInterval(-3600)
        )
        XCTAssertNil(OfflineResponseCache.loadData(
            for: request, prefix: prefix, userDefaults: defaults, maxAge: 60, now: now
        ))
        XCTAssertEqual(OfflineResponseCache.loadData(
            for: request, prefix: prefix, userDefaults: defaults
        ), data)
    }

}
