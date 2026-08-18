import Combine
import Foundation

final class LogService: ObservableObject, @unchecked Sendable {

    struct NetworkErrorRecord: Sendable, Codable {
        let endpoint: String
        let statusCode: Int?
        let message: String
        let timestamp: Date
    }

    @Published private(set) var messages: [String] = []
    @Published private(set) var lastNetworkError: NetworkErrorRecord?

    private let maxCapacity = 200

    static let shared = LogService()

    private init() {}

    nonisolated func log(_ message: String) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        let formattedMessage = "[\(timestamp)] \(message)"

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.messages.append(formattedMessage)
            if self.messages.count > self.maxCapacity {
                self.messages.removeFirst(self.messages.count - self.maxCapacity)
            }
        }

        #if DEBUG
        print("[MyIIS_DEBUG] \(formattedMessage)")
        #endif
    }

    nonisolated func recordNetworkError(endpoint: String, statusCode: Int?, message: String) {
        let record = NetworkErrorRecord(
            endpoint: endpoint,
            statusCode: statusCode,
            message: message,
            timestamp: Date()
        )
        Task { @MainActor [weak self] in
            self?.lastNetworkError = record
        }
    }

    @MainActor
    func clearLogs() {
        messages.removeAll()
        lastNetworkError = nil
    }

    @MainActor
    func recentMessages(limit: Int = 120) -> [String] {
        Array(messages.suffix(max(1, limit)))
    }

    nonisolated func recentMessagesSnapshot(limit: Int = 120) async -> [String] {
        await MainActor.run {
            self.recentMessages(limit: limit)
        }
    }
}
