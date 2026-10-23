import Foundation

/// Shared by schedules and teacher photos so an unavailable gateway is not retried for every cell.
actor ScheduleGatewayHealth {
    static let shared = ScheduleGatewayHealth()
    private var retryAfter: Date?
    private var probeInFlight = false

    func shouldAttempt(at now: Date = Date()) -> Bool {
        guard let retryAfter else { return true }
        guard now >= retryAfter, !probeInFlight else { return false }
        probeInFlight = true
        return true
    }

    func succeeded() {
        retryAfter = nil
        probeInFlight = false
    }

    func failed(at now: Date = Date()) {
        retryAfter = now.addingTimeInterval(60)
        probeInFlight = false
    }

    func cancelled() {
        probeInFlight = false
    }
}

/// A resource deadline bounds the entire gateway transfer, not just pauses between packets.
enum ScheduleGatewaySession {
    nonisolated static let shared: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 1.5
        configuration.timeoutIntervalForResource = 1.5
        configuration.waitsForConnectivity = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()
}
