import Combine
import Foundation
import Observation

@MainActor
@Observable
final class ProfileViewModel {

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
