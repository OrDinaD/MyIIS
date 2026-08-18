import Foundation
import MetricKit
import UIKit

final class CrashDiagnosticManager: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {

    static let shared = CrashDiagnosticManager()

    struct SavedCrashDiagnostic: Codable, Sendable {
        let date: Date
        let exceptionType: String?
        let signal: String?
        let terminationReason: String?
        let summary: String
    }

    struct DiagnosticReport: Codable, Sendable {
        let appVersion: String
        let buildNumber: String
        let bundleIdentifier: String
        let osVersion: String
        let deviceModel: String
        let locale: String
        let timeZone: String
        let timestamp: Date
        let lastNetworkError: LogService.NetworkErrorRecord?
        let recentLogs: [String]
        let metricKitDiagnostics: [SavedCrashDiagnostic]
    }

    private let diagnosticsDirectoryName = "Diagnostics"
    private let maxSavedDiagnostics = 5
    private let lock = NSLock()
    private var isStarted = false

    private override init() {
        super.init()
    }

    func start() {
        lock.lock()
        defer { lock.unlock() }

        guard !isStarted else { return }
        isStarted = true

        MXMetricManager.shared.add(self)
        LogService.shared.log("CrashDiagnosticManager: MetricKit subscriber registered")
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }

        guard isStarted else { return }
        isStarted = false
        MXMetricManager.shared.remove(self)
    }

    // MARK: - MXMetricManagerSubscriber

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        let count = payloads.count
        Task { @MainActor in
            LogService.shared.log("MetricKit: Received \(count) metric payload(s)")
        }
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let count = payloads.count
        Task { @MainActor in
            LogService.shared.log("MetricKit: Received \(count) diagnostic payload(s)")
        }

        var newDiagnostics: [SavedCrashDiagnostic] = []

        for payload in payloads {
            let timeStampEnd = payload.timeStampEnd

            if let crashDiagnostics = payload.crashDiagnostics {
                for crash in crashDiagnostics {
                    let excType = crash.exceptionType?.stringValue
                    let sig = crash.signal?.stringValue
                    let termReason = crash.terminationReason

                    let summary = "Crash [signal: \(sig ?? "N/A"), excType: \(excType ?? "N/A"), reason: \(termReason ?? "N/A")]"
                    newDiagnostics.append(
                        SavedCrashDiagnostic(
                            date: timeStampEnd,
                            exceptionType: excType,
                            signal: sig,
                            terminationReason: termReason,
                            summary: summary
                        )
                    )
                }
            }

            if let hangDiagnostics = payload.hangDiagnostics {
                for hang in hangDiagnostics {
                    let summary = "Hang [duration: \(hang.hangDuration.formatted())]"
                    newDiagnostics.append(
                        SavedCrashDiagnostic(
                            date: timeStampEnd,
                            exceptionType: "Hang",
                            signal: nil,
                            terminationReason: nil,
                            summary: summary
                        )
                    )
                }
            }
        }

        if !newDiagnostics.isEmpty {
            self.saveDiagnostics(newDiagnostics)
        }
    }

    // MARK: - Persistence & Storage

    nonisolated private func diagnosticsDirectoryURL() -> URL? {
        guard let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = cachesDir.appendingPathComponent(diagnosticsDirectoryName)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    nonisolated private func saveDiagnostics(_ diagnostics: [SavedCrashDiagnostic]) {
        guard let dir = diagnosticsDirectoryURL() else { return }

        var existing = loadSavedDiagnostics()
        existing.append(contentsOf: diagnostics)

        if existing.count > maxSavedDiagnostics {
            existing = Array(existing.suffix(maxSavedDiagnostics))
        }

        let fileURL = dir.appendingPathComponent("saved_diagnostics.json")
        if let data = try? JSONEncoder().encode(existing) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    nonisolated func loadSavedDiagnostics() -> [SavedCrashDiagnostic] {
        guard let dir = diagnosticsDirectoryURL() else { return [] }
        let fileURL = dir.appendingPathComponent("saved_diagnostics.json")
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? JSONDecoder().decode([SavedCrashDiagnostic].self, from: data) else {
            return []
        }
        return list
    }

    // MARK: - Sanitizer (Privacy & PII Protection)

    nonisolated static func sanitizeLogMessage(_ message: String) -> String {
        var sanitized = message

        // 1. Bearer tokens
        let bearerPattern = "(Bearer\\s+)[A-Za-z0-9\\-\\._~\\+\\/]+=*"
        if let regex = try? NSRegularExpression(pattern: bearerPattern, options: .caseInsensitive) {
            let range = NSRange(sanitized.startIndex..<sanitized.endIndex, in: sanitized)
            sanitized = regex.stringByReplacingMatches(in: sanitized, options: [], range: range, withTemplate: "$1[REDACTED]")
        }

        // 2. Passwords in JSON/query
        let passwordPattern = "(\"password\"\\s*:\\s*\")[^\"]+(\")"
        if let regex = try? NSRegularExpression(pattern: passwordPattern, options: .caseInsensitive) {
            let range = NSRange(sanitized.startIndex..<sanitized.endIndex, in: sanitized)
            sanitized = regex.stringByReplacingMatches(in: sanitized, options: [], range: range, withTemplate: "$1[REDACTED]$2")
        }

        // 3. Email addresses
        let emailPattern = "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        if let regex = try? NSRegularExpression(pattern: emailPattern, options: []) {
            let range = NSRange(sanitized.startIndex..<sanitized.endIndex, in: sanitized)
            sanitized = regex.stringByReplacingMatches(in: sanitized, options: [], range: range, withTemplate: "[EMAIL_REDACTED]")
        }

        // 4. Session tokens in URLs
        let sessionPattern = "((?:session|token|auth|key|secret)=)[^;\\s&]+"
        if let regex = try? NSRegularExpression(pattern: sessionPattern, options: .caseInsensitive) {
            let range = NSRange(sanitized.startIndex..<sanitized.endIndex, in: sanitized)
            sanitized = regex.stringByReplacingMatches(in: sanitized, options: [], range: range, withTemplate: "$1[REDACTED]")
        }

        return sanitized
    }

    // MARK: - Device Info Helper

    nonisolated static func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier.isEmpty ? "Unknown" : identifier
    }

    // MARK: - Report Generation

    func generateReport() async -> DiagnosticReport {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        let bundleID = Bundle.main.bundleIdentifier ?? "com.OrDinaD.MyIIS"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let model = Self.deviceModelIdentifier()
        let locale = Locale.current.identifier
        let timeZone = TimeZone.current.identifier

        let rawLogs = await LogService.shared.recentMessagesSnapshot(limit: 100)
        let sanitizedLogs = rawLogs.map { Self.sanitizeLogMessage($0) }

        let lastError = await MainActor.run { LogService.shared.lastNetworkError }
        let metricDiagnostics = loadSavedDiagnostics()

        return DiagnosticReport(
            appVersion: appVersion,
            buildNumber: buildNumber,
            bundleIdentifier: bundleID,
            osVersion: osVersion,
            deviceModel: model,
            locale: locale,
            timeZone: timeZone,
            timestamp: Date(),
            lastNetworkError: lastError,
            recentLogs: sanitizedLogs,
            metricKitDiagnostics: metricDiagnostics
        )
    }

    func generateReportText() async -> String {
        let report = await generateReport()
        let dateFormatter = ISO8601DateFormatter()
        let dateStr = dateFormatter.string(from: report.timestamp)

        var text = """
        ### 📱 Диагностика MyIIS
        - **Приложение**: \(report.appVersion) (Сборка \(report.buildNumber))
        - **Bundle ID**: \(report.bundleIdentifier)
        - **Устройство**: \(report.deviceModel) (\(report.osVersion))
        - **Локаль**: \(report.locale) | Часовой пояс: \(report.timeZone)
        - **Время отчета**: \(dateStr)

        """

        if let lastErr = report.lastNetworkError {
            let errDateStr = dateFormatter.string(from: lastErr.timestamp)
            text += """
            ### ⚠️ Последняя ошибка сети:
            - **Эндпоинт**: \(lastErr.endpoint)
            - **Код ответа**: \(lastErr.statusCode.map { String($0) } ?? "N/A")
            - **Сообщение**: \(lastErr.message)
            - **Время**: \(errDateStr)

            """
        }

        if !report.metricKitDiagnostics.isEmpty {
            text += "### 💥 Недавние сбои (MetricKit):\n"
            for item in report.metricKitDiagnostics {
                let diagDateStr = dateFormatter.string(from: item.date)
                text += "- [\(diagDateStr)] \(item.summary)\n"
            }
            text += "\n"
        }

        if !report.recentLogs.isEmpty {
            text += "### 📋 Последние события:\n"
            for log in report.recentLogs.suffix(25) {
                text += "- \(log)\n"
            }
        }

        return text
    }

    func exportReportFile() async throws -> URL {
        let report = await generateReport()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(report)

        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "MyIIS_Diagnostic_\(timestamp).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        try data.write(to: tempURL, options: .atomic)
        return tempURL
    }
}
