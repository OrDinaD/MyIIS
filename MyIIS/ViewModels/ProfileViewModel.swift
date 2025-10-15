import Foundation
import Combine

@MainActor
class ProfileViewModel: ObservableObject {
    
    private let authService: AuthenticationService
    
    var user: User? {
        authService.currentUser
    }
    
    init(authService: AuthenticationService = .shared) {
        self.authService = authService
    }
    
    func logout() {
        authService.logout()
    }
}
