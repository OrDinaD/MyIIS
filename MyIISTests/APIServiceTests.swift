@testable import MyIIS
import XCTest

@MainActor
final class APIServiceTests: XCTestCase {

    var apiService: APIService!

    override func setUp() async throws {
        try await super.setUp()
        // Initialize APIService for each test
        apiService = APIService(session: .shared)
    }

    override func tearDown() async throws {
        apiService = nil
        try await super.tearDown()
    }

    // MARK: - Equivalence Partitioning & Boundary Value Analysis for Status Codes

    func testHandleStatusCode_ValidClass_DoesNotThrow() {
        // Valid status code class: 200...299
        // Boundary values: 200, 299
        // Typical value: 201

        XCTAssertNoThrow(try apiService.handleStatusCode(200, data: Data()), "Should not throw for boundary 200")
        XCTAssertNoThrow(try apiService.handleStatusCode(201, data: Data()), "Should not throw for typical 201")
        XCTAssertNoThrow(try apiService.handleStatusCode(299, data: Data()), "Should not throw for boundary 299")
    }

    func testHandleStatusCode_InvalidClass_ThrowsServerError() {
        // Invalid status code class: < 200, > 299 (except 401, 418)
        // Boundary values: 199, 300

        let emptyData = Data()

        XCTAssertThrowsError(try apiService.handleStatusCode(199, data: emptyData)) { error in
            guard case APIError.serverError(let code, _) = error else {
                XCTFail("Expected APIError.serverError")
                return
            }
            XCTAssertEqual(code, 199)
        }

        XCTAssertThrowsError(try apiService.handleStatusCode(300, data: emptyData)) { error in
            guard case APIError.serverError(let code, _) = error else {
                XCTFail("Expected APIError.serverError")
                return
            }
            XCTAssertEqual(code, 300)
        }

        XCTAssertThrowsError(try apiService.handleStatusCode(500, data: emptyData)) { error in
            guard case APIError.serverError(let code, _) = error else {
                XCTFail("Expected APIError.serverError")
                return
            }
            XCTAssertEqual(code, 500)
        }
    }

    func testHandleStatusCode_Unauthorized_ThrowsUnauthorized() {
        // Specific class: 401
        let errorData = Data(
            """
            {"msg":"Token expired"}
            """.utf8
        )

        XCTAssertThrowsError(try apiService.handleStatusCode(401, data: errorData)) { error in
            guard case APIError.unauthorized(let msg) = error else {
                XCTFail("Expected APIError.unauthorized")
                return
            }
            XCTAssertEqual(msg, "Token expired")
        }
    }

    func testHandleStatusCode_Forbidden_ThrowsUnauthorized() {
        let emptyData = Data()
        XCTAssertThrowsError(try apiService.handleStatusCode(403, data: emptyData)) { error in
            guard case APIError.unauthorized = error else {
                XCTFail("Expected APIError.unauthorized for 403")
                return
            }
        }
    }

    func testHandleStatusCode_Unavailable_ThrowsServiceUnavailable() {
        // Specific class: 418
        let emptyData = Data()

        XCTAssertThrowsError(try apiService.handleStatusCode(418, data: emptyData)) { error in
            guard case APIError.serviceUnavailable(_) = error else {
                XCTFail("Expected APIError.serviceUnavailable")
                return
            }
        }
    }

    // MARK: - Equivalence Partitioning for Content-Disposition filename parsing

    func testFilenameFromContentDisposition_MissingFilename_ReturnsNil() {
        // Invalid class: missing filename*=
        let header = "attachment; filename=\"report.xlsx\""
        let result = APIService.filenameFromContentDisposition(header)
        // Note: the current logic specifically looks for filename*=
        XCTAssertNil(result)
    }

    func testFilenameFromContentDisposition_UTF8Format_ReturnsDecodedString() {
        // Valid class: UTF-8 encoding
        let header = "attachment; filename*=UTF-8''%D0%BE%D1%82%D1%87%D0%B5%D1%82.xlsx"
        let result = APIService.filenameFromContentDisposition(header)
        XCTAssertEqual(result, "отчет.xlsx")
    }

    func testFilenameFromContentDisposition_QuotesFormat_ReturnsTrimmedString() {
        // Valid class: with quotes
        let header = "attachment; filename*=\"group-list.xlsx\""
        let result = APIService.filenameFromContentDisposition(header)
        XCTAssertEqual(result, "group-list.xlsx")
    }

    func testFilenameFromContentDisposition_EmptyBoundary_ReturnsEmptyString() {
        // Boundary: empty filename
        let header = "attachment; filename*=\"\""
        let result = APIService.filenameFromContentDisposition(header)
        XCTAssertEqual(result, "")
    }

    func testDownloadGroupListReportSanitizesServerFilename() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let service = APIService(session: session)
        MockURLProtocol.requestHandler = { request in
            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: [
                        "Content-Disposition": "attachment; filename*=UTF-8''..%2F..%2Fsecret%3Anotes.xlsx"
                    ]
                )
            )
            return (response, Data("report".utf8))
        }
        defer {
            MockURLProtocol.requestHandler = nil
        }

        let fileURL = try await service.downloadGroupListReport()
        defer {
            try? FileManager.default.removeItem(
                at: fileURL.deletingLastPathComponent()
            )
        }

        XCTAssertEqual(fileURL.lastPathComponent, "secret_notes.xlsx")
        XCTAssertEqual(try Data(contentsOf: fileURL), Data("report".utf8))
    }

    // MARK: - NetworkRetryPolicy Tests

    func testNetworkRetryPolicy_ShouldRetryOnServerAndConnectionErrors() {
        let policy = NetworkRetryPolicy.default

        XCTAssertTrue(policy.shouldRetry(error: APIError.serviceUnavailable(message: "418")))
        XCTAssertTrue(policy.shouldRetry(error: APIError.serverError(statusCode: 503, message: "Server Error")))
        XCTAssertTrue(policy.shouldRetry(error: APIError.serverError(statusCode: 500, message: "Internal Server Error")))
        XCTAssertTrue(policy.shouldRetry(error: APIError.serverError(statusCode: 429, message: "Too Many Requests")))
        XCTAssertFalse(policy.shouldRetry(error: APIError.serverError(statusCode: 403, message: "Forbidden")))
        XCTAssertFalse(policy.shouldRetry(error: APIError.serverError(statusCode: 404, message: "Not Found")))
        XCTAssertTrue(policy.shouldRetry(error: URLError(.timedOut)))
        XCTAssertTrue(policy.shouldRetry(error: URLError(.networkConnectionLost)))

        XCTAssertFalse(policy.shouldRetry(error: APIError.unauthorized(message: "401")))
        XCTAssertFalse(policy.shouldRetry(error: APIError.invalidURL))
        XCTAssertFalse(policy.shouldRetry(error: CancellationError()))
    }

    func testNetworkRetryPolicy_DelayCalculationHasJitterAndCapping() {
        let policy = NetworkRetryPolicy(maxRetries: 3, initialDelay: 0.5, maxDelay: 2.0)

        XCTAssertEqual(policy.delay(forAttempt: 0), 0)
        let delayAttempt1 = policy.delay(forAttempt: 1)
        XCTAssertGreaterThan(delayAttempt1, 0.3)
        XCTAssertLessThan(delayAttempt1, 1.0)

        let delayAttempt5 = policy.delay(forAttempt: 5)
        XCTAssertLessThanOrEqual(delayAttempt5, 2.5) // capped around 2.0 * jitter max 1.2
    }
}
