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
}
