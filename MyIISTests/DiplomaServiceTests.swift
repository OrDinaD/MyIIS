@testable import MyIIS
import XCTest

@MainActor
final class DiplomaServiceTests: XCTestCase {

    var service: DiplomaService!

    override func setUp() async throws {
        try await super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        service = DiplomaService(session: session)
    }

    override func tearDown() async throws {
        MockURLProtocol.requestHandler = nil
        MockURLProtocol.mockResponse = nil
        MockURLProtocol.mockData = nil
        MockURLProtocol.mockError = nil
        service = nil
        try await super.tearDown()
    }

    func testFetchProgressUnauthorized() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            let data = Data("{\"msg\": \"Unauthorized\"}".utf8)
            return (response, data)
        }

        do {
            _ = try await service.fetchDiplomaProgress(for: "123")
            XCTFail("Expected unauthorized error")
        } catch let error as APIError {
            if case .unauthorized(let msg) = error {
                XCTAssertEqual(msg, "Unauthorized")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testFetchProgressEmptyIdentifier() async {
        do {
            _ = try await service.fetchDiplomaProgress(for: "")
            XCTFail("Expected invalidURL error")
        } catch let error as APIError {
            if case .invalidURL = error {
                // Success
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testFetchProgressServiceUnavailable() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!
            let data = Data("{\"msg\": \"Unavailable\"}".utf8)
            return (response, data)
        }

        do {
            _ = try await service.fetchDiplomaProgress(for: "123")
            XCTFail("Expected serviceUnavailable error")
        } catch let error as APIError {
            if case .serviceUnavailable(let msg) = error {
                XCTAssertEqual(msg, "Unavailable")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}
