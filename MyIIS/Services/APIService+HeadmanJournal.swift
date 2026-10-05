import Foundation

extension APIService {
    func getHeadmanJournalSubjects() async throws -> [String: [HeadmanJournalSubject]] {
        let request = URLRequest(url: baseURL.appendingPathComponent("headman/subjects"))
        return try await performRequest(request)
    }

    func getHeadmanJournalStudents() async throws -> [HeadmanJournalStudent] {
        let request = URLRequest(url: baseURL.appendingPathComponent("headman/students"))
        return try await performRequest(request)
    }

    func getHeadmanJournalData(termHoursID: Int) async throws -> HeadmanJournalData {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("headman/data"), resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "termHoursId", value: String(termHoursID))]
        guard let url = components?.url else { throw APIError.invalidURL }
        return try await performRequest(URLRequest(url: url))
    }

    func saveHeadmanJournalOmissions(
        lessonID: Int, omissions: [HeadmanStudentOmissionHours]
    ) async throws -> [String: HeadmanOmission] {
        var request = URLRequest(url: baseURL.appendingPathComponent("headman/create"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            HeadmanCreateOmissionRequest(studentOmissionsHoursDtoList: omissions, idLesson: lessonID)
        )
        return try await performRequest(
            request, retryPolicy: NetworkRetryPolicy(maxRetries: 0, initialDelay: 0, maxDelay: 0),
            allowSessionRecovery: false
        )
    }

    func saveHeadmanJournalTopic(lessonID: Int, topic: String) async throws -> HeadmanTopicRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent("headman/lessons/topic"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(HeadmanTopicRequest(lessonId: lessonID, topic: topic))
        return try await performRequest(
            request, retryPolicy: NetworkRetryPolicy(maxRetries: 0, initialDelay: 0, maxDelay: 0),
            allowSessionRecovery: false
        )
    }
}
