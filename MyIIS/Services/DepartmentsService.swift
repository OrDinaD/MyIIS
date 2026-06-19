import Combine
import Foundation
import SwiftUI

@MainActor
final class DepartmentsService: ObservableObject {
    static let shared = DepartmentsService()

    @Published var departments: [DepartmentNode] = []
    @Published var isLoading = false

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
        guard let url = URL(string: "https://iis.bsuir.by/api/v1/departments/tree") else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
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
            print("Failed to load departments: \\(error)")
        }
    }

    func fetchEmployees(for urlId: String) async -> [DepartmentEmployeeDetail] {
        guard let url = URL(string: "https://iis.bsuir.by/api/v1/employees?departmentUrlId=\\(urlId)") else { return [] }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode([DepartmentEmployeeDetail].self, from: data)
            return decoded
        } catch {
            print("Failed to fetch employees: \\(error)")
            return []
        }
    }

    func fetchEmployeeDetails(for urlId: String) async -> DepartmentEmployeeDetail? {
        guard let url = URL(string: "https://iis.bsuir.by/api/v1/employees/details-url?urlId=\\(urlId)") else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(DepartmentEmployeeDetail.self, from: data)
            return decoded
        } catch {
            print("Failed to fetch employee details: \\(error)")
            return nil
        }
    }
}
