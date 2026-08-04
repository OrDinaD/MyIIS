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

    func testBundledFixtureCoversSeveralWeeksAndThreeAPITeachers() throws {
        let document = try XCTUnwrap(LocalScheduleStore.loadBundledExample())
        let teacherIDs = Set(document.events.compactMap { $0.teacherDetails?.id })

        XCTAssertEqual(document.groupName, "420603")
        XCTAssertEqual(document.validFrom, "2026-07-26")
        XCTAssertEqual(document.validThrough, "2026-08-16")
        XCTAssertGreaterThanOrEqual(document.events.count, 25)
        XCTAssertEqual(teacherIDs, [500084, 500434, 500780])
        XCTAssertTrue(document.events.contains { $0.date == "2026-07-28" })
        XCTAssertEqual(document.apiSchedule().exams.count, 3)
    }

    func testFreshScheduleDefaultsToAPISource() {
        let suiteName = "LocalScheduleDocumentTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let viewModel = ScheduleServiceViewModel(defaults: defaults)

        XCTAssertEqual(viewModel.dataSource, .api)
    }

    func testSavedLocalScheduleSourceIsPreserved() {
        let suiteName = "LocalScheduleDocumentTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(ScheduleDataSource.localJSON.rawValue, forKey: "services.schedule.dataSource")

        let viewModel = ScheduleServiceViewModel(defaults: defaults)

        XCTAssertEqual(viewModel.dataSource, .localJSON)
    }

    func testPreparingAlreadyActiveAPISourceKeepsDisplayedSchedule() {
        let suiteName = "LocalScheduleDocumentTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(ScheduleDataSource.api.rawValue, forKey: "services.schedule.dataSource")
        let viewModel = ScheduleServiceViewModel(defaults: defaults)
        viewModel.schedule = makeDocument(events: [makeEvent(id: "visible")]).apiSchedule()

        viewModel.prepareForAPISource()

        XCTAssertNotNil(viewModel.schedule)
    }

    func testSwitchingFromLocalScheduleToAPISourceClearsLocalContent() {
        let suiteName = "LocalScheduleDocumentTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = ScheduleServiceViewModel(defaults: defaults)
        viewModel.applyLocalSchedule(makeDocument(events: [makeEvent(id: "local")]))
        viewModel.dataSource = .api

        viewModel.prepareForAPISource()

        XCTAssertNil(viewModel.schedule)
    }

    func testValidationRejectsUnsupportedSchemaAndInvalidTimeZone() {
        var document = makeDocument(events: [])
        document.schemaVersion = LocalScheduleDocument.currentSchemaVersion + 1

        XCTAssertThrowsError(try document.validated()) { error in
            XCTAssertEqual(error as? LocalScheduleValidationError, .unsupportedSchema(2))
        }

        document.schemaVersion = LocalScheduleDocument.currentSchemaVersion
        document.timeZone = "Invalid/TimeZone"

        XCTAssertThrowsError(try document.validated()) { error in
            XCTAssertEqual(
                error as? LocalScheduleValidationError,
                .invalidTimeZone("Invalid/TimeZone")
            )
        }
    }

    func testValidationRejectsMissingMetadataAndMalformedEvent() {
        var document = makeDocument(events: [])
        document.id = " "
        XCTAssertThrowsError(try document.validated()) { error in
            XCTAssertEqual(error as? LocalScheduleValidationError, .missingDocumentID)
        }

        document.id = "schedule"
        document.title = "\n"
        XCTAssertThrowsError(try document.validated()) { error in
            XCTAssertEqual(error as? LocalScheduleValidationError, .missingTitle)
        }

        var event = makeEvent(id: " ")
        document.title = "Расписание"
        document.events = [event]
        XCTAssertThrowsError(try document.validated()) { error in
            XCTAssertEqual(error as? LocalScheduleValidationError, .missingEventID)
        }

        event.id = "broken"
        event.date = "2026-99-99"
        document.events = [event]
        XCTAssertThrowsError(try document.validated()) { error in
            XCTAssertEqual(
                error as? LocalScheduleValidationError,
                .invalidDate("2026-99-99")
            )
        }
    }

    func testAPIScheduleUsesExactDateAndRealTeacherMetadata() throws {
        let teacher = LocalScheduleDocument.Teacher(
            id: 500434,
            firstName: "Игорь",
            middleName: "Иванович",
            lastName: "Абрамов",
            degree: "д.т.н.",
            rank: "профессор",
            photoLink: "https://iis.bsuir.by/api/v1/employees/photo/500434",
            urlId: "i-abramov",
            calendarId: nil
        )
        let event = LocalScheduleDocument.Event(
            id: "real-teacher",
            date: "2026-07-28",
            startTime: "09:50",
            endTime: "11:25",
            title: "Системы искусственного интеллекта",
            shortTitle: "СИИ",
            type: .practice,
            location: "409-5 к.",
            teacher: teacher.fullName,
            teacherDetails: teacher
        )
        var document = makeDocument(events: [event])
        document.groupName = "420603"

        let schedule = try document.validated().apiSchedule()
        let lesson = try XCTUnwrap(schedule.orderedDays.first?.lessons.first)

        XCTAssertEqual(schedule.group?.name, "420603")
        XCTAssertEqual(lesson.subject, "СИИ")
        XCTAssertEqual(lesson.title, "Системы искусственного интеллекта")
        XCTAssertEqual(lesson.lessonTypeAbbrev, "ПЗ")
        XCTAssertEqual(lesson.employees.first?.id, 500434)
        XCTAssertEqual(lesson.employees.first?.urlId, "i-abramov")
        XCTAssertEqual(lesson.lessonDate, LocalScheduleFormatting.dayFormatter.date(from: "2026-07-28"))
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
