import Foundation

protocol StudyServiceProtocol {
    func fetchDashboard() async throws -> StudyDashboard
    func fetchEmployees(for lessonType: MarkSheetLessonType) async throws -> [MarkSheetEmployee]
    func orderMarkSheet(_ request: MarkSheetOrderRequest) async throws -> MarkSheetRequest
    func cancelMarkSheetRequest(id: Int) async throws -> MarkSheetRequest
    func orderCertificate(_ request: CertificateRegisterRequest) async throws -> [CertificateRequest]
    func cancelCertificateRequest(id: Int) async throws -> CertificateRequest
}

final class StudyService: StudyServiceProtocol {
    private let baseURL = URLFactory.require("https://iis.bsuir.by/api/v1")
    private let apiService: APIService
    private let logService: LogService

    init(apiService: APIService = APIService(), logService: LogService = .shared) {
        self.apiService = apiService
        self.logService = logService
    }

    func fetchDashboard() async throws -> StudyDashboard {
        async let markSheetsResult: SectionLoadResult<[MarkSheetRequest]> = loadSection(path: "mark-sheet", fallback: [])
        async let markSheetTypesResult: SectionLoadResult<[MarkSheetType]> = loadSection(path: "mark-sheet/types", fallback: [])
        async let markSheetSubjectsResult: SectionLoadResult<[MarkSheetSubject]> = loadSection(path: "mark-sheet/subjects", fallback: [])
        async let certificatesResult: SectionLoadResult<[CertificateRequest]> = loadSection(path: "certificate", fallback: [])
        async let certificatePlacesResult: SectionLoadResult<[CertificatePlaceSection]> = loadSection(path: "certificate/places", fallback: [])
        async let lmsApplicationsResult: SectionLoadResult<[LMSApplication]> = loadSection(path: "lms/application-history", fallback: [])

        let markSheetsStatus = await markSheetsResult.status
        let markSheetTypesStatus = await markSheetTypesResult.status
        let markSheetSubjectsStatus = await markSheetSubjectsResult.status
        let certificatesStatus = await certificatesResult.status
        let certificatePlacesStatus = await certificatePlacesResult.status
        let lmsApplicationsStatus = await lmsApplicationsResult.status

        let results: [SectionStatus] = [
            markSheetsStatus,
            markSheetTypesStatus,
            markSheetSubjectsStatus,
            certificatesStatus,
            certificatePlacesStatus,
            lmsApplicationsStatus
        ]

        if results.allSatisfy({ $0.error != nil }), let firstError = results.compactMap(\.error).first {
            throw firstError
        }

        return await StudyDashboard(
            markSheets: markSheetsResult.value,
            markSheetTypes: markSheetTypesResult.value,
            markSheetSubjects: markSheetSubjectsResult.value,
            certificates: certificatesResult.value,
            certificatePlaceSections: certificatePlacesResult.value,
            lmsApplications: lmsApplicationsResult.value
        )
    }

    func fetchEmployees(for lessonType: MarkSheetLessonType) async throws -> [MarkSheetEmployee] {
        var components = URLComponents(url: baseURL.appendingPathComponent("employees/mark-sheet"), resolvingAgainstBaseURL: false)
        if let thId = lessonType.thId {
            components?.queryItems = [URLQueryItem(name: "thId", value: String(thId))]
        } else if let focsId = lessonType.focsId {
            components?.queryItems = [URLQueryItem(name: "focsId", value: String(focsId))]
        } else {
            throw APIError.invalidURL
        }

        guard let url = components?.url else { throw APIError.invalidURL }
        return try await apiService.execute(makeRequest(url: url))
    }

    func orderMarkSheet(_ request: MarkSheetOrderRequest) async throws -> MarkSheetRequest {
        try await apiService.execute(makeRequest(path: "mark-sheet", method: "POST", body: request))
    }

    func cancelMarkSheetRequest(id: Int) async throws -> MarkSheetRequest {
        try await apiService.execute(makeRequest(path: "mark-sheet/close", queryItems: [URLQueryItem(name: "id", value: String(id))]))
    }

    func orderCertificate(_ request: CertificateRegisterRequest) async throws -> [CertificateRequest] {
        try await apiService.execute(makeRequest(path: "certificate/register", method: "POST", body: request))
    }

    func cancelCertificateRequest(id: Int) async throws -> CertificateRequest {
        try await apiService.execute(makeRequest(path: "certificate/close", queryItems: [URLQueryItem(name: "id", value: String(id))]))
    }

    private func makeRequest(path: String, queryItems: [URLQueryItem]? = nil) -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems
        let url = components?.url ?? baseURL.appendingPathComponent(path)
        return makeRequest(url: url)
    }

    private func makeRequest<Body: Encodable>(path: String, method: String, body: Body) throws -> URLRequest {
        var request = makeRequest(path: path)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://iis.bsuir.by/personal-account/study", forHTTPHeaderField: "Referer")
        return request
    }
}

private extension StudyService {
    struct SectionLoadResult<Value> {
        let path: String
        let value: Value
        let error: Error?

        var status: SectionStatus {
            SectionStatus(path: path, error: error)
        }
    }

    struct SectionStatus {
        let path: String
        let error: Error?
    }

    func loadSection<T: Decodable>(path: String, fallback: T) async -> SectionLoadResult<T> {
        do {
            let value: T = try await apiService.execute(makeRequest(path: path))
            return SectionLoadResult(path: path, value: value, error: nil)
        } catch {
            logService.log("⚠️ Study section fallback for \(path): \(error.localizedDescription)")
            return SectionLoadResult(path: path, value: fallback, error: error)
        }
    }
}
