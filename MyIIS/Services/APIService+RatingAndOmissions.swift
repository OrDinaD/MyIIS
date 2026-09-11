import Foundation

extension APIService {
    func getRatingByQueryItems(_ queryItems: [URLQueryItem]) async throws -> [StudentRating] {
        var urlComponents = URLComponents(
            url: baseURL.appendingPathComponent("rating"),
            resolvingAgainstBaseURL: false
        )
        urlComponents?.queryItems = queryItems

        guard let url = urlComponents?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        logRequestDetails(request)

        let remoteRatings: [RemoteStudentRating] = try await performRequest(request)
        return remoteRatings.map { $0.toStudentRating() }
    }

    /// Заявки на пропуски по ОРВИ (ОРН)
    func getOmissionApplications() async throws -> [OmissionApplication] {
        if APIService.isDemoMode { return DemoMockData.omissionApplications }
        let endpoint = baseURL.appendingPathComponent("omissions-by-student-application")
        let request = URLRequest(url: endpoint)
        logRequestDetails(request)
        do {
            return try await performRequest(request)
        } catch let apiError as APIError {
            switch apiError {
            case .serverError(let statusCode, _) where statusCode == 404 || statusCode == 403:
                return []
            case .unauthorized:
                return []
            default:
                throw apiError
            }
        }
    }

    /// Количество пропусков студента по месяцам семестра
    func getMonthlyOmissionCounts() async throws -> [MonthlyOmissionCount] {
        if APIService.isDemoMode { return DemoMockData.monthlyOmissionCounts }
        let endpoint = baseURL.appendingPathComponent("omission-count-by-student-for-semester")
        let request = URLRequest(url: endpoint)
        logRequestDetails(request)
        return try await performRequest(request)
    }

    /// Информация о справках и пропусках по уважительной причине
    func getOmissionsByStudent(term: Int? = nil) async throws -> OmissionsByStudentResponse {
        if APIService.isDemoMode { return DemoMockData.omissionsByStudent }
        let endpoint = baseURL.appendingPathComponent("omissions-by-student")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        if let term {
            components?.queryItems = [URLQueryItem(name: "term", value: String(term))]
        }
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        let request = URLRequest(url: url)
        logRequestDetails(request)
        return try await performRequest(request)
    }
}
