import Foundation
import Combine
import SwiftUI

@MainActor
class LoginViewModel: ObservableObject {
    
    @Published var username: String = ""
    @Published var password: String = ""
    
    private var authService: AuthenticationService
    
    var isLoading: Bool {
        authService.isLoading
    }
    
    var errorMessage: String? {
        authService.errorMessage
    }
    
    init(authService: AuthenticationService = .shared) {
        self.authService = authService
        
#if DEBUG
        // Auto-fill credentials for faster debugging
        self.username = "42850012"
        self.password = "Bsuirinyouv.12_"
#endif
    }
    
    func login() async {
        guard validateInput() else { return }
        await authService.login(username: username, password: password)
    }
    
    func clearForm() {
        username = ""
        password = ""
    }
    
    private func validateInput() -> Bool {
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else {
            return false
        }
        guard !password.isEmpty else {
            return false
        }
        return true
    }
}
