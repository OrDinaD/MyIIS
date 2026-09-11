import Foundation
@testable import MyIIS
import XCTest

final class ScheduleTimeParsingTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Minsk") ?? .current
        return cal
    }

    private var baseDate: Date {
        let components = DateComponents(year: 2026, month: 9, day: 11, hour: 12, minute: 0)
        return calendar.date(from: components)!
    }

    // MARK: - Valid Time Parsing

    func testParse_ValidStandardTimes() {
        let result9 = ScheduleServiceViewModel.parse(time: "09:00", on: baseDate, calendar: calendar)
        XCTAssertNotNil(result9)
        XCTAssertEqual(calendar.component(.hour, from: result9!), 9)
        XCTAssertEqual(calendar.component(.minute, from: result9!), 0)

        let result13 = ScheduleServiceViewModel.parse(time: "13:45", on: baseDate, calendar: calendar)
        XCTAssertNotNil(result13)
        XCTAssertEqual(calendar.component(.hour, from: result13!), 13)
        XCTAssertEqual(calendar.component(.minute, from: result13!), 45)
    }

    func testParse_MidnightAndDayBoundaries() {
        // Midnight 00:00
        let midnight = ScheduleServiceViewModel.parse(time: "00:00", on: baseDate, calendar: calendar)
        XCTAssertNotNil(midnight)
        XCTAssertEqual(calendar.component(.hour, from: midnight!), 0)
        XCTAssertEqual(calendar.component(.minute, from: midnight!), 0)

        // Single digit zero: 0:0
        let singleZero = ScheduleServiceViewModel.parse(time: "0:0", on: baseDate, calendar: calendar)
        XCTAssertNotNil(singleZero)
        XCTAssertEqual(calendar.component(.hour, from: singleZero!), 0)
        XCTAssertEqual(calendar.component(.minute, from: singleZero!), 0)

        // Day end: 23:59
        let dayEnd = ScheduleServiceViewModel.parse(time: "23:59", on: baseDate, calendar: calendar)
        XCTAssertNotNil(dayEnd)
        XCTAssertEqual(calendar.component(.hour, from: dayEnd!), 23)
        XCTAssertEqual(calendar.component(.minute, from: dayEnd!), 59)
    }

    func testParse_WhitespaceToleranceAndExtraComponents() {
        let padded = ScheduleServiceViewModel.parse(time: "  08:15  ", on: baseDate, calendar: calendar)
        XCTAssertNotNil(padded)
        XCTAssertEqual(calendar.component(.hour, from: padded!), 8)
        XCTAssertEqual(calendar.component(.minute, from: padded!), 15)

        let withSeconds = ScheduleServiceViewModel.parse(time: "14:30:45", on: baseDate, calendar: calendar)
        XCTAssertNotNil(withSeconds)
        XCTAssertEqual(calendar.component(.hour, from: withSeconds!), 14)
        XCTAssertEqual(calendar.component(.minute, from: withSeconds!), 30)
    }

    // MARK: - Invalid Time Rejection

    func testParse_InvalidHours_ReturnsNil() {
        XCTAssertNil(ScheduleServiceViewModel.parse(time: "24:00", on: baseDate, calendar: calendar))
        XCTAssertNil(ScheduleServiceViewModel.parse(time: "25:30", on: baseDate, calendar: calendar))
        XCTAssertNil(ScheduleServiceViewModel.parse(time: "-1:00", on: baseDate, calendar: calendar))
        XCTAssertNil(ScheduleServiceViewModel.parse(time: "99:00", on: baseDate, calendar: calendar))
    }

    func testParse_InvalidMinutes_ReturnsNil() {
        XCTAssertNil(ScheduleServiceViewModel.parse(time: "10:60", on: baseDate, calendar: calendar))
        XCTAssertNil(ScheduleServiceViewModel.parse(time: "10:99", on: baseDate, calendar: calendar))
        XCTAssertNil(ScheduleServiceViewModel.parse(time: "10:-5", on: baseDate, calendar: calendar))
    }

    func testParse_MalformedInput_ReturnsNil() {
        XCTAssertNil(ScheduleServiceViewModel.parse(time: "", on: baseDate, calendar: calendar))
        XCTAssertNil(ScheduleServiceViewModel.parse(time: "   ", on: baseDate, calendar: calendar))
        XCTAssertNil(ScheduleServiceViewModel.parse(time: "12", on: baseDate, calendar: calendar))
        XCTAssertNil(ScheduleServiceViewModel.parse(time: ":30", on: baseDate, calendar: calendar))
        XCTAssertNil(ScheduleServiceViewModel.parse(time: "12:", on: baseDate, calendar: calendar))
        XCTAssertNil(ScheduleServiceViewModel.parse(time: "abc:def", on: baseDate, calendar: calendar))
        XCTAssertNil(ScheduleServiceViewModel.parse(time: "12:abc", on: baseDate, calendar: calendar))
        XCTAssertNil(ScheduleServiceViewModel.parse(time: "abc:30", on: baseDate, calendar: calendar))
        XCTAssertNil(ScheduleServiceViewModel.parse(time: ":::", on: baseDate, calendar: calendar))
    }

    // MARK: - Daylight Saving Time (DST) & TimeZones

    func testParse_DaylightSavingTransitionDate() {
        var dstCalendar = Calendar(identifier: .gregorian)
        guard let dstZone = TimeZone(identifier: "America/New_York") else { return }
        dstCalendar.timeZone = dstZone

        // March 8, 2026 is a spring-forward transition in New York (2:00 AM -> 3:00 AM)
        let springForwardComponents = DateComponents(year: 2026, month: 3, day: 8, hour: 12)
        guard let dstDate = dstCalendar.date(from: springForwardComponents) else { return }

        // Morning parse
        let morning = ScheduleServiceViewModel.parse(time: "09:00", on: dstDate, calendar: dstCalendar)
        XCTAssertNotNil(morning)
        XCTAssertEqual(dstCalendar.component(.hour, from: morning!), 9)

        // Evening parse
        let evening = ScheduleServiceViewModel.parse(time: "20:00", on: dstDate, calendar: dstCalendar)
        XCTAssertNotNil(evening)
        XCTAssertEqual(dstCalendar.component(.hour, from: evening!), 20)
    }

    func testParse_UTCCalendar() {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let date = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12))!
        let parsed = ScheduleServiceViewModel.parse(time: "08:30", on: date, calendar: utcCalendar)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(utcCalendar.component(.hour, from: parsed!), 8)
        XCTAssertEqual(utcCalendar.component(.minute, from: parsed!), 30)
    }
}
