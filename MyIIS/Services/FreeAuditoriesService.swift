//
//  FreeAuditoriesService.swift
//  MyIIS
//

import Foundation

/// Сервис получения свободных аудиторий по корпусам БГУИР.
public final class FreeAuditoriesService: Sendable {
    public static let shared = FreeAuditoriesService()

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Запрашивает свободные аудитории для указанного корпуса и временного слота.
    public func fetchFreeAuditories(
        building: String,
        day: String? = nil,
        slot: Int? = nil,
        week: Int? = nil
    ) async throws -> FreeAuditoriesResponse {
        var components = URLComponents(url: ScheduleServerConfiguration.gatewayBaseURL.appendingPathComponent("auditories/free"), resolvingAgainstBaseURL: false)

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "building", value: building)
        ]
        if let day, !day.isEmpty {
            queryItems.append(URLQueryItem(name: "day", value: day))
        }
        if let slot, slot > 0 {
            queryItems.append(URLQueryItem(name: "slot", value: String(slot)))
        }
        if let week, week > 0 {
            queryItems.append(URLQueryItem(name: "week", value: String(week)))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("br, gzip, deflate", forHTTPHeaderField: "Accept-Encoding")

        let startTime = Date()
        let (data, response) = try await session.data(for: request)
        let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 200

        ScheduleServerMetricsTracker.shared.track(
            server: "gateway",
            endpoint: "auditories/free",
            durationMs: durationMs,
            httpStatusCode: statusCode,
            isSuccess: (200...299).contains(statusCode)
        )

        guard (200...299).contains(statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(FreeAuditoriesResponse.self, from: data)
    }
}
