import Foundation
import Combine

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

        print("[MyIIS_DEBUG] \(formattedMessage)")
        NSLog("[MyIIS_DEBUG] \(formattedMessage)")
    }

    @MainActor
    func clearLogs() {
        messages.removeAll()
    }
}
