@testable import MyIIS
import XCTest

@MainActor
final class ScheduleStartupPresentationTests: XCTestCase {
    func testSavedGroupIsVisibleBeforeScheduleRestorationAndSearchDoesNotReplaceIt() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("420603", forKey: ScheduleServiceViewModel.lastGroupDefaultsKey)

        let model = ScheduleServiceViewModel(defaults: defaults)

        XCTAssertNil(model.schedule)
        XCTAssertFalse(model.hasLoadedInitialData)
        XCTAssertEqual(model.scheduleHeaderTitle, "420603")
        XCTAssertEqual(model.displayedGroupNumber, "420603")

        model.query = "620601"
        XCTAssertEqual(model.scheduleHeaderTitle, "420603")
    }

    func testPinnedGroupProvidesInitialHeaderWithoutLoadingSchedule() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["420604"], forKey: ScheduleServiceViewModel.pinnedGroupsDefaultsKey)

        let model = ScheduleServiceViewModel(defaults: defaults)

        XCTAssertNil(model.schedule)
        XCTAssertEqual(model.scheduleHeaderTitle, "420604")
        XCTAssertEqual(model.displayedGroupNumber, "420604")
    }

    func testSavedTeacherProvidesInitialHeaderInsteadOfLastGroup() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(ScheduleLookupMode.teacher.rawValue, forKey: ScheduleServiceViewModel.selectedModeDefaultsKey)
        defaults.set("420603", forKey: ScheduleServiceViewModel.lastGroupDefaultsKey)
        defaults.set("Иванов И. И.", forKey: ScheduleServiceViewModel.lastTeacherNameDefaultsKey)

        let model = ScheduleServiceViewModel(defaults: defaults)

        XCTAssertNil(model.schedule)
        XCTAssertEqual(model.scheduleHeaderTitle, "Иванов И. И.")
        XCTAssertNil(model.displayedGroupNumber)
        XCTAssertFalse(model.hasFinishedLessonsToday)
    }

    func testTeacherToolbarUsesInitialsAndKeepsFullAccessibleTitle() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(ScheduleLookupMode.teacher.rawValue, forKey: ScheduleServiceViewModel.selectedModeDefaultsKey)
        defaults.set("Константинопольский Александр Александрович", forKey: ScheduleServiceViewModel.lastTeacherNameDefaultsKey)
        let model = ScheduleServiceViewModel(defaults: defaults)
        XCTAssertEqual(model.scheduleToolbarTitle, "Константинопольский А. А.")
        XCTAssertEqual(model.scheduleHeaderTitle, "Константинопольский Александр Александрович")

        defaults.set("Иванов И.И.", forKey: ScheduleServiceViewModel.lastTeacherNameDefaultsKey)
        XCTAssertEqual(model.scheduleToolbarTitle, "Иванов И.И.")
    }

    func testWidgetPickerDoesNotRestoreOrOverwriteBrowsingSelection() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(ScheduleLookupMode.teacher.rawValue, forKey: ScheduleServiceViewModel.selectedModeDefaultsKey)
        defaults.set("Последний преподаватель", forKey: ScheduleServiceViewModel.lastTeacherNameDefaultsKey)
        let model = ScheduleServiceViewModel(defaults: defaults, persistsLookupMode: false)
        XCTAssertEqual(model.mode, .group)
        XCTAssertTrue(model.query.isEmpty)
        XCTAssertEqual(defaults.string(forKey: ScheduleServiceViewModel.selectedModeDefaultsKey), ScheduleLookupMode.teacher.rawValue)
        XCTAssertEqual(defaults.string(forKey: ScheduleServiceViewModel.lastTeacherNameDefaultsKey), "Последний преподаватель")
    }

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suite = "ScheduleStartupPresentationTests.\(UUID().uuidString)"
        return (try XCTUnwrap(UserDefaults(suiteName: suite)), suite)
    }
}
