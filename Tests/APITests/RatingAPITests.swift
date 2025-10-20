import XCTest
@testable import MyIIS

final class RatingAPITests: XCTestCase {

    func testFetchRatingForAuthenticatedGroup() async throws {
        let environment = ProcessInfo.processInfo.environment

        guard
            let username = environment["IIS_USERNAME"],
            let password = environment["IIS_PASSWORD"],
            !username.isEmpty,
            !password.isEmpty
        else {
            throw XCTSkip("Set IIS_USERNAME and IIS_PASSWORD to run rating API integration tests.")
        }

        let apiService = APIService()
        let loginResponse = try await apiService.login(username: username, password: password)

        let ratings = try await apiService.getRating(group: loginResponse.group)

        XCTAssertFalse(ratings.isEmpty, "Rating list should not be empty for an active group.")

        guard let first = ratings.first else { return }
        XCTAssertFalse(first.recordBookNumber.isEmpty, "Record book number should be present.")
        XCTAssertGreaterThanOrEqual(first.checkpoints.count, 1, "Expected at least one checkpoint value.")
    }
}
