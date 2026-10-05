@testable import MyIIS
import XCTest

@MainActor
final class ScheduleSearchMatcherTests: XCTestCase {
    func testRollingRowsPreserveLegacyDistanceForUnicodeAndAllShortInputs() {
        let alphabet = ["а", "б", "é", "👩🏽‍💻"]
        var words = [""]
        var level = [""]
        for _ in 0 ..< 3 {
            level = level.flatMap { prefix in alphabet.map { prefix + $0 } }
            words.append(contentsOf: level)
        }

        for source in words {
            for target in words {
                XCTAssertEqual(
                    ScheduleSearchMatcher.levenshteinDistance(source, target),
                    legacyDistance(source, target),
                    "\(source) → \(target)"
                )
            }
        }
    }

    func testTypoThresholdAndPrefixBehaviorArePreserved() {
        XCTAssertFalse(ScheduleSearchMatcher.isFuzzyMatch(needle: "ив", text: "иванов"))
        XCTAssertTrue(ScheduleSearchMatcher.isFuzzyMatch(needle: "иванов", text: "иванович"))
        XCTAssertTrue(ScheduleSearchMatcher.isFuzzyMatch(needle: "иванв", text: "иванов"))
        XCTAssertTrue(ScheduleSearchMatcher.isFuzzyMatch(needle: "420603", text: "420604"))
        XCTAssertFalse(ScheduleSearchMatcher.isFuzzyMatch(needle: "420603", text: "420614"))
        XCTAssertEqual(ScheduleSearchMatcher.levenshteinDistance("kitten", "sitting"), 3)
        XCTAssertEqual(ScheduleSearchMatcher.levenshteinDistance("", "иванов"), 6)
        XCTAssertEqual(ScheduleSearchMatcher.levenshteinDistance("иванов", ""), 6)
    }

    func testNormalizationAndTeacherTokenBoundariesArePreserved() {
        XCTAssertEqual(ScheduleSearchMatcher.normalizeSearchString("  ИВАНОВ  "), "иванов")
        XCTAssertEqual(ScheduleSearchMatcher.normalizeSearchString("École"), "ecole")
        XCTAssertEqual(
            ScheduleSearchMatcher.tokens(from: "иванов и.и.,петров-сидоров"),
            ["иванов", "и", "и", "петров", "сидоров"]
        )
    }

    // Reference implementation from before the memory optimization.
    private func legacyDistance(_ source: String, _ target: String) -> Int {
        let sourceChars = Array(source)
        let targetChars = Array(target)
        var distances = Array(
            repeating: Array(repeating: 0, count: targetChars.count + 1),
            count: sourceChars.count + 1
        )
        for index in 0 ... sourceChars.count { distances[index][0] = index }
        for index in 0 ... targetChars.count { distances[0][index] = index }
        for (sourceIndex, sourceCharacter) in sourceChars.enumerated() {
            for (targetIndex, targetCharacter) in targetChars.enumerated() {
                distances[sourceIndex + 1][targetIndex + 1] = min(
                    distances[sourceIndex][targetIndex + 1] + 1,
                    distances[sourceIndex + 1][targetIndex] + 1,
                    distances[sourceIndex][targetIndex] + (sourceCharacter == targetCharacter ? 0 : 1)
                )
            }
        }
        return distances[sourceChars.count][targetChars.count]
    }
}
