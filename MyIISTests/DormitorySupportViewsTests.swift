import XCTest
import SwiftUI
@testable import MyIIS

@MainActor
final class DormitorySupportViewsTests: XCTestCase {
    
    func testDormitoryStatusTagTints() {
        let tag1 = DormitoryStatusTag(status: "Заселен")
        XCTAssertEqual(tag1.tint, .green)
        
        let tag2 = DormitoryStatusTag(status: " выселен ")
        XCTAssertEqual(tag2.tint, .orange)
        
        let tag3 = DormitoryStatusTag(status: "Отказано")
        XCTAssertEqual(tag3.tint, .red)
        
        let tag4 = DormitoryStatusTag(status: "Отклонено")
        XCTAssertEqual(tag4.tint, .red)
        
        let tag5 = DormitoryStatusTag(status: "В обработке")
        XCTAssertEqual(tag5.tint, .blue)
    }
}