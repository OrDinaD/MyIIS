import Combine
import Foundation
import SwiftUI

@MainActor
final class PhoneBookService: ObservableObject {
    static let shared = PhoneBookService()

    @Published var entries: [PhoneBookEntry] = []
    @Published var isLoading = false

    private let url = URL(string: "https://iis.bsuir.by/api/v1/phone-book")!

    func search(query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = fallbackEntries(matching: trimmedQuery)

        if entries.isEmpty {
            entries = fallback
        }

        isLoading = true
        defer { isLoading = false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "searchValue": trimmedQuery,
            "currentPage": 1,
            "pageSize": 50
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            let response = try decoder.decode(PhoneBookResponse.self, from: data)
            entries = response.auditoryPhoneNumberDtoList.isEmpty ? fallback : response.auditoryPhoneNumberDtoList
        } catch {
            entries = fallback
            print("Failed to fetch phone book: \\(error)")
        }
    }

    private func fallbackEntries(matching query: String) -> [PhoneBookEntry] {
        let normalizedQuery = query.lowercased()
        let entries = DepartmentsMockData.phoneBookEntries

        let filtered: [PhoneBookEntry]
        if normalizedQuery.isEmpty {
            filtered = Array(entries.prefix(50))
        } else {
            filtered = entries.filter { $0.matches(query: normalizedQuery) }
        }

        return Array(filtered.prefix(50))
    }
}

private extension PhoneBookEntry {
    func matches(query: String) -> Bool {
        if auditory.lowercased().contains(query) {
            return true
        }

        if phones.contains(where: { $0.lowercased().contains(query) }) {
            return true
        }

        if departments.contains(where: { department in
            department.name.lowercased().contains(query) || department.abbrev.lowercased().contains(query)
        }) {
            return true
        }

        return employees.contains(where: { employee in
            employee.fio.lowercased().contains(query) ||
            (employee.jobPosition?.lowercased().contains(query) ?? false) ||
            (employee.department?.lowercased().contains(query) ?? false)
        })
    }
}
