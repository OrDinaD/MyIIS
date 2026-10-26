import Foundation
@testable import MyIIS
import XCTest

@MainActor
final class WidgetSourceRegressionTests: XCTestCase {
    private var previous: [String: Any] = [:]
    private var key = ""
    private let selectionKeys = [
        WidgetScheduleSelection.groupKey, WidgetScheduleSelection.accountGroupKey,
        WidgetScheduleSelection.teacherIDKey, WidgetScheduleSelection.teacherNameKey,
        "services.schedule.lastGroup"
    ]

    override func setUp() async throws {
        let defaults = WidgetScheduleSelection.defaults
        key = "WidgetSourceRegressionTests.\(UUID().uuidString)"
        for key in selectionKeys {
            previous[key] = defaults.object(forKey: key)
            defaults.removeObject(forKey: key)
        }
    }

    override func tearDown() async throws {
        ScheduleWidgetDataStore.clear(key: key, widgetKind: "regression-test")
        for key in selectionKeys { WidgetScheduleSelection.defaults.set(previous[key], forKey: key) }
    }

    func testOpeningTeacherCannotOverwriteAccountGroupSnapshot() {
        let defaults = WidgetScheduleSelection.defaults
        defaults.set("420603", forKey: WidgetScheduleSelection.accountGroupKey)
        save("420603")
        save("Примичева Зоя Николаевна")
        XCTAssertEqual(ScheduleWidgetDataStore.load(key: key)?.groupName, "420603")
    }

    func testExplicitGroupWinsOverAccountAndLastViewedSchedule() {
        let defaults = WidgetScheduleSelection.defaults
        defaults.set("420603", forKey: WidgetScheduleSelection.accountGroupKey)
        defaults.set("111111", forKey: "services.schedule.lastGroup")
        defaults.set("222222", forKey: WidgetScheduleSelection.groupKey)
        save("222222")
        save("111111")
        XCTAssertEqual(ScheduleWidgetDataStore.load(key: key)?.groupName, "222222")
    }

    func testOldSnapshotIsHiddenAfterSourceChanges() {
        let defaults = WidgetScheduleSelection.defaults
        defaults.set("420603", forKey: WidgetScheduleSelection.accountGroupKey)
        save("420603")
        defaults.set("222222", forKey: WidgetScheduleSelection.groupKey)
        XCTAssertNil(ScheduleWidgetDataStore.load(key: key))
    }

    func testTeacherMustBeExplicitlySelected() {
        let defaults = WidgetScheduleSelection.defaults
        defaults.set("420603", forKey: WidgetScheduleSelection.accountGroupKey)
        defaults.set("teacher-id", forKey: WidgetScheduleSelection.teacherIDKey)
        defaults.set("Преподаватель", forKey: WidgetScheduleSelection.teacherNameKey)
        save("Преподаватель")
        save("420603")
        XCTAssertEqual(ScheduleWidgetDataStore.load(key: key)?.groupName, "Преподаватель")
    }

    func testMalformedTimeComponentsAreRejectedBeforeCalendarConversion() {
        for time in ["24:00", "-1:00", "12:60", "12:x:30", "12::30", "999999999:00"] {
            let event = SessionScheduleWidgetSnapshot.Event(
                id: "bad", date: Date(), startTime: time, endTime: "23:59",
                title: "", subtitle: nil, location: nil, lessonType: nil, kind: .other
            )
            XCTAssertNil(event.interval(), time)
        }
    }

    func testValidIntervalsAcrossDSTAndMidnightBoundary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Berlin"))
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 25)))
        let event = SessionScheduleWidgetSnapshot.Event(
            id: "dst", date: day, startTime: "03:00", endTime: "04:00",
            title: "", subtitle: nil, location: nil, lessonType: nil, kind: .other
        )
        XCTAssertEqual(event.interval(calendar: calendar)?.duration, 3600)
        let reversed = SessionScheduleWidgetSnapshot.Event(
            id: "midnight", date: day, startTime: "23:30", endTime: "00:30",
            title: "", subtitle: nil, location: nil, lessonType: nil, kind: .other
        )
        XCTAssertNil(reversed.interval(calendar: calendar))
    }

    func testMissingSelectionIsSeededFromProfileAndIgnoresBrowsingHistory() {
        let defaults = WidgetScheduleSelection.defaults
        defaults.set("111111", forKey: "services.schedule.lastGroup")
        XCTAssertNil(WidgetScheduleSelection.target(in: defaults).title)

        WidgetScheduleSelection.updateAccountGroup(" 420603 ", in: defaults)
        XCTAssertEqual(defaults.string(forKey: WidgetScheduleSelection.groupKey), "420603")
        defaults.set("222222", forKey: "services.schedule.lastGroup")
        save("420603")
        save("222222")
        XCTAssertEqual(ScheduleWidgetDataStore.load(key: key)?.groupName, "420603")
    }

    func testMigrationRepairsEmptyFieldForAlreadyKnownAccount() {
        let defaults = WidgetScheduleSelection.defaults
        defaults.set("420603", forKey: WidgetScheduleSelection.accountGroupKey)
        WidgetScheduleSelection.updateAccountGroup("420603", in: defaults)
        XCTAssertEqual(defaults.string(forKey: WidgetScheduleSelection.groupKey), "420603")
    }

    func testMigrationPreservesExplicitTeacherAndGroupSelections() {
        let defaults = WidgetScheduleSelection.defaults
        defaults.set("teacher-id", forKey: WidgetScheduleSelection.teacherIDKey)
        defaults.set("Преподаватель", forKey: WidgetScheduleSelection.teacherNameKey)
        WidgetScheduleSelection.updateAccountGroup("420603", in: defaults)
        XCTAssertEqual(WidgetScheduleSelection.target(in: defaults).teacherID, "teacher-id")
        defaults.removeObject(forKey: WidgetScheduleSelection.teacherIDKey)
        defaults.set("222222", forKey: WidgetScheduleSelection.groupKey)
        WidgetScheduleSelection.updateAccountGroup("420603", in: defaults)
        XCTAssertEqual(WidgetScheduleSelection.target(in: defaults).group, "222222")
    }

    func testReturningToAccountGroupPersistsItAndRejectsPreviousTeacher() {
        let defaults = WidgetScheduleSelection.defaults
        defaults.set("420603", forKey: WidgetScheduleSelection.accountGroupKey)
        defaults.set("teacher-id", forKey: WidgetScheduleSelection.teacherIDKey)
        defaults.set("Преподаватель", forKey: WidgetScheduleSelection.teacherNameKey)
        WidgetScheduleSelection.useAccountGroup(in: defaults)
        XCTAssertEqual(defaults.string(forKey: WidgetScheduleSelection.groupKey), "420603")
        XCTAssertNil(WidgetScheduleSelection.target(in: defaults).teacherID)
        XCTAssertFalse(WidgetScheduleSelection.accepts("Преподаватель", in: defaults))
    }

    func testChangingAccountGroupResetsOldOverrideToNewAccount() {
        let defaults = WidgetScheduleSelection.defaults
        defaults.set("420603", forKey: WidgetScheduleSelection.accountGroupKey)
        defaults.set("222222", forKey: WidgetScheduleSelection.groupKey)
        XCTAssertTrue(WidgetScheduleSelection.updateAccountGroup("420604", in: defaults))
        XCTAssertEqual(defaults.string(forKey: WidgetScheduleSelection.groupKey), "420604")
    }

    private func save(_ title: String) {
        ScheduleWidgetDataStore.save(
            SessionScheduleWidgetSnapshot(
                groupName: title, startDate: nil, endDate: nil, events: [], updatedAt: Date()
            ),
            key: key, widgetKind: "regression-test"
        )
    }
}
