import Combine
import Foundation

@MainActor
final class GlobalRatingService: ObservableObject {
    static let shared = GlobalRatingService()

    @Published var faculties: [FacultyDto] = []
    @Published var specialities: [SpecialityDto] = []
    @Published var courses: [RatingCourseDto] = []
    @Published var ratingEntries: [GlobalRatingEntry] = []
    @Published var studentDetails: [String: StudentGlobalRatingDetail] = [:]

    @Published var isLoadingFaculties = false
    @Published var isLoadingSpecialities = false
    @Published var isLoadingCourses = false
    @Published var isLoadingRating = false
    @Published var loadingStudentCardNumbers: Set<String> = []

    @Published var errorMessage: String?
    @Published var studentDetailErrorMessage: String?

    private let baseURL = URLFactory.require("https://iis.bsuir.by/api/v1")
    private let session: URLSession
    private let decoder = JSONDecoder()

    private init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchFaculties() async {
        isLoadingFaculties = true
        errorMessage = nil
        defer { isLoadingFaculties = false }

        do {
            let response: [FacultyDto] = try await performGet(path: ["schedule", "faculties"])
            faculties = response.sorted { $0.text.localizedCaseInsensitiveCompare($1.text) == .orderedAscending }
        } catch is CancellationError {
            return
        } catch {
            faculties = []
            errorMessage = userFacingMessage(for: error)
        }
    }

    func fetchSpecialities(facultyId: Int) async {
        isLoadingSpecialities = true
        errorMessage = nil
        specialities = []
        courses = []
        ratingEntries = []
        defer { isLoadingSpecialities = false }

        do {
            let response: [SpecialityDto] = try await performGet(
                path: ["rating", "specialities"],
                queryItems: [URLQueryItem(name: "facultyId", value: String(facultyId))]
            )
            specialities = response.sorted { $0.text.localizedCaseInsensitiveCompare($1.text) == .orderedAscending }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    func fetchCourses(facultyId: Int, specialityId: Int) async {
        isLoadingCourses = true
        errorMessage = nil
        courses = []
        ratingEntries = []
        defer { isLoadingCourses = false }

        do {
            let response: [RatingCourseDto] = try await performGet(
                path: ["rating", "courses"],
                queryItems: [
                    URLQueryItem(name: "facultyId", value: String(facultyId)),
                    URLQueryItem(name: "specialityId", value: String(specialityId))
                ]
            )
            courses = response.sorted { $0.course < $1.course }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    func fetchRating(sdefId: Int, course: Int) async {
        isLoadingRating = true
        errorMessage = nil
        ratingEntries = []
        defer { isLoadingRating = false }

        do {
            let response: [GlobalRatingEntry] = try await performGet(
                path: ["rating"],
                queryItems: [
                    URLQueryItem(name: "sdef", value: String(sdefId)),
                    URLQueryItem(name: "course", value: String(course))
                ]
            )
            ratingEntries = response.sorted {
                if ($0.average ?? 0) != ($1.average ?? 0) {
                    return ($0.average ?? 0) > ($1.average ?? 0)
                }
                return $0.studentCardNumber < $1.studentCardNumber
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    func fetchStudentDetail(studentCardNumber: String) async {
        if studentDetails[studentCardNumber] != nil { return }

        loadingStudentCardNumbers.insert(studentCardNumber)
        studentDetailErrorMessage = nil
        defer { loadingStudentCardNumbers.remove(studentCardNumber) }

        do {
            let response: StudentGlobalRatingDetail = try await performGet(
                path: ["rating", "studentRating"],
                queryItems: [URLQueryItem(name: "studentCardNumber", value: studentCardNumber)]
            )
            studentDetails[studentCardNumber] = response
        } catch is CancellationError {
            return
        } catch {
            studentDetailErrorMessage = userFacingMessage(for: error)
        }
    }

    func resetAfterFacultyClear() {
        specialities = []
        courses = []
        ratingEntries = []
        errorMessage = nil
    }

    func resetAfterSpecialityClear() {
        courses = []
        ratingEntries = []
        errorMessage = nil
    }

    func resetRating() {
        ratingEntries = []
        errorMessage = nil
    }

    private func performGet<T: Decodable>(
        path: [String],
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        var endpoint = baseURL
        for component in path {
            endpoint.appendPathComponent(component)
        }

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw GlobalRatingServiceError.server(statusCode: httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw GlobalRatingServiceError.decoding(error)
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        switch error {
        case let serviceError as GlobalRatingServiceError:
            return serviceError.localizedDescription
        case let urlError as URLError where urlError.code == .notConnectedToInternet:
            return "Нет подключения к интернету. Проверьте сеть и повторите попытку."
        case let urlError as URLError where urlError.code == .timedOut:
            return "Сервер не ответил вовремя. Попробуйте ещё раз."
        default:
            return "Не удалось загрузить данные IIS. Попробуйте ещё раз."
        }
    }
}

private enum GlobalRatingServiceError: LocalizedError {
    case server(statusCode: Int)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .server(let statusCode):
            return "Сервер IIS вернул ошибку \(statusCode)."
        case .decoding:
            return "Ответ IIS имеет неожиданный формат."
        }
    }
}
