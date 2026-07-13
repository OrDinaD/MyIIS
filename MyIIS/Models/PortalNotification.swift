import Foundation

enum PortalNotificationKind: String, Decodable, Sendable {
    case info = "INFO"
    case success = "SUCCESS"
    case failure = "FAILURE"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Self(rawValue: rawValue) ?? .info
    }
}

struct PortalNotification: Decodable, Identifiable, Equatable, Sendable {
    let id: Int
    let message: String
    var isViewed: Bool
    let date: String
    let type: PortalNotificationKind
}

struct PortalNotificationsPage: Decodable, Equatable, Sendable {
    let notifications: [PortalNotification]
    let totalElements: Int
    let hasNext: Bool
}

struct PortalNotificationReadUpdate: Encodable {
    let id: Int
    let isViewed: Bool
}
