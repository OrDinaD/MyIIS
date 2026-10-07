//
//  ScheduleServerMetricsTracker.swift
//  MyIIS
//

import Combine
import Foundation
import Network
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// ==============================================================================
// MARK: - [DEBUG_TELEMETRY_MODULE] СНИМОК СЕТЕВОГО ОКРУЖЕНИЯ
// ==============================================================================

/// Снимок текущего сетевого состояния устройства (Wi-Fi, Cellular, VPN, экономия трафика).
public struct NetworkEnvironmentSnapshot: Codable, Sendable, Equatable {
    public let connectionType: String
    public let isVPNActive: Bool
    public let isExpensive: Bool
    public let isConstrained: Bool
    public let activeInterfaces: [String]
    public let vpnInterfaceName: String?

    public static let unknown = NetworkEnvironmentSnapshot(
        connectionType: "Неизвестно",
        isVPNActive: false,
        isExpensive: false,
        isConstrained: false,
        activeInterfaces: [],
        vpnInterfaceName: nil
    )

    public var summaryDescription: String {
        var parts: [String] = [connectionType]
        if isVPNActive {
            parts.append(vpnInterfaceName.map { "VPN (\($0))" } ?? "VPN активен")
        }
        if isConstrained {
            parts.append("Low Data Mode")
        }
        if isExpensive && connectionType != "Сотовая связь" {
            parts.append("Лимитная")
        }
        return parts.joined(separator: " • ")
    }

    public nonisolated static func from(path: NWPath) -> NetworkEnvironmentSnapshot {
        let interfaces = path.availableInterfaces
        let interfaceNames = interfaces.map(\.name)
        var vpnName: String?
        for iface in interfaces {
            let name = iface.name.lowercased()
            if name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp") || name.hasPrefix("tap") || name.hasPrefix("tun") {
                vpnName = iface.name
                break
            }
        }

        let connectionType: String
        if path.status != .satisfied {
            connectionType = "Нет соединения"
        } else if path.usesInterfaceType(.wifi) {
            connectionType = "Wi-Fi"
        } else if path.usesInterfaceType(.cellular) {
            connectionType = "Сотовая связь"
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = "Ethernet"
        } else {
            connectionType = "Другое"
        }

        return NetworkEnvironmentSnapshot(
            connectionType: connectionType,
            isVPNActive: vpnName != nil,
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained,
            activeInterfaces: interfaceNames,
            vpnInterfaceName: vpnName
        )
    }
}

// MARK: - Фоновый монитор сети (NWPathMonitor)

final class NetworkEnvironmentMonitor: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "org.ordinad.MyIIS.networkMonitor", qos: .utility)

    func start(onUpdate: @escaping @Sendable (NetworkEnvironmentSnapshot) -> Void) {
        monitor.pathUpdateHandler = { path in
            let snapshot = NetworkEnvironmentSnapshot.from(path: path)
            onUpdate(snapshot)
        }
        monitor.start(queue: queue)
        let initial = NetworkEnvironmentSnapshot.from(path: monitor.currentPath)
        onUpdate(initial)
    }

    func stop() {
        monitor.cancel()
    }
}

// ==============================================================================
// MARK: - [DEBUG_TELEMETRY_MODULE] ЗАПИСЬ О ЗАМЕРЕ ЗАПРОСА
// ==============================================================================

/// Полная запись о замере сетевого запроса к серверу расписания с детальной телеметрией.
public struct ScheduleServerMetricRecord: Codable, Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let server: String // "gateway" | "official"
    public let endpoint: String
    public let durationMs: Int
    public let httpStatusCode: Int
    public let isSuccess: Bool
    public let errorMessage: String?
    public let isClassHour: Bool

    // Расширенная сетевая диагностика
    public let connectionType: String
    public let isVPN: Bool
    public let isExpensive: Bool
    public let isConstrained: Bool
    public let responseBytes: Int?
    public let contentEncoding: String?
    public let serverTiming: String?
    public let cacheControl: String?
    public let fullURL: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        server: String,
        endpoint: String,
        durationMs: Int,
        httpStatusCode: Int,
        isSuccess: Bool,
        errorMessage: String? = nil,
        isClassHour: Bool? = nil,
        connectionType: String = "Неизвестно",
        isVPN: Bool = false,
        isExpensive: Bool = false,
        isConstrained: Bool = false,
        responseBytes: Int? = nil,
        contentEncoding: String? = nil,
        serverTiming: String? = nil,
        cacheControl: String? = nil,
        fullURL: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.server = server
        self.endpoint = endpoint
        self.durationMs = durationMs
        self.httpStatusCode = httpStatusCode
        self.isSuccess = isSuccess
        self.errorMessage = errorMessage
        self.isClassHour = isClassHour ?? ScheduleServerMetricsTracker.isDuringClassHours(at: timestamp)
        self.connectionType = connectionType
        self.isVPN = isVPN
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
        self.responseBytes = responseBytes
        self.contentEncoding = contentEncoding
        self.serverTiming = serverTiming
        self.cacheControl = cacheControl
        self.fullURL = fullURL
    }

    enum CodingKeys: String, CodingKey {
        case id, timestamp, server, endpoint, durationMs, httpStatusCode, isSuccess, errorMessage, isClassHour
        case connectionType, isVPN, isExpensive, isConstrained, responseBytes, contentEncoding, serverTiming, cacheControl, fullURL
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        server = try container.decode(String.self, forKey: .server)
        endpoint = try container.decode(String.self, forKey: .endpoint)
        durationMs = try container.decode(Int.self, forKey: .durationMs)
        httpStatusCode = try container.decode(Int.self, forKey: .httpStatusCode)
        isSuccess = try container.decode(Bool.self, forKey: .isSuccess)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        isClassHour = try container.decodeIfPresent(Bool.self, forKey: .isClassHour) ?? ScheduleServerMetricsTracker.isDuringClassHours(at: timestamp)
        connectionType = try container.decodeIfPresent(String.self, forKey: .connectionType) ?? "Неизвестно"
        isVPN = try container.decodeIfPresent(Bool.self, forKey: .isVPN) ?? false
        isExpensive = try container.decodeIfPresent(Bool.self, forKey: .isExpensive) ?? false
        isConstrained = try container.decodeIfPresent(Bool.self, forKey: .isConstrained) ?? false
        responseBytes = try container.decodeIfPresent(Int.self, forKey: .responseBytes)
        contentEncoding = try container.decodeIfPresent(String.self, forKey: .contentEncoding)
        serverTiming = try container.decodeIfPresent(String.self, forKey: .serverTiming)
        cacheControl = try container.decodeIfPresent(String.self, forKey: .cacheControl)
        fullURL = try container.decodeIfPresent(String.self, forKey: .fullURL)
    }

    public var serverDisplayName: String {
        switch server {
        case "gateway":
            return "Шлюз MyIIS"
        case "official":
            return "Официальный БГУИР"
        default:
            return server
        }
    }

    public var formattedResponseSize: String? {
        guard let responseBytes, responseBytes > 0 else { return nil }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(responseBytes))
    }
}

/// Результат интерактивного замера скорости (Ping / Benchmark).
public struct LiveBenchmarkResult: Sendable {
    public let gatewayDurationMs: Int?
    public let officialDurationMs: Int?
    public let gatewayError: String?
    public let officialError: String?
    public let networkSnapshot: NetworkEnvironmentSnapshot?

    public init(
        gatewayDurationMs: Int?,
        officialDurationMs: Int?,
        gatewayError: String? = nil,
        officialError: String? = nil,
        networkSnapshot: NetworkEnvironmentSnapshot? = nil
    ) {
        self.gatewayDurationMs = gatewayDurationMs
        self.officialDurationMs = officialDurationMs
        self.gatewayError = gatewayError
        self.officialError = officialError
        self.networkSnapshot = networkSnapshot
    }

    public var speedupFactor: Double? {
        guard let g = gatewayDurationMs, let o = officialDurationMs, g > 0 else { return nil }
        return Double(o) / Double(g)
    }
}

// ==============================================================================
// MARK: - [DEBUG_TELEMETRY_MODULE] СЕРВИС СБОРА И ЭКСПОРТА МЕТРИК
// ==============================================================================

/// Сервис отслеживания, агрегации и экспорта замеров скорости серверов расписания.
@MainActor
public final class ScheduleServerMetricsTracker: ObservableObject {
    public static let shared = ScheduleServerMetricsTracker()

    // --------------------------------------------------------------------------
    // MARK: - [DEBUG_TELEMETRY_SWITCH]
    // Чтобы мгновенно отключить весь сбор метрик и нагрузку, установите false.
    // --------------------------------------------------------------------------
    public static var isTelemetryEnabled: Bool = true

    public static let storageDefaultsKey = "services.schedule.metricsRecords.v1"
    private static let maxStoredRecords = 100

    @Published public private(set) var records: [ScheduleServerMetricRecord] = []
    @Published public private(set) var isBenchmarking: Bool = false
    @Published public private(set) var lastBenchmarkResult: LiveBenchmarkResult?
    @Published public private(set) var currentNetwork: NetworkEnvironmentSnapshot = .unknown

    private let defaults: UserDefaults
    private let networkMonitor = NetworkEnvironmentMonitor()

    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? (UserDefaults(suiteName: AppGroup.identifier) ?? .standard)
        loadRecords()
        networkMonitor.start { [weak self] snapshot in
            Task { @MainActor in
                self?.currentNetwork = snapshot
            }
        }
    }

    // MARK: - Class Hours Detection

    /// Проверяет, приходится ли указанное время на часы учебных занятий в БГУИР.
    /// Занятия: понедельник-суббота, с 08:00 до 19:30.
    public static func isDuringClassHours(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        if weekday == 1 { // Воскресенье
            return false
        }
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let totalMinutes = hour * 60 + minute
        return totalMinutes >= 480 && totalMinutes <= 1170
    }

    // MARK: - Tracking

    /// Фиксация одного замера скорости.
    public func track(
        server: String,
        endpoint: String,
        durationMs: Int,
        httpStatusCode: Int,
        isSuccess: Bool,
        errorMessage: String? = nil,
        date: Date = Date(),
        connectionType: String? = nil,
        isVPN: Bool? = nil,
        isExpensive: Bool? = nil,
        isConstrained: Bool? = nil,
        responseBytes: Int? = nil,
        contentEncoding: String? = nil,
        serverTiming: String? = nil,
        cacheControl: String? = nil,
        fullURL: String? = nil
    ) {
        guard Self.isTelemetryEnabled else { return }

        let record = ScheduleServerMetricRecord(
            timestamp: date,
            server: server,
            endpoint: endpoint,
            durationMs: durationMs,
            httpStatusCode: httpStatusCode,
            isSuccess: isSuccess,
            errorMessage: errorMessage,
            isClassHour: Self.isDuringClassHours(at: date),
            connectionType: connectionType ?? currentNetwork.connectionType,
            isVPN: isVPN ?? currentNetwork.isVPNActive,
            isExpensive: isExpensive ?? currentNetwork.isExpensive,
            isConstrained: isConstrained ?? currentNetwork.isConstrained,
            responseBytes: responseBytes,
            contentEncoding: contentEncoding,
            serverTiming: serverTiming,
            cacheControl: cacheControl,
            fullURL: fullURL
        )

        records.insert(record, at: 0)
        if records.count > Self.maxStoredRecords {
            records = Array(records.prefix(Self.maxStoredRecords))
        }
        saveRecords()
    }

    /// Потокобезопасная запись замера из любого асинхронного контекста.
    public nonisolated func recordMetric(
        server: String,
        endpoint: String,
        durationMs: Int,
        httpStatusCode: Int,
        isSuccess: Bool,
        errorMessage: String? = nil,
        responseBytes: Int? = nil,
        contentEncoding: String? = nil,
        serverTiming: String? = nil,
        cacheControl: String? = nil,
        fullURL: String? = nil
    ) {
        Task { @MainActor in
            guard Self.isTelemetryEnabled else { return }
            self.track(
                server: server,
                endpoint: endpoint,
                durationMs: durationMs,
                httpStatusCode: httpStatusCode,
                isSuccess: isSuccess,
                errorMessage: errorMessage,
                responseBytes: responseBytes,
                contentEncoding: contentEncoding,
                serverTiming: serverTiming,
                cacheControl: cacheControl,
                fullURL: fullURL
            )
        }
    }

    // MARK: - Aggregations

    public func records(for server: String) -> [ScheduleServerMetricRecord] {
        records.filter { $0.server == server }
    }

    public func averageDuration(for server: String) -> Double? {
        let matching = records.filter { $0.server == server && $0.isSuccess }
        guard !matching.isEmpty else { return nil }
        let sum = matching.reduce(0) { $0 + $1.durationMs }
        return Double(sum) / Double(matching.count)
    }

    public func minDuration(for server: String) -> Int? {
        records.filter { $0.server == server && $0.isSuccess }.map(\.durationMs).min()
    }

    public func maxDuration(for server: String) -> Int? {
        records.filter { $0.server == server && $0.isSuccess }.map(\.durationMs).max()
    }

    public func classHoursAverageDuration(for server: String) -> Double? {
        let matching = records.filter { $0.server == server && $0.isSuccess && $0.isClassHour }
        guard !matching.isEmpty else { return nil }
        let sum = matching.reduce(0) { $0 + $1.durationMs }
        return Double(sum) / Double(matching.count)
    }

    public func offHoursAverageDuration(for server: String) -> Double? {
        let matching = records.filter { $0.server == server && $0.isSuccess && !$0.isClassHour }
        guard !matching.isEmpty else { return nil }
        let sum = matching.reduce(0) { $0 + $1.durationMs }
        return Double(sum) / Double(matching.count)
    }

    public func averageDuration(for server: String, isVPN: Bool) -> Double? {
        let matching = records.filter { $0.server == server && $0.isSuccess && $0.isVPN == isVPN }
        guard !matching.isEmpty else { return nil }
        let sum = matching.reduce(0) { $0 + $1.durationMs }
        return Double(sum) / Double(matching.count)
    }

    public func averageDuration(for server: String, connectionType: String) -> Double? {
        let matching = records.filter { $0.server == server && $0.isSuccess && $0.connectionType.localizedCaseInsensitiveContains(connectionType) }
        guard !matching.isEmpty else { return nil }
        let sum = matching.reduce(0) { $0 + $1.durationMs }
        return Double(sum) / Double(matching.count)
    }

    public func averageResponseBytes(for server: String) -> Int? {
        let matching = records.compactMap { ($0.server == server && $0.isSuccess) ? $0.responseBytes : nil }
        guard !matching.isEmpty else { return nil }
        return matching.reduce(0, +) / matching.count
    }

    public func successRate(for server: String) -> Double {
        let matching = records.filter { $0.server == server }
        guard !matching.isEmpty else { return 100.0 }
        let successCount = matching.filter(\.isSuccess).count
        return (Double(successCount) / Double(matching.count)) * 100.0
    }

    public func totalRequests(for server: String) -> Int {
        records.filter { $0.server == server }.count
    }

    public var speedupComparison: String? {
        guard let gatewayAvg = averageDuration(for: "gateway"),
              let officialAvg = averageDuration(for: "official"),
              gatewayAvg > 0 else {
            return nil
        }
        let factor = officialAvg / gatewayAvg
        if factor > 1.1 {
            return String(format: "Шлюз быстрее в %.1f×", factor)
        } else if factor < 0.9 {
            return String(format: "БГУИР быстрее в %.1f×", 1.0 / factor)
        } else {
            return "Скорость сопоставима"
        }
    }

    public var lastComparisonSummary: String? {
        if let last = lastBenchmarkResult, let g = last.gatewayDurationMs, let o = last.officialDurationMs {
            return "\(g) мс vs \(o) мс"
        }
        if let gAvg = averageDuration(for: "gateway"), let oAvg = averageDuration(for: "official") {
            return "\(Int(gAvg)) мс vs \(Int(oAvg)) мс"
        }
        return nil
    }

    public func clearAll() {
        records = []
        lastBenchmarkResult = nil
        defaults.removeObject(forKey: Self.storageDefaultsKey)
    }

    // MARK: - Live Benchmark (Ping)

    public func runLiveBenchmark() async -> LiveBenchmarkResult {
        isBenchmarking = true
        defer { isBenchmarking = false }

        async let gatewayTask = measureRequest(
            url: URL(string: "https://bsuir.ordinad.xyz/api/v1/schedule/current-week")!,
            server: "gateway"
        )
        async let officialTask = measureRequest(
            url: URL(string: "https://iis.bsuir.by/api/v1/schedule/current-week")!,
            server: "official"
        )

        let (gDuration, gError) = await gatewayTask
        let (oDuration, oError) = await officialTask

        let result = LiveBenchmarkResult(
            gatewayDurationMs: gDuration,
            officialDurationMs: oDuration,
            gatewayError: gError,
            officialError: oError,
            networkSnapshot: currentNetwork
        )
        self.lastBenchmarkResult = result
        return result
    }

    private func measureRequest(url: URL, server: String) async -> (durationMs: Int?, error: String?) {
        let start = Date()
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("MyIIS-Benchmark/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("br, gzip, deflate", forHTTPHeaderField: "Accept-Encoding")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let duration = Int(Date().timeIntervalSince(start) * 1000)
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 200
            let isSuccess = (200...299).contains(statusCode)

            track(
                server: server,
                endpoint: "current-week",
                durationMs: duration,
                httpStatusCode: statusCode,
                isSuccess: isSuccess,
                errorMessage: isSuccess ? nil : "HTTP \(statusCode)",
                responseBytes: data.count,
                contentEncoding: httpResponse?.value(forHTTPHeaderField: "Content-Encoding"),
                serverTiming: httpResponse?.value(forHTTPHeaderField: "Server-Timing"),
                cacheControl: httpResponse?.value(forHTTPHeaderField: "Cache-Control"),
                fullURL: url.absoluteString
            )
            return (duration, isSuccess ? nil : "HTTP \(statusCode)")
        } catch {
            let duration = Int(Date().timeIntervalSince(start) * 1000)
            track(
                server: server,
                endpoint: "current-week",
                durationMs: duration,
                httpStatusCode: -1,
                isSuccess: false,
                errorMessage: error.localizedDescription,
                fullURL: url.absoluteString
            )
            return (nil, error.localizedDescription)
        }
    }

    // MARK: - Detailed Report Generation (Export / Diagnostics)

    /// Генерирует исчерпывающий текстовый диагностический отчет для отправки разработчику.
    public func generateDetailedReport() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ru_RU")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestampStr = dateFormatter.string(from: Date())

        #if canImport(UIKit)
        let deviceModel = UIDevice.current.model
        let systemVersion = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        #else
        let deviceModel = "Apple Device"
        let systemVersion = "macOS"
        #endif

        var lines: [String] = []
        lines.append("==================================================")
        lines.append("📊 ДИАГНОСТИЧЕСКИЙ ОТЧЕТ СЕТИ MYIIS")
        lines.append("==================================================")
        lines.append("⏱ Дата формирования: \(timestampStr) (\(TimeZone.current.identifier))")
        lines.append("📱 Устройство: \(deviceModel) (\(systemHardwareIdentifier())) | \(systemVersion)")
        lines.append("🌐 Текущая сеть: \(currentNetwork.connectionType)")
        lines.append("🛡 VPN статус: \(currentNetwork.isVPNActive ? "АКТИВЕН (\(currentNetwork.vpnInterfaceName ?? "utun"))" : "Не активен")")
        lines.append("📶 Режим данных: \(currentNetwork.isConstrained ? "Low Data Mode (Экономия)" : "Стандартный") | Лимитная: \(currentNetwork.isExpensive ? "Да" : "Нет")")
        if !currentNetwork.activeInterfaces.isEmpty {
            lines.append("🔌 Интерфейсы: \(currentNetwork.activeInterfaces.joined(separator: ", "))")
        }
        lines.append("⚙️ Активный сервер в настройках: \(ScheduleServerConfiguration.selectedServer.shortTitle)")
        lines.append("")

        lines.append("--------------------------------------------------")
        lines.append("⚡️ СВОДКА И СРАВНЕНИЕ СЕРВЕРОВ")
        lines.append("--------------------------------------------------")

        let gCount = totalRequests(for: "gateway")
        let gSuccess = successRate(for: "gateway")
        let gAvg = averageDuration(for: "gateway")
        let gMin = minDuration(for: "gateway")
        let gMax = maxDuration(for: "gateway")
        let gClass = classHoursAverageDuration(for: "gateway")
        let gOff = offHoursAverageDuration(for: "gateway")
        let gBytes = averageResponseBytes(for: "gateway")

        lines.append("🔹 Шлюз MyIIS (bsuir.ordinad.xyz):")
        lines.append("  • Всего запросов: \(gCount) | Успешно: \(String(format: "%.1f%%", gSuccess))")
        if let gAvg {
            lines.append("  • Задержка: ср. \(Int(gAvg)) мс (мин: \(gMin ?? 0) мс, макс: \(gMax ?? 0) мс)")
            if let gClass { lines.append("  • В часы пар (08:00-19:30): \(Int(gClass)) мс") }
            if let gOff { lines.append("  • Вне пар: \(Int(gOff)) мс") }
        } else {
            lines.append("  • Нет данных о задержке")
        }
        if let gBytes {
            lines.append("  • Средний размер ответа: \(formatBytesHelper(gBytes))")
        }

        let oCount = totalRequests(for: "official")
        let oSuccess = successRate(for: "official")
        let oAvg = averageDuration(for: "official")
        let oMin = minDuration(for: "official")
        let oMax = maxDuration(for: "official")
        let oClass = classHoursAverageDuration(for: "official")
        let oOff = offHoursAverageDuration(for: "official")
        let oBytes = averageResponseBytes(for: "official")

        lines.append("")
        lines.append("🔸 Официальный БГУИР (iis.bsuir.by):")
        lines.append("  • Всего запросов: \(oCount) | Успешно: \(String(format: "%.1f%%", oSuccess))")
        if let oAvg {
            lines.append("  • Задержка: ср. \(Int(oAvg)) мс (мин: \(oMin ?? 0) мс, макс: \(oMax ?? 0) мс)")
            if let oClass { lines.append("  • В часы пар (08:00-19:30): \(Int(oClass)) мс") }
            if let oOff { lines.append("  • Вне пар: \(Int(oOff)) мс") }
        } else {
            lines.append("  • Нет данных о задержке")
        }
        if let oBytes {
            lines.append("  • Средний размер ответа: \(formatBytesHelper(oBytes))")
        }

        if let speedup = speedupComparison {
            lines.append("")
            lines.append("🚀 Вывод: \(speedup)")
        }

        lines.append("")
        lines.append("--------------------------------------------------")
        lines.append("📶 АНАЛИЗ ПО СЕТЯМ И VPN")
        lines.append("--------------------------------------------------")

        // Сравнение Wi-Fi
        if let gWifi = averageDuration(for: "gateway", connectionType: "Wi-Fi"),
           let oWifi = averageDuration(for: "official", connectionType: "Wi-Fi") {
            lines.append("• Wi-Fi: Шлюз \(Int(gWifi)) мс vs БГУИР \(Int(oWifi)) мс")
        } else if let gWifi = averageDuration(for: "gateway", connectionType: "Wi-Fi") {
            lines.append("• Wi-Fi: Шлюз \(Int(gWifi)) мс")
        }

        // Сравнение сотовой связи
        if let gCell = averageDuration(for: "gateway", connectionType: "Сотовая"),
           let oCell = averageDuration(for: "official", connectionType: "Сотовая") {
            lines.append("• Сотовая связь: Шлюз \(Int(gCell)) мс vs БГУИР \(Int(oCell)) мс")
        } else if let gCell = averageDuration(for: "gateway", connectionType: "Сотовая") {
            lines.append("• Сотовая связь: Шлюз \(Int(gCell)) мс")
        }

        // Сравнение VPN
        let gVPN = averageDuration(for: "gateway", isVPN: true)
        let gNoVPN = averageDuration(for: "gateway", isVPN: false)
        if let gVPN, let gNoVPN {
            lines.append("• Шлюз с VPN (\(Int(gVPN)) мс) vs без VPN (\(Int(gNoVPN)) мс)")
        } else if let gVPN {
            lines.append("• Шлюз с VPN: \(Int(gVPN)) мс")
        }

        let oVPN = averageDuration(for: "official", isVPN: true)
        let oNoVPN = averageDuration(for: "official", isVPN: false)
        if let oVPN, let oNoVPN {
            lines.append("• БГУИР с VPN (\(Int(oVPN)) мс) vs без VPN (\(Int(oNoVPN)) мс)")
        }

        lines.append("")
        lines.append("--------------------------------------------------")
        lines.append("🔍 АНАЛИЗ УЗКИХ МЕСТ (BOTTLENECK ANALYSIS)")
        lines.append("--------------------------------------------------")
        var insights: [String] = []

        if let gAvg, let oAvg {
            if gAvg < oAvg {
                let diff = Int(oAvg - gAvg)
                let factor = oAvg / gAvg
                insights.append("1. [Скорость] Шлюз быстрее прямого сервера БГУИР в \(String(format: "%.1f×", factor)) (экономия ~\(diff) мс на каждый запрос).")
            } else {
                insights.append("1. [Скорость] Прямой сервер БГУИР отвечает быстрее шлюза.")
            }
        }

        if let gBytes, let oBytes, oBytes > 0 {
            let compressionRatio = Double(oBytes) / Double(max(gBytes, 1))
            if compressionRatio > 1.3 {
                insights.append("2. [Сжатие и трафик] Шлюз снижает сетевой трафик в \(String(format: "%.1f×", compressionRatio)) благодаря Brotli (br) сжатию и фильтрации лишних полей.")
            }
        }

        if let gVPN, let gNoVPN {
            let vpnDiff = Int(gVPN - gNoVPN)
            if vpnDiff > 100 {
                insights.append("3. [Влияние VPN] VPN увеличивает сетевую задержку шлюза на ~\(vpnDiff) мс.")
            } else {
                insights.append("3. [Влияние VPN] VPN практически не влияет на задержку (разница ~\(abs(vpnDiff)) мс).")
            }
        }

        let failedGateway = records.filter { $0.server == "gateway" && !$0.isSuccess }
        if !failedGateway.isEmpty {
            insights.append("4. [Ошибки шлюза] Зафиксировано \(failedGateway.count) сбоев шлюза (последняя: \(failedGateway.first?.errorMessage ?? "нет детализации")).")
        } else {
            insights.append("4. [Надежность шлюза] 100% запросов к шлюзу завершились успешно.")
        }

        if insights.isEmpty {
            lines.append("• Недостаточно замеров для автоматического анализа узких мест.")
        } else {
            for insight in insights {
                lines.append(insight)
            }
        }

        lines.append("")
        lines.append("--------------------------------------------------")
        lines.append("📜 ИСТОРИЯ ПОСЛЕДНИХ ЗАПРОСОВ (до 50)")
        lines.append("--------------------------------------------------")

        let timeFmt = DateFormatter()
        timeFmt.locale = Locale(identifier: "ru_RU")
        timeFmt.dateFormat = "HH:mm:ss"

        let recent = records.prefix(50)
        if recent.isEmpty {
            lines.append("• Нет записанных замеров.")
        } else {
            for (idx, r) in recent.enumerated() {
                let sName = r.server == "gateway" ? "Шлюз" : "БГУИР"
                let icon = r.isSuccess ? "✅" : "❌"
                let sizeStr = r.formattedResponseSize ?? "—"
                let encStr = r.contentEncoding ?? "none"
                let vpnStr = r.isVPN ? "VPN" : "No-VPN"

                lines.append("[\(timeFmt.string(from: r.timestamp))] #\(idx + 1) \(icon) \(sName) | \(r.endpoint)")
                lines.append("  ├─ Статус: HTTP \(r.httpStatusCode) | Задержка: \(r.durationMs) мс | Размер: \(sizeStr) | Сжатие: \(encStr)")
                lines.append("  ├─ Сеть: \(r.connectionType) (\(vpnStr)) | Пары: \(r.isClassHour ? "Да" : "Нет")")
                if let err = r.errorMessage {
                    lines.append("  ├─ Ошибка: \(err)")
                }
                if let url = r.fullURL {
                    lines.append("  └─ URL: \(url)")
                }
            }
        }

        lines.append("==================================================")
        return lines.joined(separator: "\n")
    }

    private func systemHardwareIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier.isEmpty ? "unknown" : identifier
    }

    private func formatBytesHelper(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    // MARK: - Storage

    private func loadRecords() {
        guard let data = defaults.data(forKey: Self.storageDefaultsKey) else { return }
        do {
            records = try JSONDecoder().decode([ScheduleServerMetricRecord].self, from: data)
        } catch {
            records = []
        }
    }

    private func saveRecords() {
        do {
            let data = try JSONEncoder().encode(records)
            defaults.set(data, forKey: Self.storageDefaultsKey)
        } catch {
            // Ignore encoding failure
        }
    }
}
