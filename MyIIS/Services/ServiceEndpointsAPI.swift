import Foundation

final class ServiceEndpointsAPI {
    private let baseURL: URL
    private let session: URLSession
    private let gatewaySession: URLSession
    private let gatewayHealth: ScheduleGatewayHealth
    private let logService: LogService
    private let userDefaults: UserDefaults
    private let now: () -> Date

    private static let cachePrefix = "ServiceEndpointsAPI.cache."
    private static let responseCacheLifetime: TimeInterval = 24 * 60 * 60
    private static let currentWeekCacheLifetime: TimeInterval = 60 * 60

    init(
        baseURL: URL = URLFactory.require("https://iis.bsuir.by/api/v1"),
        session: URLSession = .shared,
        gatewaySession: URLSession? = nil,
        gatewayHealth: ScheduleGatewayHealth = .shared,
        logService: LogService = .shared,
        userDefaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.baseURL = baseURL
        self.session = session
        self.gatewaySession = gatewaySession ?? (session === URLSession.shared ? ScheduleGatewaySession.shared : session)
        self.gatewayHealth = gatewayHealth
        self.logService = logService
        self.userDefaults = userDefaults
        self.now = now
    }

    static func clearResponseCache(
        in defaults: UserDefaults = .standard
    ) {
        UserDefaultsPayloadStore.clear(prefix: cachePrefix, from: defaults)
    }

    func fetchLibraryBooks() async throws -> [ServiceJSONObject] {
        do {
            return try await decodeJSONArray(path: "library/books")
        } catch let APIError.serverError(statusCode, _) where statusCode == 404 {
            return []
        }
    }

    func fetchLibraryNews() async throws -> [LibraryNewsEntry] {
        return []
    }

    func fetchAnnouncements(groupNumber: String? = nil) async throws -> [ServiceJSONObject] {
        guard let groupNumber = groupNumber?.trimmingCharacters(in: .whitespacesAndNewlines),
              !groupNumber.isEmpty else {
            return []
        }
        return try await decodeJSONArray(
            path: "announcements/student-groups",
            queryItems: [URLQueryItem(name: "name", value: groupNumber)]
        )
    }

    func fetchPenalties() async throws -> [ServiceJSONObject] {
        try await decodeJSONArray(path: "dormitory-queue-application/premium-penalty")
    }

    func fetchIsBRSM() async throws -> Bool {
        try await decodeBool(path: "activity/is-brsm")
    }

    func fetchIsProfCom() async throws -> Bool {
        try await decodeBool(path: "activity/is-prof-com")
    }

    func fetchSocialWork() async throws -> [ServiceJSONObject] {
        try await decodeJSONArray(path: "activity/social-work")
    }

    func fetchResearchWork() async throws -> [ServiceJSONObject] {
        try await decodeJSONArray(path: "activity/research-work")
    }

    func fetchCurrentWeek(preferCachedResponse: Bool = true) async throws -> Int {
        let data = try await fetchData(
            path: "schedule/current-week",
            preferCachedResponse: preferCachedResponse
        )
        do {
            return try JSONDecoder().decode(Int.self, from: data)
        } catch {
            if let asString = String(data: data, encoding: .utf8), let value = Int(asString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return value
            }
            throw APIError.decodingError(error)
        }
    }

    func fetchAllStudentGroups(preferCachedResponse: Bool = true) async throws -> [StudyGroup] {
        let data = try await fetchData(
            path: "student-groups",
            preferCachedResponse: preferCachedResponse
        )
        do {
            return try JSONDecoder().decode([StudyGroup].self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func fetchAllEmployees(preferCachedResponse: Bool = true) async throws -> [ScheduleEmployeeDirectoryEntry] {
        let data = try await fetchData(
            path: "employees/all",
            preferCachedResponse: preferCachedResponse
        )
        do {
            return try JSONDecoder().decode([ScheduleEmployeeDirectoryEntry].self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func fetchGroupSchedule(
        groupNumber: String,
        preferCachedResponse: Bool = true
    ) async throws -> PublicScheduleResponse {
        let data = try await fetchData(
            path: "schedule",
            queryItems: [URLQueryItem(name: "studentGroup", value: groupNumber)],
            preferCachedResponse: preferCachedResponse
        )
        do {
            return try JSONDecoder().decode(PublicScheduleResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func fetchEmployeeSchedule(
        urlId: String,
        preferCachedResponse: Bool = true
    ) async throws -> PublicScheduleResponse {
        let data = try await fetchData(
            path: "employees/schedule/\(urlId)",
            preferCachedResponse: preferCachedResponse
        )
        do {
            return try JSONDecoder().decode(PublicScheduleResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func cachedGroupSchedule(groupNumber: String) -> PublicScheduleResponse? {
        guard let request = try? makeGETRequest(path: "schedule", queryItems: [
            URLQueryItem(name: "studentGroup", value: groupNumber)
        ]), let data = cachedData(for: request, allowExpired: true) else {
            return nil
        }
        return try? JSONDecoder().decode(PublicScheduleResponse.self, from: data)
    }

    func cachedEmployeeSchedule(urlId: String) -> PublicScheduleResponse? {
        guard let request = try? makeGETRequest(path: "employees/schedule/\(urlId)"),
              let data = cachedData(for: request, allowExpired: true) else {
            return nil
        }
        return try? JSONDecoder().decode(PublicScheduleResponse.self, from: data)
    }

    func cachedStudentGroups() -> [StudyGroup]? {
        guard let request = try? makeGETRequest(path: "student-groups"),
              let data = cachedData(for: request) else {
            return nil
        }
        return try? JSONDecoder().decode([StudyGroup].self, from: data)
    }

    func cachedEmployees() -> [ScheduleEmployeeDirectoryEntry]? {
        guard let request = try? makeGETRequest(path: "employees/all"),
              let data = cachedData(for: request) else {
            return nil
        }
        return try? JSONDecoder().decode([ScheduleEmployeeDirectoryEntry].self, from: data)
    }

    func downloadGroupScheduleReport(groupNumber: String) async throws -> URL {
        let data = try await fetchData(path: "schedule/report", queryItems: [
            URLQueryItem(name: "student-group-name", value: groupNumber)
        ])
        let fileName = "Расписание \(Self.safeFileName(groupNumber)).xlsx"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: [.atomic])
        return url
    }

    private func decodeBool(path: String) async throws -> Bool {
        let data = try await fetchData(path: path)
        do {
            return try JSONDecoder().decode(Bool.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func decodeJSONArray(path: String, queryItems: [URLQueryItem]? = nil) async throws -> [ServiceJSONObject] {
        let data = try await fetchData(path: path, queryItems: queryItems)

        if let objects = try? JSONDecoder().decode([ServiceJSONObject].self, from: data) {
            return objects
        }

        if let values = try? JSONDecoder().decode([ServiceJSONValue].self, from: data) {
            return values.enumerated().map { index, value in
                ServiceJSONObject(fields: [
                    "_index": .int(index),
                    "value": value
                ])
            }
        }

        throw APIError.decodingError(
            NSError(domain: "ServiceEndpointsAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported array payload"])
        )
    }

    private func targetServers(for path: String) async -> [ScheduleAPIServer] {
        guard ScheduleServerConfiguration.selectedServer != .official,
              baseURL == ScheduleServerConfiguration.officialBaseURL,
              ScheduleServerConfiguration.isGatewaySupported(path: path),
              await gatewayHealth.shouldAttempt(at: now()) else {
            return [.official]
        }
        return [.gateway, .official]
    }

    private func statusCode(from error: Error) -> Int {
        if let apiError = error as? APIError {
            switch apiError {
            case .serverError(let code, _):
                return code
            case .unauthorized:
                return 401
            case .serviceUnavailable:
                return 503
            default:
                return -1
            }
        }
        if let urlError = error as? URLError {
            return urlError.errorCode
        }
        return -1
    }

    private func fetchData(
        path: String,
        queryItems: [URLQueryItem]? = nil,
        preferCachedResponse: Bool = false
    ) async throws -> Data {
        let canonicalRequest = try makeGETRequest(path: path, queryItems: queryItems)
        guard let canonicalEndpoint = canonicalRequest.url else { throw APIError.invalidURL }

        if preferCachedResponse, let cached = cachedData(for: canonicalRequest) {
            logService.log("Service endpoints: using fresh cache for \(canonicalEndpoint.absoluteString)")
            return cached
        }

        let servers = await targetServers(for: path)
        var lastError: Error?

        for server in servers {
            do {
                return try await fetchFromServer(server, path: path, queryItems: queryItems, canonicalRequest: canonicalRequest)
            } catch {
                if isCancellationError(error) {
                    if server == .gateway { await gatewayHealth.cancelled() }
                    throw CancellationError()
                }
                lastError = error
                if server == .gateway {
                    await gatewayHealth.failed(at: now())
                } else if case APIError.unauthorized = error {
                    AuthenticationSessionEvents.reportUnauthorized()
                    throw error
                }
            }
        }

        if let cached = OfflineResponseCache.loadData(
            for: canonicalRequest, prefix: Self.cachePrefix, userDefaults: userDefaults,
            maxAge: canonicalRequest.url?.path.hasSuffix("/schedule/current-week") == true ? Self.currentWeekCacheLifetime : nil,
            now: now()
        ) {
            OfflineDataStatus.shared.usedCache(for: canonicalRequest.url)
            logService.log("⚠️ Service endpoints: using offline cache for \(canonicalEndpoint.absoluteString). Original error: \(lastError?.localizedDescription ?? "unknown")")
            return cached
        }

        if let apiError = lastError as? APIError {
            throw apiError
        }

        if let error = lastError {
            logTransportError(error, endpoint: canonicalEndpoint)
            throw APIError.networkError(error)
        }

        throw APIError.networkError(NSError(domain: "ServiceEndpointsAPI", code: -1, userInfo: nil))
    }

    private func fetchFromServer(
        _ server: ScheduleAPIServer,
        path: String,
        queryItems: [URLQueryItem]?,
        canonicalRequest: URLRequest
    ) async throws -> Data {
        let serverURL = server == .gateway ? ScheduleServerConfiguration.gatewayBaseURL : baseURL
        let endpoint = try endpointURL(baseURL: serverURL, path: path, queryItems: queryItems)
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "GET"
        request.timeoutInterval = server == .gateway ? 1.5 : 10
        let started = Date()
        do {
            let transport = server == .gateway ? gatewaySession : session
            let (data, response) = try await transport.data(for: request)
            let http = try validatedHTTPResponse(response)
            if server == .gateway, (200 ... 299).contains(http.statusCode) {
                try validateGatewayData(data, path: path)
            }
            let result = try handleSuccessfulTransport(
                httpResponse: http, data: data, request: request, canonicalRequest: canonicalRequest
            )
            if server == .gateway { await gatewayHealth.succeeded() }
            ScheduleServerMetricsTracker.shared.recordMetric(
                server: server.rawValue, endpoint: path,
                durationMs: Int(Date().timeIntervalSince(started) * 1000),
                httpStatusCode: http.statusCode, isSuccess: true, responseBytes: data.count,
                contentEncoding: http.value(forHTTPHeaderField: "Content-Encoding"),
                serverTiming: http.value(forHTTPHeaderField: "Server-Timing"),
                cacheControl: http.value(forHTTPHeaderField: "Cache-Control"), fullURL: endpoint.absoluteString
            )
            return result
        } catch {
            if !isCancellationError(error) {
                ScheduleServerMetricsTracker.shared.recordMetric(
                    server: server.rawValue, endpoint: path,
                    durationMs: Int(Date().timeIntervalSince(started) * 1000),
                    httpStatusCode: statusCode(from: error), isSuccess: false,
                    errorMessage: error.localizedDescription, fullURL: endpoint.absoluteString
                )
            }
            throw error
        }
    }

    private func validateGatewayData(_ data: Data, path: String) throws {
        let decoder = JSONDecoder()
        if path == "schedule" || path.hasPrefix("employees/schedule/") {
            _ = try decoder.decode(PublicScheduleResponse.self, from: data)
        } else if path == "schedule/current-week" {
            let week = try decoder.decode(Int.self, from: data)
            guard (1...4).contains(week) else { throw APIError.invalidResponse }
        } else if path == "student-groups" {
            _ = try decoder.decode([StudyGroup].self, from: data)
        } else if path == "employees/all" {
            _ = try decoder.decode([ScheduleEmployeeDirectoryEntry].self, from: data)
        } else {
            _ = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        }
    }

    private func makeGETRequest(baseURL: URL? = nil, path: String, queryItems: [URLQueryItem]? = nil) throws -> URLRequest {
        let endpoint = try endpointURL(baseURL: baseURL ?? self.baseURL, path: path, queryItems: queryItems)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        return request
    }

    private func endpointURL(baseURL: URL? = nil, path: String, queryItems: [URLQueryItem]?) throws -> URL {
        let base = baseURL ?? self.baseURL
        var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems
        guard let endpoint = components?.url else {
            throw APIError.invalidURL
        }
        return endpoint
    }

    private static func safeFileName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        return value.unicodeScalars.map { allowed.contains($0) ? String($0) : "_" }.joined()
    }

    private func validatedHTTPResponse(_ response: URLResponse) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        return httpResponse
    }

    private func handleSuccessfulTransport(
        httpResponse: HTTPURLResponse,
        data: Data,
        request: URLRequest,
        canonicalRequest: URLRequest? = nil
    ) throws -> Data {
        switch httpResponse.statusCode {
        case 200 ... 299:
            OfflineDataStatus.shared.refreshed(canonicalRequest?.url ?? request.url)
            persistCache(data: data, for: canonicalRequest ?? request)
            return data
        case 401, 403:
            throw APIError.unauthorized(message: NSLocalizedString(
                "api_error_session_expired",
                value: "Сессия истекла. Войдите заново.",
                comment: ""
            ))
        case 418:
            throw APIError.serviceUnavailable(message: "Сервис временно недоступен")
        default:
            let message = String(data: data, encoding: .utf8) ?? "Ошибка сервера"
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
    }

    private func logTransportError(_ error: Error, endpoint: URL) {
        if let urlError = error as? URLError {
            logService.log("❌ Service endpoint transport error: \(urlError.code.rawValue) (\(urlError.code)) for \(endpoint.absoluteString)")
            if let failingURL = urlError.failingURL {
                logService.log("Failing URL: \(failingURL.absoluteString)")
            }
            return
        }

        let nsError = error as NSError
        logService.log("❌ Service endpoint transport NSError: \(nsError.domain) / \(nsError.code) for \(endpoint.absoluteString)")
    }

    private func persistCache(data: Data, for request: URLRequest) {
        OfflineResponseCache.persist(data: data, for: request, prefix: Self.cachePrefix, userDefaults: userDefaults, cachedAt: now())
    }

    private func cachedData(for request: URLRequest, allowExpired: Bool = false) -> Data? {
        OfflineResponseCache.loadData(
            for: request,
            prefix: Self.cachePrefix,
            userDefaults: userDefaults,
            maxAge: allowExpired ? nil : cacheLifetime(for: request),
            now: now()
        )
    }

    private func cacheLifetime(for request: URLRequest) -> TimeInterval {
        if request.url?.path.hasSuffix("/schedule/current-week") == true {
            return Self.currentWeekCacheLifetime
        }
        if request.url?.path.hasSuffix("/schedule") == true || request.url?.path.contains("/employees/schedule/") == true {
            return 5 * 60
        }
        return Self.responseCacheLifetime
    }

    private func isCancellationError(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return Task.isCancelled
    }
}
