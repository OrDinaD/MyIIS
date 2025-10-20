import XCTest
@testable import MyIIS

@MainActor
final class ProfileViewModelTests: XCTestCase {
    func testUserReflectsAuthenticationService() {
        let authService = makeAuthServiceSpy()
        authService.currentUser = .mock

        let viewModel = ProfileViewModel(authService: authService)

        XCTAssertEqual(viewModel.user, .mock)
    }

    func testLogoutDelegatesToService() {
        let authService = makeAuthServiceSpy()
        let viewModel = ProfileViewModel(authService: authService)

        viewModel.logout()

        XCTAssertEqual(authService.logoutCallCount, 1)
    }
}

private var authServiceSpyPool: [AuthenticationServiceSpy] = []

private func makeAuthServiceSpy() -> AuthenticationServiceSpy {
    let service = AuthenticationServiceSpy()
    authServiceSpyPool.append(service)
    return service
}

private final class AuthenticationServiceSpy: AuthenticationService {
    private(set) var logoutCallCount = 0

    override init(apiService: APIService = APIService(), logService: LogService = .shared) {
        super.init(apiService: apiService, logService: logService)
    }

    override func logout() {
        logoutCallCount += 1
        super.logout()
    }
}
