import Foundation

extension ScheduleServiceViewModel {
    func scheduleDebouncedSearchUpdate() {
        searchDebounceTask?.cancel()
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchDebounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            debouncedQuery = value
        }
    }

    func loadDirectoryIfNeeded(force: Bool) async {
        let shouldLoadGroups = mode == .group && (groups.isEmpty || force)
        let shouldLoadEmployees = mode == .teacher && (employees.isEmpty || force)
        guard shouldLoadGroups || shouldLoadEmployees else {
            hasLoadedInitialData = true
            return
        }

        guard !isDirectoryLoading else { return }

        if shouldLoadGroups, let cachedGroups = api.cachedStudentGroups() {
            groups = cachedGroups.sorted { $0.name < $1.name }
        }
        if shouldLoadEmployees, let cachedEmployees = api.cachedEmployees() {
            employees = Self.filteredEmployeeDirectory(cachedEmployees)
        }

        isDirectoryLoading = true
        updateLoadingState()
        defer {
            isDirectoryLoading = false
            updateLoadingState()
            hasLoadedInitialData = true
        }

        do {
            if shouldLoadGroups {
                groups = try await api.fetchAllStudentGroups(preferCachedResponse: !force)
                    .sorted { $0.name < $1.name }
            }
            if shouldLoadEmployees {
                employees = Self.filteredEmployeeDirectory(
                    try await api.fetchAllEmployees(preferCachedResponse: !force)
                )
            }
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = userFacingScheduleError(error)
        }
    }

    func updateLoadingState() {
        isLoading = isDirectoryLoading || activeScheduleRequestID != nil
    }

    private static func filteredEmployeeDirectory(
        _ entries: [ScheduleEmployeeDirectoryEntry]
    ) -> [ScheduleEmployeeDirectoryEntry] {
        entries
            .filter { ($0.urlId?.isEmpty == false) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}
