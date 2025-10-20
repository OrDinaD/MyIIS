import XCTest
@testable import MyIIS

@MainActor
final class DormitoryViewModelTests: XCTestCase {
    func testLoadIfNeededFetchesDataAndActions() async {
        let baseDate = Date()
        let info = DormitoryInfo(
            id: UUID(),
            dormitoryName: "Общежитие №5",
            roomNumber: "305",
            bedPlace: "Место 1",
            floor: 3,
            moveInDate: baseDate.addingTimeInterval(-100_000),
            contractEndDate: baseDate.addingTimeInterval(200_000),
            paidUntil: baseDate.addingTimeInterval(10_000),
            monthlyFee: 80,
            currentBalance: 40,
            status: .active,
            lastPaymentDate: baseDate.addingTimeInterval(-20_000),
            notes: nil
        )

        let history = [
            ResidenceHistory(
                id: UUID(),
                eventDate: baseDate.addingTimeInterval(-1000),
                type: .payment,
                title: "Оплата",
                amount: 40,
                description: nil,
                status: nil
            ),
            ResidenceHistory(
                id: UUID(),
                eventDate: baseDate.addingTimeInterval(-100),
                type: .maintenance,
                title: "Заявка",
                amount: nil,
                description: nil,
                status: nil
            )
        ]

        let actions = DormitoryAction.ActionType.allCases.map { DormitoryAction(type: $0) }

        let service = DormitoryServiceMock(
            infoResult: .success(info),
            historyResult: .success(history),
            actions: actions
        )

        let viewModel = DormitoryViewModel(dormitoryService: service)

        await viewModel.loadIfNeeded()

        XCTAssertEqual(service.fetchInfoCallCount, 1)
        XCTAssertEqual(service.fetchHistoryCallCount, 1)
        XCTAssertEqual(viewModel.dormitoryInfo, info)
        XCTAssertEqual(viewModel.history.map { $0.title }, ["Заявка", "Оплата"])
        XCTAssertEqual(viewModel.actions.map { $0.type }, actions.map { $0.type })
        XCTAssertNil(viewModel.errorMessage)

        await viewModel.loadIfNeeded()
        XCTAssertEqual(service.fetchInfoCallCount, 1, "Повторный loadIfNeeded не должен обращаться к сервису")
    }

    func testTriggerActionShowsInfoMessage() {
        let service = DormitoryServiceMock(
            infoResult: .success(.previewValue),
            historyResult: .success([]),
            actions: []
        )
        let viewModel = DormitoryViewModel(dormitoryService: service)

        let paymentAction = DormitoryAction(type: .makePayment)
        viewModel.triggerAction(paymentAction)
        XCTAssertEqual(viewModel.infoMessage, "Перейдите в раздел оплат, чтобы завершить платёж.")

        let extendAction = DormitoryAction(type: .extendContract)
        viewModel.triggerAction(extendAction)
        XCTAssertEqual(viewModel.infoMessage, "Вы можете продлить договор через деканат или онлайн-заявку.")

        viewModel.dismissInfoMessage()
        XCTAssertNil(viewModel.infoMessage)
    }

    func testLoadHandlesError() async {
        let service = DormitoryServiceMock(
            infoResult: .failure(DormitoryServiceError.serviceUnavailable),
            historyResult: .success([]),
            actions: []
        )
        let viewModel = DormitoryViewModel(dormitoryService: service)

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.errorMessage, DormitoryServiceError.serviceUnavailable.localizedDescription)
        XCTAssertFalse(viewModel.isLoading)
    }
}

private final class DormitoryServiceMock: DormitoryServicing {
    var infoResult: Result<DormitoryInfo, Error>
    var historyResult: Result<[ResidenceHistory], Error>
    var actions: [DormitoryAction]

    private(set) var fetchInfoCallCount = 0
    private(set) var fetchHistoryCallCount = 0

    init(
        infoResult: Result<DormitoryInfo, Error>,
        historyResult: Result<[ResidenceHistory], Error>,
        actions: [DormitoryAction]
    ) {
        self.infoResult = infoResult
        self.historyResult = historyResult
        self.actions = actions
    }

    func fetchDormitoryInfo() async throws -> DormitoryInfo {
        fetchInfoCallCount += 1
        return try infoResult.get()
    }

    func fetchResidenceHistory() async throws -> [ResidenceHistory] {
        fetchHistoryCallCount += 1
        return try historyResult.get()
    }

    func availableActions(for info: DormitoryInfo) -> [DormitoryAction] {
        actions
    }
}
