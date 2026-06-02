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
        let endpoint = baseURL.appendingPathComponent("omissions-by-student-application")
        let request = URLRequest(url: endpoint)
        logRequestDetails(request)
        return try await performRequest(request)
    }

    /// Количество пропусков студента по месяцам семестра
    func getMonthlyOmissionCounts() async throws -> [MonthlyOmissionCount] {
        let endpoint = baseURL.appendingPathComponent("omission-count-by-student-for-semester")
        let request = URLRequest(url: endpoint)
        logRequestDetails(request)
        return try await performRequest(request)
    }

    /// Информация о справках и пропусках по уважительной причине
    func getOmissionsByStudent() async throws -> OmissionsByStudentResponse {
        let endpoint = baseURL.appendingPathComponent("omissions-by-student")
        let request = URLRequest(url: endpoint)
        logRequestDetails(request)
        return try await performRequest(request)
    }
}
