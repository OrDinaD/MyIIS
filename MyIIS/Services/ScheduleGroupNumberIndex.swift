import Foundation

/// Six-digit undergraduate numbering from BSUIR order №143 (28 June 2017).
/// Labels and available combinations come from the loaded directory, not the old faculty table.
struct ScheduleGroupNumberIndex: Sendable {
    private struct Entry: Sendable {
        let group: StudyGroup
        let digits: [Int]
    }

    private let entries: [Entry]

    nonisolated init(groups: [StudyGroup]) {
        var seen: Set<String> = []
        entries = groups.compactMap { group in
            guard seen.insert(group.name).inserted,
                  group.name.utf8.count == 6,
                  group.name.utf8.allSatisfy({ (48 ... 57).contains($0) }) else { return nil }
            return Entry(group: group, digits: group.name.utf8.map { Int($0 - 48) })
        }.sorted { $0.group.name < $1.group.name }
    }

    nonisolated func groups(matching selection: [Int?], ignoring position: Int? = nil) -> [StudyGroup] {
        guard selection.count == 6 else { return [] }
        return entries.filter { entry in
            selection.enumerated().allSatisfy { index, value in
                index == position || value == nil || value == entry.digits[index]
            }
        }.map(\.group)
    }

    nonisolated func options(at position: Int, selection: [Int?]) -> [Int] {
        guard (0 ..< 6).contains(position), selection.count == 6 else { return [] }
        return Array(Set(entries.filter { entry in
            selection.enumerated().allSatisfy { index, value in
                index == position || value == nil || value == entry.digits[index]
            }
        }.map { $0.digits[position] })).sorted()
    }
}
