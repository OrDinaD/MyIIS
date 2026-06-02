import Combine
import Foundation

final class LogService: ObservableObject, @unchecked Sendable {

    @Published private(set) var messages: [String] = []

    static let shared = LogService()

    private init() {}

    nonisolated func log(_ message: String) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        let formattedMessage = "[\(timestamp)] \(message)"

        Task { @MainActor [weak self] in
            self?.messages.append(formattedMessage)
        }

        #if DEBUG
        print("[MyIIS_DEBUG] \(formattedMessage)")
        #endif
    }

    @MainActor
    func clearLogs() {
        messages.removeAll()
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
