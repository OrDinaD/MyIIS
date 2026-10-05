import Foundation

extension ScheduleServiceViewModel {
    var accountGroupName: String? {
        authService.currentUser?.education.group.nilIfBlank
    }

    var searchPlaceholder: String {
        switch mode {
        case .group:
            return NSLocalizedString("services_schedule_group_placeholder", comment: "")
        case .teacher:
            return NSLocalizedString("services_schedule_teacher_placeholder", comment: "")
        }
    }

    var filteredGroups: [StudyGroup] {
        let needle = debouncedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else {
            return prioritizedGroups(groups)
        }

        let normalizedNeedle = ScheduleSearchMatcher.normalizeSearchString(needle)
        let compactNeedle = normalizedNeedle.replacingOccurrences(of: " ", with: "")
        let scored = groups.compactMap { group -> (group: StudyGroup, rank: Int)? in
            let normalizedName = ScheduleSearchMatcher.normalizeSearchString(group.name)
            let compactName = normalizedName.replacingOccurrences(of: " ", with: "")
            let normalizedSpec = ScheduleSearchMatcher.normalizeSearchString(group.specialityName ?? "")

            let isExact = compactName == compactNeedle || normalizedName == normalizedNeedle
            let isPrefix = compactName.hasPrefix(compactNeedle) || normalizedName.hasPrefix(normalizedNeedle)
            let isSubstring = compactName.contains(compactNeedle) || normalizedName.contains(normalizedNeedle) || normalizedSpec.contains(normalizedNeedle)
            let isFuzzy = ScheduleSearchMatcher.isFuzzyMatch(needle: compactNeedle, text: compactName)
                || ScheduleSearchMatcher.isFuzzyMatch(needle: normalizedNeedle, text: normalizedName)

            guard isExact || isPrefix || isSubstring || isFuzzy else {
                return nil
            }

            var rank = 10
            if isExact {
                rank = 0
            } else if isPrefix {
                rank = group.name == accountGroupName ? 1 : (pinnedGroupNames.contains(group.name) ? 2 : 3)
            } else if isSubstring {
                rank = group.name == accountGroupName ? 4 : (pinnedGroupNames.contains(group.name) ? 5 : 6)
            } else if isFuzzy {
                rank = 7
            }

            return (group, rank)
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
                return lhs.group.name < rhs.group.name
            }
            .prefix(35)
            .map(\.group)
    }

    private func prioritizedGroups(_ source: [StudyGroup], limit: Int = 30) -> [StudyGroup] {
        var seen: Set<String> = []
        var result: [StudyGroup] = []

        func append(_ group: StudyGroup?) {
            guard let group, seen.insert(group.name).inserted else { return }
            result.append(group)
        }

        if let accountGroupName {
            append(source.first { $0.name == accountGroupName })
        }
        for name in pinnedGroupNames {
            append(source.first { $0.name == name })
        }
        for name in recentGroupNames {
            append(source.first { $0.name == name })
        }
        for group in source {
            append(group)
            if result.count >= limit { break }
        }
        return Array(result.prefix(limit))
    }
}
