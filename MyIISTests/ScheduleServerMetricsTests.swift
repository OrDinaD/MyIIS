//
//  ScheduleServerMetricsTests.swift
//  MyIISTests
//

import XCTest
@testable import MyIIS

@MainActor
final class ScheduleServerMetricsTests: XCTestCase {
    private var testDefaults: UserDefaults!
    private let suiteName = "test.schedule.server.metrics"

    override func setUp() async throws {
        try await super.setUp()
        testDefaults = UserDefaults(suiteName: suiteName)
        testDefaults.removePersistentDomain(forName: suiteName)
        ScheduleServerMetricsTracker.isTelemetryEnabled = true
    }

    override func tearDown() async throws {
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults = nil
        ScheduleServerMetricsTracker.isTelemetryEnabled = true
        try await super.tearDown()
    }

    // MARK: - ScheduleServerConfiguration Tests

    func testServerConfigurationDefaultsToAuto() {
        testDefaults.removeObject(forKey: ScheduleServerConfiguration.serverDefaultsKey)
        XCTAssertEqual(ScheduleAPIServer.auto.rawValue, "auto")
        XCTAssertEqual(ScheduleAPIServer.gateway.rawValue, "gateway")
        XCTAssertEqual(ScheduleAPIServer.official.rawValue, "official")
    }

    func testServerHostsAndBaseURLs() {
        XCTAssertEqual(ScheduleAPIServer.official.host, "iis.bsuir.by")
        XCTAssertEqual(ScheduleAPIServer.gateway.host, "bsuir.ordinad.xyz")
        XCTAssertEqual(ScheduleAPIServer.auto.host, "bsuir.ordinad.xyz")

        XCTAssertEqual(ScheduleAPIServer.official.baseURL.absoluteString, "https://iis.bsuir.by/api/v1")
        XCTAssertEqual(ScheduleAPIServer.gateway.baseURL.absoluteString, "https://bsuir.ordinad.xyz/api/v1")
    }

    func testGatewaySupportedPaths() {
        XCTAssertTrue(ScheduleServerConfiguration.isGatewaySupported(path: "schedule"))
        XCTAssertTrue(ScheduleServerConfiguration.isGatewaySupported(path: "schedule/current-week"))
        XCTAssertTrue(ScheduleServerConfiguration.isGatewaySupported(path: "student-groups"))
        XCTAssertTrue(ScheduleServerConfiguration.isGatewaySupported(path: "employees/all"))
        XCTAssertTrue(ScheduleServerConfiguration.isGatewaySupported(path: "employees/schedule/ivanov"))
        XCTAssertTrue(ScheduleServerConfiguration.isGatewaySupported(path: "auditories"))
        XCTAssertTrue(ScheduleServerConfiguration.isGatewaySupported(path: "faculties"))

        // Private / non-cached paths
        XCTAssertFalse(ScheduleServerConfiguration.isGatewaySupported(path: "library/books"))
        XCTAssertFalse(ScheduleServerConfiguration.isGatewaySupported(path: "dormitory-queue-application/premium-penalty"))
        XCTAssertFalse(ScheduleServerConfiguration.isGatewaySupported(path: "activity/is-brsm"))
    }

    // MARK: - Class Hours Detection Tests

    func testClassHoursDetectionOnWeekdays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Minsk") ?? .current

        // Monday at 10:30 (Class hour)
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 12 // Monday
        components.hour = 10
        components.minute = 30
        let classTime = calendar.date(from: components)!
        XCTAssertTrue(ScheduleServerMetricsTracker.isDuringClassHours(at: classTime, calendar: calendar))

        // Monday at 21:00 (Evening / off-hours)
        components.hour = 21
        components.minute = 0
        let eveningTime = calendar.date(from: components)!
        XCTAssertFalse(ScheduleServerMetricsTracker.isDuringClassHours(at: eveningTime, calendar: calendar))

        // Sunday at 12:00 (Weekend / off-hours)
        components.day = 18 // Sunday
        components.hour = 12
        let sundayTime = calendar.date(from: components)!
        XCTAssertFalse(ScheduleServerMetricsTracker.isDuringClassHours(at: sundayTime, calendar: calendar))
    }

    // MARK: - Metrics Tracker Tests

    @MainActor
    func testMetricsTrackerAggregations() {
        let tracker = ScheduleServerMetricsTracker(defaults: testDefaults)
        tracker.clearAll()

        // Track gateway requests
        tracker.track(
            server: "gateway",
            endpoint: "schedule",
            durationMs: 150,
            httpStatusCode: 200,
            isSuccess: true,
            connectionType: "Wi-Fi",
            isVPN: false,
            responseBytes: 30000,
            contentEncoding: "br"
        )
        tracker.track(
            server: "gateway",
            endpoint: "current-week",
            durationMs: 250,
            httpStatusCode: 200,
            isSuccess: true,
            connectionType: "Wi-Fi",
            isVPN: true,
            responseBytes: 1500,
            contentEncoding: "br"
        )

        // Track official requests
        tracker.track(
            server: "official",
            endpoint: "schedule",
            durationMs: 600,
            httpStatusCode: 200,
            isSuccess: true,
            connectionType: "Wi-Fi",
            isVPN: false,
            responseBytes: 120000,
            contentEncoding: "gzip"
        )
        tracker.track(
            server: "official",
            endpoint: "current-week",
            durationMs: 800,
            httpStatusCode: 200,
            isSuccess: true,
            connectionType: "Wi-Fi",
            isVPN: true,
            responseBytes: 2500,
            contentEncoding: nil
        )

        XCTAssertEqual(tracker.totalRequests(for: "gateway"), 2)
        XCTAssertEqual(tracker.totalRequests(for: "official"), 2)

        XCTAssertEqual(tracker.averageDuration(for: "gateway"), 200.0)
        XCTAssertEqual(tracker.averageDuration(for: "official"), 700.0)

        XCTAssertEqual(tracker.minDuration(for: "gateway"), 150)
        XCTAssertEqual(tracker.maxDuration(for: "gateway"), 250)

        XCTAssertEqual(tracker.averageDuration(for: "gateway", isVPN: false), 150.0)
        XCTAssertEqual(tracker.averageDuration(for: "gateway", isVPN: true), 250.0)

        XCTAssertEqual(tracker.successRate(for: "gateway"), 100.0)
        XCTAssertEqual(tracker.successRate(for: "official"), 100.0)

        // Check speedup comparison text
        XCTAssertNotNil(tracker.speedupComparison)
        XCTAssertTrue(tracker.speedupComparison?.contains("быстрее") == true)

        // Check report generation
        let report = tracker.generateDetailedReport()
        XCTAssertTrue(report.contains("ДИАГНОСТИЧЕСКИЙ ОТЧЕТ СЕТИ MYIIS"))
        XCTAssertTrue(report.contains("Шлюз MyIIS"))
        XCTAssertTrue(report.contains("Официальный БГУИР"))
        XCTAssertTrue(report.contains("АНАЛИЗ УЗКИХ МЕСТ"))

        // Test clear
        tracker.clearAll()
        XCTAssertTrue(tracker.records.isEmpty)
        XCTAssertNil(tracker.averageDuration(for: "gateway"))
    }

    // MARK: - Backward Compatibility Decoding Test

    func testLegacyRecordDecoding() throws {
        let legacyJSON = """
        [
            {
                "id": "11111111-2222-3333-4444-555555555555",
                "timestamp": 1728300000,
                "server": "gateway",
                "endpoint": "schedule",
                "durationMs": 350,
                "httpStatusCode": 200,
                "isSuccess": true,
                "isClassHour": true
            }
        ]
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let records = try decoder.decode([ScheduleServerMetricRecord].self, from: legacyJSON)
        XCTAssertEqual(records.count, 1)
        let record = records[0]
        XCTAssertEqual(record.server, "gateway")
        XCTAssertEqual(record.durationMs, 350)
        XCTAssertEqual(record.connectionType, "Неизвестно")
        XCTAssertFalse(record.isVPN)
        XCTAssertNil(record.responseBytes)
    }

    // MARK: - Telemetry Toggle Test

    @MainActor
    func testTelemetryToggle() {
        let tracker = ScheduleServerMetricsTracker(defaults: testDefaults)
        tracker.clearAll()

        ScheduleServerMetricsTracker.isTelemetryEnabled = false
        tracker.track(server: "gateway", endpoint: "test", durationMs: 100, httpStatusCode: 200, isSuccess: true)

        XCTAssertEqual(tracker.records.count, 0, "No records should be tracked when telemetry is disabled")

        ScheduleServerMetricsTracker.isTelemetryEnabled = true
        tracker.track(server: "gateway", endpoint: "test", durationMs: 100, httpStatusCode: 200, isSuccess: true)

        XCTAssertEqual(tracker.records.count, 1, "Record should be tracked when telemetry is enabled")
    }
}
