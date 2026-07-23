import Observation
import SwiftUI

@Observable
@MainActor
final class DepartmentsViewModel {
    var tree: [DepartmentTreeNodeDTO] = []
    var isLoading = false

    private let repository = EmployeesRepository.shared

    func loadTree() async {
        isLoading = true
        do {
            tree = try await repository.fetchDepartmentsTree()
        } catch {
            print("Error loading tree: \(error)")
        }
        isLoading = false
    }
}

@Observable
@MainActor
final class DepartmentDetailViewModel {
    var employees: [EmployeeSummaryDTO] = []
    var isLoading = false

    private let repository = EmployeesRepository.shared
    private let apiClient = EmployeesAPIClient()

    func loadEmployees(urlId: String) async {
        isLoading = true
        do {
            employees = try await apiClient.fetchEmployees(forDepartment: urlId)
        } catch {
            print("Error loading employees: \(error)")
        }
        isLoading = false
    }
}
