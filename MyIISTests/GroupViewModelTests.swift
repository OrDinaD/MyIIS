@testable import MyIIS
import XCTest

// MARK: - Mock URL Protocol
final class MockURLProtocol: URLProtocol {
    static nonisolated(unsafe) var mockData: Data?
    static nonisolated(unsafe) var mockResponse: HTTPURLResponse?
    static nonisolated(unsafe) var mockError: Error?
    static nonisolated(unsafe) var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let handler = MockURLProtocol.requestHandler {
            do {
                let (response, data) = try handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
            return
        }

        if let error = MockURLProtocol.mockError {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            if let response = MockURLProtocol.mockResponse {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data = MockURLProtocol.mockData {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

@MainActor
final class GroupViewModelTests: XCTestCase {

    var viewModel: GroupViewModel!
    var authService: AuthenticationService!
    var apiService: APIService!

    override func setUp() async throws {
        try await super.setUp()
        // Clear APIService cache
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("APIService.responseCache.") {
            defaults.removeObject(forKey: key)
        }

        authService = AuthenticationService(allowSessionRestore: false)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        config.urlCache = nil
        apiService = APIService(session: URLSession(configuration: config))
        viewModel = GroupViewModel(apiService: apiService, authService: authService)
    }

    override func tearDown() async throws {
        viewModel = nil
        authService = nil
        apiService = nil
        MockURLProtocol.mockResponse = nil
        MockURLProtocol.mockError = nil
        MockURLProtocol.mockData = nil
        try await super.tearDown()
    }

    // MARK: - isCurrentUser Tests

    func testIsCurrentUser_NilOrEmptyUserName_ReturnsFalse() {
        authService.currentUser = nil
        let student = GroupStudent(position: "Студент", fio: "Иванов Иван", urlId: nil)
        XCTAssertFalse(viewModel.isCurrentUser(student))
    }

    func testIsCurrentUser_ExactMatch_ReturnsTrue() {
        authService.currentUser = createMockUser(firstName: "Иван", lastName: "Иванов", middleName: "Иванович")
        let student = GroupStudent(position: "Студент", fio: "Иванов Иван Иванович", urlId: nil)
        XCTAssertTrue(viewModel.isCurrentUser(student))
    }

    func testIsCurrentUser_CaseInsensitiveMatch_ReturnsTrue() {
        authService.currentUser = createMockUser(firstName: "Иван", lastName: "Иванов", middleName: "Иванович")
        let student = GroupStudent(position: "Студент", fio: "иванов иван иванович", urlId: nil)
        XCTAssertTrue(viewModel.isCurrentUser(student))
    }

    func testIsCurrentUser_DiacriticMatch_ReturnsTrue() {
        authService.currentUser = createMockUser(firstName: "Фёдор", lastName: "Иванов", middleName: "Иванович")
        let student = GroupStudent(position: "Студент", fio: "Иванов Федор Иванович", urlId: nil)
        XCTAssertTrue(viewModel.isCurrentUser(student))
    }

    func testIsCurrentUser_Mismatch_ReturnsFalse() {
        authService.currentUser = createMockUser(firstName: "Алексей", lastName: "Петров", middleName: "Иванович")
        let student = GroupStudent(position: "Студент", fio: "Иванов Иван Иванович", urlId: nil)
        XCTAssertFalse(viewModel.isCurrentUser(student))
    }

    // MARK: - groupTitle Tests

    func testGroupTitle_WhenGroupInfoLoaded_ReturnsGroupInfoNumber() throws {
        let json = Data("""
        {
            "numberOfGroup": "G-123",
            "groupInfoStudentDto": []
        }
        """.utf8)
        viewModel.groupInfo = try JSONDecoder().decode(UserGroupInfoResponse.self, from: json)
        authService.currentUser = createMockUser(group: "G-456")
        XCTAssertEqual(viewModel.groupTitle, "G-123")
    }

    func testGroupTitle_WhenGroupInfoNil_ReturnsUserGroup() {
        viewModel.groupInfo = nil
        authService.currentUser = createMockUser(group: "G-456")
        XCTAssertEqual(viewModel.groupTitle, "G-456")
    }

    func testGroupTitle_WhenBothNil_ReturnsFallback() {
        viewModel.groupInfo = nil
        authService.currentUser = nil
        XCTAssertEqual(viewModel.groupTitle, "—")
    }

    // MARK: - studentsCount and students Tests

    func testStudentsCount_ReturnsArrayCount() throws {
        let json = Data("""
        {
            "numberOfGroup": "1",
            "groupInfoStudentDto": [
                {"position": "A", "fio": "B"},
                {"position": "C", "fio": "D"}
            ]
        }
        """.utf8)
        viewModel.groupInfo = try JSONDecoder().decode(UserGroupInfoResponse.self, from: json)
        XCTAssertEqual(viewModel.studentsCount, 2)
        XCTAssertEqual(viewModel.students.count, 2)
    }

    func testStudentsCount_WhenNil_ReturnsZero() {
        viewModel.groupInfo = nil
        XCTAssertEqual(viewModel.studentsCount, 0)
        XCTAssertTrue(viewModel.students.isEmpty)
    }

    // MARK: - load() state tests

    func testLoadIfNeeded_FirstCall_FetchesData() async throws {
        let json = Data("""
        {
            "numberOfGroup": "123",
            "groupInfoStudentDto": []
        }
        """.utf8)
        MockURLProtocol.mockData = json
        MockURLProtocol.mockResponse = HTTPURLResponse(url: URL(string: "https://test.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.groupInfo?.numberOfGroup, "123")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoad_WhenAlreadyLoading_DoesNotFetchAgain() async {
        viewModel.isLoading = true
        await viewModel.reload()
        XCTAssertNil(viewModel.groupInfo) // Because it returned early
    }

    func testLoad_WhenFails_SetsErrorMessage() async {
        MockURLProtocol.mockError = URLError(.notConnectedToInternet)

        await viewModel.loadIfNeeded()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isShowingStaleDataWarning)
    }

    func testLoad_WhenFailsAndHasLoadedOnce_SetsStaleDataWarning() async throws {
        // Load once successfully
        let json = Data("""
        {
            "numberOfGroup": "123",
            "groupInfoStudentDto": []
        }
        """.utf8)
        MockURLProtocol.mockData = json
        MockURLProtocol.mockResponse = HTTPURLResponse(url: URL(string: "https://test.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        await viewModel.loadIfNeeded()

        // Clear APIService cache so reload actually fails instead of returning cached data
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("APIService.responseCache.") {
            defaults.removeObject(forKey: key)
        }

        // Load again with failure
        MockURLProtocol.mockData = nil
        MockURLProtocol.mockResponse = nil
        MockURLProtocol.mockError = URLError(.notConnectedToInternet)
        await viewModel.reload()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.isShowingStaleDataWarning)
    }

    func testClearForm() {
        // Just empty, for illustration or logout?
    }

    // MARK: - Download Group Report Tests

    func testDownloadGroupReport_WhenSuccessful_SetsURL() async throws {
        let url = try XCTUnwrap(URL(string: "https://test.com"))
        let headerFields = ["Content-Disposition": "attachment; filename=\"report.xlsx\""]

        MockURLProtocol.mockData = Data()
        MockURLProtocol.mockResponse = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: headerFields
        )

        await viewModel.downloadGroupReport()

        XCTAssertNotNil(viewModel.downloadedReportURL)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testDownloadGroupReport_WhenAlreadyDownloading_DoesNotFetchAgain() async {
        viewModel.isDownloadingReport = true
        await viewModel.downloadGroupReport()
        XCTAssertNil(viewModel.downloadedReportURL)
    }

    func testDownloadGroupReport_WhenFails_SetsErrorMessage() async {
        MockURLProtocol.mockError = URLError(.notConnectedToInternet)

        await viewModel.downloadGroupReport()

        XCTAssertNil(viewModel.downloadedReportURL)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - Logout Tests

    func testLogout_CallsAuthService() {
        authService.currentUser = createMockUser(firstName: "Иван", lastName: "Иванов", middleName: "Иванович")
        viewModel.logout()
        // AuthService handles the logout asynchronously or clears defaults.
        // Assuming logout clears currentUser:
        XCTAssertNil(authService.currentUser)
    }

    // MARK: - Helpers

    private func createMockUser(firstName: String = "Иван", lastName: String = "Иванов", middleName: String = "Иванович", group: String = "851001") -> User {
        User(
            id: 1,
            firstName: firstName,
            lastName: lastName,
            middleName: middleName,
            belarusianFirstName: nil,
            belarusianLastName: nil,
            belarusianMiddleName: nil,
            birthDay: "2000-01-01",
            email: "test@test.com",
            phone: nil,
            photo: nil,
            summary: nil,
            rating: 5,
            education: Education(
                faculty: "КСиС",
                course: 1,
                speciality: "ПОИТ",
                group: group,
                specialityDepartmentEducationFormId: nil
            ),
            skills: [],
            references: [],
            settings: .default,
            isHeadman: false
        )
    }
}
