//
//  FreeAuditoriesAndNotificationTests.swift
//  MyIISTests
//

import XCTest
@testable import MyIIS

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
        let json = """
        {
            "building": "4",
            "day": "Понедельник",
            "timeSlot": "09:45–11:20",
            "weekNumber": 2,
            "totalAuditories": 35,
            "freeAuditories": ["401-4", "402-4", "405-4"],
            "busyAuditories": ["403-4"]
        }
        """.data(using: .utf8)!

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

    // MARK: - Schedule Signature & Change Detection Tests

    func testScheduleSignatureDeterminismAndChangeDetection() {
        let lesson1 = DisciplineSchedule(
            id: "1",
            auditories: ["101-4"],
            endLessonTime: "10:20",
            lessonTypeAbbrev: "ЛК",
            note: nil,
            subgroup: 0,
            startLessonTime: "09:00",
            studentGroups: [],
            subject: "Физика",
            subjectFullName: "Общая физика",
            weekNumbers: [1, 2],
            employees: [],
            lessonDate: nil,
            startLessonDate: nil,
            endLessonDate: nil,
            isAnnouncement: false,
            isSplit: false
        )

        let schedule1 = PublicScheduleResponse(
            employee: nil,
            group: StudyGroup(
                name: "420603",
                facultyId: nil,
                facultyAbbrev: nil,
                facultyName: nil,
                specialityDepartmentEducationFormId: nil,
                specialityName: nil,
                specialityAbbrev: nil,
                course: nil,
                id: nil,
                calendarId: nil,
                educationDegree: nil
            ),
            exams: [],
            startDate: nil,
            endDate: nil,
            startExamsDate: nil,
            endExamsDate: nil,
            scheduleByWeekday: [.monday: [lesson1]],
            previousScheduleByWeekday: [:],
            nextScheduleByWeekday: [:]
        )

        let sig1 = ScheduleNotificationMonitorService.computeScheduleSignature(schedule1)
        XCTAssertFalse(sig1.isEmpty)

        // Calling again gives the exact same signature
        let sig1Repeat = ScheduleNotificationMonitorService.computeScheduleSignature(schedule1)
        XCTAssertEqual(sig1, sig1Repeat)

        // Lesson moved to another classroom (102-4 instead of 101-4)
        let lessonMoved = DisciplineSchedule(
            id: "1",
            auditories: ["102-4"],
            endLessonTime: "10:20",
            lessonTypeAbbrev: "ЛК",
            note: nil,
            subgroup: 0,
            startLessonTime: "09:00",
            studentGroups: [],
            subject: "Физика",
            subjectFullName: "Общая физика",
            weekNumbers: [1, 2],
            employees: [],
            lessonDate: nil,
            startLessonDate: nil,
            endLessonDate: nil,
            isAnnouncement: false,
            isSplit: false
        )

        let scheduleChanged = PublicScheduleResponse(
            employee: nil,
            group: schedule1.group,
            exams: [],
            startDate: nil,
            endDate: nil,
            startExamsDate: nil,
            endExamsDate: nil,
            scheduleByWeekday: [.monday: [lessonMoved]],
            previousScheduleByWeekday: [:],
            nextScheduleByWeekday: [:]
        )

        let sig2 = ScheduleNotificationMonitorService.computeScheduleSignature(scheduleChanged)
        XCTAssertNotEqual(sig1, sig2, "Signature must differ when classroom changes")
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

    func testRemoteNotificationServiceEndpointsAndTokenHandling() async {
        guard let testDefaults else { return }
        let service = RemoteNotificationService(defaults: testDefaults)

        XCTAssertEqual(RemoteNotificationService.registrationEndpoint.absoluteString, "https://bsuir.ordinad.xyz/api/v1/notifications/register")
        XCTAssertNil(service.currentDeviceToken)

        // Raw bytes for device token
        let tokenBytes: [UInt8] = [0xde, 0xad, 0xbe, 0xef, 0x01, 0x02, 0x03, 0x04]
        let deviceTokenData = Data(tokenBytes)
        service.handleDeviceToken(deviceTokenData)

        XCTAssertEqual(service.currentDeviceToken, "deadbeef01020304")

        // Handle remote notification with silent update
        let result = await service.handleRemoteNotification(["group": "420603", "action": "schedule_update"])
        XCTAssertEqual(result, .newData)
    }
}
