@testable import MyIIS
import XCTest

final class ScheduleResponseBehaviorTests: XCTestCase {
    private let julySix2026 = Date(timeIntervalSince1970: 1_783_286_400)

    func testPublicScheduleDoesNotFallbackToPreviousSchedulesWhenCurrentIsEmpty() throws {
        let json = #"""
        {
          "schedules": {},
          "previousSchedules": {
            "Понедельник": [
              {
                "auditories": ["1-101"],
                "endLessonTime": "10:35",
                "lessonTypeAbbrev": "ЛК",
                "numSubgroup": 0,
                "startLessonTime": "09:00",
                "studentGroups": [],
                "subject": "СТАР",
                "weekNumber": [1],
                "employees": [],
                "announcement": false,
                "split": false
              }
            ]
          },
          "nextSchedules": {},
          "exams": []
        }
        """#

        let decoded = try JSONDecoder().decode(PublicScheduleResponse.self, from: Data(json.utf8))

        XCTAssertTrue(decoded.orderedDays.isEmpty)
        XCTAssertTrue(decoded.availableWeekNumbers.isEmpty)
        XCTAssertTrue(decoded.isSchedulePublicationPending(referenceDate: julySix2026))
    }

    func testPublicScheduleMarksExpiredSemesterAsPublicationPending() throws {
        let json = #"""
        {
          "startDate": "01.02.2026",
          "endDate": "30.06.2026",
          "schedules": {
            "Понедельник": [
              {
                "auditories": ["1-101"],
                "endLessonTime": "10:35",
                "lessonTypeAbbrev": "ЛК",
                "numSubgroup": 0,
                "startLessonTime": "09:00",
                "studentGroups": [],
                "subject": "СТАР",
                "weekNumber": [1],
                "employees": [],
                "announcement": false,
                "split": false
              }
            ]
          },
          "nextSchedules": {},
          "exams": []
        }
        """#

        let decoded = try JSONDecoder().decode(PublicScheduleResponse.self, from: Data(json.utf8))

        XCTAssertFalse(decoded.orderedDays.isEmpty)
        XCTAssertTrue(decoded.isSchedulePublicationPending(referenceDate: julySix2026))
    }
}
