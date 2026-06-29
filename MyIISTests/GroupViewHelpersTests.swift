import XCTest
import SwiftUI
@testable import MyIIS

@MainActor
final class GroupViewHelpersTests: XCTestCase {

    func testOptionalText() {
        let view = GroupView()
        
        XCTAssertEqual(view.optionalText("Hello"), "Hello")
        XCTAssertEqual(view.optionalText("  Hello  \n"), "Hello")
        XCTAssertNil(view.optionalText(""))
        XCTAssertNil(view.optionalText("   "))
        XCTAssertNil(view.optionalText(nil))
    }

    func testRoleBadgeDoesNotCrash() {
        let view = GroupView()
        let badge = view.roleBadge(text: "Role", tint: .red)
        XCTAssertNotNil(badge)
    }

    func testCardContainerDoesNotCrash() {
        let view = GroupView()
        let card = view.cardContainer {
            Text("Content")
        }
        XCTAssertNotNil(card)
    }
}