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

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suite = "ScheduleStartupPresentationTests.\(UUID().uuidString)"
        return (try XCTUnwrap(UserDefaults(suiteName: suite)), suite)
    }
}
