import XCTest
@testable import MyIIS

final class LibraryViewModelTests: XCTestCase {
    @MainActor
    func testSeparatesActiveAndArchiveAfterLoad() async {
        let service = MockLibraryService()
        let viewModel = LibraryViewModel(service: service)

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.activeLoans.count, 2)
        XCTAssertEqual(viewModel.archiveLoans.count, 1)
    }

    @MainActor
    func testSearchFiltersCatalog() async {
        let service = MockLibraryService()
        let viewModel = LibraryViewModel(service: service)

        await viewModel.loadIfNeeded()

        viewModel.selectedSegment = .catalog
        viewModel.searchQuery = "машин"

        XCTAssertEqual(viewModel.filteredCatalog.count, 1)
        XCTAssertEqual(viewModel.filteredCatalog.first?.title, "Основы машинного обучения")
    }

    @MainActor
    func testSearchFiltersActiveLoans() async {
        let service = MockLibraryService()
        let viewModel = LibraryViewModel(service: service)

        await viewModel.loadIfNeeded()

        viewModel.selectedSegment = .active
        viewModel.searchQuery = "swiftui"

        XCTAssertEqual(viewModel.filteredActiveLoans.count, 1)
        XCTAssertEqual(viewModel.filteredActiveLoans.first?.title, "Разработка приложений на SwiftUI")
    }
}

private struct MockLibraryService: LibraryServicing {
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
