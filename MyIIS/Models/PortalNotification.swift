import Foundation

enum PortalNotificationKind: String, Codable, Sendable {
    case info = "INFO"
    case success = "SUCCESS"
    case failure = "FAILURE"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Self(rawValue: rawValue) ?? .info
    }
}

struct PortalNotification: Codable, Identifiable, Equatable, Sendable {
    let id: Int
    let message: String
    var isViewed: Bool
    let date: String
    let type: PortalNotificationKind

    var destination: PortalNotificationDestination? {
        if message.localizedCaseInsensitiveContains("справк") {
            return .certificate(number: number(after: #"справк[а-яё]*\s*№\s*(\d+)"#))
        }
        if message.localizedCaseInsensitiveContains("общежит") {
            return .dormitory(applicationNumber: number(after: #"заявк[а-яё]*\s*№\s*(\d+)"#))
        }
        return nil
    }

    private func number(after pattern: String) -> Int? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = expression.firstMatch(
                in: message,
                range: NSRange(message.startIndex..., in: message)
              ),
              let range = Range(match.range(at: 1), in: message) else {
            return nil
        }
        return Int(message[range])
    }
}

struct PortalNotificationsPage: Codable, Equatable, Sendable {
    let notifications: [PortalNotification]
    let totalElements: Int
    let hasNext: Bool
}

struct PortalNotificationReadUpdate: Encodable {
    let id: Int
    let isViewed: Bool
}
