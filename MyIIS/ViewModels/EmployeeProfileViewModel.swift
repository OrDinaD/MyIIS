import SwiftUI
import Observation

@Observable
@MainActor
final class EmployeeProfileViewModel {
    var profile: EmployeeProfile?
    var isLoading = false
    var error: Error?
    
    private let repository = EmployeesRepository.shared
    
    func loadProfile(for hit: EmployeeSearchHit) async {
        isLoading = true
        error = nil
        do {
            profile = try await repository.resolveProfile(for: hit)
        } catch {
            self.error = error
        }
        isLoading = false
    }
}
