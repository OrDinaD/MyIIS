@testable import MyIIS
import XCTest

@MainActor
final class OfflineAndRatingSummaryTests: XCTestCase {
    func testCurrentMonthUsesAttendanceCountsInsteadOfJournalOrPreviousMonth() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-26T12:00:00Z"))
        let counts = [
            MonthlyOmissionCount(month: "08.2026", omissionCount: 4),
            MonthlyOmissionCount(month: "09.2026", omissionCount: 0)
        ]
        XCTAssertEqual(RatingOmissionsViewModel.currentMonthHours(counts, now: now), 0)
        XCTAssertNil(RatingOmissionsViewModel.currentMonthHours([counts[0]], now: now))
    }

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

    func testMonthlyCountsSurviveOfflineReloadAndModelRecreation() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let id = Int.random(in: 10000000...99999999)
        defer { UserDefaultsPayloadStore.clear(forKey: "rating_monthly_omissions.\(id)", from: defaults) }
        #if DEBUG
        let previousDemoMode = APIService.isDemoMode
        APIService.isDemoMode = false
        defer { APIService.isDemoMode = previousDemoMode }
        #endif
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        defer {
            session.invalidateAndCancel()
            MockURLProtocol.requestHandler = nil
        }
        let api = APIService(session: session)
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.lastPathComponent, "omission-count-by-student-for-semester")
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil
            ))
            return (response, Data(#"[{"month":"09.2026","omissionCount":0}]"#.utf8))
        }
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-26T12:00:00Z"))
        let online = RatingOmissionsViewModel(api: api, defaults: defaults)
        await online.load(userID: id, now: now)
        XCTAssertEqual(online.hours, 0)
        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }
        let restored = RatingOmissionsViewModel(api: api, defaults: defaults)
        await restored.load(userID: id, now: now.addingTimeInterval(60))
        XCTAssertEqual(restored.hours, 0)
        XCTAssertEqual(restored.updatedAt, now)
        XCTAssertTrue(restored.isStale)
        await restored.load(userID: id + 1, now: now)
        XCTAssertNil(restored.hours, "Another account must not inherit cached hours")
    }
}
