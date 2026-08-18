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

    func testSavedLocalScheduleSourceIsMigratedToAPI() {
        let suiteName = "LocalScheduleDocumentTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(ScheduleDataSource.localJSON.rawValue, forKey: "services.schedule.dataSource")

        let viewModel = ScheduleServiceViewModel(defaults: defaults)

        XCTAssertEqual(viewModel.dataSource, .api)
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
        XCTAssertEqual(lesson.fullTitle, "Системы искусственного интеллекта")
        XCTAssertEqual(lesson.lessonTypeAbbrev, "ПЗ")
        XCTAssertEqual(lesson.employees.first?.id, 500434)
        XCTAssertEqual(lesson.employees.first?.urlId, "i-abramov")
        XCTAssertEqual(lesson.lessonDate, LocalScheduleFormatting.dayFormatter.date(from: "2026-07-28"))
    }

    func testLocalScheduleEventTypePropertiesAndLocalization() {
        for type in LocalScheduleEventType.allCases {
            XCTAssertEqual(type.id, type.rawValue)
            XCTAssertFalse(type.localizedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    func testLocalScheduleDocumentEmptyAndExample() throws {
        let empty = LocalScheduleDocument.empty()
        XCTAssertEqual(empty.schemaVersion, LocalScheduleDocument.currentSchemaVersion)
        XCTAssertTrue(empty.events.isEmpty)
        XCTAssertFalse(empty.title.isEmpty)

        let calendar = Calendar(identifier: .gregorian)
        let referenceDate = Date(timeIntervalSince1970: 1780000000)
        let example = LocalScheduleDocument.example(referenceDate: referenceDate, calendar: calendar)
        XCTAssertEqual(example.events.count, 2)
        let validated = try example.validated()
        XCTAssertEqual(validated.events.count, 2)
    }

    func testTeacherFullNameAndDisplayName() {
        let teacherWithMiddle = LocalScheduleDocument.Teacher(
            id: 1,
            firstName: "Иван",
            middleName: "Иванович",
            lastName: "Иванов",
            degree: "к.т.н.",
            rank: "доцент",
            photoLink: "https://example.com/photo.jpg",
            urlId: "i-ivanov",
            calendarId: "cal-1"
        )
        XCTAssertEqual(teacherWithMiddle.fullName, "Иванов Иван Иванович")

        let teacherWithoutMiddle = LocalScheduleDocument.Teacher(
            id: 2,
            firstName: "Петр",
            middleName: " ",
            lastName: "Петров",
            degree: nil,
            rank: nil,
            photoLink: nil,
            urlId: nil,
            calendarId: nil
        )
        XCTAssertEqual(teacherWithoutMiddle.fullName, "Петров Петр")

        var event = makeEvent(id: "e1")
        event.teacherDetails = teacherWithMiddle
        XCTAssertEqual(event.teacherDisplayName, "Иванов Иван Иванович")

        event.teacherDetails = nil
        event.teacher = "Сидоров С.С."
        XCTAssertEqual(event.teacherDisplayName, "Сидоров С.С.")

        event.teacher = " "
        XCTAssertNil(event.teacherDisplayName)
    }

    func testEventIntervalEdgeCases() {
        let timeZone = TimeZone(identifier: "Europe/Minsk")!
        var event = makeEvent(id: "e1")
        
        // Invalid start time
        event.startTime = "invalid"
        XCTAssertNil(event.interval(timeZone: timeZone))

        // Invalid end time
        event.startTime = "09:00"
        event.endTime = "25:00"
        XCTAssertNil(event.interval(timeZone: timeZone))

        // End earlier than start
        event.endTime = "08:00"
        XCTAssertNil(event.interval(timeZone: timeZone))

        // Invalid date
        event.endTime = "10:30"
        event.date = "bad-date"
        XCTAssertNil(event.interval(timeZone: timeZone))
    }

    func testTimeComponentsFormatting() {
        XCTAssertEqual(LocalScheduleFormatting.timeComponents(from: "00:00"), DateComponents(hour: 0, minute: 0))
        XCTAssertEqual(LocalScheduleFormatting.timeComponents(from: "23:59"), DateComponents(hour: 23, minute: 59))
        XCTAssertEqual(LocalScheduleFormatting.timeComponents(from: "09:30"), DateComponents(hour: 9, minute: 30))

        XCTAssertNil(LocalScheduleFormatting.timeComponents(from: "24:00"))
        XCTAssertNil(LocalScheduleFormatting.timeComponents(from: "-1:00"))
        XCTAssertNil(LocalScheduleFormatting.timeComponents(from: "12:60"))
        XCTAssertNil(LocalScheduleFormatting.timeComponents(from: "abc"))
        XCTAssertNil(LocalScheduleFormatting.timeComponents(from: "12"))
        XCTAssertNil(LocalScheduleFormatting.timeComponents(from: "12:30:00"))
        XCTAssertNil(LocalScheduleFormatting.timeComponents(from: ""))
    }

    func testValidationErrorsDescription() {
        let errors: [LocalScheduleValidationError] = [
            .unsupportedSchema(2),
            .missingDocumentID,
            .missingTitle,
            .invalidTimeZone("XYZ"),
            .missingEventID,
            .duplicateEventID("d1"),
            .invalidDate("2026-99-99"),
            .missingEventTitle("e1"),
            .invalidTimeRange("e1")
        ]

        for error in errors {
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }

    func testMissingEventTitleValidation() {
        var document = makeDocument(events: [])
        var event = makeEvent(id: "no-title")
        event.title = "   \n "
        document.events = [event]

        XCTAssertThrowsError(try document.validated()) { error in
            XCTAssertEqual(error as? LocalScheduleValidationError, .missingEventTitle("no-title"))
        }
    }

    func testLocalScheduleStoreSaveLoadDeleteCycle() throws {
        let event = makeEvent(id: "save-load-test", shortTitle: "Saved")
        let doc = makeDocument(events: [event])

        let savedURL = try LocalScheduleStore.save(doc)
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))

        let loaded = try LocalScheduleStore.load()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.events.first?.id, "save-load-test")
        XCTAssertEqual(loaded?.events.first?.displayTitle, "Saved")

        try LocalScheduleStore.delete()
        let loadedAfterDelete = try LocalScheduleStore.load()
        XCTAssertNil(loadedAfterDelete)
    }

    func testLocalScheduleStoreAllEventTypesAndWeekdaysToAPISchedule() throws {
        let teacher = LocalScheduleDocument.Teacher(
            id: 777,
            firstName: "Тест",
            middleName: "Тестович",
            lastName: "Тестов",
            degree: "к.т.н.",
            rank: "доцент",
            photoLink: nil,
            urlId: "test-teacher",
            calendarId: nil
        )

        // 2026-08-16 is Sunday (1)
        // 2026-08-17 is Monday (2)
        // 2026-08-18 is Tuesday (3)
        // 2026-08-19 is Wednesday (4)
        // 2026-08-20 is Thursday (5)
        // 2026-08-21 is Friday (6)
        // 2026-08-22 is Saturday (7)
        let datesAndTypes: [(String, LocalScheduleEventType, String)] = [
            ("2026-08-16", .lecture, "ЛК"),
            ("2026-08-17", .practice, "ПЗ"),
            ("2026-08-18", .lab, "ЛР"),
            ("2026-08-19", .exam, "Экзамен"),
            ("2026-08-20", .consultation, "Консультация"),
            ("2026-08-21", .announcement, "Объявление"),
            ("2026-08-22", .other, "Событие")
        ]

        var events: [LocalScheduleDocument.Event] = []
        for (idx, item) in datesAndTypes.enumerated() {
            var evt = makeEvent(id: "evt-\(idx)")
            evt.date = item.0
            evt.type = item.1
            evt.teacherDetails = teacher
            events.append(evt)
        }

        let doc = makeDocument(events: events)
        let validated = try doc.validated()

        // Test teacherDirectoryEntry
        let entry = validated.teacherDirectoryEntry(id: 777)
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.id, 777)
        XCTAssertEqual(entry?.fio, "Тестов Тест Тестович")
        XCTAssertNil(validated.teacherDirectoryEntry(id: 999999))

        // Test apiSchedule with teacher filter
        let teacherSchedule = validated.apiSchedule(teacherID: 777)
        XCTAssertNotNil(teacherSchedule.employee)
        XCTAssertEqual(teacherSchedule.employee?.id, 777)
        XCTAssertNil(teacherSchedule.group)

        // Test apiSchedule without teacher filter (group schedule)
        let groupSchedule = validated.apiSchedule()
        XCTAssertNotNil(groupSchedule.group)
        XCTAssertEqual(groupSchedule.exams.count, 3) // exam, consultation, announcement
    }

    func testWidgetKindMappingForAllEventTypes() throws {
        let types: [(LocalScheduleEventType, SessionScheduleWidgetEventKind)] = [
            (.announcement, .announcement),
            (.exam, .exam),
            (.consultation, .consultation),
            (.lecture, .other),
            (.practice, .other),
            (.lab, .other),
            (.other, .other)
        ]

        for (idx, pair) in types.enumerated() {
            var evt = makeEvent(id: "kind-\(idx)")
            evt.type = pair.0
            let doc = try makeDocument(events: [evt]).validated()
            let snapshot = doc.widgetSnapshot()
            XCTAssertEqual(snapshot.events.first?.kind, pair.1)
        }
    }

    func testLocalSchedulePerformanceBenchmark() throws {
        var events: [LocalScheduleDocument.Event] = []
        for i in 0..<300 {
            let dayOffset = (i % 28) + 1
            let dayString = String(format: "2026-08-%02d", dayOffset)
            var event = makeEvent(id: "bench-\(i)")
            event.date = dayString
            event.startTime = "09:00"
            event.endTime = "10:30"
            events.append(event)
        }

        let document = makeDocument(events: events)
        let encoder = JSONEncoder()
        let data = try encoder.encode(document)

        measure {
            do {
                let decoded = try LocalScheduleStore.decode(data)
                _ = decoded.widgetSnapshot()
                _ = decoded.apiSchedule()
            } catch {
                XCTFail("Benchmark failed with error: \(error)")
            }
        }
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

@MainActor
final class LocalScheduleViewModelTests: XCTestCase {
    private var suiteName: String = ""
    private var defaults: UserDefaults = .standard

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "LocalScheduleViewModelTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        try? LocalScheduleStore.delete()
        try await super.tearDown()
    }

    func testViewModelInitializationAndFixtureInstall() {
        let viewModel = LocalScheduleViewModel(defaults: defaults)
        XCTAssertNotNil(viewModel.document)
        XCTAssertFalse(viewModel.groupedEvents.isEmpty)
        XCTAssertNotNil(viewModel.currentFileURL)
    }

    func testViewModelImportDataAndSecurityScopedFile() throws {
        let viewModel = LocalScheduleViewModel(defaults: defaults)
        
        let validJSON = """
        {
          "schemaVersion": 1,
          "id": "imported-doc",
          "title": "Импортированное расписание",
          "timeZone": "Europe/Minsk",
          "events": [
            {
              "id": "e1",
              "date": "2026-08-20",
              "startTime": "09:00",
              "endTime": "10:30",
              "title": "Лекция",
              "type": "lecture"
            }
          ]
        }
        """

        let success = viewModel.importData(Data(validJSON.utf8))
        XCTAssertTrue(success)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNotNil(viewModel.noticeMessage)
        XCTAssertEqual(viewModel.document?.id, "imported-doc")
        XCTAssertEqual(viewModel.groupedEvents.count, 1)

        // Invalid JSON
        let failure = viewModel.importData(Data("invalid json".utf8))
        XCTAssertFalse(failure)
        XCTAssertNotNil(viewModel.errorMessage)

        // Import file at URL
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_schedule_\(UUID().uuidString).json")
        try validJSON.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        viewModel.importFile(at: tempURL)
        XCTAssertNil(viewModel.errorMessage)

        // Import non-existent file
        let badURL = FileManager.default.temporaryDirectory.appendingPathComponent("non_existent_\(UUID().uuidString).json")
        viewModel.importFile(at: badURL)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testCreateEmptyAndCreateExample() {
        let viewModel = LocalScheduleViewModel(defaults: defaults)

        viewModel.createEmpty()
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNotNil(viewModel.document)
        XCTAssertTrue(viewModel.document?.events.isEmpty ?? false)

        viewModel.createExample()
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNotNil(viewModel.document)
        XCTAssertFalse(viewModel.document?.events.isEmpty ?? true)
    }

    func testUpdateMetadataAndEventsUpsertDelete() {
        let viewModel = LocalScheduleViewModel(defaults: defaults)
        viewModel.createEmpty()

        viewModel.updateMetadata(title: "Новое название", timeZone: "Europe/Minsk")
        XCTAssertEqual(viewModel.document?.title, "Новое название")
        XCTAssertEqual(viewModel.document?.timeZone, "Europe/Minsk")

        // Invalid timezone triggers error
        viewModel.updateMetadata(title: "Новое", timeZone: "Invalid/TZ")
        XCTAssertNotNil(viewModel.errorMessage)

        // Upsert new event
        let newEvent = viewModel.makeNewEvent()
        var customEvent = newEvent
        customEvent.title = "Тестовая пара"
        customEvent.type = .practice
        viewModel.upsert(customEvent)
        XCTAssertEqual(viewModel.document?.events.first?.title, "Тестовая пара")

        // Upsert modified event (update existing)
        customEvent.title = "Обновленная пара"
        viewModel.upsert(customEvent)
        XCTAssertEqual(viewModel.document?.events.first?.title, "Обновленная пара")

        // Delete event
        viewModel.delete(customEvent)
        XCTAssertTrue(viewModel.document?.events.isEmpty ?? false)
    }

    func testPublishAndDayTitleFormatting() {
        let viewModel = LocalScheduleViewModel(defaults: defaults)
        viewModel.createExample()

        viewModel.publishCurrentDocument()

        let formattedDay = viewModel.dayTitle("2026-08-18")
        XCTAssertFalse(formattedDay.isEmpty)
        XCTAssertFalse(formattedDay == "2026-08-18")

        let fallbackDay = viewModel.dayTitle("invalid-date")
        XCTAssertEqual(fallbackDay, "invalid-date")
    }

    func testDeleteDocument() {
        let viewModel = LocalScheduleViewModel(defaults: defaults)
        viewModel.createExample()
        XCTAssertNotNil(viewModel.document)

        viewModel.deleteDocument()
        XCTAssertNil(viewModel.document)
        XCTAssertNotNil(viewModel.noticeMessage)
    }
}

