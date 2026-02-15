import Foundation
import Combine

@MainActor
final class LibraryViewModel: ObservableObject {
    enum Segment: String, CaseIterable, Identifiable {
        case active
        case archive
        case catalog

        var id: Segment { self }

        var title: String {
            switch self {
            case .active: return "Активные"
            case .archive: return "Архив"
            case .catalog: return "Каталог"
            }
        }
    }

    @Published private(set) var catalogItems: [LibraryItem]
    @Published private(set) var activeLoans: [BorrowHistoryEntry]
    @Published private(set) var archiveLoans: [BorrowHistoryEntry]
    @Published var searchQuery: String
    @Published var selectedSegment: Segment
    @Published private(set) var isLoading: Bool
    @Published private(set) var errorMessage: String?

    private let service: LibraryServicing
    private var hasLoadedOnce = false

    init(
        service: LibraryServicing = LibraryService(),
        catalogItems: [LibraryItem] = [],
        activeLoans: [BorrowHistoryEntry] = [],
        archiveLoans: [BorrowHistoryEntry] = [],
        searchQuery: String = "",
        selectedSegment: Segment = .active,
        isLoading: Bool = false,
        errorMessage: String? = nil
    ) {
        self.service = service
        self.catalogItems = catalogItems
        self.activeLoans = activeLoans
        self.archiveLoans = archiveLoans
        self.searchQuery = searchQuery
        self.selectedSegment = selectedSegment
        self.isLoading = isLoading
        self.errorMessage = errorMessage
    }

    func loadIfNeeded() async {
        guard !hasLoadedOnce else { return }
        await load(force: true)
    }

    func refresh() async {
        await load(force: true)
    }

    func clearSearch() {
        searchQuery = ""
    }

    var isEmpty: Bool {
        activeLoans.isEmpty && archiveLoans.isEmpty && catalogItems.isEmpty
    }

    var filteredActiveLoans: [BorrowHistoryEntry] {
        applySearch(to: activeLoans)
    }

    var filteredArchiveLoans: [BorrowHistoryEntry] {
        applySearch(to: archiveLoans)
    }

    var filteredCatalog: [LibraryItem] {
        applySearch(to: catalogItems)
    }

    private func load(force: Bool) async {
        if isLoading { return }
        if hasLoadedOnce && !force { return }

        isLoading = true
        errorMessage = nil

        do {
            async let catalogTask = service.fetchCatalog(searchQuery: nil)
            async let activeTask = service.fetchActiveLoans()
            async let historyTask = service.fetchBorrowHistory()

            let (catalog, active, history) = try await (catalogTask, activeTask, historyTask)

            self.catalogItems = catalog
            self.activeLoans = active
            self.archiveLoans = history.filter { !$0.isActive }
            hasLoadedOnce = true
        } catch let apiError as APIError {
            errorMessage = apiError.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func applySearch(to items: [LibraryItem]) -> [LibraryItem] {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return items
        }
        return items.filter { $0.matches(query: searchQuery) }
    }

    private func applySearch(to items: [BorrowHistoryEntry]) -> [BorrowHistoryEntry] {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return items
        }
        return items.filter { $0.matches(query: searchQuery) }
    }
}

// MARK: - Previews

extension LibraryViewModel {
    static var preview: LibraryViewModel {
        LibraryViewModel(
            service: PreviewLibraryService(),
            catalogItems: LibraryItem.previewCatalog,
            activeLoans: BorrowHistoryEntry.previewActive,
            archiveLoans: BorrowHistoryEntry.previewArchive,
            searchQuery: "",
            selectedSegment: .active
        )
    }
}

private struct PreviewLibraryService: LibraryServicing {
    func fetchCatalog(searchQuery: String?) async throws -> [LibraryItem] {
        LibraryItem.previewCatalog
    }

    func fetchActiveLoans() async throws -> [BorrowHistoryEntry] {
        BorrowHistoryEntry.previewActive
    }

    func fetchBorrowHistory() async throws -> [BorrowHistoryEntry] {
        BorrowHistoryEntry.previewActive + BorrowHistoryEntry.previewArchive
    }
}
