//
//  FreeAuditoriesAndNotificationTests.swift
//  MyIISTests
//

@testable import MyIIS
import XCTest

@MainActor
final class FreeAuditoriesAndNotificationTests: XCTestCase {
    private var testDefaults: UserDefaults!
    private let suiteName = "test.free.auditories.notifications"

    override func setUp() async throws {
        try await super.setUp()
        testDefaults = UserDefaults(suiteName: suiteName)
        testDefaults?.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        testDefaults?.removePersistentDomain(forName: suiteName)
        testDefaults = nil
        try await super.tearDown()
    }

    // MARK: - BSUIRBuilding Tests

    func testBSUIRBuildingProperties() {
        XCTAssertEqual(BSUIRBuilding.allCases.count, 7)

        let building4 = BSUIRBuilding.b4
        XCTAssertEqual(building4.rawValue, "4")
        XCTAssertEqual(building4.displayName, "4 корпус")
        XCTAssertEqual(building4.shortName, "4 к.")

        let building1 = BSUIRBuilding.b1
        XCTAssertEqual(building1.rawValue, "1")
        XCTAssertEqual(building1.displayName, "1 корпус")
        XCTAssertEqual(building1.shortName, "1 к.")

        let building5 = BSUIRBuilding.b5
        XCTAssertEqual(building5.rawValue, "5")
        XCTAssertEqual(building5.displayName, "5 корпус")
        XCTAssertEqual(building5.shortName, "5 к.")
    }

    // MARK: - LessonTimeSlot Tests

    func testLessonTimeSlotProperties() {
        XCTAssertEqual(LessonTimeSlot.allSlots.count, 7)

        let firstSlot = LessonTimeSlot.allSlots[0]
        XCTAssertEqual(firstSlot.slot, 1)
        XCTAssertEqual(firstSlot.title, "1 пара")
        XCTAssertEqual(firstSlot.timeIntervalString, "08:00–09:35")

        let lastSlot = LessonTimeSlot.allSlots[6]
        XCTAssertEqual(lastSlot.slot, 7)
        XCTAssertEqual(lastSlot.title, "7 пара")
        XCTAssertEqual(lastSlot.timeIntervalString, "18:45–20:20")
    }

    func testLessonTimeSlotCurrentSlotCalculation() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Minsk") ?? .current

        // 08:30 -> Slot 1
        var comp1 = DateComponents()
        comp1.year = 2026; comp1.month = 10; comp1.day = 7
        comp1.hour = 8; comp1.minute = 30
        let date1 = calendar.date(from: comp1)!
        XCTAssertEqual(LessonTimeSlot.currentSlot(at: date1, calendar: calendar), 1)

        // 10:30 -> Slot 2
        var comp2 = DateComponents()
        comp2.year = 2026; comp2.month = 10; comp2.day = 7
        comp2.hour = 10; comp2.minute = 30
        let date2 = calendar.date(from: comp2)!
        XCTAssertEqual(LessonTimeSlot.currentSlot(at: date2, calendar: calendar), 2)

        // 14:00 -> Slot 4
        var comp4 = DateComponents()
        comp4.year = 2026; comp4.month = 10; comp4.day = 7
        comp4.hour = 14; comp4.minute = 0
        let date4 = calendar.date(from: comp4)!
        XCTAssertEqual(LessonTimeSlot.currentSlot(at: date4, calendar: calendar), 4)

        // 19:30 -> Slot 7
        var comp7 = DateComponents()
        comp7.year = 2026; comp7.month = 10; comp7.day = 7
        comp7.hour = 19; comp7.minute = 30
        let date7 = calendar.date(from: comp7)!
        XCTAssertEqual(LessonTimeSlot.currentSlot(at: date7, calendar: calendar), 7)
    }

    // MARK: - FreeAuditoriesResponse Decoding Tests

    func testFreeAuditoriesResponseDecoding() throws {
        let json = Data("""
        {
            "building": "4",
            "day": "Понедельник",
            "timeSlot": "09:45–11:20",
            "weekNumber": 2,
            "totalAuditories": 35,
            "freeAuditories": ["401-4", "402-4", "405-4"],
            "busyAuditories": ["403-4"]
        }
        """.utf8)

        let response = try JSONDecoder().decode(FreeAuditoriesResponse.self, from: json)
        XCTAssertEqual(response.building, "4")
        XCTAssertEqual(response.day, "Понедельник")
        XCTAssertEqual(response.timeSlot, "09:45–11:20")
        XCTAssertEqual(response.weekNumber, 2)
        XCTAssertEqual(response.totalAuditories, 35)
        XCTAssertEqual(response.freeAuditories, ["401-4", "402-4", "405-4"])
        XCTAssertEqual(response.busyAuditories, ["403-4"])
    }

    // MARK: - Notification Preferences Tests

    func testScheduleNotificationPreferencesDefaults() {
        guard let testDefaults else { return }
        let service = ScheduleNotificationMonitorService(defaults: testDefaults)

        // Default states are true
        XCTAssertTrue(service.isScheduleChangesEnabled)
        XCTAssertTrue(service.isAnnouncementsEnabled)

        // Toggling updates storage
        service.isScheduleChangesEnabled = false
        XCTAssertFalse(service.isScheduleChangesEnabled)

        service.isAnnouncementsEnabled = false
        XCTAssertFalse(service.isAnnouncementsEnabled)
    }

    // MARK: - Schedule Notification Tests

    func testScheduleNotificationIgnoresReorderingMetadataAndDuplicateRows() throws {
        let first = try scheduleSnapshot("""
        {"studentGroupDto":{"name":"453501"},"currentPeriod":"Осенний",
         "schedules":{"Понедельник":[
           {"subject":"Физика","auditories":["101-4","102-4"],"weekNumber":[1,2,3,4],"note":null},
           {"subject":"Математика","employees":[{"id":42,"photoLink":"old"}]}
         ]}}
        """)
        let reordered = try scheduleSnapshot("""
        {"currentPeriod":"Сессия","studentGroupDto":{"name":"453501","course":3},
         "schedules":{"Понедельник":[
           {"subject":"Математика","employees":[{"id":42,"photoLink":"new"}]},
           {"subject":"Физика","auditories":["102-4","101-4"],"weekNumber":0,"note":" "},
           {"subject":"Физика","auditories":["101-4","102-4"]}
         ]}}
        """)
        XCTAssertEqual(first, reordered)
        XCTAssertNil(reordered.summary(since: first))
    }

    func testScheduleNotificationExplainsClassroomChangeAndNote() throws {
        let first = try scheduleSnapshot("""
        {"schedules":{"Понедельник":[
          {"subject":"Физика","lessonTypeAbbrev":"ЛК","startLessonTime":"09:00","auditories":["101-4"]}
        ]}}
        """)
        let changed = try scheduleSnapshot("""
        {"schedules":{"Понедельник":[
          {"subject":"Физика","lessonTypeAbbrev":"ЛК","startLessonTime":"09:00",
           "auditories":["102-4"],"note":"Взять конспект"}
        ]}}
        """)
        let body = try XCTUnwrap(changed.summary(since: first)).body
        XCTAssertTrue(body.contains("Физика (ЛК)"))
        XCTAssertTrue(body.contains("\(StudyWeekday.monday.localizedTitle) 09:00"), body)
        XCTAssertTrue(body.contains("101-4 → 102-4"))
        XCTAssertTrue(body.contains("Взять конспект"))
        let empty = try scheduleSnapshot("{}")
        XCTAssertNil(empty.summary(since: first))
    }

    func testScheduleNotificationDistinguishesSessionPublicationFromDateChange() throws {
        let first = try scheduleSnapshot("""
        {"schedules":{"Среда":[{"subject":"Физика"}]}}
        """)
        let published = try scheduleSnapshot("""
        {"schedules":{"Среда":[{"subject":"Физика"}]},
         "startExamsDate":"22.12.2026","endExamsDate":"11.01.2027",
         "exams":[{"subject":"Физика","lessonTypeAbbrev":"Экзамен","dateLesson":"22.12.2026",
                   "startLessonTime":"09:00","auditories":["102-4"]}]}
        """)
        let moved = try scheduleSnapshot("""
        {"schedules":{"Среда":[{"subject":"Физика"}]},
         "startExamsDate":"22.12.2026","endExamsDate":"11.01.2027",
         "exams":[{"subject":"Физика","lessonTypeAbbrev":"Экзамен","dateLesson":"23.12.2026",
                   "startLessonTime":"09:00","auditories":["102-4"]}]}
        """)
        XCTAssertEqual(published.summary(since: first)?.title, "Опубликовано расписание сессии")
        let update = try XCTUnwrap(moved.summary(since: published))
        XCTAssertEqual(update.title, "Изменение в расписании сессии")
        XCTAssertTrue(update.body.contains("→"))
    }

    private func scheduleSnapshot(_ json: String) throws -> ScheduleNotificationSnapshot {
        let response = try JSONDecoder().decode(PublicScheduleResponse.self, from: Data(json.utf8))
        return ScheduleNotificationSnapshot(response)
    }

    // MARK: - Calendar URL Tests

    func testCalendarSubscriptionURLs() {
        let group = "420603"
        let groupURL = URL(string: "webcal://bsuir.ordinad.xyz/api/v1/calendar/group/\(group).ics")
        XCTAssertEqual(groupURL?.scheme, "webcal")
        XCTAssertEqual(groupURL?.host, "bsuir.ordinad.xyz")
        XCTAssertEqual(groupURL?.path, "/api/v1/calendar/group/420603.ics")

        let teacherUrlId = "ivanov-i-i"
        let teacherURL = URL(string: "webcal://bsuir.ordinad.xyz/api/v1/calendar/employee/\(teacherUrlId).ics")
        XCTAssertEqual(teacherURL?.scheme, "webcal")
        XCTAssertEqual(teacherURL?.host, "bsuir.ordinad.xyz")
        XCTAssertEqual(teacherURL?.path, "/api/v1/calendar/employee/ivanov-i-i.ics")
    }

    // MARK: - RemoteNotificationService Tests

    func testRemoteNotificationServiceEndpointsAndTokenHandling() {
        guard let testDefaults else { return }
        let service = RemoteNotificationService(defaults: testDefaults)

        XCTAssertEqual(RemoteNotificationService.registrationEndpoint.absoluteString, "https://bsuir.ordinad.xyz/api/v1/notifications/register")
        XCTAssertNil(service.currentDeviceToken)

        // Raw bytes for device token
        let tokenBytes: [UInt8] = [0xde, 0xad, 0xbe, 0xef, 0x01, 0x02, 0x03, 0x04]
        let deviceTokenData = Data(tokenBytes)
        service.handleDeviceToken(deviceTokenData)

        XCTAssertEqual(service.currentDeviceToken, "deadbeef01020304")
    }
}
