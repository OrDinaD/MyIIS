//
//  ScheduleServerMetricsTracker.swift
//  MyIIS
//

import Combine
import Foundation
import SwiftUI

/// Запись о замере сетевого запроса к серверу расписания.
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

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        server: String,
        endpoint: String,
        durationMs: Int,
        httpStatusCode: Int,
        isSuccess: Bool,
        errorMessage: String? = nil,
        isClassHour: Bool? = nil
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
}

/// Результат интерактивного замера скорости (Ping / Benchmark).
public struct LiveBenchmarkResult: Sendable {
    public let gatewayDurationMs: Int?
    public let officialDurationMs: Int?
    public let gatewayError: String?
    public let officialError: String?

    public var speedupFactor: Double? {
        guard let g = gatewayDurationMs, let o = officialDurationMs, g > 0 else { return nil }
        return Double(o) / Double(g)
    }
}

/// Сервис отслеживания и агрегации замеров скорости серверов расписания.
@MainActor
public final class ScheduleServerMetricsTracker: ObservableObject {
    public static let shared = ScheduleServerMetricsTracker()

    public static let storageDefaultsKey = "services.schedule.metricsRecords.v1"
    private static let maxStoredRecords = 100

    @Published public private(set) var records: [ScheduleServerMetricRecord] = []
    @Published public private(set) var isBenchmarking: Bool = false
    @Published public private(set) var lastBenchmarkResult: LiveBenchmarkResult?

    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? (UserDefaults(suiteName: AppGroup.identifier) ?? .standard)
        loadRecords()
    }

    // MARK: - Class Hours Detection

    /// Проверяет, приходится ли указанное время на часы учебных занятий в БГУИР.
    /// Занятия: понедельник-суббота, с 08:00 до 19:30.
    public static func isDuringClassHours(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        // В Gregorian календаре 1 = Воскресенье (Sunday). В БГУИР воскресенье — выходной.
        if weekday == 1 {
            return false
        }
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let totalMinutes = hour * 60 + minute

        // 08:00 (480 мин) — 19:30 (1170 мин)
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
        date: Date = Date()
    ) {
        let record = ScheduleServerMetricRecord(
            timestamp: date,
            server: server,
            endpoint: endpoint,
            durationMs: durationMs,
            httpStatusCode: httpStatusCode,
            isSuccess: isSuccess,
            errorMessage: errorMessage,
            isClassHour: Self.isDuringClassHours(at: date)
        )

        records.insert(record, at: 0)
        if records.count > Self.maxStoredRecords {
            records = Array(records.prefix(Self.maxStoredRecords))
        }
        saveRecords()
    }

    /// Потокобезопасная запись замера из асинхронного контекста.
    public nonisolated func recordMetric(
        server: String,
        endpoint: String,
        durationMs: Int,
        httpStatusCode: Int,
        isSuccess: Bool,
        errorMessage: String? = nil
    ) {
        Task { @MainActor in
            self.track(
                server: server,
                endpoint: endpoint,
                durationMs: durationMs,
                httpStatusCode: httpStatusCode,
                isSuccess: isSuccess,
                errorMessage: errorMessage
            )
        }
    }

    // MARK: - Aggregations

    public func records(for server: String) -> [ScheduleServerMetricRecord] {
        records.filter { $0.server == server }
    }

    public func averageDuration(for server: String) -> Double? {
        let serverRecords = records.filter { $0.server == server && $0.isSuccess }
        guard !serverRecords.isEmpty else { return nil }
        let sum = serverRecords.reduce(0) { $0 + $1.durationMs }
        return Double(sum) / Double(serverRecords.count)
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
            officialError: oError
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

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let duration = Int(Date().timeIntervalSince(start) * 1000)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 200
            let isSuccess = (200...299).contains(statusCode)

            track(
                server: server,
                endpoint: "current-week",
                durationMs: duration,
                httpStatusCode: statusCode,
                isSuccess: isSuccess,
                errorMessage: isSuccess ? nil : "HTTP \(statusCode)"
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
                errorMessage: error.localizedDescription
            )
            return (nil, error.localizedDescription)
        }
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
