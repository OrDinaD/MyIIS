import Foundation
import Combine
import SwiftUI

class DepartmentsService: ObservableObject {
    static let shared = DepartmentsService()
    
    @Published var departments: [DepartmentNode] = []
    @Published var isLoading = false
    
    private init() {
        loadMockData()
    }
    
    func loadMockData() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let data = DepartmentsMockData.jsonString.data(using: .utf8) else {
                DispatchQueue.main.async { self?.isLoading = false }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let decoded = try decoder.decode([DepartmentNode].self, from: data)
                DispatchQueue.main.async {
                    self?.departments = decoded
                    self?.isLoading = false
                }
            } catch {
                print("Failed to decode departments: \\(error)")
                DispatchQueue.main.async { self?.isLoading = false }
            }
        }
    }
}
