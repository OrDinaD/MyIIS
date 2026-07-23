@testable import MyIIS
import XCTest

@MainActor
final class AnnouncementsEndpointTests: XCTestCase {
    func testStudentAnnouncementsDecodeHARPageShape() throws {
        let json = #"""
        {
          "content": [],
          "totalElements": 0,
          "totalPages": 0,
          "last": true,
          "size": 1,
          "number": 0,
          "empty": true
        }
        """#

        let page = try JSONDecoder().decode(ServiceJSONObjectPage.self, from: Data(json.utf8))

        XCTAssertTrue(page.content.isEmpty)
        XCTAssertEqual(page.size, 1)
        XCTAssertTrue(page.isLast)
        XCTAssertTrue(page.isEmpty)
    }

    func testAnnouncementContentBecomesCardTitle() throws {
        let json = #"""
        {
          "id": 42,
          "content": "Перенос занятия",
          "date": "2026-07-24",
          "startTime": "09:00",
          "endTime": "10:35"
        }
        """#

        let announcement = try JSONDecoder().decode(ServiceJSONObject.self, from: Data(json.utf8))

        XCTAssertEqual(announcement.primaryText, "Перенос занятия")
        XCTAssertEqual(announcement.secondaryText, "2026-07-24")
        XCTAssertEqual(announcement.stableID, "42")
    }
}
