import Foundation

// MARK: - API Service

class APIService {

    static var isDemoMode = false
    static let demoUsername = "demo"
    static let demoPassword = "demo"

    let baseURL = URLFactory.require("https://iis.bsuir.by/api/v1")
    private let session: URLSession
    private let logService = LogService.shared
    private let userDefaults = UserDefaults.standard

    init(session: URLSession = APIService.createOptimizedSession()) {
        self.session = session
    }

    static func createOptimizedSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 20.0
        config.timeoutIntervalForResource = 60.0
        config.httpMaximumConnectionsPerHost = 8

        let cache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 100 * 1024 * 1024,
            directory: nil
        )
        config.urlCache = cache
        config.requestCachePolicy = .useProtocolCachePolicy
        return URLSession(configuration: config)
    }

    private static let responseCachePrefix = "APIService.responseCache."
    private static let responseCacheLifetime: TimeInterval = 24 * 60 * 60

    private struct CachedResponseEnvelope: Codable {
        let data: Data
        let cachedAt: Date
    }

    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func resetDemoMode() {
        isDemoMode = false
    }

    static func clearResponseCache(in defaults: UserDefaults = .standard) {
        UserDefaultsPayloadStore.clear(prefix: responseCachePrefix, from: defaults)
    }

    /// Аутентификация пользователя
    /// - Parameters:
    ///   - username: Логин пользователя
    ///   - password: Пароль пользователя
    /// - Returns: LoginResponse с данными пользователя
    func login(username: String, password: String) async throws -> LoginResponse {
        if username == Self.demoUsername && password == Self.demoPassword {
            APIService.isDemoMode = true
            return DemoMockData.loginResponse
        }
        APIService.isDemoMode = false

        let endpoint = baseURL.appendingPathComponent("auth").appendingPathComponent("login")
        let loginRequest = LoginRequest(username: username, password: password)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(loginRequest)

        logRequestDetails(request)

        return try await performRequest(request)
    }

    /// Получение профиля пользователя через endpoint из веб-версии IIS.
    /// Требует SESSION cookie (автоматически отправляется после логина).
    func getPersonalProfile() async throws -> PersonalProfile {
        if APIService.isDemoMode { return DemoMockData.personalProfile }
        let endpoint = baseURL
            .appendingPathComponent("profiles")
            .appendingPathComponent("personal-profile")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        logRequestDetails(request)

        return try await performRequest(request)
    }

    /// Получение информации о факультете и специальности из расписания группы
    /// - Parameter group: Номер группы (например, "420603")
    /// - Returns: ScheduleInfo с данными о факультете и специальности
    func getScheduleInfo(group: String) async throws -> ScheduleInfo? {
        if APIService.isDemoMode { return DemoMockData.scheduleInfo }
        // Добавляем query параметр studentGroup
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("schedule"), resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = [
            URLQueryItem(name: "studentGroup", value: group)
        ]

        guard let url = urlComponents?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        logRequestDetails(request)

        let scheduleResponse: ScheduleResponse = try await performRequest(request)

        // Преобразуем в упрощённую структуру
        guard let dto = scheduleResponse.studentGroupDto else {
            return nil
        }

        return ScheduleInfo(
            facultyAbbrev: dto.facultyAbbrev,
            facultyName: dto.facultyName,
            specialityAbbrev: dto.specialityAbbrev,
            specialityName: dto.specialityName,
            course: dto.course,
            specialityDepartmentEducationFormId: dto.specialityDepartmentEducationFormId,
            studentGroupId: dto.id,
            educationDegree: dto.educationDegree
        )
    }

    /// Получение полного учебного плана группы со списком дисциплин и расписанием
    /// - Parameter group: Номер учебной группы
    /// - Returns: Структура StudyPlan с данными расписания
    func getStudyPlan(for group: String) async throws -> StudyPlan {
        if APIService.isDemoMode { return DemoMockData.studyPlan }
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("schedule"), resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = [
            URLQueryItem(name: "studentGroup", value: group)
        ]

        guard let url = urlComponents?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        logRequestDetails(request)

        return try await performRequest(request)
    }

    /// Получение информации о группе пользователя:
    /// номер группы, куратор и список студентов.
    func getUserGroupInfo() async throws -> UserGroupInfoResponse {
        if APIService.isDemoMode { return DemoMockData.userGroupInfo }
        let endpoint = baseURL
            .appendingPathComponent("student-groups")
            .appendingPathComponent("user-group-info")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        logRequestDetails(request)

        return try await performRequest(request)
    }

    /// Скачивает Excel-отчёт со списком группы и возвращает локальный URL файла.
    func downloadGroupListReport() async throws -> URL {
        if APIService.isDemoMode {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("group-list.xlsx")
            try? Data().write(to: url)
            return url
        }
        let endpoint = baseURL
            .appendingPathComponent("group-list")
            .appendingPathComponent("get-report")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/vnd.ms-excel", forHTTPHeaderField: "Accept")

        logRequestDetails(request)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            logService.log("Status Code: \(httpResponse.statusCode)")

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                throw APIError.serverError(
                    statusCode: httpResponse.statusCode,
                    message: NSLocalizedString("api_error_server", value: "Ошибка сервера", comment: "")
                )
            }

            let suggestedName = httpResponse.value(forHTTPHeaderField: "Content-Disposition")
                .flatMap(Self.filenameFromContentDisposition(_:))
                ?? "group-list.xlsx"

            let temporaryURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(suggestedName)

            try data.write(to: temporaryURL, options: [.atomic])
            return temporaryURL
        } catch let apiError as APIError {
            throw apiError
        } catch {
            throw APIError.networkError(error)
        }
    }

    /// Получение зачётной книжки (как на web: /markbook)
    func getMarkbook() async throws -> MarkbookResponse {
        if APIService.isDemoMode { return DemoMockData.markbookResponse }
        let endpoint = baseURL.appendingPathComponent("markbook")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        logRequestDetails(request)

        return try await performRequest(request)
    }

    /// Получение зачётной книжки студента по legacy endpoint.
    func getGradebook(for studentId: String) async throws -> Gradebook {
        if APIService.isDemoMode { return DemoMockData.gradebook }
        let endpoint = baseURL
            .appendingPathComponent("gradebook")
            .appendingPathComponent(studentId)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        logRequestDetails(request)

        let gradebook: Gradebook = try await performRequest(request)
        return gradebook.normalized()
    }

    /// Данные рейтинга по предметам из веб-вкладки "Рейтинг".
    /// Используется как основной источник предметов/оценок вместо /gradebook/{id},
    /// потому что для части аккаунтов этот endpoint стабильно возвращает 404.
    func getPortalGradeBookLessons() async throws -> [PortalGradeBookLesson] {
        if APIService.isDemoMode { return DemoMockData.portalGradeBookLessons }
        let endpoint = baseURL.appendingPathComponent("grade-book")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        logRequestDetails(request)

        let response: [PortalGradeBookEntry] = try await performRequest(request)
        return response
            .compactMap { $0.student }
            .flatMap { $0.lessons }
    }

    func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        try await performRequest(request)
    }

    func performRequest<T: Decodable>(_ request: URLRequest, retryPolicy: NetworkRetryPolicy = .default) async throws -> T {
        var attempt = 0
        while true {
            do {
                return try await performSingleRequest(request)
            } catch {
                attempt += 1
                if attempt <= retryPolicy.maxRetries && retryPolicy.shouldRetry(error: error) {
                    let delay = retryPolicy.delay(forAttempt: attempt)
                    let errMessage = error.localizedDescription
                    logService.log("⚠️ Request failed (\(errMessage)). Retrying attempt \(attempt)/\(retryPolicy.maxRetries) in \(String(format: "%.2f", delay))s...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }

                if let cached: T = tryDecodeCachedResponse(for: request, originalErrorDescription: error.localizedDescription) {
                    return cached
                }
                throw error
            }
        }
    }

    private func performSingleRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            logResponse(data, response)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            try handleStatusCode(httpResponse.statusCode, data: data)
            persistCache(data: data, for: request)
            return try decode(data)
        } catch let apiError as APIError {
            throw apiError
        } catch {
            if isCancellationError(error) {
                throw CancellationError()
            }
            logTransportFailure(error, request: request)
            throw APIError.networkError(error)
        }
    }

    func performEmptyRequest(_ request: URLRequest) async throws {
        do {
            let (data, response) = try await session.data(for: request)
            logResponse(data, response)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            try handleStatusCode(httpResponse.statusCode, data: data)
        } catch let apiError as APIError {
            throw apiError
        } catch {
            if isCancellationError(error) {
                throw CancellationError()
            }
            logTransportFailure(error, request: request)
            throw APIError.networkError(error)
        }
    }

    private func logResponse(_ data: Data, _ response: URLResponse) {
        if let httpResponse = response as? HTTPURLResponse {
            logService.log("Response: HTTP \(httpResponse.statusCode), \(data.count) bytes")
        } else {
            logService.log("Response: \(type(of: response)), \(data.count) bytes")
        }
    }

    private func logTransportFailure(_ error: Error, request: URLRequest) {
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "—"
        logService.log("❌ Transport error for \(method) \(url)")

        if let urlError = error as? URLError {
            logService.log("URLError: \(urlError.code.rawValue) (\(urlError.code))")
            if let failingURL = urlError.failingURL {
                logService.log("Failing URL: \(failingURL.absoluteString)")
            }
            return
        }

        let nsError = error as NSError
        logService.log("NSError domain/code: \(nsError.domain) / \(nsError.code)")
    }

    private func isCancellationError(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return Task.isCancelled
    }

    func handleStatusCode(_ statusCode: Int, data: Data) throws {
        guard !(200 ... 299).contains(statusCode) else { return }

        let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
        let message = errorResponse?.msg

        switch statusCode {
        case 401:
            logService.log("❌ 401 Unauthorized: \(message ?? "nil")")
            throw APIError.unauthorized(
                message: message ?? NSLocalizedString(
                    "api_error_bad_credentials",
                    value: "Неверный логин или пароль",
                    comment: ""
                )
            )
        case 418:
            logService.log("❌ 418 IIS Unavailable: \(message ?? "nil")")
            throw APIError.serviceUnavailable(
                message: message ?? NSLocalizedString(
                    "api_error_iis_unavailable",
                    value: "Сервис ИИС недоступен",
                    comment: ""
                )
            )
        default:
            logService.log("❌ Server Error \(statusCode): \(message ?? "nil")")
            throw APIError.serverError(
                statusCode: statusCode,
                message: message ?? NSLocalizedString("api_error_server", value: "Ошибка сервера", comment: "")
            )
        }
    }

    private func persistCache(data: Data, for request: URLRequest) {
        guard shouldCache(request) else { return }
        guard let key = cacheKey(for: request) else { return }

        let envelope = CachedResponseEnvelope(data: data, cachedAt: Date())
        guard let payload = try? JSONEncoder().encode(envelope) else { return }

        _ = UserDefaultsPayloadStore.save(payload, forKey: key, in: userDefaults)
    }

    private func tryDecodeCachedResponse<T: Decodable>(for request: URLRequest, originalErrorDescription: String) -> T? {
        guard shouldCache(request) else { return nil }
        guard let key = cacheKey(for: request) else { return nil }
        guard let payload = UserDefaultsPayloadStore.load(forKey: key, from: userDefaults) else { return nil }
        guard let envelope = try? JSONDecoder().decode(CachedResponseEnvelope.self, from: payload) else { return nil }

        guard Date().timeIntervalSince(envelope.cachedAt) <= Self.responseCacheLifetime else {
            userDefaults.removeObject(forKey: key)
            return nil
        }

        do {
            let decoded: T = try decode(envelope.data)
            let method = request.httpMethod ?? "GET"
            let url = request.url?.absoluteString ?? "—"
            logService.log("⚠️ Using offline cache for \(method) \(url). Original error: \(originalErrorDescription)")
            return decoded
        } catch {
            return nil
        }
    }

    private func shouldCache(_ request: URLRequest) -> Bool {
        let method = request.httpMethod?.uppercased() ?? "GET"
        guard method == "GET" else { return false }
        guard let url = request.url else { return false }

        // Keep the generic API cache narrow. Authenticated/student endpoints
        // can contain personal data and should use explicit feature-level caches.
        return url.path.hasSuffix("/api/v1/schedule")
    }

    private func cacheKey(for request: URLRequest) -> String? {
        guard let url = request.url?.absoluteString else { return nil }
        let method = request.httpMethod?.uppercased() ?? "GET"
        let composite = "\(method)|\(url)"
        let encoded = Data(composite.utf8).base64EncodedString()
        return Self.responseCachePrefix + encoded
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            logService.log("❌ Decoding Error: \(error)")
            throw APIError.decodingError(error)
        }
    }

}

extension APIService {
    static func filenameFromContentDisposition(_ contentDisposition: String) -> String? {
        let lowercased = contentDisposition.lowercased()
        guard let range = lowercased.range(of: "filename*=") else { return nil }
        let raw = contentDisposition[range.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let utf8Range = raw.range(of: "''") {
            let encodedName = String(raw[utf8Range.upperBound...])
            let cleaned = encodedName.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            return cleaned.removingPercentEncoding
        }

        return String(raw).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }

    func logRequestDetails(_ request: URLRequest) {
        logService.log("--- New Request ---")
        if let url = request.url?.absoluteString { logService.log("URL: \(url)") }
        if let method = request.httpMethod { logService.log("Method: \(method)") }
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            let sensitiveHeaderKeys: Set<String> = ["cookie", "authorization", "set-cookie", "x-auth-token"]
            var sanitizedHeaders: [String: String] = [:]
            for (key, value) in headers {
                if sensitiveHeaderKeys.contains(key.lowercased()) {
                    sanitizedHeaders[key] = "[REDACTED]"
                } else {
                    sanitizedHeaders[key] = value
                }
            }
            logService.log("Headers: \(sanitizedHeaders)")
        }

        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            let lowercased = bodyString.lowercased()
            let containsSensitiveData = lowercased.contains("password") || lowercased.contains("token") || lowercased.contains("secret")
            let sanitizedBody = containsSensitiveData ? "[REDACTED]" : bodyString
            logService.log("Body: \(sanitizedBody)")
        }
        logService.log("------------------")
    }
}
