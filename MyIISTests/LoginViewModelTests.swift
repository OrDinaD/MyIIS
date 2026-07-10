@testable import MyIIS
import XCTest

@MainActor
final class LoginViewModelTests: XCTestCase {
    var viewModel: LoginViewModel!
    var authService: AuthenticationService!

    override func setUp() async throws {
        try await super.setUp()
        authService = AuthenticationService(allowSessionRestore: false)
        viewModel = LoginViewModel(authService: authService)
    }

    override func tearDown() async throws {
        viewModel = nil
        authService = nil
        try await super.tearDown()
    }

    func testLoginWithDemoCredentialsUsesDemoAccount() async {
        viewModel.username = APIService.demoUsername
        viewModel.password = APIService.demoPassword

        await viewModel.login()

        XCTAssertNotNil(authService.currentUser)
        XCTAssertTrue(authService.isSessionReady)
        XCTAssertFalse(authService.isRestoringSession)
        XCTAssertTrue(APIService.isDemoMode)
    }

    func testClearForm() {
        viewModel.username = "testUser"
        viewModel.password = "password123"

        viewModel.clearForm()

        XCTAssertTrue(viewModel.username.isEmpty, "Username should be empty after clearForm")
        XCTAssertTrue(viewModel.password.isEmpty, "Password should be empty after clearForm")
    }

    func testLoginValidationEmptyUsername() async {
        viewModel.username = ""
        viewModel.password = "password123"

        await viewModel.login()

        XCTAssertFalse(viewModel.isLoading, "Should not attempt to login if username is empty")
    }

    func testLoginValidationEmptyPassword() async {
        viewModel.username = "testUser"
        viewModel.password = ""

        await viewModel.login()

        XCTAssertFalse(viewModel.isLoading, "Should not attempt to login if password is empty")
    }

    func testLoginValidationWhitespaceUsername() async {
        viewModel.username = "   "
        viewModel.password = "password123"

        await viewModel.login()

        XCTAssertFalse(viewModel.isLoading, "Should not attempt to login if username contains only whitespace")
    }
}
