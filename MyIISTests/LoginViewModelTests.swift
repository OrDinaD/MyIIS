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

@MainActor
final class AuthenticationServiceTests: XCTestCase {
    override func tearDown() async throws {
        AuthenticationMockURLProtocol.requestHandler = nil
        try await super.tearDown()
    }

    func testSilentLoginKeepsCachedSessionWithoutNetwork() async {
        let cachedUser = User.mock
        let authService = makeAuthenticationService { _ in
            throw URLError(.notConnectedToInternet)
        }
        authService.currentUser = cachedUser

        await authService.login(
            username: "123456",
            password: "password",
            persistCredentials: false,
            isSilent: true
        )

        XCTAssertEqual(authService.currentUser, cachedUser)
        XCTAssertTrue(authService.isSessionReady)
        XCTAssertFalse(authService.isRestoringSession)
        XCTAssertNil(authService.errorMessage)
    }

    func testSilentLoginClearsCachedSessionWhenCredentialsAreRejected() async {
        let authService = makeAuthenticationService { request in
            (
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Data()
            )
        }
        authService.currentUser = .mock

        await authService.login(
            username: "123456",
            password: "wrong-password",
            persistCredentials: false,
            isSilent: true
        )

        XCTAssertNil(authService.currentUser)
        XCTAssertFalse(authService.isSessionReady)
        XCTAssertNotNil(authService.errorMessage)
    }

    func testSilentLoginKeepsCachedSessionWhenProfileRefreshIsRejected() async throws {
        let loginData = try JSONEncoder().encode(DemoMockData.loginResponse)
        let authService = makeAuthenticationService { request in
            let url = try XCTUnwrap(request.url)
            if url.path.hasSuffix("/auth/login") {
                return (
                    HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!,
                    loginData
                )
            }

            return (
                HTTPURLResponse(
                    url: url,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Data()
            )
        }
        let cachedUser = User.mock
        authService.currentUser = cachedUser

        await authService.login(
            username: "123456",
            password: "password",
            persistCredentials: false,
            isSilent: true
        )

        XCTAssertEqual(authService.currentUser, cachedUser)
        XCTAssertTrue(authService.isSessionReady)
        XCTAssertNil(authService.errorMessage)
    }

    private func makeAuthenticationService(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> AuthenticationService {
        AuthenticationMockURLProtocol.requestHandler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AuthenticationMockURLProtocol.self]
        let apiService = APIService(session: URLSession(configuration: configuration))
        return AuthenticationService(apiService: apiService, allowSessionRestore: false)
    }
}

private final class AuthenticationMockURLProtocol: URLProtocol {
    static nonisolated(unsafe) var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
