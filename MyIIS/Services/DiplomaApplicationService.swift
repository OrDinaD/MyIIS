import Foundation

protocol DiplomaApplicationServicing {
    func fetchContext() async throws -> DiplomaContext
    func searchSupervisors(query: String, includeExternal: Bool) async throws -> [DiplomaSupervisor]
    func fetchEmployeeTopics(employeeId: Int) async throws -> [DiplomaEmployeeTopic]
    func submitApplication(_ payload: DiplomaApplicationPayload) async throws -> DiplomaApplication
    func deleteApplication(id: Int) async throws
    func downloadApplication(for application: DiplomaApplication) async throws -> URL
}

final class DiplomaApplicationService: DiplomaApplicationServicing {
    private let baseURL: URL
    private let session: URLSession
    private let logService: LogService
    private let userDefaults = UserDefaults.standard

    private static let cachePrefix = "DiplomaApplicationService.cache."

    private struct CachedEnvelope: Codable {
        let data: Data
        let cachedAt: Date
    }

    init(
        baseURL: URL = URLFactory.require("https://iis.bsuir.by/api/v1"),
        session: URLSession = .shared,
        logService: LogService = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        self.logService = logService
    }

    func fetchContext() async throws -> DiplomaContext {
        async let personalInformation: DiplomaPersonalInformation = fetchPersonalInformation()
        async let applications: [DiplomaApplication] = fetchApplications()
        return try await DiplomaContext(
            personalInformation: personalInformation,
            applications: applications
        )
    }

    func searchSupervisors(query: String, includeExternal: Bool) async throws -> [DiplomaSupervisor] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            return []
        }

        async let employees = fetchEmployees(query: trimmedQuery)

        if includeExternal {
            async let externalManagers = fetchExternalManagers(query: trimmedQuery)
            let (employeeResults, externalResults) = try await (employees, externalManagers)
            return employeeResults.map(DiplomaSupervisor.employee)
                + externalResults.map(DiplomaSupervisor.external)
        }

        let employeeResults = try await employees
        return employeeResults.map(DiplomaSupervisor.employee)
    }

    func fetchEmployeeTopics(employeeId: Int) async throws -> [DiplomaEmployeeTopic] {
        var components = URLComponents(
            url: baseURL
                .appendingPathComponent("diploma-topic-suggestion")
                .appendingPathComponent("employee-topics"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "employeeId", value: String(employeeId))
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        return try await performDecodableRequest(URLRequest(url: url))
    }

    func submitApplication(_ payload: DiplomaApplicationPayload) async throws -> DiplomaApplication {
        let endpoint = baseURL
            .appendingPathComponent("diploma-topic-suggestion")
            .appendingPathComponent("add")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        return try await performDecodableRequest(request)
    }

    func deleteApplication(id: Int) async throws {
        var components = URLComponents(
            url: baseURL
                .appendingPathComponent("diploma-topic-suggestion")
                .appendingPathComponent("delete"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "id", value: String(id))
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        _ = try await performDataRequest(request)
    }

    func downloadApplication(for application: DiplomaApplication) async throws -> URL {
        let endpoint = baseURL
            .appendingPathComponent("diploma")
            .appendingPathComponent("generate-application")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)

        let data = try await performDataRequest(request)
        let fileName = "Заявление_\(application.id).docx"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: outputURL, options: .atomic)
        return outputURL
    }

    private func fetchPersonalInformation() async throws -> DiplomaPersonalInformation {
        let request = URLRequest(url: baseURL.appendingPathComponent("personal-information"))
        return try await performDecodableRequest(request)
    }

    private func fetchApplications() async throws -> [DiplomaApplication] {
        let endpoint = baseURL
            .appendingPathComponent("diploma-topic-suggestion")
            .appendingPathComponent("topics")
        return try await performDecodableRequest(URLRequest(url: endpoint))
    }

    private func fetchEmployees(query: String) async throws -> [DiplomaEmployee] {
        var components = URLComponents(
            url: baseURL
                .appendingPathComponent("employees")
                .appendingPathComponent("fio")
                .appendingPathComponent("requests"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "employee-fio", value: query)
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        return try await performDecodableRequest(URLRequest(url: url))
    }

    private func fetchExternalManagers(query: String) async throws -> [DiplomaExternalManager] {
        var components = URLComponents(
            url: baseURL
                .appendingPathComponent("externalManagers")
                .appendingPathComponent("fio"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "external-manager-fio", value: query)
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        return try await performDecodableRequest(URLRequest(url: url))
    }

    private func performDecodableRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data = try await performDataRequest(request)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func performDataRequest(_ request: URLRequest) async throws -> Data {
        logRequest(request)

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200 ... 299:
                persistCache(data: data, for: request)
                return data
            case 401, 403:
                throw APIError.unauthorized(message: decodeErrorMessage(from: data) ?? "Сессия истекла. Войдите заново.")
            case 418, 503:
                throw APIError.serviceUnavailable(message: decodeErrorMessage(from: data) ?? "Сервис временно недоступен")
            default:
                throw APIError.serverError(
                    statusCode: httpResponse.statusCode,
                    message: decodeErrorMessage(from: data) ?? "Ошибка сервера"
                )
            }
        } catch let apiError as APIError {
            if case .unauthorized = apiError {
                AuthenticationSessionEvents.reportUnauthorized()
            }
            if let cached = tryDecodeCachedData(for: request, originalError: apiError.localizedDescription) {
                return cached
            }
            throw apiError
        } catch {
            if let cached = tryDecodeCachedData(for: request, originalError: error.localizedDescription) {
                return cached
            }
            throw APIError.networkError(error)
        }
    }

    private func persistCache(data: Data, for request: URLRequest) {
        guard shouldCache(request), let key = cacheKey(for: request) else { return }
        let envelope = CachedEnvelope(data: data, cachedAt: Date())
        guard let payload = try? JSONEncoder().encode(envelope) else { return }
        _ = UserDefaultsPayloadStore.save(payload, forKey: key, in: userDefaults)
    }

    private func tryDecodeCachedData(for request: URLRequest, originalError: String) -> Data? {
        guard shouldCache(request),
              let key = cacheKey(for: request),
              let payload = UserDefaultsPayloadStore.load(forKey: key, from: userDefaults),
              let envelope = try? JSONDecoder().decode(CachedEnvelope.self, from: payload) else {
            return nil
        }

        let url = request.url?.absoluteString ?? "—"
        logService.log("⚠️ Diploma endpoints offline cache used for \(url). Original error: \(originalError)")
        return envelope.data
    }

    private func shouldCache(_ request: URLRequest) -> Bool {
        let method = request.httpMethod?.uppercased() ?? "GET"
        return method == "GET"
    }

    private func cacheKey(for request: URLRequest) -> String? {
        guard let url = request.url?.absoluteString else { return nil }
        let method = request.httpMethod?.uppercased() ?? "GET"
        let composite = "\(method)|\(url)"
        return Self.cachePrefix + Data(composite.utf8).base64EncodedString()
    }

    private func logRequest(_ request: URLRequest) {
        logService.log("Diploma endpoint request: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")
    }

    private func decodeErrorMessage(from data: Data) -> String? {
        guard !data.isEmpty else {
            return nil
        }
        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            return errorResponse.msg
        }
        return String(data: data, encoding: .utf8)
    }
}
