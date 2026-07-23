import Foundation

actor EmployeesRepository {
    static let shared = EmployeesRepository()

    private let apiClient = EmployeesAPIClient()
    private var treeCache: [DepartmentTreeNodeDTO]?
    private var globalIndex: [EmployeeSearchHit] = []

    func fetchDepartmentsTree() async throws -> [DepartmentTreeNodeDTO] {
        if let treeCache {
            return treeCache
        }

        let tree = try await apiClient.fetchDepartmentsTree()
        treeCache = tree
        buildGlobalIndex(from: tree)
        return tree
    }

    func search(query: String) async -> [EmployeeSearchHit] {
        if globalIndex.isEmpty {
            _ = try? await fetchDepartmentsTree()
        }

        let normalizedQuery = normalizeSearch(query)
        guard !normalizedQuery.isEmpty else {
            return globalIndex
        }

        let queryTokens = normalizedQuery.split(separator: " ").map(String.init)
        let phoneDigits = normalizedQuery.filter(\.isNumber)

        return globalIndex
            .compactMap { hit -> (hit: EmployeeSearchHit, score: Int)? in
                let score = searchScore(
                    for: hit,
                    normalizedQuery: normalizedQuery,
                    queryTokens: queryTokens,
                    phoneDigits: phoneDigits
                )
                return score > 0 ? (hit, score) : nil
            }
            .sorted(by: isHigherRanked)
            .map(\.hit)
    }

    func resolveProfile(for hit: EmployeeSearchHit) async throws -> EmployeeProfile {
        let summaries = try await apiClient.fetchEmployees(forDepartment: hit.departmentUrlId)
        guard let summary = summaries.first(where: {
            normalizeSearch($0.getFullName()) == hit.normalizedFIO
        }) else {
            throw EmployeesAPIError.invalidResponse
        }

        let details = try await apiClient.fetchEmployeeDetails(urlId: summary.urlId)
        return merge(
            summary: summary,
            details: details,
            departmentUrlId: hit.departmentUrlId
        )
    }

    nonisolated func normalizeSearch(_ value: String) -> String {
        let keyboardTranslation: [Character: Character] = [
            "q": "й", "w": "ц", "e": "у", "r": "к", "t": "е", "y": "н",
            "u": "г", "i": "ш", "o": "щ", "p": "з", "[": "х", "]": "ъ",
            "a": "ф", "s": "ы", "d": "в", "f": "а", "g": "п", "h": "р",
            "j": "о", "k": "л", "l": "д", ";": "ж", "'": "э", "z": "я",
            "x": "ч", "c": "с", "v": "м", "b": "и", "n": "т", "m": "ь",
            ",": "б", ".": "ю"
        ]

        let lowered = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
        let corrected = String(lowered.map { keyboardTranslation[$0] ?? $0 })

        return corrected
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private func buildGlobalIndex(from tree: [DepartmentTreeNodeDTO]) {
        var index: [EmployeeSearchHit] = []

        func appendEmployees(from nodes: [DepartmentTreeNodeDTO]) {
            for node in nodes {
                for employee in node.data.employees ?? [] {
                    index.append(
                        EmployeeSearchHit(
                            fio: employee.fio,
                            normalizedFIO: normalizeSearch(employee.fio),
                            surname: employee.fio.components(separatedBy: " ").first ?? "",
                            phones: employee.phoneNumbers?.map(normalizePhone) ?? [],
                            departmentId: node.data.id,
                            departmentUrlId: node.data.urlId ?? "",
                            departmentName: node.data.name,
                            departmentAbbrev: node.data.abbrev ?? "",
                            departmentTypeId: node.data.typeId
                        )
                    )
                }

                if let children = node.children {
                    appendEmployees(from: children)
                }
            }
        }

        appendEmployees(from: tree)
        globalIndex = index
    }

    private func searchScore(
        for hit: EmployeeSearchHit,
        normalizedQuery: String,
        queryTokens: [String],
        phoneDigits: String
    ) -> Int {
        max(
            nameScore(for: hit, normalizedQuery: normalizedQuery),
            tokenScore(for: hit, queryTokens: queryTokens),
            phoneScore(for: hit, phoneDigits: phoneDigits),
            departmentScore(for: hit, normalizedQuery: normalizedQuery)
        )
    }

    private func nameScore(
        for hit: EmployeeSearchHit,
        normalizedQuery: String
    ) -> Int {
        if hit.normalizedFIO == normalizedQuery {
            return 120
        }
        if hit.surname.lowercased() == normalizedQuery {
            return 110
        }
        if hit.normalizedFIO.hasPrefix(normalizedQuery) {
            return 90
        }
        if hit.normalizedFIO.contains(normalizedQuery) {
            return 60
        }
        return 0
    }

    private func tokenScore(
        for hit: EmployeeSearchHit,
        queryTokens: [String]
    ) -> Int {
        let hitTokens = hit.normalizedFIO.split(separator: " ")
        let hasPrefixMatch = queryTokens.contains { queryToken in
            hitTokens.contains { $0.hasPrefix(queryToken) }
        }
        return hasPrefixMatch ? 75 : 0
    }

    private func phoneScore(
        for hit: EmployeeSearchHit,
        phoneDigits: String
    ) -> Int {
        guard !phoneDigits.isEmpty else {
            return 0
        }
        return hit.phones.contains(where: { $0.contains(phoneDigits) }) ? 80 : 0
    }

    private func departmentScore(
        for hit: EmployeeSearchHit,
        normalizedQuery: String
    ) -> Int {
        let abbreviation = hit.departmentAbbrev.lowercased()
        if abbreviation == normalizedQuery {
            return 70
        }
        if abbreviation.contains(normalizedQuery)
            || hit.departmentName.lowercased().contains(normalizedQuery) {
            return 35
        }
        return 0
    }

    private func isHigherRanked(
        _ lhs: (hit: EmployeeSearchHit, score: Int),
        _ rhs: (hit: EmployeeSearchHit, score: Int)
    ) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }

        let lhsIsAcademicDepartment = lhs.hit.departmentTypeId == 3
        let rhsIsAcademicDepartment = rhs.hit.departmentTypeId == 3
        if lhsIsAcademicDepartment != rhsIsAcademicDepartment {
            return lhsIsAcademicDepartment
        }
        return lhs.hit.fio < rhs.hit.fio
    }

    private func merge(
        summary: EmployeeSummaryDTO,
        details: EmployeeDetailsDTO,
        departmentUrlId: String
    ) -> EmployeeProfile {
        var departmentLeadership: [String: Bool] = [:]
        if let chief = summary.chief {
            departmentLeadership[departmentUrlId] = chief
        }

        let name = PersonName(
            firstName: summary.firstName,
            lastName: summary.lastName,
            middleName: summary.middleName
        )
        let mergedPositions = mergePositions(
            summary: summary.jobPositions,
            details: details.jobPositions
        )

        return EmployeeProfile(
            id: details.id,
            urlId: details.urlId,
            name: name,
            photoURL: details.photoLink ?? summary.photoLink,
            degree: details.degree ?? summary.degree,
            degreeAbbreviation: firstNonempty(details.degreeAbbrev, summary.degreeAbbrev),
            rank: details.rank ?? summary.rank,
            email: details.email ?? summary.email,
            calendarId: firstNonempty(details.calendarId, summary.calendarId),
            positions: mergedPositions,
            departmentLeadership: departmentLeadership,
            readingCourses: uniqueStrings(details.readingCourses ?? []),
            additionalSections: makeAdditionalSections(details.additionalInformation ?? []),
            profileLinks: makeProfileLinks(details.profileLinks ?? [])
        )
    }

    private func mergePositions(
        summary: [EmployeeJobPositionDTO]?,
        details: [EmployeeJobPositionDTO]?
    ) -> [EmployeePosition] {
        let allPositions = (summary ?? []) + (details ?? [])
        var result: [EmployeePosition] = []

        for positionDTO in allPositions {
            let position = EmployeePosition(
                departmentId: positionDTO.employeeDepartmentId,
                departmentName: positionDTO.department ?? "",
                title: positionDTO.jobPosition ?? "",
                contacts: (positionDTO.contacts ?? []).map {
                    EmployeeContact(phone: $0.phoneNumber, address: $0.address)
                }
            )
            guard !result.contains(where: {
                $0.departmentName == position.departmentName && $0.title == position.title
            }) else {
                continue
            }
            result.append(position)
        }
        return result
    }

    private func makeAdditionalSections(
        _ information: [EmployeeAdditionalInformationDTO]
    ) -> [EmployeeInfoSection] {
        var seenTypes: Set<Int> = []
        return information.compactMap { info in
            guard let content = info.content, !content.isEmpty else {
                return nil
            }

            let section = EmployeeInfoSection(
                idType: info.idType,
                title: info.nameType,
                htmlContent: content
            )
            guard !section.textContent.isEmpty, seenTypes.insert(section.id).inserted else {
                return nil
            }
            return section
        }
    }

    private func makeProfileLinks(
        _ links: [EmployeeProfileLinkDTO]
    ) -> [EmployeeLink] {
        links.compactMap { link in
            guard let url = URL(string: link.link),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "https" || scheme == "http" else {
                return nil
            }
            return EmployeeLink(type: link.profileLinkType, url: url)
        }
    }

    private func uniqueStrings(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }

    private func firstNonempty(_ primary: String?, _ fallback: String?) -> String? {
        if let primary, !primary.isEmpty {
            return primary
        }
        if let fallback, !fallback.isEmpty {
            return fallback
        }
        return nil
    }

    private func normalizePhone(_ phone: String) -> String {
        phone.filter(\.isNumber)
    }
}
