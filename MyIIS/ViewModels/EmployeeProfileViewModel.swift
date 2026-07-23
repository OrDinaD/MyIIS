import Observation
import SwiftUI

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
        defer { isLoading = false }

        do {
            profile = try await repository.resolveProfile(for: hit)
        } catch is CancellationError {
            return
        } catch {
            self.error = error
        }
    }
}
