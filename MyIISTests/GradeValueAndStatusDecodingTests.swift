@testable import MyIIS
import XCTest

@MainActor
final class GradeValueAndStatusDecodingTests: XCTestCase {
    func testGradeValueDecodesFromStringWithComma() throws {
        let data = Data("\"8,5\"".utf8)
        let value = try JSONDecoder().decode(GradeValue.self, from: data)

        XCTAssertEqual(value.numericValue ?? -1, 8.5, accuracy: 0.0001)
        XCTAssertEqual(value.displayValue, "8,5")
    }

    func testGradeValueDecodesTextualWhenNotNumeric() throws {
        let data = Data("\"зачтено\"".utf8)
        let value = try JSONDecoder().decode(GradeValue.self, from: data)

        XCTAssertNil(value.numericValue)
        XCTAssertEqual(value.displayValue, "зачтено")
    }

    func testAttemptStatusDecodesKnownAndCustomValues() throws {
        let known = try JSONDecoder().decode(GradeAttempt.AttemptStatus.self, from: Data("\"PASSED\"".utf8))
        let custom = try JSONDecoder().decode(GradeAttempt.AttemptStatus.self, from: Data("\"postponed\"".utf8))

        XCTAssertEqual(known, .passed)
        XCTAssertEqual(custom, .custom("POSTPONED"))
    }
}
