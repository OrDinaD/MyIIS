import XCTest
@testable import MyIIS

final class PenaltiesViewModelTests: XCTestCase {
    @MainActor
    func testSectionsGroupedByMonthDescending() async {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        let records = [
            PenaltyRecord(
                recordID: "1",
                type: .warning,
                title: "Предупреждение",
                description: nil,
                issuedAt: formatter.date(from: "2024-02-15T12:00:00Z")!,
                updatedAt: nil,
                authority: "Деканат",
                status: .resolved,
                note: nil
            ),
            PenaltyRecord(
                recordID: "2",
                type: .severeReprimand,
                title: "Строгий выговор",
                description: nil,
                issuedAt: formatter.date(from: "2024-02-20T08:00:00Z")!,
                updatedAt: nil,
                authority: "Комиссия",
                status: .active,
                note: nil
            ),
            PenaltyRecord(
                recordID: "3",
                type: .remark,
                title: "Замечание",
                description: nil,
                issuedAt: formatter.date(from: "2024-01-05T09:00:00Z")!,
                updatedAt: nil,
                authority: nil,
                status: .cancelled,
                note: nil
            )
        ]

        let service = MockPenaltiesService(records: records)
        let viewModel = PenaltiesViewModel(service: service)

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.sections.count, 2)
        XCTAssertEqual(viewModel.sections.first?.title, "Февраль 2024")
        XCTAssertEqual(viewModel.sections.first?.items.map(\.id), ["2", "1"])
        XCTAssertEqual(viewModel.sections.last?.title, "Январь 2024")
        XCTAssertEqual(viewModel.status, .loaded)
        XCTAssertEqual(viewModel.availableTypes, [.severeReprimand, .warning, .remark])
    }

    @MainActor
    func testFilterUpdatesStatusWhenEmpty() async {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let records = [
            PenaltyRecord(
                recordID: "1",
                type: .warning,
                title: "Предупреждение",
                description: nil,
                issuedAt: formatter.date(from: "2024-04-01T12:00:00Z")!,
                updatedAt: nil,
                authority: nil,
                status: .resolved,
                note: nil
            )
        ]

        let service = MockPenaltiesService(records: records)
        let viewModel = PenaltiesViewModel(service: service)

        await viewModel.loadIfNeeded()
        XCTAssertEqual(viewModel.status, .loaded)

        viewModel.selectType(.severeReprimand)
        XCTAssertEqual(viewModel.status, .filteredEmpty)
        XCTAssertTrue(viewModel.sections.isEmpty)

        viewModel.selectType(nil)
        XCTAssertEqual(viewModel.status, .loaded)
        XCTAssertEqual(viewModel.sections.first?.items.first?.id, "1")
    }

    @MainActor
    func testEmptyResponseChangesStatus() async {
        let service = MockPenaltiesService(records: [])
        let viewModel = PenaltiesViewModel(service: service)

        await viewModel.loadIfNeeded()

        XCTAssertTrue(viewModel.sections.isEmpty)
        XCTAssertEqual(viewModel.status, .empty)
    }
}

private actor MockPenaltiesService: PenaltiesServicing {
    private let records: [PenaltyRecord]

    init(records: [PenaltyRecord]) {
        self.records = records
    }

    func fetchPenalties() async throws -> [PenaltyRecord] {
        records
    }
}
