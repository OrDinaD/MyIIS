@testable import MyIIS
import XCTest

final class SessionScheduleWidgetTests: XCTestCase {
    let calendar: Calendar = {
        var cal = Calendar.current
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    func testNumericDateFormatUsesRussianDayMonthYearOrder() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 16))!

        XCTAssertEqual(SessionScheduleWidgetDateFormatting.numericDateText(from: date), "16.06.2026")
    }

    func testEventInterval() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10))!
        let event = SessionScheduleWidgetSnapshot.Event(
            id: "1", date: date,
            startTime: "12:00", endTime: "13:30",
            title: "Test", subtitle: nil, location: nil, kind: .other
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
            title: "Test", subtitle: nil, location: nil, kind: .other
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
            title: "Test", subtitle: nil, location: nil, kind: .other
        )
        let event2 = SessionScheduleWidgetSnapshot.Event(
            id: "2", date: date,
            startTime: "13:30", endTime: "12:00", // start > end
            title: "Test", subtitle: nil, location: nil, kind: .other
        )

        XCTAssertNil(event1.interval(calendar: calendar))
        XCTAssertNil(event2.interval(calendar: calendar))
    }
}
