import XCTest

@MainActor
final class WatchScheduleComplicationTests: XCTestCase {
    private struct TestWatchEvent: Sendable {
        let id: String
        let date: Date?
        let startTime: String
        let endTime: String
        let title: String
        let subtitle: String?
        let location: String?
        let lessonType: String?

        func interval(calendar: Calendar = .current) -> DateInterval? {
            guard let date else { return nil }
            let startParts = startTime.split(separator: ":").compactMap { Int($0) }
            let endParts = endTime.split(separator: ":").compactMap { Int($0) }
            guard startParts.count == 2, endParts.count == 2 else { return nil }

            var startComponents = calendar.dateComponents([.year, .month, .day], from: date)
            startComponents.hour = startParts[0]
            startComponents.minute = startParts[1]
            guard let start = calendar.date(from: startComponents) else { return nil }

            var endComponents = startComponents
            endComponents.hour = endParts[0]
            endComponents.minute = endParts[1]
            guard var end = calendar.date(from: endComponents) else { return nil }

            if end <= start {
                guard let nextDayEnd = calendar.date(byAdding: .day, value: 1, to: end) else { return nil }
                end = nextDayEnd
            }

            return DateInterval(start: start, end: end)
        }

        func isCurrent(at date: Date, calendar: Calendar = .current) -> Bool {
            interval(calendar: calendar)?.contains(date) == true
        }

        func progress(at date: Date, calendar: Calendar = .current) -> Double {
            guard let interval = interval(calendar: calendar) else { return 0 }
            if date <= interval.start { return 0 }
            if date >= interval.end { return 1 }
            return date.timeIntervalSince(interval.start) / interval.duration
        }

        func shortLocation() -> String? {
            guard let location, !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            var text = location.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.hasSuffix(" к.") {
                text = String(text.dropLast(" к.".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if text.hasSuffix(" к") {
                text = String(text.dropLast(" к".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if text.hasSuffix(" корп.") {
                text = String(text.dropLast(" корп.".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return text.isEmpty ? nil : text
        }
    }

    private struct TestWatchSnapshot: Sendable {
        let events: [TestWatchEvent]

        func relevantEvent(at date: Date, calendar: Calendar = .current) -> TestWatchEvent? {
            let active = events.first { $0.isCurrent(at: date, calendar: calendar) }
            if let active { return active }

            return events
                .compactMap { event -> (TestWatchEvent, Date)? in
                    guard let start = event.interval(calendar: calendar)?.start, start > date else {
                        return nil
                    }
                    return (event, start)
                }
                .sorted { $0.1 < $1.1 }
                .first?
                .0
        }

        func makeTimelineDates(from now: Date, calendar: Calendar = .current) -> [Date] {
            var dates: Set<Date> = [now]
            for event in events {
                guard let interval = event.interval(calendar: calendar) else { continue }
                if interval.start >= now {
                    dates.insert(interval.start)
                    let lead = interval.start.addingTimeInterval(-30 * 60)
                    if lead >= now {
                        dates.insert(lead)
                    }
                }
                if interval.end >= now {
                    dates.insert(interval.end)
                }
            }
            return dates.filter { $0 >= now }.sorted()
        }
    }

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    func testCurrentEventSelectionWhenClassIsActive() throws {
        let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 11))!
        let activeEvent = TestWatchEvent(
            id: "e1",
            date: day,
            startTime: "10:05",
            endTime: "11:30",
            title: "АМД",
            subtitle: "Лекция",
            location: "409-1 к.",
            lessonType: "ЛК"
        )
        let upcomingEvent = TestWatchEvent(
            id: "e2",
            date: day,
            startTime: "11:45",
            endTime: "13:10",
            title: "Сети",
            subtitle: "ПЗ",
            location: "301-4",
            lessonType: "ПЗ"
        )
        let snapshot = TestWatchSnapshot(events: [upcomingEvent, activeEvent])

        let nowDuringFirst = calendar.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 10, minute: 45))!
        let selected = try XCTUnwrap(snapshot.relevantEvent(at: nowDuringFirst, calendar: calendar))

        XCTAssertEqual(selected.id, "e1")
        XCTAssertEqual(selected.title, "АМД")
        XCTAssertEqual(selected.progress(at: nowDuringFirst, calendar: calendar), 40.0 / 85.0, accuracy: 0.01)
    }

    func testUpcomingEventSelectionBeforeClass() {
        let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 11))!
        let event = TestWatchEvent(
            id: "e1",
            date: day,
            startTime: "10:05",
            endTime: "11:30",
            title: "АМД",
            subtitle: "Лекция",
            location: "409-1 к.",
            lessonType: "ЛК"
        )
        let snapshot = TestWatchSnapshot(events: [event])

        let beforeClass = calendar.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 9, minute: 30))!
        let selected = snapshot.relevantEvent(at: beforeClass, calendar: calendar)

        XCTAssertEqual(selected?.id, "e1")
        XCTAssertFalse(selected?.isCurrent(at: beforeClass, calendar: calendar) ?? true)
    }

    func testEmptyStateWhenAllEventsFinished() {
        let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 11))!
        let event = TestWatchEvent(
            id: "e1",
            date: day,
            startTime: "10:05",
            endTime: "11:30",
            title: "АМД",
            subtitle: "Лекция",
            location: "409-1 к.",
            lessonType: "ЛК"
        )
        let snapshot = TestWatchSnapshot(events: [event])

        let evening = calendar.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 18, minute: 0))!
        let selected = snapshot.relevantEvent(at: evening, calendar: calendar)

        XCTAssertNil(selected)
    }

    func testEmptySnapshotReturnsNil() {
        let snapshot = TestWatchSnapshot(events: [])
        let selected = snapshot.relevantEvent(at: Date(), calendar: calendar)
        XCTAssertNil(selected)
    }

    func testMidnightCrossingInterval() {
        let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 11))!
        let event = TestWatchEvent(
            id: "night-event",
            date: day,
            startTime: "23:30",
            endTime: "01:00",
            title: "Ночное занятие",
            subtitle: nil,
            location: nil,
            lessonType: nil
        )

        let interval = event.interval(calendar: calendar)
        XCTAssertNotNil(interval)
        XCTAssertTrue(interval!.end > interval!.start)

        let expectedStart = calendar.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 23, minute: 30))!
        let expectedEnd = calendar.date(from: DateComponents(year: 2026, month: 9, day: 12, hour: 1, minute: 0))!
        XCTAssertEqual(interval?.start, expectedStart)
        XCTAssertEqual(interval?.end, expectedEnd)
    }

    func testInvalidTimeStringDoesNotCrash() {
        let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 11))!
        let invalidEvent1 = TestWatchEvent(
            id: "bad1",
            date: day,
            startTime: "invalid",
            endTime: "11:30",
            title: "Тест",
            subtitle: nil,
            location: nil,
            lessonType: nil
        )
        let invalidEvent2 = TestWatchEvent(
            id: "bad2",
            date: nil,
            startTime: "10:05",
            endTime: "11:30",
            title: "Тест",
            subtitle: nil,
            location: nil,
            lessonType: nil
        )

        XCTAssertNil(invalidEvent1.interval(calendar: calendar))
        XCTAssertNil(invalidEvent2.interval(calendar: calendar))
    }

    func testShortLocationNormalization() {
        let cases: [(String?, String?)] = [
            ("409-1 к.", "409-1"),
            (" 205-4 к ", "205-4"),
            ("601 корп.", "601"),
            ("301-4", "301-4"),
            ("   ", nil),
            (nil, nil)
        ]

        for (input, expected) in cases {
            let event = TestWatchEvent(
                id: "loc-test",
                date: nil,
                startTime: "10:00",
                endTime: "11:00",
                title: "T",
                subtitle: nil,
                location: input,
                lessonType: nil
            )
            XCTAssertEqual(event.shortLocation(), expected)
        }
    }

    func testTimelineBoundaryCalculations() {
        let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 11))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 9, minute: 0))!
        let event = TestWatchEvent(
            id: "e1",
            date: day,
            startTime: "10:05",
            endTime: "11:30",
            title: "АМД",
            subtitle: nil,
            location: nil,
            lessonType: nil
        )
        let snapshot = TestWatchSnapshot(events: [event])

        let dates = snapshot.makeTimelineDates(from: now, calendar: calendar)

        let expectedLead = calendar.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 9, minute: 35))!
        let expectedStart = calendar.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 10, minute: 5))!
        let expectedEnd = calendar.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 11, minute: 30))!

        XCTAssertEqual(dates, [now, expectedLead, expectedStart, expectedEnd])
    }
}
