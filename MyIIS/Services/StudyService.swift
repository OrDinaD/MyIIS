import Foundation

protocol StudyServiceProtocol {
    func fetchStudyPlan(for group: String) async throws -> StudyPlan
}

final class StudyService: StudyServiceProtocol {
    private let apiService: APIService

    init(apiService: APIService = APIService()) {
        self.apiService = apiService
    }

    func fetchStudyPlan(for group: String) async throws -> StudyPlan {
        try await apiService.getStudyPlan(for: group)
    }
}
