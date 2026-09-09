import Foundation
import MetricKit
import UIKit

// swiftlint:disable:next type_body_length
final class CrashDiagnosticManager: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {

    static let shared = CrashDiagnosticManager()

    struct SavedCrashDiagnostic: Codable, Sendable {
        let date: Date
        let exceptionType: String?
        let signal: String?
        let terminationReason: String?
        let summary: String
        var callStackTreeJSON: String? = nil
    }

    struct PerformanceSample: Codable, Sendable {
        let timestamp: Date
        let framesPerSecond: Double
        let expectedFramesPerSecond: Double
        let droppedFrameEstimate: Int
        let hitchCount: Int
        let maximumFrameGapMilliseconds: Double
    }

    struct PerformanceSnapshot: Codable, Sendable {
        let monitoringDurationSeconds: Double
        let samples: [PerformanceSample]
        let averageFramesPerSecond: Double?
        let minimumFramesPerSecond: Double?
        let totalDroppedFrameEstimate: Int
        let totalHitchCount: Int
        let mainThreadStallCount: Int
        let maximumMainThreadStallMilliseconds: Double
        let thermalState: String
        let isLowPowerModeEnabled: Bool
    }

    struct DirectoryFootprint: Codable, Sendable {
        let name: String
        let bytes: Int64
        let fileCount: Int
        let isTruncated: Bool
    }

    struct ScheduleCacheSnapshot: Codable, Sendable {
        let hasSelectedGroup: Bool
        let responseCacheFileCount: Int
        let responseCacheBytes: Int64
        let oldestResponseCacheAgeSeconds: Double?
        let newestResponseCacheAgeSeconds: Double?
        let sessionWidgetSnapshotBytes: Int64?
        let sessionWidgetEventCount: Int?
        let sessionWidgetDuplicateEventCount: Int?
        let sessionWidgetSnapshotAgeSeconds: Double?
        let classWidgetSnapshotBytes: Int64?
        let classWidgetEventCount: Int?
        let classWidgetDuplicateEventCount: Int?
        let classWidgetSnapshotAgeSeconds: Double?
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
        let performance: PerformanceSnapshot
        let storageFootprint: [DirectoryFootprint]
        let scheduleCache: ScheduleCacheSnapshot
    }

    private let diagnosticsDirectoryName = "Diagnostics"
    private let maxSavedDiagnostics = 5
    private let maxPerformanceSamples = 120
    private let storageEnumerationLimit = 10_000
    private let lock = NSLock()
    private var isStarted = false
    private var displayLink: CADisplayLink?
    private var heartbeatTimer: DispatchSourceTimer?
    private var monitoringStartedAt: Date?
    private var isApplicationActive = true
    private var lastFrameTimestamp: CFTimeInterval?
    private var sampleStartedAt: CFTimeInterval?
    private var sampleFrameCount = 0
    private var sampleDroppedFrameEstimate = 0
    private var sampleHitchCount = 0
    private var sampleMaximumFrameGap = 0.0
    private var recentPerformanceSamples: [PerformanceSample] = []
    private var heartbeatPending = false
    private var mainThreadStallCount = 0
    private var maximumMainThreadStallMilliseconds = 0.0

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
        Task { @MainActor [weak self] in
            self?.startPerformanceMonitoring()
        }
    }

    func stop() {
        lock.lock()
        guard isStarted else {
            lock.unlock()
            return
        }
        isStarted = false
        lock.unlock()

        MXMetricManager.shared.remove(self)
        Task { @MainActor [weak self] in
            self?.stopPerformanceMonitoring()
        }
    }

    // MARK: - Live performance monitoring

    @MainActor
    private func startPerformanceMonitoring() {
        guard displayLink == nil else { return }

        lock.lock()
        monitoringStartedAt = Date()
        isApplicationActive = UIApplication.shared.applicationState == .active
        lock.unlock()

        let link = CADisplayLink(target: self, selector: #selector(handleDisplayLink(_:)))
        link.add(to: .main, forMode: .common)
        link.isPaused = !isApplicationActive
        displayLink = link

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        let timer = DispatchSource.makeTimerSource(
            queue: DispatchQueue(label: "com.OrDinaD.MyIIS.performance-heartbeat", qos: .utility)
        )
        timer.schedule(
            deadline: .now() + .milliseconds(500),
            repeating: .milliseconds(500),
            leeway: .milliseconds(100)
        )
        timer.setEventHandler { [weak self] in
            self?.scheduleMainThreadHeartbeat()
        }
        timer.resume()
        heartbeatTimer = timer
    }

    @MainActor
    private func stopPerformanceMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @MainActor
    @objc private func applicationDidEnterBackground() {
        displayLink?.isPaused = true
        lock.lock()
        isApplicationActive = false
        lastFrameTimestamp = nil
        sampleStartedAt = nil
        heartbeatPending = false
        lock.unlock()
    }

    @MainActor
    @objc private func applicationDidBecomeActive() {
        lock.lock()
        isApplicationActive = true
        lastFrameTimestamp = nil
        sampleStartedAt = nil
        lock.unlock()
        displayLink?.isPaused = false
    }

    @MainActor
    @objc private func handleDisplayLink(_ link: CADisplayLink) {
        let timestamp = link.timestamp
        let expectedInterval = max(link.targetTimestamp - link.timestamp, link.duration)
        let expectedFramesPerSecond = expectedInterval > 0 ? 1.0 / expectedInterval : 0

        lock.lock()
        defer { lock.unlock() }

        guard isApplicationActive else { return }
        if sampleStartedAt == nil {
            sampleStartedAt = timestamp
        }

        if let previousTimestamp = lastFrameTimestamp {
            let gap = timestamp - previousTimestamp
            sampleMaximumFrameGap = max(sampleMaximumFrameGap, gap)
            if expectedInterval > 0 {
                sampleDroppedFrameEstimate += max(0, Int(gap / expectedInterval) - 1)
            }
            if gap >= 0.1 {
                sampleHitchCount += 1
            }
        }
        lastFrameTimestamp = timestamp
        sampleFrameCount += 1

        guard let startedAt = sampleStartedAt, timestamp - startedAt >= 1 else { return }
        let duration = timestamp - startedAt
        let framesPerSecond = duration > 0 ? Double(sampleFrameCount) / duration : 0
        recentPerformanceSamples.append(
            PerformanceSample(
                timestamp: Date(),
                framesPerSecond: framesPerSecond,
                expectedFramesPerSecond: expectedFramesPerSecond,
                droppedFrameEstimate: sampleDroppedFrameEstimate,
                hitchCount: sampleHitchCount,
                maximumFrameGapMilliseconds: sampleMaximumFrameGap * 1_000
            )
        )
        if recentPerformanceSamples.count > maxPerformanceSamples {
            recentPerformanceSamples.removeFirst(recentPerformanceSamples.count - maxPerformanceSamples)
        }

        sampleStartedAt = timestamp
        sampleFrameCount = 0
        sampleDroppedFrameEstimate = 0
        sampleHitchCount = 0
        sampleMaximumFrameGap = 0
    }

    private func scheduleMainThreadHeartbeat() {
        let sentAt = CACurrentMediaTime()

        lock.lock()
        guard isApplicationActive, !heartbeatPending else {
            lock.unlock()
            return
        }
        heartbeatPending = true
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.recordMainThreadHeartbeat(sentAt: sentAt)
        }
    }

    @MainActor
    private func recordMainThreadHeartbeat(sentAt: CFTimeInterval) {
        let delayMilliseconds = max(0, (CACurrentMediaTime() - sentAt) * 1_000)

        lock.lock()
        heartbeatPending = false
        if delayMilliseconds >= 250 {
            mainThreadStallCount += 1
            maximumMainThreadStallMilliseconds = max(maximumMainThreadStallMilliseconds, delayMilliseconds)
        }
        lock.unlock()
    }

    // MARK: - MXMetricManagerSubscriber

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        let count = payloads.count
        Task { @MainActor in
            LogService.shared.log("MetricKit: Received \(count) metric payload(s)")
        }

        var newDiagnostics: [SavedCrashDiagnostic] = []
        for payload in payloads {
            let timeStampEnd = payload.timeStampEnd
            let metricJSON = String(data: payload.jsonRepresentation(), encoding: .utf8)
            var summaryParts: [String] = []

            if let scrollHitchRatio = payload.animationMetrics?.scrollHitchTimeRatio {
                summaryParts.append("ScrollHitchRatio: \(scrollHitchRatio.value)")
            }
            if let fgTime = payload.applicationTimeMetrics?.cumulativeForegroundTime {
                summaryParts.append("ForegroundTime: \(fgTime.value)")
            }

            let summary = summaryParts.isEmpty ? "MetricKitMetrics" : "MetricKitMetrics [\(summaryParts.joined(separator: ", "))]"
            newDiagnostics.append(
                SavedCrashDiagnostic(
                    date: timeStampEnd,
                    exceptionType: "MetricKitMetrics",
                    signal: nil,
                    terminationReason: nil,
                    summary: summary,
                    callStackTreeJSON: metricJSON
                )
            )
        }

        if !newDiagnostics.isEmpty {
            self.saveDiagnostics(newDiagnostics)
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
                    let callStackJSON = String(data: crash.callStackTree.jsonRepresentation(), encoding: .utf8)

                    let summary = "Crash [signal: \(sig ?? "N/A"), excType: \(excType ?? "N/A"), reason: \(termReason ?? "N/A")]"
                    newDiagnostics.append(
                        SavedCrashDiagnostic(
                            date: timeStampEnd,
                            exceptionType: excType,
                            signal: sig,
                            terminationReason: termReason,
                            summary: summary,
                            callStackTreeJSON: callStackJSON
                        )
                    )
                }
            }

            if let hangDiagnostics = payload.hangDiagnostics {
                for hang in hangDiagnostics {
                    let callStackJSON = String(data: hang.callStackTree.jsonRepresentation(), encoding: .utf8)
                    let summary = "Hang [duration: \(hang.hangDuration.formatted())]"
                    newDiagnostics.append(
                        SavedCrashDiagnostic(
                            date: timeStampEnd,
                            exceptionType: "Hang",
                            signal: nil,
                            terminationReason: nil,
                            summary: summary,
                            callStackTreeJSON: callStackJSON
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

        // 5. Student identifiers and names emitted by authentication logs
        let studentIDPattern = "(Attempting to log in user:\\s*)[^\\s]+"
        if let regex = try? NSRegularExpression(pattern: studentIDPattern, options: .caseInsensitive) {
            let range = NSRange(sanitized.startIndex..<sanitized.endIndex, in: sanitized)
            sanitized = regex.stringByReplacingMatches(in: sanitized, options: [], range: range, withTemplate: "$1[STUDENT_ID_REDACTED]")
        }

        let profileNamePattern = "((?:Restored cached user profile for|User profile loaded:)\\s*)[^\\r\\n]+"
        if let regex = try? NSRegularExpression(pattern: profileNamePattern, options: .caseInsensitive) {
            let range = NSRange(sanitized.startIndex..<sanitized.endIndex, in: sanitized)
            sanitized = regex.stringByReplacingMatches(in: sanitized, options: [], range: range, withTemplate: "$1[NAME_REDACTED]")
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

    // MARK: - Performance snapshot

    private func performanceSnapshot() -> PerformanceSnapshot {
        lock.lock()
        let samples = recentPerformanceSamples
        let startedAt = monitoringStartedAt
        let stallCount = mainThreadStallCount
        let maximumStall = maximumMainThreadStallMilliseconds
        lock.unlock()

        let averageFPS: Double?
        if samples.isEmpty {
            averageFPS = nil
        } else {
            averageFPS = samples.map(\.framesPerSecond).reduce(0, +) / Double(samples.count)
        }

        return PerformanceSnapshot(
            monitoringDurationSeconds: startedAt.map { max(0, Date().timeIntervalSince($0)) } ?? 0,
            samples: samples,
            averageFramesPerSecond: averageFPS,
            minimumFramesPerSecond: samples.map(\.framesPerSecond).min(),
            totalDroppedFrameEstimate: samples.map(\.droppedFrameEstimate).reduce(0, +),
            totalHitchCount: samples.map(\.hitchCount).reduce(0, +),
            mainThreadStallCount: stallCount,
            maximumMainThreadStallMilliseconds: maximumStall,
            thermalState: Self.thermalStateDescription(ProcessInfo.processInfo.thermalState),
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }

    nonisolated private static func thermalStateDescription(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:
            return "nominal"
        case .fair:
            return "fair"
        case .serious:
            return "serious"
        case .critical:
            return "critical"
        @unknown default:
            return "unknown"
        }
    }

    nonisolated private static func collectStorageFootprint(
        limit: Int,
        appGroupIdentifier: String
    ) async -> [DirectoryFootprint] {
        await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            var roots: [(String, URL)] = []

            if let url = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
                roots.append(("Caches", url))
            }
            if let url = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                roots.append(("Application Support", url))
            }
            if let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                roots.append(("Documents", url))
            }
            if let url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
                roots.append(("App Group", url))
            }

            return roots.map { name, url in
                directoryFootprint(name: name, url: url, limit: limit, fileManager: fileManager)
            }
        }.value
    }

    nonisolated private static func directoryFootprint(
        name: String,
        url: URL,
        limit: Int,
        fileManager: FileManager
    ) -> DirectoryFootprint {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey]
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return DirectoryFootprint(name: name, bytes: 0, fileCount: 0, isTruncated: false)
        }

        var bytes: Int64 = 0
        var fileCount = 0
        var isTruncated = false

        while let fileURL = enumerator.nextObject() as? URL {
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else {
                continue
            }

            fileCount += 1
            bytes += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            if fileCount >= limit {
                isTruncated = true
                break
            }
        }

        return DirectoryFootprint(
            name: name,
            bytes: bytes,
            fileCount: fileCount,
            isTruncated: isTruncated
        )
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
        let performance = performanceSnapshot()
        let appGroupIdentifier = await MainActor.run { AppGroup.identifier }
        async let storageFootprint = Self.collectStorageFootprint(
            limit: storageEnumerationLimit,
            appGroupIdentifier: appGroupIdentifier
        )
        async let scheduleCache = ScheduleCacheDiagnosticCollector.collect(
            appGroupIdentifier: appGroupIdentifier
        )

        return await DiagnosticReport(
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
            metricKitDiagnostics: metricDiagnostics,
            performance: performance,
            storageFootprint: storageFootprint,
            scheduleCache: scheduleCache
        )
    }

    // swiftlint:disable:next function_body_length
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

        let averageFPS = report.performance.averageFramesPerSecond
            .map { String(format: "%.1f", $0) } ?? "N/A"
        let minimumFPS = report.performance.minimumFramesPerSecond
            .map { String(format: "%.1f", $0) } ?? "N/A"
        text += """
        ### Производительность:
        - **FPS (средний / минимум)**: \(averageFPS) / \(minimumFPS)
        - **Оценка пропущенных кадров**: \(report.performance.totalDroppedFrameEstimate)
        - **Задержки кадров >= 100 мс**: \(report.performance.totalHitchCount)
        - **Блокировки main thread >= 250 мс**: \(report.performance.mainThreadStallCount)
        - **Максимальная блокировка main thread**: \(String(format: "%.0f", report.performance.maximumMainThreadStallMilliseconds)) мс
        - **Thermal state**: \(report.performance.thermalState)
        - **Low Power Mode**: \(report.performance.isLowPowerModeEnabled ? "on" : "off")

        """

        let byteFormatter = ByteCountFormatter()
        byteFormatter.countStyle = .file
        let cache = report.scheduleCache
        text += """
        ### Кэш расписания:
        - **Выбранная группа сохранена**: \(cache.hasSelectedGroup ? "да" : "нет")
        - **API-кэш**: \(byteFormatter.string(fromByteCount: cache.responseCacheBytes)), файлов: \(cache.responseCacheFileCount)
        - **Виджет сессии (события / дубликаты)**: \(cache.sessionWidgetEventCount.map(String.init) ?? "нет") / \(cache.sessionWidgetDuplicateEventCount.map(String.init) ?? "нет")
        - **Виджет занятий (события / дубликаты)**: \(cache.classWidgetEventCount.map(String.init) ?? "нет") / \(cache.classWidgetDuplicateEventCount.map(String.init) ?? "нет")

        """

        if !report.storageFootprint.isEmpty {
            text += "### Хранилище и кэши:\n"
            for item in report.storageFootprint {
                let suffix = item.isTruncated ? " (неполный подсчёт)" : ""
                text += "- **\(item.name)**: \(byteFormatter.string(fromByteCount: item.bytes)), файлов: \(item.fileCount)\(suffix)\n"
            }
            text += "\n"
        }

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
