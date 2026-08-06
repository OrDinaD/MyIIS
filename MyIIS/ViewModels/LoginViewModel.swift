import Combine
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class LoginViewModel {

    var username: String = ""
    var password: String = ""

    var isLoading: Bool = false
    var errorMessage: String?
    var isServerActive: Bool?

    private var authService: AuthenticationService
    private var cancellables = Set<AnyCancellable>()

    init(authService: AuthenticationService) {
        self.authService = authService

        authService.$isLoading
            .receive(on: RunLoop.main)
            .sink { [weak self] val in self?.isLoading = val }
            .store(in: &cancellables)

        authService.$errorMessage
            .receive(on: RunLoop.main)
            .sink { [weak self] msg in self?.errorMessage = msg }
            .store(in: &cancellables)

        checkServerStatus()
    }

    func checkServerStatus() {
        Task {
            let active = await authService.checkServerStatus()
            self.isServerActive = active
        }
    }

    @MainActor
    convenience init() {
        self.init(authService: .shared)
    }

    func login() async {
        guard validateInput() else { return }
        let usesDemoCredentials = username == APIService.demoUsername && password == APIService.demoPassword
        guard usesDemoCredentials || isServerActive == true else { return }
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
