import XCTest
@testable import MyIIS

@MainActor
final class DiplomaViewModelTests: XCTestCase {
    func testLoadProgressUpdatesComputedProperties() async {
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let milestones = [
            Milestone(
                id: "1",
                title: "Тема утверждена",
                details: nil,
                plannedDate: updatedAt.addingTimeInterval(-10_000),
                actualDate: updatedAt.addingTimeInterval(-9_000),
                status: .completed,
                comment: nil,
                order: 1
            ),
            Milestone(
                id: "2",
                title: "Исследование",
                details: nil,
                plannedDate: updatedAt.addingTimeInterval(10_000),
                actualDate: nil,
                status: .inProgress,
                comment: "Необходимо согласовать план",
                order: 2
            ),
            Milestone(
                id: "3",
                title: "Подготовка к защите",
                details: nil,
                plannedDate: updatedAt.addingTimeInterval(50_000),
                actualDate: nil,
                status: .planned,
                comment: nil,
                order: 3
            )
        ]

        let progress = DiplomaProgress(
            topic: "Разработка iOS-приложения",
            advisor: "Проф. Иванов",
            status: .inProgress,
            comment: "Работа идёт по плану",
            updatedAt: updatedAt,
            milestones: milestones
        )

        let service = DiplomaServiceMock(results: [.success(progress)])
        let viewModel = DiplomaViewModel(diplomaService: service)

        await viewModel.loadProgress(for: "420603")

        XCTAssertEqual(service.identifierRequests, ["420603"])
        XCTAssertTrue(viewModel.hasContent)
        XCTAssertEqual(viewModel.statusText, "В работе")
        XCTAssertEqual(viewModel.topic, "Разработка iOS-приложения")
        XCTAssertEqual(viewModel.advisorText, "Проф. Иванов")
        XCTAssertEqual(viewModel.milestones.count, 3)
        XCTAssertEqual(viewModel.nextMilestone?.id, "2")
        XCTAssertEqual(viewModel.commentText, "Работа идёт по плану")
        XCTAssertEqual(viewModel.completionPercentage, 1.0 / 3.0, accuracy: 0.0001)
        XCTAssertNotNil(viewModel.plannedDateText(for: milestones[1]))
        XCTAssertNotNil(viewModel.actualDateText(for: milestones[0]))
        XCTAssertNotNil(viewModel.updatedAtText)
    }

    func testLoadProgressWithNilIdentifierShowsError() async {
        let service = DiplomaServiceMock(results: [])
        let viewModel = DiplomaViewModel(diplomaService: service)

        await viewModel.loadProgress(for: nil)

        XCTAssertEqual(viewModel.errorMessage, "Не удалось определить пользователя")
        XCTAssertTrue(service.identifierRequests.isEmpty)
    }

    func testRefreshForcesReloadEvenWithCachedData() async {
        let first = DiplomaProgress(
            topic: "Работа 1",
            advisor: nil,
            status: .inProgress,
            comment: nil,
            updatedAt: nil,
            milestones: []
        )
        let second = DiplomaProgress(
            topic: "Работа 2",
            advisor: "Преподаватель",
            status: .awaitingDefense,
            comment: nil,
            updatedAt: nil,
            milestones: []
        )

        let service = DiplomaServiceMock(results: [.success(first), .success(second)])
        let viewModel = DiplomaViewModel(diplomaService: service)

        await viewModel.loadProgress(for: "1")
        XCTAssertEqual(viewModel.topic, "Работа 1")

        await viewModel.loadProgress(for: "1")
        XCTAssertEqual(service.identifierRequests, ["1"], "Повторная загрузка без форса не должна обращаться к сервису")

        await viewModel.refresh(for: "1")
        XCTAssertEqual(service.identifierRequests, ["1", "1"], "Refresh должен форсировать повторный запрос")
        XCTAssertEqual(viewModel.topic, "Работа 2")
    }

    func testServiceErrorIsPresented() async {
        let service = DiplomaServiceMock(results: [.failure(APIError.serviceUnavailable(message: "Недоступно"))])
        let viewModel = DiplomaViewModel(diplomaService: service)

        await viewModel.loadProgress(for: "student")

        XCTAssertEqual(viewModel.errorMessage, "Недоступно")
    }
}

private final class DiplomaServiceMock: DiplomaServicing {
    var results: [Result<DiplomaProgress, Error>]
    private(set) var identifierRequests: [String] = []
    private var lastResult: Result<DiplomaProgress, Error>?

    init(results: [Result<DiplomaProgress, Error>]) {
        self.results = results
        self.lastResult = results.last
    }

    func fetchDiplomaProgress(for userIdentifier: String) async throws -> DiplomaProgress {
        identifierRequests.append(userIdentifier)
        let result: Result<DiplomaProgress, Error>
        if !results.isEmpty {
            result = results.removeFirst()
            lastResult = result
        } else if let lastResult {
            result = lastResult
        } else {
            result = .failure(APIError.serviceUnavailable(message: "Нет данных"))
        }
        return try result.get()
    }
}
