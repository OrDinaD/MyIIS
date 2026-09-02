@testable import MyIIS
import XCTest

@MainActor
final class ServiceEndpointsAPICacheTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var session: URLSession!
    private var baseURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "ServiceEndpointsAPICacheTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        baseURL = URL(string: "https://iis.bsuir.by/api/v1/tests/\(UUID().uuidString)")!

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = nil
        MockURLProtocol.mockData = nil
        MockURLProtocol.mockResponse = nil
        MockURLProtocol.mockError = nil
    }

    override func tearDown() async throws {
        ServiceEndpointsAPI.clearResponseCache(in: defaults)
        defaults.removePersistentDomain(forName: suiteName)
        session.invalidateAndCancel()
        MockURLProtocol.requestHandler = nil
        MockURLProtocol.mockData = nil
        MockURLProtocol.mockResponse = nil
        MockURLProtocol.mockError = nil
        try await super.tearDown()
    }

    func testUnauthorizedResponseNeverFallsBackToCachedWeek() async throws {
        let cachedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let api = makeAPI(now: cachedAt)

        MockURLProtocol.requestHandler = { request in
            (Self.response(for: request, statusCode: 200), Data("2".utf8))
        }
        let initialWeek = try await api.fetchCurrentWeek()
        XCTAssertEqual(initialWeek, 2)

        let event = expectation(description: "session expiration event")
        let token = NotificationCenter.default.addObserver(
            forName: .myiisAuthenticationSessionExpired,
            object: nil,
            queue: nil
        ) { _ in
            event.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        MockURLProtocol.requestHandler = { request in
            (Self.response(for: request, statusCode: 401), Data())
        }

        do {
            _ = try await api.fetchCurrentWeek(preferCachedResponse: false)
            XCTFail("401 must not be masked during an explicit refresh")
        } catch APIError.unauthorized {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        await fulfillment(of: [event], timeout: 1)
    }

    func testCurrentWeekCacheExpiresAfterOneHour() async throws {
        let cachedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let writer = makeAPI(now: cachedAt)

        MockURLProtocol.requestHandler = { request in
            (Self.response(for: request, statusCode: 200), Data("3".utf8))
        }
        let initialWeek = try await writer.fetchCurrentWeek()
        XCTAssertEqual(initialWeek, 3)

        let reader = makeAPI(now: cachedAt.addingTimeInterval(2 * 60 * 60))
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await reader.fetchCurrentWeek()
            XCTFail("Expired current-week cache must not be returned")
        } catch APIError.networkError {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFreshCurrentWeekCacheSupportsOfflineFallback() async throws {
        let cachedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let writer = makeAPI(now: cachedAt)

        MockURLProtocol.requestHandler = { request in
            (Self.response(for: request, statusCode: 200), Data("4".utf8))
        }
        let initialWeek = try await writer.fetchCurrentWeek()
        XCTAssertEqual(initialWeek, 4)

        let reader = makeAPI(now: cachedAt.addingTimeInterval(30 * 60))
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let cachedWeek = try await reader.fetchCurrentWeek()
        XCTAssertEqual(cachedWeek, 4)
    }

    private func makeAPI(now: Date) -> ServiceEndpointsAPI {
        ServiceEndpointsAPI(
            baseURL: baseURL,
            session: session,
            userDefaults: defaults,
            now: { now }
        )
    }

    private static func response(for request: URLRequest, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}
