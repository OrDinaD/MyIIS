import XCTest
@testable import MyIIS

@MainActor
final class GradebookViewModelTests: XCTestCase {
    func testLoadGradebookAppliesNormalization() async throws {
        let initialGradebook = Gradebook(
            semesters: [
                GradebookSemester(
                    number: 1,
                    title: nil,
                    year: "2023",
                    disciplines: [
                        GradebookDiscipline(
                            code: "CS101",
                            name: "Программирование",
                            controlForm: "Экзамен",
                            teacher: nil,
                            hours: 72,
                            attempts: [
                                GradeAttempt(attempt: 1, type: "Экзамен", grade: .numeric(7), date: nil, status: .passed),
                                GradeAttempt(attempt: 2, type: "Экзамен", grade: .numeric(9), date: nil, status: .passed)
                            ]
                        )
                    ]
                ),
                GradebookSemester(
                    number: 2,
                    title: "Весенний семестр",
                    year: "2024",
                    disciplines: [
                        GradebookDiscipline(
                            code: "MA201",
                            name: "Математика",
                            controlForm: "Зачёт",
                            teacher: nil,
                            hours: 54,
                            attempts: [
                                GradeAttempt(attempt: 1, type: "Зачёт", grade: .numeric(8), date: nil, status: .passed)
                            ]
                        )
                    ]
                )
            ]
        )

        let service = GradebookAPIServiceMock(results: [.success(initialGradebook)])
        let viewModel = GradebookViewModel(apiService: service)

        await viewModel.loadGradebook(for: "12345")

        XCTAssertEqual(service.fetchCallCount, 1)
        XCTAssertEqual(service.receivedStudentIDs, ["12345"])
        XCTAssertEqual(viewModel.semesters.map(\.number), [2, 1], "Семестры должны сортироваться по убыванию номера")
        let average = try XCTUnwrap(viewModel.averageGrade)
        XCTAssertEqual(average, 8.5, accuracy: 0.001)
        XCTAssertEqual(viewModel.averageGradeText, "8,5")
        XCTAssertTrue(viewModel.hasContent)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoadWithEmptyStudentIdShowsError() async {
        let service = GradebookAPIServiceMock(results: [])
        let viewModel = GradebookViewModel(apiService: service)

        await viewModel.loadGradebook(for: "")

        XCTAssertEqual(viewModel.errorMessage, "Не указан идентификатор студента.")
        XCTAssertEqual(service.fetchCallCount, 0)
    }

    func testRefreshUsesStoredStudentId() async throws {
        let first = makeGradebook(average: 6)
        let second = makeGradebook(average: 9)
        let service = GradebookAPIServiceMock(results: [.success(first), .success(second)])
        let viewModel = GradebookViewModel(apiService: service)

        await viewModel.loadGradebook(for: "999")
        XCTAssertEqual(try XCTUnwrap(viewModel.averageGrade), 6, accuracy: 0.001)

        await viewModel.refresh()

        XCTAssertEqual(service.fetchCallCount, 2)
        XCTAssertEqual(service.receivedStudentIDs, ["999", "999"])
        XCTAssertEqual(try XCTUnwrap(viewModel.averageGrade), 9, accuracy: 0.001)
    }

    private func makeGradebook(average: Double) -> Gradebook {
        let attempt = GradeAttempt(attempt: 1, type: "Экзамен", grade: .numeric(average), date: nil, status: .passed)
        let discipline = GradebookDiscipline(
            code: UUID().uuidString,
            name: "Дисциплина",
            controlForm: "Экзамен",
            teacher: nil,
            hours: 36,
            attempts: [attempt]
        )
        let semester = GradebookSemester(number: 1, title: nil, year: nil, disciplines: [discipline])
        return Gradebook(semesters: [semester])
    }
}

private final class GradebookAPIServiceMock: APIService {
    var results: [Result<Gradebook, Error>]
    private(set) var fetchCallCount = 0
    private(set) var receivedStudentIDs: [String] = []
    private var lastResult: Result<Gradebook, Error>?

    init(results: [Result<Gradebook, Error>]) {
        self.results = results
        self.lastResult = results.last
    }

    override func getGradebook(for studentId: String) async throws -> Gradebook {
        fetchCallCount += 1
        receivedStudentIDs.append(studentId)

        let result: Result<Gradebook, Error>
        if !results.isEmpty {
            result = results.removeFirst()
            lastResult = result
        } else if let lastResult {
            result = lastResult
        } else {
            result = .failure(APIError.serverError(statusCode: 500, message: "Нет данных"))
        }

        return try result.get()
    }
}
