import Foundation

extension Notification.Name {
    static let myiisAuthenticationSessionExpired = Notification.Name(
        "by.bsuir.MyIIS.authenticationSessionExpired"
    )
}

enum AuthenticationSessionEvents {
    static func reportUnauthorized(
        center: NotificationCenter = .default
    ) {
        center.post(name: .myiisAuthenticationSessionExpired, object: nil)
    }
}
