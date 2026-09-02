import Combine
import Foundation
import SwiftUI

enum LMSError: LocalizedError {
    case invalidResponse
    case invalidCredentials
    case loginFailed
    case sessionExpired
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "СЭО вернула некорректный ответ."
        case .invalidCredentials:
            return "СЭО отклонила логин или пароль."
        case .loginFailed:
            return "Не удалось войти в СЭО."
        case .sessionExpired:
            return "Сессия СЭО истекла. Войдите ещё раз."
        case .networkUnavailable:
            return "Не удалось обновить данные СЭО."
        }
    }
}

class LMSService: ObservableObject {
    static let shared = LMSService()

    private let session: URLSession
    private let logService = LogService.shared
    private let credentialStore = CredentialStore.lms
    private let userDefaults = UserDefaults.standard

    private static let cachePrefix = "LMSService.cache."
    private static let automaticRefreshInterval: TimeInterval = 5 * 60
    private static let courseURLs = [
        NetworkSecurityPolicy.lmsBaseURL,
        NetworkSecurityPolicy.lmsBaseURL.appendingPathComponent("my", isDirectory: true)
    ]

    private struct CachedEnvelope: Codable {
        let data: Data
        let cachedAt: Date
    }

    private struct CourseLoadResult {
        let courses: [LMSCourse]
        let updatedAt: Date
        let isFromCache: Bool
    }

    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var courses: [LMSCourse] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdatedAt: Date?

    private init() {
        self.session = URLSession(
            configuration: NetworkSecurityPolicy.makeLMSConfiguration()
        )
        self.isLoggedIn = hasSessionCookie

        if isLoggedIn, let cached = cachedCourseResult() {
            self.courses = cached.courses
            self.lastUpdatedAt = cached.updatedAt
        }
    }
}

extension LMSService {
    @MainActor
    func refreshCourses(force: Bool = false) async {
        guard !isLoading else {
            logService.log("ℹ️ LMS: Reusing the active courses refresh.")
            return
        }

        isLoggedIn = hasSessionCookie
        guard isLoggedIn else {
            errorMessage = nil
            return
        }

        if !force,
           let lastUpdatedAt,
           Date().timeIntervalSince(lastUpdatedAt) < Self.automaticRefreshInterval {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await loadCourses()
            guard !Task.isCancelled else { return }

            courses = result.courses
            lastUpdatedAt = result.updatedAt
            errorMessage = result.isFromCache
                ? "СЭО сейчас недоступна. Показаны сохранённые курсы."
                : nil
            logService.log(
                result.isFromCache
                    ? "⚠️ LMS: Refresh completed from cache."
                    : "✅ LMS: Refresh completed with \(result.courses.count) courses."
            )
        } catch is CancellationError {
            logService.log("ℹ️ LMS: Courses refresh cancelled.")
        } catch LMSError.sessionExpired {
            isLoggedIn = false
            errorMessage = LMSError.sessionExpired.localizedDescription
            logService.log("⚠️ LMS: Session is no longer valid.")
        } catch {
            errorMessage = error.localizedDescription
            logService.log("⚠️ LMS: Courses refresh failed: \(error.localizedDescription)")
        }
    }

    private func loadCourses() async throws -> CourseLoadResult {
        logService.log("📡 LMS: Starting courses refresh.")
        var receivedValidPage = false
        var latestError: Error?

        for url in Self.courseURLs {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 20

            do {
                let (data, response) = try await session.data(for: request)
                let html = try Self.validatedHTML(data: data, response: response)

                receivedValidPage = true
                persistCache(data: data, for: request)
                let parsed = Self.parseCourses(from: html)
                if !parsed.isEmpty {
                    return CourseLoadResult(courses: parsed, updatedAt: Date(), isFromCache: false)
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch LMSError.sessionExpired {
                throw LMSError.sessionExpired
            } catch {
                latestError = error
                logService.log("⚠️ LMS: \(url.absoluteString) failed: \(error.localizedDescription)")
            }
        }

        if latestError != nil, let cached = cachedCourseResult() {
            return cached
        }
        if receivedValidPage {
            return CourseLoadResult(courses: [], updatedAt: Date(), isFromCache: false)
        }
        throw latestError ?? LMSError.networkUnavailable
    }

    private static func validatedHTML(data: Data, response: URLResponse) throws -> String {
        guard let httpResponse = response as? HTTPURLResponse,
              let responseURL = httpResponse.url,
              NetworkSecurityPolicy.isTrustedLMSURL(responseURL) else {
            throw NetworkSecurityError.untrustedURL
        }
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw LMSError.sessionExpired
        }
        guard httpResponse.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else {
            throw LMSError.invalidResponse
        }
        guard !isLoginPage(html: html, responseURL: httpResponse.url) else {
            throw LMSError.sessionExpired
        }
        return html
    }

    private static func isLoginPage(html: String, responseURL: URL?) -> Bool {
        if responseURL?.path.localizedCaseInsensitiveContains("/login/") == true {
            return true
        }
        return html.localizedCaseInsensitiveContains("id=\"loginform\"")
            || html.localizedCaseInsensitiveContains("name=\"logintoken\"")
    }

    static func parseCourses(from html: String) -> [LMSCourse] {
        let scopedHTML = coursesHTMLScope(in: html)
        var results: [LMSCourse] = []
        let startPattern = #"<div\b(?=[^>]*\bclass="[^"]*\bcoursebox\b[^"]*")(?=[^>]*\bdata-courseid="\d+")[^>]*>"#
        let matches = scopedHTML.matches(pattern: startPattern)
        guard !matches.isEmpty else { return [] }

        for (idx, match) in matches.enumerated() {
            guard let idText = match.fullText.captureGroup(at: 1, pattern: #"\bdata-courseid="(\d+)""#),
                  let courseId = Int(idText) else { continue }

            let start = match.fullRange.lowerBound
            let end = idx + 1 < matches.count ? matches[idx + 1].fullRange.lowerBound : scopedHTML.endIndex
            let content = String(scopedHTML[start ..< end])

            let namePattern = #"<h3[^>]*class="[^"]*\bcoursename\b[^"]*"[^>]*>\s*<a[^>]*>([\s\S]*?)<\/a>\s*<\/h3>"#
            let nameRaw = content.captureGroup(at: 1, pattern: namePattern) ?? "Курс \(courseId)"
            let name = cleanHTMLText(nameRaw)

            let imgPattern = #"<div[^>]*class="[^"]*\bcourseimage\b[^"]*"[^>]*>\s*<img[^>]*src="([^"]+)""#
            let imgUrlStr = content.captureGroup(at: 1, pattern: imgPattern)?.decodingHTMLEntities()
            let imgUrl = imgUrlStr.flatMap(URL.init(string:))

            let teacherPattern = #"<li>\s*(?:<span[^>]*>[\s\S]*?<\/span>\s*)?<a[^>]*href="[^"]*\/user\/profile\.php\?id=\d+[^"]*"[^>]*>([\s\S]*?)<\/a>\s*<\/li>"#
            let teachers = content
                .captureGroups(at: 1, pattern: teacherPattern)
                .map(cleanHTMLText)
                .filter { !$0.isEmpty }

            results.append(
                LMSCourse(
                    id: courseId,
                    name: name,
                    teachers: teachers,
                    backgroundUrl: imgUrl
                )
            )
        }
        return results
    }

    private static func coursesHTMLScope(in html: String) -> String {
        guard let start = html.range(of: #"<div\s+id="frontpage-course-list""#, options: .regularExpression) else {
            return html
        }

        let searchRange = start.lowerBound ..< html.endIndex
        let end = html.range(of: #"<span\s+class="skip-block-to"\s+id="skipmycourses""#, options: .regularExpression, range: searchRange)
        return String(html[start.lowerBound ..< (end?.lowerBound ?? html.endIndex)])
    }

    private static func cleanHTMLText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression, range: nil)
            .decodingHTMLEntities()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

}

extension LMSService {
    func fetchCourseDetail(id: Int) async throws -> LMSCourseDetail {
        logService.log("🔍 LMS: Fetching detail for ID \(id)")
        var components = URLComponents(
            url: NetworkSecurityPolicy.lmsBaseURL
                .appendingPathComponent("course")
                .appendingPathComponent("view.php"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "id", value: String(id))]
        guard let url = components?.url else {
            throw NetworkSecurityError.untrustedURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let html: String

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  let responseURL = httpResponse.url,
                  NetworkSecurityPolicy.isTrustedLMSURL(responseURL),
                  httpResponse.statusCode == 200 else {
                logService.log("❌ LMS detail failed: code \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                throw LMSError.invalidResponse
            }

            persistCache(data: data, for: request)

            guard let decoded = String(data: data, encoding: .utf8) else {
                logService.log("❌ LMS detail: encoding error")
                throw LMSError.invalidResponse
            }

            html = decoded
        } catch {
            guard let cached = cachedData(for: request),
                  let cachedHTML = String(data: cached, encoding: .utf8) else {
                throw error
            }
            logService.log("⚠️ LMS: Loaded course detail from offline cache for ID \(id).")
            html = cachedHTML
        }

        logService.log("🔍 LMS: HTML received (\(html.count) chars)")

        let titlePattern = #"<title>Курс:\s*(.*?) \| СЭО<\/title>"#
        let title = html.captureGroup(at: 1, pattern: titlePattern) ?? "Курс \(id)"

        let sections = Self.parseSections(from: html)

        if sections.isEmpty {
            logService.log("⚠️ LMS: No sections parsed from course HTML")
        } else {
            logService.log("✅ LMS: Successfully parsed \(sections.count) sections")
        }

        return LMSCourseDetail(id: id, fullname: title, sections: sections)
    }

    private func persistCache(data: Data, for request: URLRequest) {
        guard let key = cacheKey(for: request) else { return }
        let envelope = CachedEnvelope(data: data, cachedAt: Date())
        guard let payload = try? JSONEncoder().encode(envelope) else { return }
        _ = UserDefaultsPayloadStore.save(payload, forKey: key, in: userDefaults)
    }

    private func cachedData(for request: URLRequest) -> Data? {
        cachedEnvelope(for: request)?.data
    }

    private func cachedEnvelope(for request: URLRequest) -> CachedEnvelope? {
        guard let key = cacheKey(for: request),
              let payload = UserDefaultsPayloadStore.load(forKey: key, from: userDefaults) else {
            return nil
        }
        return try? JSONDecoder().decode(CachedEnvelope.self, from: payload)
    }

    private func cachedCourseResult() -> CourseLoadResult? {
        for url in Self.courseURLs {
            let request = URLRequest(url: url)
            guard let envelope = cachedEnvelope(for: request),
                  let html = String(data: envelope.data, encoding: .utf8) else {
                continue
            }

            let parsed = Self.parseCourses(from: html)
            if !parsed.isEmpty {
                return CourseLoadResult(
                    courses: parsed,
                    updatedAt: envelope.cachedAt,
                    isFromCache: true
                )
            }
        }
        return nil
    }

    private var hasSessionCookie: Bool {
        let lmsURL = NetworkSecurityPolicy.lmsBaseURL
        let cookies = HTTPCookieStorage.shared.cookies(for: lmsURL) ?? []
        return cookies.contains { cookie in
            cookie.name == "MoodleSession" && (cookie.expiresDate == nil || cookie.expiresDate! > Date())
        }
    }

    private func cacheKey(for request: URLRequest) -> String? {
        guard let url = request.url?.absoluteString else { return nil }
        let method = request.httpMethod?.uppercased() ?? "GET"
        let composite = "\(method)|\(url)"
        return Self.cachePrefix + Data(composite.utf8).base64EncodedString()
    }

    private func prepareLoginPage() async throws -> (url: URL, token: String?) {
        let url = NetworkSecurityPolicy.lmsBaseURL
            .appendingPathComponent("login")
            .appendingPathComponent("index.php")
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              let responseURL = httpResponse.url,
              NetworkSecurityPolicy.isTrustedLMSURL(responseURL),
              (200 ... 399).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw LMSError.invalidResponse
        }

        let tokenPattern = #"name=["']logintoken["'][^>]*value=["']([^"']+)["']"#
        let token = html.captureGroup(at: 1, pattern: tokenPattern)
        return (url, token)
    }

    @MainActor
    func login(
        username: String,
        password: String,
        persistCredentials: Bool
    ) async throws {
        guard !isLoading else { return }
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty, !password.isEmpty else {
            throw LMSError.invalidCredentials
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        logService.log("🔐 LMS: Logging in as \(trimmedUsername)")
        let loginPage = try await prepareLoginPage()
        var request = URLRequest(url: loginPage.url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = [
            "username": trimmedUsername,
            "password": password
        ]
        if let token = loginPage.token {
            bodyComponents["logintoken"] = token
        }
        let bodyString = bodyComponents
            .compactMap { key, value -> String? in
                guard let encodedValue = value.addingPercentEncoding(
                    withAllowedCharacters: .urlQueryValueAllowed
                ) else {
                    return nil
                }
                return "\(key)=\(encodedValue)"
            }
            .joined(separator: "&")

        request.httpBody = bodyString.data(using: .utf8)
        let (data, response) = try await session.data(for: request)
        guard let responseURL = response.url,
              NetworkSecurityPolicy.isTrustedLMSURL(responseURL) else {
            throw NetworkSecurityError.untrustedURL
        }
        let html = String(data: data, encoding: .utf8) ?? ""

        guard hasSessionCookie,
              !Self.isLoginPage(html: html, responseURL: responseURL) else {
            isLoggedIn = false
            if html.localizedCaseInsensitiveContains("loginerrormessage") {
                logService.log("❌ LMS: Invalid credentials.")
                throw LMSError.invalidCredentials
            }
            logService.log("❌ LMS: Login failed.")
            throw LMSError.loginFailed
        }

        if persistCredentials {
            try credentialStore.save(
                StoredCredentials(username: trimmedUsername, password: password)
            )
        } else {
            try credentialStore.clear()
        }

        isLoggedIn = true
        let result = try await loadCourses()
        courses = result.courses
        lastUpdatedAt = result.updatedAt
        errorMessage = result.isFromCache
            ? "Вход выполнен. Пока показаны сохранённые курсы."
            : nil
        logService.log("✅ LMS: Login and session validation succeeded.")
    }

    func savedUsername() -> String {
        (try? credentialStore.retrieve()?.username) ?? ""
    }

    @MainActor
    func logout() {
        NetworkSecurityPolicy.removeCookies(forHost: NetworkSecurityPolicy.lmsHost)
        try? credentialStore.clear()
        isLoggedIn = false
        courses = []
        errorMessage = nil
        lastUpdatedAt = nil
    }

    @MainActor
    func checkSession() async {
        await refreshCourses()
        guard !isLoggedIn, !Task.isCancelled else { return }

        do {
            guard let credentials = try credentialStore.retrieve() else { return }
            logService.log("ℹ️ LMS: Restoring an expired session from saved credentials.")
            try await login(
                username: credentials.username,
                password: credentials.password,
                persistCredentials: true
            )
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
            logService.log("⚠️ LMS: Automatic session restoration failed: \(error.localizedDescription)")
        }
    }
}
