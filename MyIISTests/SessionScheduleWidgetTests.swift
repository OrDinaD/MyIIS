@testable import MyIIS
import SwiftUI
import XCTest

@MainActor
final class SessionScheduleWidgetTests: XCTestCase {
    let calendar: Calendar = {
        var cal = Calendar.current
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    func testNumericDateFormatUsesRussianDayMonthYearOrderAndWeekday() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 16))!

        XCTAssertEqual(
            SessionScheduleWidgetDateFormatting.numericDateText(
                from: date,
                locale: Locale(identifier: "ru_RU"),
                calendar: calendar
            ),
            "16.06.2026(Вт)"
        )
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

    func testUndatedEventIsNotTreatedAsForeverUpcoming() {
        let event = SessionScheduleWidgetSnapshot.Event(
            id: "announcement",
            date: nil,
            startTime: "",
            endTime: "",
            title: "Announcement",
            subtitle: nil,
            location: nil,
            lessonType: nil,
            kind: .announcement
        )

        XCTAssertFalse(event.isUpcoming(at: Date(), calendar: calendar))
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

    func testCurrentBSUIRPairResolvesFiveMinuteBreak() {
        XCTAssertEqual(
            ScheduleMidPairBreakCalculator.resolve(startTime: "13:35", endTime: "15:00"),
            ScheduleMidPairBreak(startTime: "14:15", endTime: "14:20")
        )
    }

    func testLegacyNinetyFiveMinutePairStillResolvesFiveMinuteBreak() {
        XCTAssertEqual(
            ScheduleMidPairBreakCalculator.resolve(startTime: "09:00", endTime: "10:35"),
            ScheduleMidPairBreak(startTime: "09:45", endTime: "09:50")
        )
    }

    func testNonPairIntervalDoesNotInventBreak() {
        XCTAssertNil(ScheduleMidPairBreakCalculator.resolve(startTime: "12:00", endTime: "13:30"))
        XCTAssertNil(ScheduleMidPairBreakCalculator.resolve(startTime: "invalid", endTime: "15:00"))
    }

    @MainActor
    func testGroupScheduleFallsBackToPersistentCacheWithoutNetwork() async throws {
        let baseURL = URL(string: "https://offline-cache-\(UUID().uuidString).example/api/v1")!
        let endpoint = baseURL.appendingPathComponent("schedule")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "studentGroup", value: "420603")]
        let requestURL = try XCTUnwrap(components.url)
        let cacheKey = "ServiceEndpointsAPI.cache."
            + Data("GET|\(requestURL.absoluteString)".utf8).base64EncodedString()
        defer {
            UserDefaultsPayloadStore.clear(forKey: cacheKey, from: .standard)
            MockURLProtocol.mockData = nil
            MockURLProtocol.mockResponse = nil
            MockURLProtocol.mockError = nil
            MockURLProtocol.requestHandler = nil
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let api = ServiceEndpointsAPI(
            baseURL: baseURL,
            session: URLSession(configuration: configuration)
        )
        let payload = Data(#"{"startDate":"01.09.2026","schedules":{}}"#.utf8)
        MockURLProtocol.mockData = payload
        MockURLProtocol.mockResponse = HTTPURLResponse(
            url: requestURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let online = try await api.fetchGroupSchedule(groupNumber: "420603")
        MockURLProtocol.mockData = nil
        MockURLProtocol.mockResponse = nil
        MockURLProtocol.mockError = URLError(.notConnectedToInternet)
        let offline = try await api.fetchGroupSchedule(groupNumber: "420603")

        XCTAssertEqual(online.startDate, offline.startDate)
        XCTAssertNotNil(offline.startDate)
    }

    func testScheduleCardDensityAndSubgroupDisplayProperties() {
        for density in ScheduleCardDensity.allCases {
            XCTAssertEqual(density.id, density.rawValue)
            XCTAssertFalse(density.localizedTitle.isEmpty)
        }

        for display in ScheduleOtherSubgroupDisplay.allCases {
            XCTAssertEqual(display.id, display.rawValue)
            XCTAssertFalse(display.localizedTitle.isEmpty)
        }
    }

    func testScheduleDisplayPreferencesDefaultsAndOverrides() {
        let defaults = ScheduleDisplayPreferences.defaults
        let prevBreaks = defaults.object(forKey: ScheduleDisplayPreferences.showsMidPairBreaksKey)
        let prevHide = defaults.object(forKey: ScheduleDisplayPreferences.hidePastLessonsKey)
        let prevDensity = defaults.object(forKey: ScheduleDisplayPreferences.cardDensityKey)
        let prevSubgroup = defaults.object(forKey: ScheduleDisplayPreferences.otherSubgroupDisplayKey)

        defer {
            defaults.setValue(prevBreaks, forKey: ScheduleDisplayPreferences.showsMidPairBreaksKey)
            defaults.setValue(prevHide, forKey: ScheduleDisplayPreferences.hidePastLessonsKey)
            defaults.setValue(prevDensity, forKey: ScheduleDisplayPreferences.cardDensityKey)
            defaults.setValue(prevSubgroup, forKey: ScheduleDisplayPreferences.otherSubgroupDisplayKey)
        }

        // Test default state when nil
        defaults.removeObject(forKey: ScheduleDisplayPreferences.hidePastLessonsKey)
        XCTAssertTrue(ScheduleDisplayPreferences.hidePastLessons)

        defaults.set(false, forKey: ScheduleDisplayPreferences.hidePastLessonsKey)
        XCTAssertFalse(ScheduleDisplayPreferences.hidePastLessons)

        defaults.set(true, forKey: ScheduleDisplayPreferences.showsMidPairBreaksKey)
        XCTAssertTrue(ScheduleDisplayPreferences.showsMidPairBreaks)

        defaults.set("compact", forKey: ScheduleDisplayPreferences.cardDensityKey)
        XCTAssertEqual(ScheduleDisplayPreferences.cardDensity, .compact)

        defaults.set("invalid_density", forKey: ScheduleDisplayPreferences.cardDensityKey)
        XCTAssertEqual(ScheduleDisplayPreferences.cardDensity, .regular)

        defaults.set("hidden", forKey: ScheduleDisplayPreferences.otherSubgroupDisplayKey)
        XCTAssertEqual(ScheduleDisplayPreferences.otherSubgroupDisplay, .hidden)

        defaults.set("invalid_option", forKey: ScheduleDisplayPreferences.otherSubgroupDisplayKey)
        XCTAssertEqual(ScheduleDisplayPreferences.otherSubgroupDisplay, .compact)

        ScheduleDisplayPreferences.reloadClassScheduleWidget()
    }

    func testWidgetDataStoresSaveLoadClear() {
        let event = SessionScheduleWidgetSnapshot.Event(
            id: "test-widget-event",
            date: Date(),
            startTime: "09:00",
            endTime: "10:30",
            title: "Базы данных",
            subtitle: "ЛК",
            location: "201-4 к.",
            lessonType: "Лекция",
            kind: .other,
            subgroup: 1
        )
        let snapshot = SessionScheduleWidgetSnapshot(
            groupName: "420603",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 14),
            events: [event],
            updatedAt: Date()
        )

        // SessionScheduleWidgetDataStore
        SessionScheduleWidgetDataStore.save(snapshot)
        let loadedSession = SessionScheduleWidgetDataStore.loadSnapshot()
        XCTAssertEqual(loadedSession?.groupName, "420603")
        XCTAssertEqual(loadedSession?.events.count, 1)
        SessionScheduleWidgetDataStore.clear()
        XCTAssertNil(SessionScheduleWidgetDataStore.loadSnapshot())

        // ClassScheduleWidgetDataStore
        ClassScheduleWidgetDataStore.save(snapshot)
        let loadedClass = ClassScheduleWidgetDataStore.loadSnapshot()
        XCTAssertEqual(loadedClass?.groupName, "420603")
        XCTAssertEqual(loadedClass?.events.count, 1)
        ClassScheduleWidgetDataStore.clear()
        XCTAssertNil(ClassScheduleWidgetDataStore.loadSnapshot())
    }

    func testSessionScheduleWidgetPresentationLocationAndSubtitles() {
        XCTAssertEqual(SessionScheduleWidgetPresentation.normalizedLocation("409-1 к."), "409-1")
        XCTAssertEqual(SessionScheduleWidgetPresentation.normalizedLocation(" 205-4 к "), "205-4")
        XCTAssertEqual(SessionScheduleWidgetPresentation.normalizedLocation("Корпус 1"), "1")
        XCTAssertNil(SessionScheduleWidgetPresentation.normalizedLocation("   "))
        XCTAssertNil(SessionScheduleWidgetPresentation.normalizedLocation(nil))

        let eventWithLocation = SessionScheduleWidgetSnapshot.Event(
            id: "e1",
            date: nil,
            startTime: "09:00",
            endTime: "10:30",
            title: "Math",
            subtitle: nil,
            location: "101-1 к.",
            lessonType: "ЛК",
            kind: .other
        )
        XCTAssertEqual(SessionScheduleWidgetPresentation.accessorySubtitle(for: eventWithLocation), "101-1")

        let eventWithoutLocation = SessionScheduleWidgetSnapshot.Event(
            id: "e2",
            date: nil,
            startTime: "09:00",
            endTime: "10:30",
            title: "Math",
            subtitle: nil,
            location: nil,
            lessonType: "Лекция",
            kind: .other
        )
        XCTAssertEqual(SessionScheduleWidgetPresentation.accessorySubtitle(for: eventWithoutLocation), "Лекция")

        let eventMinimal = SessionScheduleWidgetSnapshot.Event(
            id: "e3",
            date: nil,
            startTime: "09:00",
            endTime: "10:30",
            title: "Math",
            subtitle: nil,
            location: nil,
            lessonType: nil,
            kind: .other
        )
        XCTAssertEqual(SessionScheduleWidgetPresentation.accessorySubtitle(for: eventMinimal), "10:30")
    }

    func testEventUpcomingAndActivePredicates() {
        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 8, day: 18, hour: 12, minute: 0))!
        let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 18))!
        let yesterday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 17))!
        let tomorrow = calendar.date(from: DateComponents(year: 2026, month: 8, day: 19))!

        let activeEvent = SessionScheduleWidgetSnapshot.Event(
            id: "active",
            date: today,
            startTime: "11:30",
            endTime: "13:00",
            title: "Active",
            subtitle: nil,
            location: nil,
            lessonType: nil,
            kind: .other
        )
        XCTAssertTrue(activeEvent.isActive(at: referenceDate, calendar: calendar))
        XCTAssertTrue(activeEvent.isUpcoming(at: referenceDate, calendar: calendar))

        let pastEvent = SessionScheduleWidgetSnapshot.Event(
            id: "past",
            date: yesterday,
            startTime: "09:00",
            endTime: "10:30",
            title: "Past",
            subtitle: nil,
            location: nil,
            lessonType: nil,
            kind: .other
        )
        XCTAssertFalse(pastEvent.isActive(at: referenceDate, calendar: calendar))
        XCTAssertFalse(pastEvent.isUpcoming(at: referenceDate, calendar: calendar))

        let futureEventWithoutTimes = SessionScheduleWidgetSnapshot.Event(
            id: "future",
            date: tomorrow,
            startTime: "",
            endTime: "",
            title: "Future",
            subtitle: nil,
            location: nil,
            lessonType: nil,
            kind: .announcement
        )
        XCTAssertTrue(futureEventWithoutTimes.isUpcoming(at: referenceDate, calendar: calendar))
    }

    func testLessonTypeCategoryParsingAndProperties() {
        for category in LessonTypeCategory.allCases {
            XCTAssertEqual(category.id, category.rawValue)
            XCTAssertFalse(category.localizedTitle.isEmpty)
            XCTAssertFalse(category.defaultHex.isEmpty)
            XCTAssertFalse(category.defaultSymbolName.isEmpty)
        }

        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: "ЛК"), .lecture)
        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: "лекция"), .lecture)
        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: "ПЗ"), .practice)
        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: "семинар"), .practice)
        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: "ЛР"), .laboratory)
        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: "лабораторная"), .laboratory)
        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: "Консультация"), .consultation)
        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: "Экзамен"), .exam)
        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: "Диф. зачет"), .exam)
        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: "Неизвестно"), .other)
        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: nil), .other)
        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: "   "), .other)
    }

    func testScheduleColorPreferencesCustomization() {
        ScheduleColorPreferences.resetAllColors()
        XCTAssertFalse(ScheduleColorPreferences.isCustomized(category: .lecture))

        let defaultHex = ScheduleColorPreferences.hexColor(for: .lecture)
        XCTAssertEqual(defaultHex, LessonTypeCategory.lecture.defaultHex)

        ScheduleColorPreferences.setHexColor("#123456", for: .lecture)
        XCTAssertTrue(ScheduleColorPreferences.isCustomized(category: .lecture))
        XCTAssertEqual(ScheduleColorPreferences.hexColor(for: .lecture), "#123456")
        XCTAssertEqual(ScheduleColorPreferences.hexColor(for: "ЛК"), "#123456")

        _ = ScheduleColorPreferences.color(for: .lecture)
        _ = ScheduleColorPreferences.color(for: "ЛК")

        ScheduleColorPreferences.resetColor(for: .lecture)
        XCTAssertFalse(ScheduleColorPreferences.isCustomized(category: .lecture))
    }

    func testColorHexConversion() {
        let hex6 = Color(hex: "#34C759")
        XCTAssertNotNil(hex6)
        let hex8 = Color(hex: "#34C759FF")
        XCTAssertNotNil(hex8)

        XCTAssertNil(Color(hex: "invalid"))
        XCTAssertNil(Color(hex: "#12345"))

        let roundtripHex = hex6?.toHex()
        XCTAssertNotNil(roundtripHex)
    }

    func testWidgetPerformanceBenchmark() {
        var events: [SessionScheduleWidgetSnapshot.Event] = []
        let baseDate = Date()
        for i in 0..<500 {
            let event = SessionScheduleWidgetSnapshot.Event(
                id: "bench-\(i)",
                date: baseDate.addingTimeInterval(Double(i * 3600)),
                startTime: "09:00",
                endTime: "10:30",
                title: "Дисциплина \(i)",
                subtitle: "Преподаватель \(i)",
                location: "\(i)-4 к.",
                lessonType: "Лекция",
                kind: .other
            )
            events.append(event)
        }

        let snapshot = SessionScheduleWidgetSnapshot(
            groupName: "420603",
            startDate: baseDate,
            endDate: baseDate.addingTimeInterval(86400 * 30),
            events: events,
            updatedAt: Date()
        )

        measure {
            for event in snapshot.events {
                _ = event.interval(calendar: calendar)
                _ = event.progress(at: baseDate, calendar: calendar)
                _ = event.isActive(at: baseDate, calendar: calendar)
                _ = event.isUpcoming(at: baseDate, calendar: calendar)
                _ = SessionScheduleWidgetPresentation.accessorySubtitle(for: event)
                _ = SessionScheduleWidgetPresentation.accessoryStatus(for: event, at: baseDate, calendar: calendar)
            }
        }
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

    func testFallbackEventsHaveDistinctWeekdayDates() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let weekdayComponent = calendar.component(.weekday, from: today)
        let currentWeekdayOrdinal = (weekdayComponent + 5) % 7
        let mondayOfCurrentWeek = calendar.date(byAdding: .day, value: -currentWeekdayOrdinal, to: today) ?? today
        let referenceMonday = currentWeekdayOrdinal == 6
            ? (calendar.date(byAdding: .day, value: 7, to: mondayOfCurrentWeek) ?? mondayOfCurrentWeek)
            : mondayOfCurrentWeek

        let monDate = calendar.date(byAdding: .day, value: 0, to: referenceMonday)!
        let tueDate = calendar.date(byAdding: .day, value: 1, to: referenceMonday)!

        XCTAssertNotEqual(monDate, tueDate)
        XCTAssertEqual(calendar.component(.weekday, from: monDate), 2) // Monday in Gregorian
        XCTAssertEqual(calendar.component(.weekday, from: tueDate), 3) // Tuesday in Gregorian
    }
}
