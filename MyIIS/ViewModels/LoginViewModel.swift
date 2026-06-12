import Combine
import Foundation
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

    init(authService: AuthenticationService) {
        self.authService = authService
    }

    @MainActor
    convenience init() {
        self.init(authService: .shared)
    }

    func login() async {
        guard validateInput() else { return }
        await authService.login(username: username, password: password)
    }

    func loginDemo() async {
        username = APIService.demoUsername
        password = APIService.demoPassword
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
