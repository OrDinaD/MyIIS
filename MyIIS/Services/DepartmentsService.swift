import Foundation
import Combine
import SwiftUI

class DepartmentsService: ObservableObject {
    static let shared = DepartmentsService()
    
    @Published var departments: [DepartmentNode] = []
    @Published var isLoading = false
    
    private init() {}
    
    func loadMockData() {
        guard let url = URL(string: "https://iis.bsuir.by/api/v1/departments/tree") else { return }
        
        DispatchQueue.main.async { self.isLoading = true }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let decoder = JSONDecoder()
                let decoded = try decoder.decode([DepartmentNode].self, from: data)
                DispatchQueue.main.async {
                    self.departments = decoded
                    self.isLoading = false
                }
            } catch {
                print("Failed to decode departments: \\(error)")
                DispatchQueue.main.async { self.isLoading = false }
            }
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
