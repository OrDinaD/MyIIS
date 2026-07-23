import Observation
import SwiftUI

@Observable
@MainActor
final class EmployeesDirectoryViewModel {
    var searchText = ""
    var searchResults: [EmployeeSearchHit] = []
    var isLoading = false

    private let repository = EmployeesRepository.shared
    private var searchTask: Task<Void, Never>?
    private var searchGeneration = 0

    func performSearch() {
        searchTask?.cancel()
        searchGeneration += 1

        let generation = searchGeneration
        let query = searchText
        searchTask = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
                try Task.checkCancellation()
                guard generation == searchGeneration else { return }

                isLoading = true
                let results = await repository.search(query: query)
                try Task.checkCancellation()
                guard generation == searchGeneration else { return }

                searchResults = results
            } catch is CancellationError {
                // A newer search owns the loading state and results.
            } catch {
                // Local search currently has no recoverable error to present.
            }

            if generation == searchGeneration {
                isLoading = false
            }
        }
    }

    func loadInitial() async {
        searchTask?.cancel()
        searchGeneration += 1

        let generation = searchGeneration
        isLoading = true
        let results = await repository.search(query: "")
        guard generation == searchGeneration else { return }

        searchResults = results
        isLoading = false
    }
}
