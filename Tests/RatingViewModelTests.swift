import XCTest
@testable import MyIIS

@MainActor
final class RatingViewModelTests: XCTestCase {
    func testLoadRatingSortsStudentsAndBuildsSummary() async {
        let students = [
            StudentRating(
                recordBookNumber: "B2",
                studentName: "Борис",
                averageGrade: 7.5,
                missedHours: 4,
                averageShift: 0.1,
                checkpoints: [
                    RatingCheckpoint(number: 1, averageGrade: 7.5, missedHours: 2),
                    RatingCheckpoint(number: 2, averageGrade: 8.0, missedHours: nil)
                ]
            ),
            StudentRating(
                recordBookNumber: "A1",
                studentName: "Анна",
                averageGrade: 9.2,
                missedHours: 1,
                averageShift: 0.4,
                checkpoints: [
                    RatingCheckpoint(number: 1, averageGrade: 9.2, missedHours: 1),
                    RatingCheckpoint(number: 3, averageGrade: 9.0, missedHours: nil)
                ]
            )
        ]

        let service = RatingAPIServiceMock(result: .success(students))
        let viewModel = RatingViewModel(apiService: service)

        await viewModel.loadRating(forGroup: "420603")

        XCTAssertEqual(service.groupRequests, ["420603"])
        XCTAssertEqual(viewModel.students.map(\.recordBookNumber), ["A1", "B2"])
        XCTAssertEqual(viewModel.checkpointNumbers, [1, 2, 3])
        XCTAssertNotNil(viewModel.summary)
        XCTAssertEqual(viewModel.summary?.studentCount, 2)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testSubsequentLoadWithSameGroupDoesNotRefetch() async {
        let student = StudentRating(
            recordBookNumber: "S1",
            studentName: "Студент",
            averageGrade: 8.0,
            missedHours: 0,
            averageShift: nil,
            checkpoints: []
        )
        let service = RatingAPIServiceMock(result: .success([student]))
        let viewModel = RatingViewModel(apiService: service)

        await viewModel.loadRating(forGroup: "123")
        await viewModel.loadRating(forGroup: "123")

        XCTAssertEqual(service.groupRequests, ["123"])
    }

    func testRefreshForcesReloadAndHandlesError() async {
        let service = RatingAPIServiceMock(result: .failure(APIError.serviceUnavailable(message: "Недоступно")))
        let viewModel = RatingViewModel(apiService: service)

        await viewModel.refresh(forGroup: "420")

        XCTAssertEqual(service.groupRequests, ["420"])
        XCTAssertEqual(viewModel.errorMessage, "Недоступно")
        XCTAssertTrue(viewModel.students.isEmpty)
    }
}

private final class RatingAPIServiceMock: APIService {
    var result: Result<[StudentRating], Error>
    private(set) var groupRequests: [String] = []

    init(result: Result<[StudentRating], Error>) {
        self.result = result
    }

    override func getRating(group: String) async throws -> [StudentRating] {
        groupRequests.append(group)
        return try result.get()
    }
}
