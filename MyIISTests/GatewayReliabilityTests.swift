import Foundation
@testable import MyIIS
import XCTest

@MainActor
final class GatewayReliabilityTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var session: URLSession!
    private var previousServer: String?

    override func setUp() async throws {
        previousServer = ScheduleServerConfiguration.defaults.string(forKey: ScheduleServerConfiguration.serverDefaultsKey)
        ScheduleServerConfiguration.selectedServer = .gateway
        suiteName = "GatewayReliabilityTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
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
        ScheduleServerConfiguration.defaults.set(previousServer, forKey: ScheduleServerConfiguration.serverDefaultsKey)
        ServiceEndpointsAPI.clearResponseCache(in: defaults)
        defaults.removePersistentDomain(forName: suiteName)
        session.invalidateAndCancel()
        MockURLProtocol.requestHandler = nil
    }

    func testGatewayTimeoutFallsBackAndNextRequestBypassesGateway() async throws {
        let api = ServiceEndpointsAPI(session: session, gatewayHealth: ScheduleGatewayHealth(), userDefaults: defaults)
        var hosts: [String] = []
        MockURLProtocol.requestHandler = { request in
            hosts.append(request.url!.host!)
            if request.url?.host == "bsuir.ordinad.xyz" { throw URLError(.timedOut) }
            return (Self.response(request, status: 200), Data("3".utf8))
        }
        let first = try await api.fetchCurrentWeek(preferCachedResponse: false)
        let second = try await api.fetchCurrentWeek(preferCachedResponse: false)
        XCTAssertEqual(first, 3)
        XCTAssertEqual(second, 3)
        XCTAssertEqual(hosts, ["bsuir.ordinad.xyz", "iis.bsuir.by", "iis.bsuir.by"])
    }

    func testInvalidGatewayPayloadFallsBackWithoutPoisoningCache() async throws {
        let api = ServiceEndpointsAPI(session: session, gatewayHealth: ScheduleGatewayHealth(), userDefaults: defaults)
        MockURLProtocol.requestHandler = { request in
            let value = request.url?.host == "bsuir.ordinad.xyz" ? "<html>Unavailable</html>" : "2"
            return (Self.response(request, status: 200), Data(value.utf8))
        }
        let week = try await api.fetchCurrentWeek()
        XCTAssertEqual(week, 2)
        MockURLProtocol.requestHandler = { _ in
            XCTFail("The validated response should be served from cache")
            throw URLError(.notConnectedToInternet)
        }
        let cached = try await api.fetchCurrentWeek()
        XCTAssertEqual(cached, 2)
    }

    func testCancellationDoesNotStartOfficialFallback() async throws {
        let api = ServiceEndpointsAPI(session: session, gatewayHealth: ScheduleGatewayHealth(), userDefaults: defaults)
        var count = 0
        MockURLProtocol.requestHandler = { _ in
            count += 1
            throw URLError(.cancelled)
        }
        do {
            _ = try await api.fetchCurrentWeek(preferCachedResponse: false)
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertEqual(count, 1)
        }
    }

    func testGatewayCooldownAllowsOnlyOneRecoveryProbe() async {
        let health = ScheduleGatewayHealth()
        let now = Date()
        await health.failed(at: now)
        let blocked = await health.shouldAttempt(at: now.addingTimeInterval(59))
        let probe = await health.shouldAttempt(at: now.addingTimeInterval(60))
        let duplicateProbe = await health.shouldAttempt(at: now.addingTimeInterval(61))
        XCTAssertFalse(blocked)
        XCTAssertTrue(probe)
        XCTAssertFalse(duplicateProbe)
        await health.succeeded()
        let recovered = await health.shouldAttempt(at: now.addingTimeInterval(62))
        XCTAssertTrue(recovered)
    }

    func testPhotoCacheIdentitySurvivesServerSwitch() throws {
        let official = try XCTUnwrap(URL(string: "https://iis.bsuir.by/api/v1/employees/photo/42"))
        let gateway = try XCTUnwrap(SchedulePhotoRouting.gatewayURL(for: official))
        XCTAssertEqual(SchedulePhotoRouting.canonicalURL(gateway), official)
        XCTAssertEqual(gateway.host, "bsuir.ordinad.xyz")
        let external = try XCTUnwrap(URL(string: "https://example.com/photo/42"))
        XCTAssertNil(SchedulePhotoRouting.gatewayURL(for: external))
        XCTAssertEqual(SchedulePhotoRouting.canonicalURL(external), external)
    }

    func testSuccessfulPushRegistrationIsDeduplicatedAndGroupChangeIsSent() async {
        var groups: [String] = []
        MockURLProtocol.requestHandler = { request in
            // URLSession may supply the JSON through httpBodyStream, so assert the transport here.
            XCTAssertEqual(request.httpMethod, "POST")
            groups.append(request.url!.path)
            return (Self.response(request, status: 200), Data("{}".utf8))
        }
        let service = RemoteNotificationService(defaults: defaults, session: session)
        await service.registerOnGateway(token: "test-token", targetGroup: "420603")
        await service.registerOnGateway(token: "test-token", targetGroup: "420603")
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(service.lastRegisteredGroup, "420603")
        await service.registerOnGateway(token: "test-token", targetGroup: "420604")
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(service.lastRegisteredGroup, "420604")
    }

    func testRejectedPushRegistrationIsNotRecordedAsSuccessful() async {
        MockURLProtocol.requestHandler = { request in
            (Self.response(request, status: 400), Data())
        }
        let service = RemoteNotificationService(defaults: defaults, session: session)
        await service.registerOnGateway(token: "test-token", targetGroup: "420603")
        XCTAssertNil(service.lastRegisteredGroup)
    }

    func testOfficialSelectionNeverContactsGateway() async throws {
        ScheduleServerConfiguration.selectedServer = .official
        let api = ServiceEndpointsAPI(session: session, userDefaults: defaults)
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.host, "iis.bsuir.by")
            return (Self.response(request, status: 200), Data("2".utf8))
        }
        let week = try await api.fetchCurrentWeek(preferCachedResponse: false)
        XCTAssertEqual(week, 2)
    }

    func testMissingSelectionDefaultsToOfficial() {
        ScheduleServerConfiguration.defaults.removeObject(forKey: ScheduleServerConfiguration.serverDefaultsKey)
        XCTAssertEqual(ScheduleServerConfiguration.selectedServer, .official)
    }

    private static func response(_ request: URLRequest, status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }
}
