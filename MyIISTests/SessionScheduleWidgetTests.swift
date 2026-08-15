@testable import MyIIS
import XCTest

final class SessionScheduleWidgetTests: XCTestCase {
    let calendar: Calendar = {
        var cal = Calendar.current
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    func testNumericDateFormatUsesRussianDayMonthYearOrderAndWeekday() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 16))!

        XCTAssertEqual(SessionScheduleWidgetDateFormatting.numericDateText(from: date), "16.06.2026(Вт)")
    }

    func testEventInterval() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10))!
        let event = SessionScheduleWidgetSnapshot.Event(
            id: "1", date: date,
            startTime: "12:00", endTime: "13:30",
            title: "Test", subtitle: nil, location: nil, lessonType: nil, kind: .other
        )

        let interval = event.interval(calendar: calendar)
        XCTAssertNotNil(interval)

        let expectedStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 12, minute: 0))!
        let expectedEnd = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 13, minute: 30))!

        XCTAssertEqual(interval?.start, expectedStart)
        XCTAssertEqual(interval?.end, expectedEnd)
    }

    func testEventProgress() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10))!
        let event = SessionScheduleWidgetSnapshot.Event(
            id: "1", date: date,
            startTime: "12:00", endTime: "13:30", // 90 mins
            title: "Test", subtitle: nil, location: nil, lessonType: nil, kind: .other
        )

        let before = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 11, minute: 59))!
        let middle = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 12, minute: 45))!
        let after = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 13, minute: 31))!

        XCTAssertEqual(event.progress(at: before, calendar: calendar), 0.0)
        XCTAssertEqual(event.progress(at: middle, calendar: calendar), 0.5)
        XCTAssertEqual(event.progress(at: after, calendar: calendar), 1.0)
    }

    func testInvalidTimeDoesNotCrash() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10))!
        let event1 = SessionScheduleWidgetSnapshot.Event(
            id: "1", date: date,
            startTime: "invalid", endTime: "13:30",
            title: "Test", subtitle: nil, location: nil, lessonType: nil, kind: .other
        )
        let event2 = SessionScheduleWidgetSnapshot.Event(
            id: "2", date: date,
            startTime: "13:30", endTime: "12:00", // start > end
            title: "Test", subtitle: nil, location: nil, lessonType: nil, kind: .other
        )

        XCTAssertNil(event1.interval(calendar: calendar))
        XCTAssertNil(event2.interval(calendar: calendar))
    }

    func testLockScreenStatusUsesCompactCopy() {
        let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        let event = SessionScheduleWidgetSnapshot.Event(
            id: "amd", date: day,
            startTime: "10:05", endTime: "11:30",
            title: "АМД",
            subtitle: "ЛК, 409-1 к., длинное примечание",
            location: "409-1 к.",
            lessonType: "ЛК",
            kind: .other
        )
        let before = calendar.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 9))!
        let during = calendar.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 10, minute: 30))!

        XCTAssertEqual(
            SessionScheduleWidgetPresentation.accessoryStatus(for: event, at: before, calendar: calendar),
            "В 10:05"
        )
        XCTAssertEqual(
            SessionScheduleWidgetPresentation.accessoryStatus(for: event, at: during, calendar: calendar),
            "До 11:30"
        )
    }

    func testLockScreenSubtitlePrefersShortLocationWithoutDuplication() {
        let event = SessionScheduleWidgetSnapshot.Event(
            id: "amd", date: nil,
            startTime: "10:05", endTime: "11:30",
            title: "АМД",
            subtitle: "ЛК, 409-1 к., длинное примечание",
            location: "409-1 к.",
            lessonType: "ЛК",
            kind: .other
        )

        XCTAssertEqual(SessionScheduleWidgetPresentation.accessorySubtitle(for: event), "409-1")
    }
}

@MainActor
final class ScheduleMultiTeacherContractTests: XCTestCase {
    private static let twoTeacherLessonJSON = #"""
    {
      "auditories": ["409-1 к."],
      "endLessonTime": "11:30",
      "lessonTypeAbbrev": "ЛК",
      "numSubgroup": 0,
      "startLessonTime": "10:05",
      "studentGroups": [{"name": "420603"}],
      "subject": "АМД",
      "subjectFullName": "Анализ многомерных данных",
      "weekNumber": [1, 2, 3, 4],
      "employees": [
        {"id": 510001, "firstName": "Алексей", "middleName": "Фёдорович", "lastName": "Трофимович"},
        {"id": 510002, "firstName": "Андрей", "middleName": "Константинович", "lastName": "Ючков"}
      ],
      "announcement": false,
      "split": false
    }
    """#

    func testLessonAndDisciplineSummaryPreserveEveryTeacher() throws {
        let lesson = try JSONDecoder().decode(
            DisciplineSchedule.self,
            from: Data(Self.twoTeacherLessonJSON.utf8)
        )
        let plan = StudyPlan(
            startDate: nil,
            endDate: nil,
            startExamsDate: nil,
            endExamsDate: nil,
            group: nil,
            schedule: [.thursday: [lesson]]
        )

        XCTAssertEqual(
            lesson.employees.map(\.fullName),
            ["Трофимович Алексей Фёдорович", "Ючков Андрей Константинович"]
        )
        XCTAssertEqual(plan.uniqueDisciplines().first?.teachers, lesson.employees.map(\.fullName).sorted())
    }

    func testLiveRequiredGroupSchedulesDecodeCurrentContract() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_LIVE_BSUIR_API_TESTS"] == "1",
            "Set RUN_LIVE_BSUIR_API_TESTS=1 to call the current BSUIR API."
        )

        for groupName in ["520601", "520602", "420603"] {
            try await verifyLiveGroup(groupName)
        }
    }

    private func verifyLiveGroup(_ groupName: String) async throws {
        var components = URLComponents(string: "https://iis.bsuir.by/api/v1/schedule")!
        components.queryItems = [URLQueryItem(name: "studentGroup", value: groupName)]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(httpResponse.statusCode, 200, "Unexpected HTTP status for \(groupName)")
        guard httpResponse.statusCode == 200 else { return }

        let decoded = try JSONDecoder().decode(PublicScheduleResponse.self, from: data)
        XCTAssertEqual(decoded.group?.name, groupName)
        XCTAssertFalse(decoded.orderedDays.isEmpty, "No current or next schedule decoded for \(groupName)")

        let lessonsBySubject = Dictionary(grouping: decoded.orderedDays.flatMap(\.lessons), by: \.subject)
        let hasMultipleTeachers = lessonsBySubject.values.contains { lessons in
            let names = lessons.flatMap(\.employees).map(\.fullName).filter { !$0.isEmpty }
            return Set(names).count > 1
        }
        XCTAssertTrue(hasMultipleTeachers, "No multi-teacher subject decoded for \(groupName)")
    }
}
