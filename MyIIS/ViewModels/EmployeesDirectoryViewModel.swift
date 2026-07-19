import SwiftUI
import Observation

@Observable
@MainActor
final class EmployeesDirectoryViewModel {
    var searchText = ""
    var searchResults: [EmployeeSearchHit] = []
    var isLoading = false
    
    private let repository = EmployeesRepository.shared
    private var searchTask: Task<Void, Never>?
    
    func performSearch() {
        searchTask?.cancel()
        searchTask = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
                if Task.isCancelled { return }
                
                self.isLoading = true
                let results = await repository.search(query: searchText)
                if Task.isCancelled { return }
                
                self.searchResults = results
                self.isLoading = false
            } catch {
                self.isLoading = false
            }
        }
    }
    
    func loadInitial() async {
        isLoading = true
        searchResults = await repository.search(query: "")
        isLoading = false
    }
}
