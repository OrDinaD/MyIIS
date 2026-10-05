import Foundation
import Observation

@Observable
@MainActor
final class ScheduleGroupNumberFinderModel {
    private var index = ScheduleGroupNumberIndex(groups: [])
    private(set) var digits: [Int?] = Array(repeating: nil, count: 6)
    private(set) var matches: [StudyGroup] = []
    private(set) var options: [Int] = []
    private var resultsVisibilityOverride: Bool?
    private var optionTitles: [Int: String] = [:]
    var activePosition = 0 {
        didSet { updateOptions() }
    }

    func updateDirectory(_ groups: [StudyGroup]) {
        index = ScheduleGroupNumberIndex(groups: groups)
        updateMatches()
    }

    func select(_ value: Int?) {
        guard (0 ..< 6).contains(activePosition) else { return }
        digits[activePosition] = value
        updateMatches()
    }

    func reset() {
        resultsVisibilityOverride = nil
        digits = Array(repeating: nil, count: 6)
        activePosition = 0
        updateMatches()
    }

    var hasSelection: Bool { digits.contains { $0 != nil } }
    var shouldRevealResults: Bool { hasSelection && matches.count <= 10 }
    var areResultsVisible: Bool { resultsVisibilityOverride ?? shouldRevealResults }

    func showResults() { resultsVisibilityOverride = true }
    func toggleResults() { resultsVisibilityOverride = !areResultsVisible }

    var explanation: String {
        switch activePosition {
        case 0: return ScheduleSearchCopy.text("year_hint")
        case 1: return ScheduleSearchCopy.text("faculty_hint")
        case 2, 3: return ScheduleSearchCopy.text("speciality_hint")
        case 4: return ScheduleSearchCopy.text("form_hint")
        default: return ScheduleSearchCopy.text("stream_hint")
        }
    }

    func optionTitle(_ value: Int) -> String {
        optionTitles[value] ?? String(value)
    }

    private func makeOptionTitle(_ value: Int) -> String {
        var selection = digits
        selection[activePosition] = value
        let candidates = index.groups(matching: selection)
        let labels: [String]
        switch activePosition {
        case 0:
            let courses = Set(candidates.compactMap(\.course).filter { $0 > 0 }).sorted()
            let titles = courses.map { String(format: ScheduleSearchCopy.text("course"), $0) }
            return titles.isEmpty ? String(value) : "\(value) (\(titles.joined(separator: " / ")))"
        case 1: labels = candidates.compactMap(\.facultyAbbrev)
        case 2, 3:
            labels = candidates.compactMap(\.specialityAbbrev)
        case 4:
            return "\(value) · " + ScheduleSearchCopy.text("form_\(value)")
        default: return String(value)
        }
        let unique = Array(Set(labels)).sorted()
        let description = unique.prefix(2).joined(separator: " / ")
        return description.isEmpty ? String(value) : "\(value) · \(description)" + (unique.count > 2 ? " …" : "")
    }

    private func updateMatches() {
        matches = index.groups(matching: digits)
        updateOptions()
    }

    private func updateOptions() {
        options = index.options(at: activePosition, selection: digits)
        optionTitles = Dictionary(uniqueKeysWithValues: options.map { ($0, makeOptionTitle($0)) })
    }
}
