@testable import MyIIS
import XCTest

@MainActor
final class PasswordRecoveryTests: XCTestCase {
    private var session: URLSession!

    override func setUp() async throws {
        try await super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: configuration)
    }

    override func tearDown() async throws {
        session.invalidateAndCancel()
        MockURLProtocol.requestHandler = nil
        try await super.tearDown()
    }

    func testPasswordExpiredIsDistinctFromBadCredentialsAndNeverRetried() throws {
        let api = APIService(session: session)
        XCTAssertThrowsError(try api.handleStatusCode(
            401, data: Data(#"{"error":"PASSWORD_EXPIRED","message":"Password expired"}"#.utf8)
        )) { error in
            guard let error = error as? APIError, case .passwordExpired = error else {
                return XCTFail("Expected password expiration")
            }
            XCTAssertFalse(NetworkRetryPolicy.default.shouldRetry(error: error))
        }
        XCTAssertThrowsError(try api.handleStatusCode(
            401, data: Data(#"{"error":"BAD_CREDENTIALS","message":"Invalid credentials"}"#.utf8)
        )) { error in
            guard let error = error as? APIError, case .unauthorized = error else {
                return XCTFail("Bad credentials must remain distinct")
            }
        }
    }

    func testSilentLoginWithExpiredPasswordDropsCachedSessionAndKeepsReason() async throws {
        let credentials = try CredentialStore.shared.retrieve()
        defer { restoreCredentials(credentials) }
        MockURLProtocol.requestHandler = { request in
            (try Self.response(request, status: 401), Data(#"{"error":"PASSWORD_EXPIRED","message":"Password expired"}"#.utf8))
        }
        let auth = AuthenticationService(apiService: APIService(session: session), allowSessionRestore: false)
        auth.currentUser = .mock
        let success = await auth.login(username: "test-account", password: "old", persistCredentials: false, isSilent: true)
        XCTAssertFalse(success)
        XCTAssertNil(auth.currentUser)
        XCTAssertFalse(auth.isSessionReady)
        XCTAssertTrue(auth.isPasswordExpired)
        XCTAssertEqual(auth.recoveryUsername, "test-account")
        XCTAssertEqual(auth.errorMessage, APIError.passwordExpired.localizedDescription)
    }

    func testRecoveryRequestsUseHARContractIncludingExplicitNullPassword() async throws {
        let service = AccountSettingsService(session: session, recoverySession: session)
        let contact = "student+recovery@example.com"
        MockURLProtocol.requestHandler = Self.contractResponse
        let accounts = try await service.recoveryAccounts(contact: contact)
        XCTAssertEqual(accounts.first?.id, 17)
        XCTAssertFalse(try XCTUnwrap(accounts.first).isBlocked)
        let expiration = try await service.recoveryCodeExpiration(accountID: 17, contact: contact)
        XCTAssertNil(expiration)
        let attempts = try await service.recoveryRemainingAttempts(accountID: 17)
        XCTAssertEqual(attempts, 5)
        let lifetime = try await service.sendRecoveryCode(accountID: 17, contact: contact)
        XCTAssertEqual(lifetime, 180)
        let confirmation = try await service.confirmRecoveryCode(accountID: 17, contact: contact, code: "123456")
        try await service.setRecoveredPassword(confirmation: confirmation, password: "Valid!Password7")
    }

    func testRateLimitedCodeSendIsNotRetried() async {
        var count = 0
        MockURLProtocol.requestHandler = { request in
            count += 1
            return (try Self.response(request, status: 429), Data())
        }
        do {
            _ = try await AccountSettingsService(session: session, recoverySession: session).sendRecoveryCode(accountID: 17, contact: "test@example.com")
            XCTFail("Rate limit must fail")
        } catch {
            XCTAssertEqual((error as? PasswordRecoveryFailure)?.key, "password_recovery_blocked")
        }
        XCTAssertEqual(count, 1)
    }

    func testRecoveryModelDoesNotRepeatPasswordMutationAfterFailedLogin() async throws {
        let credentials = try CredentialStore.shared.retrieve()
        defer { restoreCredentials(credentials) }
        var mutations = 0
        MockURLProtocol.requestHandler = { request in
            let path = try XCTUnwrap(request.url?.path)
            let payload: String
            switch path {
            case "/api/v1/settings/rate-limit/ban-status", "/api/v1/settings/confirmation-code-expiration-time":
                payload = ""
            case "/api/v1/settings/contact/accounts-by-contact":
                payload = #"[{"id":17,"login":"student","expireBanDate":null}]"#
            case "/api/v1/settings/remaining-attempts":
                payload = "5"
            case "/api/v1/settings/send-code":
                payload = #"{"codeLifetimeSeconds":180}"#
            case "/api/v1/settings/confirm-code":
                payload = #"{"login":"student","token":"test-token"}"#
            case "/api/v1/settings/password/new":
                mutations += 1
                payload = ""
            case "/api/v1/auth/login":
                return (try Self.response(request, status: 401), Data(#"{"error":"BAD_CREDENTIALS"}"#.utf8))
            default:
                throw URLError(.unsupportedURL)
            }
            return (try Self.response(request), Data(payload.utf8))
        }
        let auth = AuthenticationService(apiService: APIService(session: session), allowSessionRestore: false)
        let model = PasswordRecoveryViewModel(authService: auth, service: AccountSettingsService(session: session, recoverySession: session))
        model.contact = "student@example.com"
        await model.lookupAccounts()
        await model.selectAccount(try XCTUnwrap(model.accounts.first))
        await model.sendCode()
        model.code = "123456"
        await model.confirmCode()
        model.newPassword = "Valid!Password7"
        model.repeatedPassword = model.newPassword
        await model.savePassword()
        XCTAssertEqual(model.step, .completed)
        XCTAssertFalse(model.didSignIn)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(model.newPassword.isEmpty)
        await model.savePassword()
        XCTAssertEqual(mutations, 1)
    }

    func testPasswordPolicyMatchesPortalRules() {
        XCTAssertTrue(IISPasswordPolicy.isValid("Valid!Password7", login: "student"))
        for invalid in ["short", "lowercaseonly1!", "NOLOWERCASE1!", "NoSpecial123", "Кириллица1!Ab", "Valid! student7"] {
            XCTAssertFalse(IISPasswordPolicy.isValid(invalid, login: "student"))
        }
        XCTAssertFalse(IISPasswordPolicy.isValid("Student!123", login: "student"))
    }

    nonisolated private static func contractResponse(_ request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let contact = "student+recovery@example.com"
        let path = try XCTUnwrap(request.url?.path)
        let query = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
        switch path {
        case "/api/v1/settings/rate-limit/ban-status":
            XCTAssertEqual(query.first { $0.name == "endpoint" }?.value, "/settings/contact/accounts-by-contact")
            return (try Self.response(request), Data())
        case "/api/v1/settings/contact/accounts-by-contact":
            XCTAssertEqual(query.first { $0.name == "contactValue" }?.value, contact)
            return (try Self.response(request), Data(#"[{"id":17,"login":"student","expireBanDate":null}]"#.utf8))
        case "/api/v1/settings/confirmation-code-expiration-time":
            XCTAssertEqual(query.first { $0.name == "codeType" }?.value, "Password")
            return (try Self.response(request), Data())
        case "/api/v1/settings/remaining-attempts":
            XCTAssertEqual(query.first { $0.name == "attemptType" }?.value, "RECOVERY")
            return (try Self.response(request), Data("5".utf8))
        default:
            XCTAssertEqual(request.httpMethod, "POST")
            let body = try Self.body(request)
            if path.hasSuffix("/send-code") {
                XCTAssertEqual(body["accountId"] as? Int, 17)
                XCTAssertEqual(body["contactValue"] as? String, contact)
                return (try Self.response(request), Data(#"{"codeLifetimeSeconds":180}"#.utf8))
            }
            if path.hasSuffix("/confirm-code") {
                XCTAssertEqual(body["confirmCode"] as? String, "123456")
                return (try Self.response(request), Data(#"{"login":"student","token":"test-token"}"#.utf8))
            }
            XCTAssertEqual(path, "/api/v1/settings/password/new")
            XCTAssertTrue(body["currentPassword"] is NSNull)
            XCTAssertEqual(body["token"] as? String, "test-token")
            XCTAssertEqual(body["newPassword"] as? String, "Valid!Password7")
            return (try Self.response(request), Data())
        }
    }

    nonisolated private static func response(_ request: URLRequest, status: Int = 200) throws -> HTTPURLResponse {
        try XCTUnwrap(HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: status, httpVersion: nil, headerFields: nil))
    }

    nonisolated private static func body(_ request: URLRequest) throws -> [String: Any] {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let size = stream.read(&buffer, maxLength: buffer.count)
                guard size > 0 else { break }
                data.append(buffer, count: size)
            }
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func restoreCredentials(_ credentials: StoredCredentials?) {
        if let credentials {
            try? CredentialStore.shared.save(credentials)
        } else {
            try? CredentialStore.shared.clear()
        }
    }
}
