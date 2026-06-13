@testable import MyIIS
import XCTest

@MainActor
final class APIDecodingBehaviorTests: XCTestCase {
    func testOmissionApplicationDecodesMixedDateFormats() throws {
        let json = #"""
        {
          "id": 10,
          "status": "PENDING",
          "number": 1,
          "createdDate": 1714972800000,
          "omissionCertificateType": "MEDICAL",
          "dateFrom": "1715059200000",
          "dateTo": "2024-05-08T00:00:00Z",
          "placeOfStay": "Minsk",
          "signature": null
        }
        """#

        let decoded = try JSONDecoder().decode(OmissionApplication.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.id, 10)
        XCTAssertEqual(decoded.createdDate.timeIntervalSince1970, 1714972800, accuracy: 0.001)
        XCTAssertEqual(decoded.dateFrom.timeIntervalSince1970, 1715059200, accuracy: 0.001)
        XCTAssertEqual(decoded.dateTo.timeIntervalSince1970, 1715126400, accuracy: 1.0)
    }

    func testOmissionsByStudentResponseSupportsArrayRoot() throws {
        let json = #"""
        [
          {"id": 1, "dateFrom": 1715059200000, "dateTo": 1715145600000, "name": "Illness", "term": "1"}
        ]
        """#

        let decoded = try JSONDecoder().decode(OmissionsByStudentResponse.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.omissionDtoList.count, 1)
        XCTAssertNil(decoded.faculty)
    }

    func testOmissionsByStudentResponseSupportsAlternativeKey() throws {
        let json = #"""
        {
          "faculty": "FITU",
          "omissionList": [
            {"id": 2, "dateFrom": 1715059200000, "dateTo": 1715145600000, "name": "Competition", "term": 2}
          ]
        }
        """#

        let decoded = try JSONDecoder().decode(OmissionsByStudentResponse.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.omissionDtoList.count, 1)
        XCTAssertEqual(decoded.faculty, "FITU")
        XCTAssertEqual(decoded.omissionDtoList.first?.term, "2")
    }

    func testDiplomaApplicationComputedFlags() {
        let app = DiplomaApplication(
            id: 1,
            date: nil,
            employee: nil,
            externalManager: nil,
            topic: "Topic",
            belarusianTopic: nil,
            englishTopic: nil,
            justification: nil,
            rejectionReason: nil,
            status: "Draft",
            statusId: 5
        )

        XCTAssertTrue(app.canCancel)
        XCTAssertFalse(app.canDownloadApplication)
        XCTAssertEqual(app.supervisorName, "Руководитель не указан")
    }

    func testDiplomaSupervisorPrefersEmployeeNameWhenAvailable() {
        let employee = DiplomaEmployee(
            id: 1,
            firstName: "Иван",
            lastName: "Иванов",
            middleName: "Иванович",
            fio: "",
            academicDepartment: "Кафедра ПО",
            price: nil
        )

        XCTAssertEqual(employee.displayName, "Иванов Иван Иванович")
        XCTAssertEqual(employee.subtitle, "Кафедра ПО")
    }

    func testHeadmanLessonsByDateResponseDecodesWrappedPayload() throws {
        let json = #"""
        {
          "lessons": [
            {
              "id": 101,
              "dateString": "26.05.2026",
              "nameAbbrev": "Математика",
              "lessonTypeAbbrev": "ЛК",
              "lessonPeriod": { "lessonPeriodHours": 2, "startTime": "09:00", "endTime": "10:35" },
              "subGroup": 0,
              "students": []
            }
          ]
        }
        """#

        let decoded = try JSONDecoder().decode(HeadmanLessonsByDateResponse.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.lessons.count, 1)
        XCTAssertEqual(decoded.lessons.first?.id, 101)
    }

    func testHeadmanLessonsByDateResponseDecodesArrayPayload() throws {
        let json = #"""
        [
          {
            "id": 202,
            "dateString": "26.05.2026",
            "nameAbbrev": "Физика",
            "lessonTypeAbbrev": "ПЗ",
            "lessonPeriod": { "lessonPeriodHours": 2, "startTime": "11:00", "endTime": "12:35" },
            "subGroup": 1,
            "students": []
          }
        ]
        """#

        let decoded = try JSONDecoder().decode(HeadmanLessonsByDateResponse.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.lessons.count, 1)
        XCTAssertEqual(decoded.lessons.first?.id, 202)
        XCTAssertEqual(decoded.lessons.first?.subGroup, 1)
    }

    func testPublicScheduleFallsBackToNextSchedulesWhenCurrentIsEmpty() throws {
        let json = #"""
        {
          "studentGroupDto": {"name": "420603"},
          "startDate": "01.09.2025",
          "endDate": "31.12.2025",
          "schedules": {},
          "nextSchedules": {
            "Понедельник": [
              {
                "auditories": ["1-101"],
                "endLessonTime": "10:35",
                "lessonTypeAbbrev": "ЛК",
                "numSubgroup": 0,
                "startLessonTime": "09:00",
                "studentGroups": [],
                "subject": "МАТ",
                "weekNumber": [1, 3],
                "employees": [],
                "announcement": false,
                "split": false
              }
            ]
          },
          "previousSchedules": {
            "Вторник": [
              {
                "auditories": ["1-102"],
                "endLessonTime": "12:25",
                "lessonTypeAbbrev": "ПЗ",
                "numSubgroup": 0,
                "startLessonTime": "11:00",
                "studentGroups": [],
                "subject": "ФИЗ",
                "weekNumber": [2],
                "employees": [],
                "announcement": false,
                "split": false
              }
            ]
          },
          "exams": []
        }
        """#

        let decoded = try JSONDecoder().decode(PublicScheduleResponse.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.orderedDays.count, 1)
        XCTAssertEqual(decoded.orderedDays.first?.weekday, .monday)
        XCTAssertEqual(decoded.orderedDays.first?.lessons.first?.subject, "МАТ")
    }

    func testDisciplineScheduleDecodesSingleWeekNumberAndAlwaysWeekNumber() throws {
        let alwaysWeekJSON = #"""
        {
          "auditories": [],
          "endLessonTime": "10:35",
          "lessonTypeAbbrev": "ЛК",
          "numSubgroup": 0,
          "startLessonTime": "09:00",
          "studentGroups": [],
          "subject": "АЛГ",
          "weekNumber": 0,
          "employees": [],
          "announcement": false,
          "split": false
        }
        """#

        let singleWeekJSON = #"""
        {
          "auditories": [],
          "endLessonTime": "12:25",
          "lessonTypeAbbrev": "ПЗ",
          "numSubgroup": 0,
          "startLessonTime": "11:00",
          "studentGroups": [],
          "subject": "ГЕОМ",
          "weekNumber": 2,
          "employees": [],
          "announcement": false,
          "split": false
        }
        """#

        let alwaysWeek = try JSONDecoder().decode(DisciplineSchedule.self, from: Data(alwaysWeekJSON.utf8))
        let singleWeek = try JSONDecoder().decode(DisciplineSchedule.self, from: Data(singleWeekJSON.utf8))

        XCTAssertEqual(alwaysWeek.weekNumbers, [1, 2, 3, 4])
        XCTAssertEqual(singleWeek.weekNumbers, [2])
    }

    func testDisciplineScheduleHandlesReversedDateRange() {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 20))!
        let middle = calendar.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 6, day: 16))!
        let outside = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21))!
        let lesson = DisciplineSchedule(
            id: "reversed-range",
            auditories: [],
            endLessonTime: "10:35",
            lessonTypeAbbrev: "ЛК",
            note: nil,
            subgroup: 0,
            startLessonTime: "09:00",
            studentGroups: [],
            subject: "АЛГ",
            subjectFullName: nil,
            weekNumbers: [1],
            employees: [],
            lessonDate: nil,
            startLessonDate: start,
            endLessonDate: end,
            isAnnouncement: false,
            isSplit: false
        )

        XCTAssertTrue(lesson.isScheduled(on: middle, calendar: calendar))
        XCTAssertFalse(lesson.isScheduled(on: outside, calendar: calendar))
    }
}
