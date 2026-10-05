@testable import MyIIS
import XCTest

@MainActor
final class ScheduleGroupNumberFinderTests: XCTestCase {
    func testSixPositionsFilterExactCombinationsWithoutFuzzyMatches() throws {
        let groups = try makeGroups(["420603", "420604", "421703", "453503", "520603"])
        let index = ScheduleGroupNumberIndex(groups: groups)
        XCTAssertEqual(index.groups(matching: [4, 2, 0, 6, 0, nil]).map(\.name), ["420603", "420604"])
        XCTAssertEqual(index.groups(matching: [nil, 2, 0, 6, 0, 3]).map(\.name), ["420603", "520603"])
        XCTAssertEqual(index.groups(matching: [4, 2, 0, 6, 0, 5]).count, 0)
        XCTAssertEqual(index.groups(matching: [4, 2, 1, 7, 0, 3]).map(\.name), ["421703"])
    }

    func testChangingOneDigitOffersAllCompatibleAlternatives() throws {
        let index = ScheduleGroupNumberIndex(groups: try makeGroups(["420603", "520603", "453503"]))
        XCTAssertEqual(index.options(at: 0, selection: [4, 2, 0, 6, 0, 3]), [4, 5])
        XCTAssertEqual(index.options(at: 1, selection: [4, nil, nil, nil, nil, nil]), [2, 5])
        XCTAssertEqual(index.options(at: 6, selection: Array(repeating: nil, count: 6)), [])
        XCTAssertEqual(index.groups(matching: [4]), [])
    }

    func testDirectoryRejectsMalformedAndDuplicateNumbers() throws {
        let index = ScheduleGroupNumberIndex(groups: try makeGroups([
            "420603", "420603", "42060", "4206031", "４２０６０３", "4206а3", ""
        ]))
        XCTAssertEqual(index.groups(matching: Array(repeating: nil, count: 6)).map(\.name), ["420603"])
    }

    func testResultsAppearAutomaticallyOnlyAfterSelectionAndAtMostTenMatches() throws {
        let model = ScheduleGroupNumberFinderModel()
        let names = (0 ..< 15).map { String(format: "4206%02d", $0) }
        model.updateDirectory(try makeGroups(names))
        XCTAssertFalse(model.hasSelection)
        XCTAssertFalse(model.shouldRevealResults)
        model.select(4)
        XCTAssertEqual(model.matches.count, 15)
        XCTAssertFalse(model.shouldRevealResults)
        model.activePosition = 4
        model.select(0)
        XCTAssertEqual(model.matches.count, 10)
        XCTAssertTrue(model.shouldRevealResults)
        model.activePosition = 5
        model.select(3)
        XCTAssertEqual(model.matches.map(\.name), ["420603"])
        model.select(nil)
        XCTAssertEqual(model.matches.count, 10)
        model.reset()
        XCTAssertEqual(model.matches.count, 15)
        XCTAssertFalse(model.hasSelection)
        XCTAssertFalse(model.shouldRevealResults)
    }

    func testDirectoryRefreshPreservesChosenDigitsAndReportsMissingCombination() throws {
        let model = ScheduleGroupNumberFinderModel()
        model.updateDirectory(try makeGroups(["420603", "520603"]))
        model.select(4)
        XCTAssertEqual(model.matches.count, 1)
        model.updateDirectory(try makeGroups(["520603"]))
        XCTAssertEqual(model.digits[0], 4)
        XCTAssertEqual(model.matches.count, 0)
        XCTAssertEqual(model.options, [5])
    }

    func testManualHideSurvivesSelectionAndDirectoryRefreshUntilReopened() throws {
        let model = ScheduleGroupNumberFinderModel()
        let groups = try makeGroups(["420603", "420604", "520603"])
        model.updateDirectory(groups)
        model.select(4)
        XCTAssertTrue(model.areResultsVisible)
        model.toggleResults()
        XCTAssertFalse(model.areResultsVisible)
        model.activePosition = 5
        model.select(3)
        model.updateDirectory(groups)
        XCTAssertFalse(model.areResultsVisible)
        model.showResults()
        XCTAssertTrue(model.areResultsVisible)
        model.reset()
        XCTAssertFalse(model.areResultsVisible)
        model.showResults()
        XCTAssertTrue(model.areResultsVisible)
        model.toggleResults()
        XCTAssertFalse(model.areResultsVisible)
    }

    func testAdmissionDigitUsesActualCoursesAndRespectsOtherSelectedDigits() throws {
        let data = Data("""
            [{"name":"420603","course":3},{"name":"453503","course":2},
             {"name":"520603"},{"name":"620603","course":0}]
            """.utf8)
        let model = ScheduleGroupNumberFinderModel()
        model.updateDirectory(try JSONDecoder().decode([StudyGroup].self, from: data))
        let course2 = String(format: ScheduleSearchCopy.text("course"), 2)
        let course3 = String(format: ScheduleSearchCopy.text("course"), 3)
        XCTAssertEqual(model.optionTitle(4), "4 (\(course2) / \(course3))")
        XCTAssertEqual(model.optionTitle(5), "5")
        XCTAssertEqual(model.optionTitle(6), "6")
        model.activePosition = 1
        model.select(2)
        model.activePosition = 0
        XCTAssertEqual(model.optionTitle(4), "4 (\(course3))")
    }

    func testSearchCopyIsBundledInAllSupportedLanguages() throws {
        for language in ["ru", "en", "be", "uk"] {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
            let bundle = try XCTUnwrap(Bundle(path: path))
            for key in ["number_finder", "year", "any", "show_results", "hide_results", "course", "count", "form_7"] {
                XCTAssertNotEqual(bundle.localizedString(forKey: key, value: nil, table: "ScheduleSearch"), key)
            }
        }
    }

    func testGeneratedClickCanBeDecodedByTheAudioPlayer() {
        let feedback = ScheduleNumberClickFeedback()
        XCTAssertTrue(feedback.prepare())
        feedback.stop()
    }

    private func makeGroups(_ names: [String]) throws -> [StudyGroup] {
        let objects = names.map { ["name": $0] }
        return try JSONDecoder().decode([StudyGroup].self, from: JSONSerialization.data(withJSONObject: objects))
    }
}
