import Foundation

/// Shared normalization and typo matching for group and teacher search.
enum ScheduleSearchMatcher {
    static func normalizeSearchString(_ string: String) -> String {
        string
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func tokens(from string: String) -> [String] {
        string
            .split(whereSeparator: { $0.isWhitespace || $0 == "." || $0 == "," || $0 == "-" })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    static func isFuzzyMatch(needle: String, text: String) -> Bool {
        guard needle.count >= 3 else { return false }
        if text.contains(needle) { return true }
        let distance = levenshteinDistance(needle, String(text.prefix(needle.count + 1)))
        return distance <= 1
    }

    static func levenshteinDistance(_ source: String, _ target: String) -> Int {
        let sourceChars = Array(source)
        let targetChars = Array(target)
        guard !sourceChars.isEmpty else { return targetChars.count }
        guard !targetChars.isEmpty else { return sourceChars.count }

        var previous = Array(0 ... targetChars.count)
        var current = Array(repeating: 0, count: targetChars.count + 1)
        for (sourceIndex, sourceCharacter) in sourceChars.enumerated() {
            current[0] = sourceIndex + 1
            for (targetIndex, targetCharacter) in targetChars.enumerated() {
                let substitutionCost = sourceCharacter == targetCharacter ? 0 : 1
                current[targetIndex + 1] = min(
                    previous[targetIndex + 1] + 1,
                    current[targetIndex] + 1,
                    previous[targetIndex] + substitutionCost
                )
            }
            swap(&previous, &current)
        }
        return previous[targetChars.count]
    }
}
