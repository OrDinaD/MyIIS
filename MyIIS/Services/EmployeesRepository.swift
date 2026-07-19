import Foundation

actor EmployeesRepository {
    static let shared = EmployeesRepository()
    private let apiClient = EmployeesAPIClient()

    private var treeCache: [DepartmentTreeNodeDTO]?
    private var globalIndex: [EmployeeSearchHit] = []

    func fetchDepartmentsTree() async throws -> [DepartmentTreeNodeDTO] {
        if let cache = treeCache { return cache }
        let tree = try await apiClient.fetchDepartmentsTree()
        treeCache = tree
        buildGlobalIndex(from: tree)
        return tree
    }

    private func buildGlobalIndex(from tree: [DepartmentTreeNodeDTO]) {
        var index = [EmployeeSearchHit]()
        
        func flatten(nodes: [DepartmentTreeNodeDTO]) {
            for node in nodes {
                if let emps = node.data.employees {
                    for emp in emps {
                        let hit = EmployeeSearchHit(
                            fio: emp.fio,
                            normalizedFIO: normalizeSearch(emp.fio),
                            surname: emp.fio.components(separatedBy: " ").first ?? "",
                            phones: emp.phoneNumbers?.map { normalizePhone($0) } ?? [],
                            departmentId: node.data.id,
                            departmentUrlId: node.data.urlId ?? "",
                            departmentName: node.data.name,
                            departmentAbbrev: node.data.abbrev ?? "",
                            departmentTypeId: node.data.typeId
                        )
                        index.append(hit)
                    }
                }
                if let children = node.children {
                    flatten(nodes: children)
                }
            }
        }
        
        flatten(nodes: tree)
        self.globalIndex = index
    }

    func search(query: String) async -> [EmployeeSearchHit] {
        if globalIndex.isEmpty {
            _ = try? await fetchDepartmentsTree()
        }
        let normQuery = normalizeSearch(query)
        if normQuery.isEmpty { return globalIndex }
        
        let queryTokens = normQuery.split(separator: " ").map { String($0) }
        
        var scored: [(hit: EmployeeSearchHit, score: Int)] = []
        for hit in globalIndex {
            var score = 0
            
            if hit.normalizedFIO == normQuery { score = max(score, 120) }
            else if hit.surname.lowercased() == normQuery { score = max(score, 110) }
            else if hit.normalizedFIO.hasPrefix(normQuery) { score = max(score, 90) }
            else if hit.normalizedFIO.contains(normQuery) { score = max(score, 60) }
            
            let hitTokens = hit.normalizedFIO.split(separator: " ")
            for qToken in queryTokens {
                if hitTokens.contains(where: { $0.hasPrefix(qToken) }) {
                    score = max(score, 75)
                }
            }
            
            let digitsOnly = normQuery.filter { $0.isNumber }
            if !digitsOnly.isEmpty {
                if hit.phones.contains(where: { $0.contains(digitsOnly) }) {
                    score = max(score, 80)
                }
            }
            
            if hit.departmentAbbrev.lowercased() == normQuery { score = max(score, 70) }
            else if hit.departmentAbbrev.lowercased().contains(normQuery) || hit.departmentName.lowercased().contains(normQuery) { score = max(score, 35) }
            
            if score > 0 {
                scored.append((hit, score))
            }
        }
        
        return scored.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.hit.departmentTypeId == 3 && $1.hit.departmentTypeId != 3 { return true }
            if $1.hit.departmentTypeId == 3 && $0.hit.departmentTypeId != 3 { return false }
            return $0.hit.fio < $1.hit.fio
        }.map { $0.hit }
    }

    func resolveProfile(for hit: EmployeeSearchHit) async throws -> EmployeeProfile {
        let summaries = try await apiClient.fetchEmployees(forDepartment: hit.departmentUrlId)
        
        let candidates = summaries.filter { normalizeSearch($0.getFullName()) == hit.normalizedFIO }
        guard let summary = candidates.first else {
            throw EmployeesAPIError.invalidResponse
        }
        
        let details = try await apiClient.fetchEmployeeDetails(urlId: summary.urlId)
        return merge(summary: summary, details: details, departmentUrlId: hit.departmentUrlId)
    }

    private func merge(summary: EmployeeSummaryDTO, details: EmployeeDetailsDTO, departmentUrlId: String) -> EmployeeProfile {
        var chiefDict = [String: Bool]()
        if let chief = summary.chief {
            chiefDict[departmentUrlId] = chief
        }
        
        let name = PersonName(firstName: summary.firstName, lastName: summary.lastName, middleName: summary.middleName)
        let mergedPositions = mergePositions(summary: summary.jobPositions, details: details.jobPositions)
        
        let calendarId: String? = {
            if let c = details.calendarId, !c.isEmpty { return c }
            if let c = summary.calendarId, !c.isEmpty { return c }
            return nil
        }()
        
        let degreeAbbrev: String? = {
            if let d = details.degreeAbbrev, !d.isEmpty { return d }
            if let d = summary.degreeAbbrev, !d.isEmpty { return d }
            return nil
        }()
        
        return EmployeeProfile(
            id: details.id,
            urlId: details.urlId,
            name: name,
            photoURL: details.photoLink ?? summary.photoLink,
            degree: details.degree ?? summary.degree,
            degreeAbbreviation: degreeAbbrev,
            rank: details.rank ?? summary.rank,
            email: details.email ?? summary.email,
            calendarId: calendarId,
            positions: mergedPositions,
            departmentLeadership: chiefDict,
            readingCourses: details.readingCourses ?? [],
            additionalSections: (details.additionalInformation ?? []).compactMap { info in
                guard let content = info.content, !content.isEmpty else { return nil }
                return EmployeeInfoSection(idType: info.idType, title: info.nameType, htmlContent: content)
            },
            profileLinks: (details.profileLinks ?? []).map { EmployeeLink(type: $0.profileLinkType, url: URL(string: $0.link) ?? URL(string: "https://iis.bsuir.by")!) }
        )
    }

    private func mergePositions(summary: [EmployeeJobPositionDTO]?, details: [EmployeeJobPositionDTO]?) -> [EmployeePosition] {
        let allDTOs = (summary ?? []) + (details ?? [])
        var result = [EmployeePosition]()
        
        for dto in allDTOs {
            let contacts = (dto.contacts ?? []).map {
                EmployeeContact(phone: $0.phoneNumber, address: $0.address)
            }
            let pos = EmployeePosition(
                departmentId: dto.employeeDepartmentId,
                departmentName: dto.department ?? "",
                title: dto.jobPosition ?? "",
                contacts: contacts
            )
            if !result.contains(where: { $0.departmentName == pos.departmentName && $0.title == pos.title }) {
                result.append(pos)
            }
        }
        return result
    }

    nonisolated func normalizeSearch(_ value: String) -> String {
        let engToRus: [Character: Character] = [
            "q": "й", "w": "ц", "e": "у", "r": "к", "t": "е", "y": "н", "u": "г", "i": "ш", "o": "щ", "p": "з", "[": "х", "]": "ъ",
            "a": "ф", "s": "ы", "d": "в", "f": "а", "g": "п", "h": "р", "j": "о", "k": "л", "l": "д", ";": "ж", "'": "э",
            "z": "я", "x": "ч", "c": "с", "v": "м", "b": "и", "n": "т", "m": "ь", ",": "б", ".": "ю"
        ]
        
        let lowered = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            
        let corrected = String(lowered.map { engToRus[$0] ?? $0 })
        
        return corrected.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private func normalizePhone(_ phone: String) -> String {
        phone.filter { $0.isNumber }
    }
}
