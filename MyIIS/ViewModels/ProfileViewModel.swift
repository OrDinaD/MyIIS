import Combine
import Foundation

@MainActor
class ProfileViewModel: ObservableObject {

    private let authService: AuthenticationService

    var user: User? {
        authService.currentUser
    }

    init(authService: AuthenticationService) {
        self.authService = authService
    }

    convenience init() {
        self.init(authService: AuthenticationService.shared)
    }

    func logout() {
        authService.logout()
    }
}
