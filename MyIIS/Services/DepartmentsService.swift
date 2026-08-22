import Combine
import Foundation
import SwiftUI

@MainActor
final class DepartmentsService: ObservableObject {
    static let shared = DepartmentsService()

    @Published var departments: [DepartmentNode] = []
    @Published var isLoading = false

    private static let apiBaseURL = NetworkSecurityPolicy.iisBaseURL
        .appendingPathComponent("api")
        .appendingPathComponent("v1")

    private init() {}

    func loadMockData() {
        guard !isLoading else { return }
        if departments.isEmpty {
            departments = DepartmentsMockData.departments
        }

        Task {
            await refreshRemoteData()
        }
    }

    private func refreshRemoteData() async {
        let url = Self.apiBaseURL
            .appendingPathComponent("departments")
            .appendingPathComponent("tree")

        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await fetchData(from: url)
            let decoded = try JSONDecoder().decode([DepartmentNode].self, from: data)
            if !decoded.isEmpty {
                departments = decoded
            } else if departments.isEmpty {
                departments = DepartmentsMockData.departments
            }
        } catch {
            if departments.isEmpty {
                departments = DepartmentsMockData.departments
            }
            print("Failed to load departments: \(error)")
        }
    }

    func fetchEmployees(for urlId: String) async -> [DepartmentEmployeeDetail] {
        guard let url = Self.endpoint(
            path: "employees",
            queryItems: [URLQueryItem(name: "departmentUrlId", value: urlId)]
        ) else {
            return []
        }

        do {
            let data = try await fetchData(from: url)
            return try JSONDecoder().decode([DepartmentEmployeeDetail].self, from: data)
        } catch {
            print("Failed to fetch employees: \(error)")
            return []
        }
    }

    func fetchEmployeeDetails(for urlId: String) async -> DepartmentEmployeeDetail? {
        guard let url = Self.endpoint(
            path: "employees/details-url",
            queryItems: [URLQueryItem(name: "urlId", value: urlId)]
        ) else {
            return nil
        }

        do {
            let data = try await fetchData(from: url)
            return try JSONDecoder().decode(DepartmentEmployeeDetail.self, from: data)
        } catch {
            print("Failed to fetch employee details: \(error)")
            return nil
        }
    }

    private func fetchData(from url: URL) async throws -> Data {
        guard NetworkSecurityPolicy.isSecureURL(url),
              url.host?.lowercased() == NetworkSecurityPolicy.iisHost else {
            throw NetworkSecurityError.untrustedURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let response = response as? HTTPURLResponse,
              let responseURL = response.url,
              responseURL.host?.lowercased() == NetworkSecurityPolicy.iisHost,
              NetworkSecurityPolicy.isSecureURL(responseURL),
              (200 ... 299).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private static func endpoint(
        path: String,
        queryItems: [URLQueryItem]
    ) -> URL? {
        var components = URLComponents(
            url: apiBaseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = queryItems
        return components?.url
    }
}
