import XCTest
@testable import MyIIS

@MainActor
final class LoginViewModelTests: XCTestCase {
    func testLoginWithValidCredentialsDelegatesToService() async {
        let authService = makeAuthService()
        let viewModel = LoginViewModel(authService: authService)

        viewModel.username = "student"
        viewModel.password = "secret"

        await viewModel.login()

        XCTAssertEqual(authService.loginCallCount, 1)
        XCTAssertEqual(authService.lastCredentials?.username, "student")
        XCTAssertEqual(authService.lastCredentials?.password, "secret")
    }

    func testLoginDoesNotRunWhenCredentialsInvalid() async {
        let authService = makeAuthService()
        let viewModel = LoginViewModel(authService: authService)

        viewModel.username = " "
        viewModel.password = "password"
        await viewModel.login()
        XCTAssertEqual(authService.loginCallCount, 0)

        viewModel.username = "student"
        viewModel.password = ""
        await viewModel.login()
        XCTAssertEqual(authService.loginCallCount, 0)
    }

    func testClearFormResetsFields() {
        let authService = makeAuthService()
        let viewModel = LoginViewModel(authService: authService)

        viewModel.username = "student"
        viewModel.password = "secret"

        viewModel.clearForm()

        XCTAssertEqual(viewModel.username, "")
        XCTAssertEqual(viewModel.password, "")
    }

    func testDerivedPropertiesReflectServiceState() {
        let authService = makeAuthService()
        authService.isLoading = true
        authService.errorMessage = "Ошибка"

        let viewModel = LoginViewModel(authService: authService)

        XCTAssertTrue(viewModel.isLoading)
        XCTAssertEqual(viewModel.errorMessage, "Ошибка")
    }
}

private var authServicePool: [AuthenticationServiceMock] = []

private func makeAuthService() -> AuthenticationServiceMock {
    let service = AuthenticationServiceMock()
    authServicePool.append(service)
    return service
}

private final class AuthenticationServiceMock: AuthenticationService {
    private(set) var loginCallCount = 0
    private(set) var lastCredentials: (username: String, password: String)?

    init() {
        super.init(apiService: APIService(), logService: LogService.shared)
    }

    override func login(
        username: String,
        password: String,
        persistCredentials: Bool,
        isSilent: Bool
    ) async {
        loginCallCount += 1
        lastCredentials = (username, password)
    }
}
