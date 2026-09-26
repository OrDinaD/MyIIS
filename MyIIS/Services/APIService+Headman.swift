import Foundation

extension APIService {
    func getHeadmanIsGroupHead() async throws -> Bool {
        let endpoint = baseURL
            .appendingPathComponent("grade-book")
            .appendingPathComponent("is-group-head")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        logRequestDetails(request)

        return try await performRequest(request)
    }

    func getHeadmanWhoCanNote() async throws -> [Int] {
        let endpoint = baseURL
            .appendingPathComponent("grade-book")
            .appendingPathComponent("who-can-note")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        logRequestDetails(request)

        return try await performRequest(request)
    }

    func getHeadmanGroupStudents() async throws -> [HeadmanStudent] {
        let endpoint = baseURL
            .appendingPathComponent("grade-book")
            .appendingPathComponent("group-students")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        logRequestDetails(request)

        return try await performRequest(request)
    }

    func getHeadmanSubjects() async throws -> [String: [HeadmanSubjectLesson]] {
        let endpoint = baseURL
            .appendingPathComponent("grade-book")
            .appendingPathComponent("subjects")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        logRequestDetails(request)

        return try await performRequest(request)
    }

    func getHeadmanLessonsByDate(_ date: Date) async throws -> [HeadmanLesson] {
        var urlComponents = URLComponents(
            url: baseURL
                .appendingPathComponent("grade-book")
                .appendingPathComponent("by-date"),
            resolvingAgainstBaseURL: false
        )
        urlComponents?.queryItems = [
            URLQueryItem(name: "date", value: Self.headmanDateFormatter.string(from: date))
        ]

        guard let url = urlComponents?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        logRequestDetails(request)

        let response: HeadmanLessonsByDateResponse = try await performRequest(request)
        return response.lessons
    }

    func getHeadmanSummary(subjectId: Int, subgroup: Int) async throws -> [HeadmanSummaryStudent] {
        let endpoint = baseURL
            .appendingPathComponent("grade-book")
            .appendingPathComponent(String(subjectId))
            .appendingPathComponent(String(subgroup))

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        logRequestDetails(request)

        let response: [HeadmanSummaryResponse] = try await performRequest(request)
        return response.first?.students ?? []
    }

    @discardableResult
    func createHeadmanOmissions(lessonId: Int, omissions: [HeadmanStudentOmissionHours]) async throws -> [HeadmanLessonStudent] {
        let endpoint = baseURL
            .appendingPathComponent("grade-book")
            .appendingPathComponent("create")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            HeadmanCreateOmissionRequest(
                studentOmissionsHoursDtoList: omissions,
                idLesson: lessonId
            )
        )
        logRequestDetails(request)

        return try await performRequest(request)
    }

    func assignHeadmanResponsible(studentId: Int) async throws {
        let endpoint = baseURL
            .appendingPathComponent("grade-book")
            .appendingPathComponent("assign-responsible")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            HeadmanAssignResponsibleRequest(studentIds: [studentId], studentFlags: [true])
        )
        logRequestDetails(request)

        try await performEmptyRequest(request)
    }

    func removeHeadmanResponsible(studentId: Int) async throws {
        let endpoint = baseURL
            .appendingPathComponent("grade-book")
            .appendingPathComponent("remove-responsible")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([studentId])
        logRequestDetails(request)

        try await performEmptyRequest(request)
    }

    private static let headmanDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
