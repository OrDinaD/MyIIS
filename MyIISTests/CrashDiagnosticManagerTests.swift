@testable import MyIIS
import XCTest

@MainActor
final class CrashDiagnosticManagerTests: XCTestCase {

    func testLogSanitizationMasksBearerToken() {
        let rawLog = "Authorization request: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.doNotLeakThis"
        let sanitized = CrashDiagnosticManager.sanitizeLogMessage(rawLog)

        XCTAssertFalse(sanitized.contains("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"))
        XCTAssertTrue(sanitized.contains("Bearer [REDACTED]"))
    }

    func testLogSanitizationMasksPasswords() {
        let rawLog = "POST payload: {\"username\": \"student123\", \"password\": \"SuperSecretPass123!\", \"grant_type\": \"password\"}"
        let sanitized = CrashDiagnosticManager.sanitizeLogMessage(rawLog)

        XCTAssertFalse(sanitized.contains("SuperSecretPass123!"))
        XCTAssertTrue(sanitized.contains("\"password\": \"[REDACTED]\""))
    }

    func testLogSanitizationMasksEmail() {
        let rawLog = "User profile fetched for student.bsuir@edu.by with id 54321"
        let sanitized = CrashDiagnosticManager.sanitizeLogMessage(rawLog)

        XCTAssertFalse(sanitized.contains("student.bsuir@edu.by"))
        XCTAssertTrue(sanitized.contains("[EMAIL_REDACTED]"))
    }

    func testLogSanitizationMasksSessionParameters() {
        let rawLog = "GET /api/v1/schedule?session=abc123secret&group=123456"
        let sanitized = CrashDiagnosticManager.sanitizeLogMessage(rawLog)

        XCTAssertFalse(sanitized.contains("abc123secret"))
        XCTAssertTrue(sanitized.contains("session=[REDACTED]"))
    }

    func testLogSanitizationMasksStudentIdentity() {
        let rawLogs = [
            "Attempting to log in user: 42850094",
            "Restored cached user profile for Иванов Иван Иванович",
            "User profile loaded: Иванов Иван Иванович"
        ]

        let sanitized = rawLogs.map(CrashDiagnosticManager.sanitizeLogMessage)

        XCTAssertFalse(sanitized.joined().contains("42850094"))
        XCTAssertFalse(sanitized.joined().contains("Иванов"))
        XCTAssertTrue(sanitized[0].contains("[STUDENT_ID_REDACTED]"))
        XCTAssertTrue(sanitized[1].contains("[NAME_REDACTED]"))
    }

    func testDiagnosticReportGeneration() async {
        let report = await CrashDiagnosticManager.shared.generateReport()

        XCTAssertFalse(report.appVersion.isEmpty)
        XCTAssertFalse(report.buildNumber.isEmpty)
        XCTAssertFalse(report.bundleIdentifier.isEmpty)
        XCTAssertFalse(report.osVersion.isEmpty)
        XCTAssertFalse(report.deviceModel.isEmpty)
        XCTAssertFalse(report.locale.isEmpty)
        XCTAssertFalse(report.timeZone.isEmpty)
        XCTAssertGreaterThanOrEqual(report.performance.monitoringDurationSeconds, 0)
        XCTAssertGreaterThanOrEqual(report.performance.totalDroppedFrameEstimate, 0)
        XCTAssertGreaterThanOrEqual(report.performance.mainThreadStallCount, 0)
        XCTAssertFalse(report.performance.thermalState.isEmpty)
        XCTAssertFalse(report.storageFootprint.isEmpty)
        XCTAssertGreaterThanOrEqual(report.scheduleCache.responseCacheFileCount, 0)
        XCTAssertGreaterThanOrEqual(report.scheduleCache.responseCacheBytes, 0)
    }

    func testDiagnosticReportTextGeneration() async {
        let text = await CrashDiagnosticManager.shared.generateReportText()

        XCTAssertTrue(text.contains("### 📱 Диагностика MyIIS"))
        XCTAssertTrue(text.contains("Bundle ID"))
        XCTAssertTrue(text.contains("Устройство"))
        XCTAssertTrue(text.contains("Производительность"))
        XCTAssertTrue(text.contains("Кэш расписания"))
        XCTAssertTrue(text.contains("Хранилище и кэши"))
    }

    func testExportReportFileCreationAndValidJSON() async throws {
        let fileURL = try await CrashDiagnosticManager.shared.exportReportFile()

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let report = try decoder.decode(CrashDiagnosticManager.DiagnosticReport.self, from: data)

        XCTAssertFalse(report.bundleIdentifier.isEmpty)

        try? FileManager.default.removeItem(at: fileURL)
    }

    func testLogServiceRingBufferCapacity() async {
        let logService = LogService.shared
        await MainActor.run {
            logService.clearLogs()
        }

        for index in 1...250 {
            logService.log("Test log entry #\(index)")
        }

        // Give a short moment for main actor dispatch
        try? await Task.sleep(nanoseconds: 100_000_000)

        let messages = await logService.recentMessagesSnapshot(limit: 300)
        XCTAssertLessThanOrEqual(messages.count, 200)
        XCTAssertTrue(messages.last?.contains("Test log entry #250") == true)
    }

    func testLogServiceNetworkErrorRecording() async {
        let logService = LogService.shared
        logService.recordNetworkError(endpoint: "GET /api/v1/schedule", statusCode: 502, message: "Bad Gateway")

        try? await Task.sleep(nanoseconds: 50_000_000)

        let lastError = await MainActor.run { logService.lastNetworkError }
        XCTAssertEqual(lastError?.endpoint, "GET /api/v1/schedule")
        XCTAssertEqual(lastError?.statusCode, 502)
        XCTAssertEqual(lastError?.message, "Bad Gateway")
    }
}
