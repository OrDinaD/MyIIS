import Combine
import Foundation
import SwiftUI

@MainActor
class LoginViewModel: ObservableObject {

    @Published var username: String = ""
    @Published var password: String = ""

    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private var authService: AuthenticationService
    private var cancellables = Set<AnyCancellable>()

    init(authService: AuthenticationService) {
        self.authService = authService
        
        authService.$isLoading
            .receive(on: RunLoop.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
            
        authService.$errorMessage
            .receive(on: RunLoop.main)
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
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
