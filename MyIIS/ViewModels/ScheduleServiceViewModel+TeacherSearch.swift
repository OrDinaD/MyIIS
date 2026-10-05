import Foundation

extension ScheduleServiceViewModel {
    var filteredEmployees: [ScheduleEmployeeDirectoryEntry] {
        let needle = debouncedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard needle.count >= 2 else {
            return recentAndPinnedEmployeeSuggestions
        }
        return matchingEmployees(for: needle, limit: 15)
    }

    var recentAndPinnedEmployeeSuggestions: [ScheduleEmployeeDirectoryEntry] {
        var result: [ScheduleEmployeeDirectoryEntry] = []
        var seen: Set<String> = []

        func append(urlId: String?, displayName: String) {
            guard let urlId, !urlId.isEmpty, seen.insert(urlId).inserted else { return }
            if let found = employees.first(where: { $0.urlId == urlId }) {
                result.append(found)
            } else {
                result.append(
                    ScheduleEmployeeDirectoryEntry(
                        firstName: nil,
                        lastName: nil,
                        middleName: nil,
                        degree: nil,
                        rank: nil,
                        photoLink: nil,
                        calendarId: nil,
                        id: Int.min,
                        urlId: urlId,
                        fio: displayName
                    )
                )
            }
        }

        for teacher in pinnedTeachers {
            append(urlId: teacher.urlId, displayName: teacher.name)
        }
        for teacher in recentTeachers {
            append(urlId: teacher.urlId, displayName: teacher.name)
        }
        if let lastUrlId = defaults.string(forKey: Self.lastTeacherURLIDDefaultsKey)?.nilIfBlank {
            let lastName = defaults.string(forKey: Self.lastTeacherNameDefaultsKey) ?? lastUrlId
            append(urlId: lastUrlId, displayName: lastName)
        }

        return Array(result.prefix(8))
    }

    private func matchingEmployees(for query: String, limit: Int) -> [ScheduleEmployeeDirectoryEntry] {
        let tokens = normalizedSearchTokens(from: query)
        guard !tokens.isEmpty else { return [] }

        let scored = employees.compactMap { employee -> (employee: ScheduleEmployeeDirectoryEntry, rank: Int)? in
            let normalizedFio = ScheduleSearchMatcher.normalizeSearchString(employee.displayName)
            let employeeTokens = ScheduleSearchMatcher.tokens(from: normalizedFio)

            // Exact match
            if tokens.count == 1 && (normalizedFio == tokens[0] || employee.urlId == tokens[0]) {
                return (employee, 0)
            }

            // All search tokens are prefixes of words in FIO
            let allTokensMatch = tokens.allSatisfy { token in
                employeeTokens.contains { $0.hasPrefix(token) }
            }
            if allTokensMatch {
                let rank = isTeacherPinned(employee.urlId ?? "") ? 1 : 2
                return (employee, rank)
            }

            // Any token substring match
            let substringMatch = tokens.allSatisfy { normalizedFio.contains($0) }
            if substringMatch {
                let rank = isTeacherPinned(employee.urlId ?? "") ? 3 : 4
                return (employee, rank)
            }

            // Fuzzy match
            if tokens.allSatisfy({ token in
                employeeTokens.contains { ScheduleSearchMatcher.isFuzzyMatch(needle: token, text: $0) }
            }) {
                return (employee, 5)
            }

            return nil
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
                return lhs.employee.displayName.localizedCaseInsensitiveCompare(rhs.employee.displayName) == .orderedAscending
            }
            .prefix(limit)
            .map(\.employee)
    }

    private func normalizedSearchTokens(from query: String) -> [String] {
        query
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: { $0.isWhitespace || $0 == "." || $0 == "," || $0 == "-" })
            .map(String.init)
            .map(ScheduleSearchMatcher.normalizeSearchString)
            .filter { !$0.isEmpty }
    }

    var isTeacherSearchQueryTooShort: Bool {
        mode == .teacher
            && query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2
            && recentAndPinnedEmployeeSuggestions.isEmpty
    }
}
