@testable import MyIIS
import XCTest

@MainActor
final class SharedStorageAndWidgetPolicyTests: XCTestCase {
    func testPayloadStoreReaderUsesFileBackedContract() throws {
        let suiteName = "SharedStorageAndWidgetPolicyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let key = "message-gradebook.\(UUID().uuidString)"
        let payload = Data("shared snapshot".utf8)
        defer {
            UserDefaultsPayloadStore.clear(forKey: key, from: defaults)
            defaults.removePersistentDomain(forName: suiteName)
        }

        XCTAssertTrue(UserDefaultsPayloadStore.save(payload, forKey: key, in: defaults))
        XCTAssertNil(defaults.data(forKey: key))
        XCTAssertEqual(UserDefaultsPayloadStore.load(forKey: key, from: defaults), payload)
    }

    func testWidgetTimelineContainsOnlyNowAndEventBoundaries() throws {
        let calendar = utcCalendar()
        let eventDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))
        )
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 9))
        )
        let start = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 10))
        )
        let end = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 12))
        )
        let snapshot = makeSnapshot(events: [
            makeEvent(id: "single", date: eventDate, startTime: "10:00", endTime: "12:00")
        ])

        XCTAssertEqual(
            ScheduleWidgetTimelinePolicy.makeDates(
                snapshot: snapshot,
                from: now,
                calendar: calendar
            ),
            [now, start, end]
        )
    }

    func testWidgetTimelineIsCappedAtSystemSafeEntryCount() throws {
        let calendar = utcCalendar()
        let firstDay = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))
        )
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 8))
        )
        let events = try (0 ..< 40).map { index in
            makeEvent(
                id: "event-\(index)",
                date: try XCTUnwrap(calendar.date(byAdding: .day, value: index, to: firstDay)),
                startTime: "10:00",
                endTime: "11:00"
            )
        }

        let dates = ScheduleWidgetTimelinePolicy.makeDates(
            snapshot: makeSnapshot(events: events),
            from: now,
            calendar: calendar
        )

        XCTAssertEqual(dates.count, ScheduleWidgetTimelinePolicy.maximumEntries)
        XCTAssertEqual(dates.first, now)
        XCTAssertEqual(dates, dates.sorted())
    }

    private func makeSnapshot(
        events: [SessionScheduleWidgetSnapshot.Event]
    ) -> SessionScheduleWidgetSnapshot {
        SessionScheduleWidgetSnapshot(
            groupName: "420-603",
            startDate: events.compactMap(\.date).min(),
            endDate: events.compactMap(\.date).max(),
            events: events,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }

    private func makeEvent(
        id: String,
        date: Date,
        startTime: String,
        endTime: String
    ) -> SessionScheduleWidgetSnapshot.Event {
        SessionScheduleWidgetSnapshot.Event(
            id: id,
            date: date,
            startTime: startTime,
            endTime: endTime,
            title: "Test",
            subtitle: nil,
            location: nil,
            lessonType: nil,
            kind: .other,
            subgroup: nil
        )
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
