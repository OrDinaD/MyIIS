
import Foundation
import Combine

@MainActor
class LogService: ObservableObject {
    
    @Published private(set) var messages: [String] = []
    
    static let shared = LogService()
    
    private init() {}
    
    func log(_ message: String) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        let formattedMessage = "[\(timestamp)] \(message)"
        messages.append(formattedMessage)
        print("[MyIIS_DEBUG] \(formattedMessage)")
        NSLog("[MyIIS_DEBUG] \(formattedMessage)")
    }
    
    func clearLogs() {
        messages.removeAll()
    }
}
