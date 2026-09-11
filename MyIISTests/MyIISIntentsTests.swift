import AppIntents
@testable import MyIIS
import XCTest

@MainActor
final class MyIISIntentsTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        MyIISDataStore.clear()
    }

    override func tearDown() async throws {
        MyIISDataStore.clear()
        try await super.tearDown()
    }

    // MARK: - ShowAverageScoreIntent Tests

    func testShowAverageScoreIntent_WithValue_ReturnsFormattedScore() async throws {
        MyIISDataStore.update(averageScore: 8.75)

        let intent = ShowAverageScoreIntent()
        let result = try await intent.perform()

        let value = result.value
        XCTAssertNotNil(value)
        XCTAssertTrue(value?.contains("8,75") == true || value?.contains("8.75") == true)
    }

    func testShowAverageScoreIntent_WithoutValue_ReturnsGracefulUnavailable() async throws {
        let intent = ShowAverageScoreIntent()
        let result = try await intent.perform()

        let value = result.value
        XCTAssertNotNil(value)
        XCTAssertFalse(value?.isEmpty ?? true)
    }

    func testShowAverageScoreIntent_RunsOnBackgroundThreadWithoutCrashing() async throws {
        MyIISDataStore.update(averageScore: 9.2)

        let result = try await Task.detached(priority: .background) {
            let intent = ShowAverageScoreIntent()
            return try await intent.perform()
        }.value

        XCTAssertNotNil(result.value)
    }

    // MARK: - ShowAbsencesIntent Tests

    func testShowAbsencesIntent_WithValue_ReturnsFormattedHours() async throws {
        MyIISDataStore.update(unexcusedAbsences: 14)

        let intent = ShowAbsencesIntent()
        let result = try await intent.perform()

        let value = result.value
        XCTAssertNotNil(value)
        XCTAssertTrue(value?.contains("14") == true)
    }

    func testShowAbsencesIntent_WithoutValue_ReturnsGracefulUnavailable() async throws {
        let intent = ShowAbsencesIntent()
        let result = try await intent.perform()

        let value = result.value
        XCTAssertNotNil(value)
        XCTAssertFalse(value?.isEmpty ?? true)
    }

    func testShowAbsencesIntent_RunsOnBackgroundThreadWithoutCrashing() async throws {
        MyIISDataStore.update(unexcusedAbsences: 6)

        let result = try await Task.detached(priority: .utility) {
            let intent = ShowAbsencesIntent()
            return try await intent.perform()
        }.value

        XCTAssertNotNil(result.value)
    }

    // MARK: - ShowGroupIntent Tests

    func testShowGroupIntent_WithValue_ReturnsGroupName() async throws {
        MyIISDataStore.update(userGroup: "420603")

        let intent = ShowGroupIntent()
        let result = try await intent.perform()

        let value = result.value
        XCTAssertNotNil(value)
        XCTAssertTrue(value?.contains("420603") == true)
    }

    func testShowGroupIntent_WithoutValue_ReturnsGracefulUnavailable() async throws {
        let intent = ShowGroupIntent()
        let result = try await intent.perform()

        let value = result.value
        XCTAssertNotNil(value)
        XCTAssertFalse(value?.isEmpty ?? true)
    }

    func testShowGroupIntent_RunsOnBackgroundThreadWithoutCrashing() async throws {
        MyIISDataStore.update(userGroup: "123456")

        let result = try await Task.detached(priority: .background) {
            let intent = ShowGroupIntent()
            return try await intent.perform()
        }.value

        XCTAssertNotNil(result.value)
    }

    // MARK: - OpenMyIISSectionIntent Tests

    func testOpenMyIISSectionIntent_StagesRequestedSection() async throws {
        _ = AppIntentNavigationStore.takePendingSection()

        for enumCase in SectionAppEnum.allCases {
            let intent = OpenMyIISSectionIntent(target: enumCase)
            _ = try await intent.perform()

            let staged = AppIntentNavigationStore.takePendingSection()
            XCTAssertEqual(staged, enumCase.appSection, "Failed for section: \(enumCase)")
        }
    }

    // MARK: - AppShortcuts Tests

    func testAppShortcutsProviderHasDefinedShortcuts() {
        let shortcuts = MyIISShortcuts.appShortcuts
        XCTAssertEqual(shortcuts.count, 4)
    }
}
