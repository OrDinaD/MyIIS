@testable import MyIIS
import XCTest

@MainActor
final class LocalScheduleDocumentTests: XCTestCase {
    func testDecodeValidJSONSortsEventsAndUsesCancellationDefault() throws {
        let json = """
        {
          "schemaVersion": 1,
          "id": "summer-school",
          "title": "Летняя школа",
          "timeZone": "Europe/Minsk",
          "events": [
            {
              "id": "second",
              "date": "2026-07-17",
              "startTime": "11:00",
              "endTime": "12:30",
              "title": "Практика",
              "type": "practice"
            },
            {
              "id": "first",
              "date": "2026-07-16",
              "startTime": "09:00",
              "endTime": "10:30",
              "title": "Лекция",
              "shortTitle": "SwiftUI",
              "type": "lecture",
              "location": "Аудитория 1"
            }
          ]
        }
        """

        let document = try LocalScheduleStore.decode(Data(json.utf8))

        XCTAssertEqual(document.events.map(\.id), ["first", "second"])
        XCTAssertFalse(document.events[0].isCancelled)
        XCTAssertEqual(document.events[0].displayTitle, "SwiftUI")
    }

    func testValidationRejectsDuplicateEventIdentifiers() {
        let event = makeEvent(id: "duplicate")
        let document = makeDocument(events: [event, event])

        XCTAssertThrowsError(try document.validated()) { error in
            XCTAssertEqual(
                error as? LocalScheduleValidationError,
                .duplicateEventID("duplicate")
            )
        }
    }

    func testValidationRejectsInvalidTimeRange() {
        let event = makeEvent(id: "invalid-time", startTime: "13:30", endTime: "12:00")
        let document = makeDocument(events: [event])

        XCTAssertThrowsError(try document.validated()) { error in
            XCTAssertEqual(
                error as? LocalScheduleValidationError,
                .invalidTimeRange("invalid-time")
            )
        }
    }

    func testWidgetSnapshotSkipsCancelledEventsAndUsesShortTitle() throws {
        let visible = makeEvent(id: "visible", shortTitle: "SwiftUI")
        let cancelled = makeEvent(id: "cancelled", isCancelled: true)
        let document = try makeDocument(events: [visible, cancelled]).validated()

        let snapshot = document.widgetSnapshot()

        XCTAssertEqual(snapshot.groupName, "Летняя школа")
        XCTAssertEqual(snapshot.events.map(\.id), ["visible"])
        XCTAssertEqual(snapshot.events.first?.title, "SwiftUI")
    }

    private func makeDocument(events: [LocalScheduleDocument.Event]) -> LocalScheduleDocument {
        LocalScheduleDocument(
            schemaVersion: LocalScheduleDocument.currentSchemaVersion,
            id: "summer-school",
            title: "Летняя школа",
            timeZone: "Europe/Minsk",
            validFrom: "2026-07-16",
            validThrough: "2026-07-31",
            updatedAt: nil,
            events: events
        )
    }

    private func makeEvent(
        id: String,
        startTime: String = "09:00",
        endTime: String = "10:30",
        shortTitle: String? = nil,
        isCancelled: Bool = false
    ) -> LocalScheduleDocument.Event {
        LocalScheduleDocument.Event(
            id: id,
            date: "2026-07-16",
            startTime: startTime,
            endTime: endTime,
            title: "Основы SwiftUI",
            shortTitle: shortTitle,
            type: .lecture,
            location: "Аудитория 1",
            isCancelled: isCancelled
        )
    }
}
