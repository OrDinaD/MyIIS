import Combine
import Foundation
import SwiftUI

enum LMSError: Error {
    case invalidResponse
    case noCredentials
    case invalidCredentials
    case loginFailed
}

class LMSService: ObservableObject {
    static let shared = LMSService()

    private let session: URLSession
    private let logService = LogService.shared
    private let credentialStore = CredentialStore.shared
    private let userDefaults = UserDefaults.standard

    private static let cachePrefix = "LMSService.cache."

    private struct CachedEnvelope: Codable {
        let data: Data
        let cachedAt: Date
    }

    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var courses: [LMSCourse] = []

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = .shared
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        self.session = URLSession(configuration: configuration)

        Task {
            await checkSession()
        }
    }

    func fetchCourses() async throws {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        logService.log("📡 LMS: Starting courses fetch")
        let urls = [
            "https://lms.bsuir.by/my/",
            "https://lms.bsuir.by/"
        ]

        var allCourses: [LMSCourse] = []

        for urlString in urls {
            guard let url = URL(string: urlString) else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    logService.log("📡 LMS: Page \(urlString) returned \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
                    continue
                }

                persistCache(data: data, for: request)

                if let html = String(data: data, encoding: .utf8) {
                    logService.log("📡 LMS: Received HTML (\(html.count) chars) from \(urlString)")
                    let parsed = parseCourses(from: html)
                    if !parsed.isEmpty {
                        logService.log("📡 LMS: Successfully parsed \(parsed.count) courses")
                        allCourses = parsed
                        break
                    }
                }
            } catch {
                if let cachedData = cachedData(for: request),
                   let html = String(data: cachedData, encoding: .utf8) {
                    let parsed = parseCourses(from: html)
                    if !parsed.isEmpty {
                        logService.log("⚠️ LMS: Loaded courses from offline cache for \(urlString).")
                        allCourses = parsed
                        break
                    }
                }
            }
        }

        await MainActor.run {
            self.courses = allCourses
        }
    }

    private func parseCourses(from html: String) -> [LMSCourse] {
        var results: [LMSCourse] = []
        let startPattern = #"<div[^>]*class="[^"]*coursebox[^"]*"[^>]*data-courseid="(\d+)"[^>]*>"#
        let matches = html.matches(pattern: startPattern)
        guard !matches.isEmpty else { return [] }

        for (idx, match) in matches.enumerated() {
            guard let idText = match.groups[safe: 0],
                  let courseId = Int(idText) else { continue }

            let start = match.fullRange.lowerBound
            let end = idx + 1 < matches.count ? matches[idx + 1].fullRange.lowerBound : html.endIndex
            let content = String(html[start..<end])

            let namePattern = #"<h3[^>]*class="coursename"[^>]*><a[^>]*>([\s\S]*?)<\/a><\/h3>"#
            let nameRaw = content.captureGroup(at: 1, pattern: namePattern)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Курс \(courseId)"
            let name = nameRaw.decodingHTMLEntities()

            let imgPattern = #"<div[^>]*class="courseimage"[^>]*><img[^>]*src="([^"]+)"[^>]*>"#
            let imgUrlStr = content.captureGroup(at: 1, pattern: imgPattern)?.decodingHTMLEntities()
            let imgUrl = imgUrlStr.flatMap(URL.init(string:))

            let teacherPattern = #"<li>\s*<span[^>]*>\s*Преподаватель:\s*<\/span>\s*<a[^>]*>([\s\S]*?)<\/a>\s*<\/li>"#
            let teachers = content
                .captureGroups(at: 1, pattern: teacherPattern)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).decodingHTMLEntities() }
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

    func fetchCourseDetail(id: Int) async throws -> LMSCourseDetail {
        logService.log("🔍 LMS: Fetching detail for ID \(id)")
        let url = URL(string: "https://lms.bsuir.by/course/view.php?id=\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let html: String

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
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
        guard let key = cacheKey(for: request),
              let payload = UserDefaultsPayloadStore.load(forKey: key, from: userDefaults),
              let envelope = try? JSONDecoder().decode(CachedEnvelope.self, from: payload) else {
            return nil
        }
        return envelope.data
    }

    private func cacheKey(for request: URLRequest) -> String? {
        guard let url = request.url?.absoluteString else { return nil }
        let method = request.httpMethod?.uppercased() ?? "GET"
        let composite = "\(method)|\(url)"
        return Self.cachePrefix + Data(composite.utf8).base64EncodedString()
    }

    func login() async throws {
        guard let credentials = try credentialStore.retrieve() else {
            throw LMSError.noCredentials
        }

        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        logService.log("🔐 LMS: Logging in as \(credentials.username)")
        let url = URL(string: "https://lms.bsuir.by/login/index.php")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyComponents = [
            "username": credentials.username,
            "password": credentials.password
        ]

        let bodyString = bodyComponents
            .compactMap { (key, value) -> String? in
                guard let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) else { return nil }
                return "\(key)=\(encodedValue)"
            }
            .joined(separator: "&")

        request.httpBody = bodyString.data(using: .utf8)
        let (data, _) = try await session.data(for: request)

        let cookies = HTTPCookieStorage.shared.cookies(for: URL(string: "https://lms.bsuir.by")!) ?? []
        let hasSession = cookies.contains(where: { $0.name == "MoodleSession" })

        await MainActor.run {
            self.isLoggedIn = hasSession
        }

        if hasSession {
            logService.log("✅ LMS: Login success (Session found)")
            try? await fetchCourses()
        } else {
            if let html = String(data: data, encoding: .utf8), html.contains("loginerrormessage") {
                logService.log("❌ LMS: Invalid credentials")
                throw LMSError.invalidCredentials
            }
            logService.log("❌ LMS: Login failed")
            throw LMSError.loginFailed
        }
    }

    func logout() {
        let storage = HTTPCookieStorage.shared
        if let cookies = storage.cookies(for: URL(string: "https://lms.bsuir.by")!) {
            for cookie in cookies {
                storage.deleteCookie(cookie)
            }
        }
        isLoggedIn = false
        courses = []
    }

    func checkSession() async {
        let cookies = HTTPCookieStorage.shared.cookies(for: URL(string: "https://lms.bsuir.by")!) ?? []
        let hasSession = cookies.contains(where: { $0.name == "MoodleSession" })
        await MainActor.run {
            self.isLoggedIn = hasSession
        }
        if hasSession {
            try? await fetchCourses()
        }
    }
}

// RESTORING MISSING EXTENSIONS
extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@"
        let subDelimitersToEncode = "!$&'()*+,;="

        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        return allowed
    }()
}

extension String {
    struct RegexMatch {
        let fullText: String
        let fullRange: Range<String.Index>
        let groups: [String]
    }

    func matches(pattern: String) -> [RegexMatch] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else { return [] }
        let nsRange = NSRange(self.startIndex..<self.endIndex, in: self)
        return regex.matches(in: self, range: nsRange).compactMap { match in
            guard let fullRange = Range(match.range(at: 0), in: self) else { return nil }
            var groups: [String] = []
            if match.numberOfRanges > 1 {
                for idx in 1..<match.numberOfRanges {
                    let groupRange = match.range(at: idx)
                    if groupRange.location != NSNotFound, let captureRange = Range(groupRange, in: self) {
                        groups.append(String(self[captureRange]))
                    } else {
                        groups.append("")
                    }
                }
            }
            return RegexMatch(
                fullText: String(self[fullRange]),
                fullRange: fullRange,
                groups: groups
            )
        }
    }

    func captureGroup(at index: Int, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else { return nil }
        let nsRange = NSRange(self.startIndex..<self.endIndex, in: self)
        if let match = regex.firstMatch(in: self, range: nsRange) {
            if match.numberOfRanges > index {
                let range = match.range(at: index)
                if let captureRange = Range(range, in: self) {
                    return String(self[captureRange])
                }
            }
        }
        return nil
    }

    func captureGroups(at index: Int, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else { return [] }
        let nsRange = NSRange(self.startIndex..<self.endIndex, in: self)
        let matches = regex.matches(in: self, range: nsRange)
        return matches.compactMap { match in
            if match.numberOfRanges > index {
                let range = match.range(at: index)
                if let captureRange = Range(range, in: self) {
                    return String(self[captureRange])
                }
            }
            return nil
        }
    }

    func decodingHTMLEntities() -> String {
        var decoded = self
        let replacements: [(String, String)] = [
            ("&quot;", "\""),
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&apos;", "'"),
            ("&#039;", "'"),
            ("&nbsp;", " ")
        ]

        for (entity, value) in replacements where decoded.contains(entity) {
            decoded = decoded.replacingOccurrences(of: entity, with: value)
        }

        return decoded
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension LMSService {
    private static func parseSections(from html: String) -> [LMSSection] {
        var sections: [LMSSection] = []
        let sectionPattern = #"<li[^>]*data-for="section"[^>]*data-sectionname="([^"]+)"[^>]*>"#
        let sectionMatches = html.matches(pattern: sectionPattern)

        for (idx, sectionMatch) in sectionMatches.enumerated() {
            guard let sectionNameRaw = sectionMatch.groups[safe: 0] else { continue }
            let sectionName = sectionNameRaw.decodingHTMLEntities()

            let blockStart = sectionMatch.fullRange.lowerBound
            let blockEnd = idx + 1 < sectionMatches.count ? sectionMatches[idx + 1].fullRange.lowerBound : html.endIndex
            let sectionBlock = String(html[blockStart..<blockEnd])

            let modules = parseModules(from: sectionBlock, sectionIndex: idx)
            if !modules.isEmpty {
                sections.append(LMSSection(name: sectionName, modules: modules))
            }
        }

        if sections.isEmpty {
            let fallbackModules = parseModules(from: html, sectionIndex: 0)
            if !fallbackModules.isEmpty {
                sections.append(LMSSection(name: "Материалы курса", modules: fallbackModules))
            }
        }

        return sections
    }

    // swiftlint:disable:next function_body_length
    private static func parseModules(from source: String, sectionIndex: Int) -> [LMSModule] {
        let activityPattern =
            #"<li[^>]*class="[^"]*activity[^"]*activity-wrapper[^"]*"[^>]*id="module-(\d+)"[^>]*>([\s\S]*?)"#
            + #"(?=<li[^>]*class="[^"]*activity[^"]*activity-wrapper[^"]*"|<\/ul>|$)"#
        let matches = source.matches(pattern: activityPattern)
        var modules: [LMSModule] = []
        var fallbackIndex = 0

        for match in matches {
            let moduleId = Int(match.groups[safe: 0] ?? "") ?? ((sectionIndex + 1) * 10_000 + fallbackIndex + 1)
            fallbackIndex += 1
            let moduleFull = match.fullText

            let modName = moduleFull.captureGroup(at: 1, pattern: #"data-activityname="([^"]+)""#)?
                .decodingHTMLEntities()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                ?? "Элемент \(moduleId)"

            let modTypeStr = moduleFull.captureGroup(at: 1, pattern: #"modtype_([^"\s]+)"#) ?? "unknown"
            let type = LMSModule.LMSModuleType(rawValue: modTypeStr) ?? .unknown

            let modHref =
                moduleFull.captureGroup(at: 1, pattern: #"<a[^>]*class="[^"]*aalink[^"]*"[^>]*href="([^"]+)""#)
                ?? moduleFull.captureGroup(at: 1, pattern: #"href="([^"]+)""#)
            let modUrl = modHref
                .map { $0.decodingHTMLEntities() }
                .flatMap { URL(string: $0, relativeTo: URL(string: "https://lms.bsuir.by"))?.absoluteURL }

            let descriptionRaw = moduleFull.captureGroup(
                at: 1,
                pattern: #"<div[^>]*class="[^"]*contentafterlink[^"]*"[^>]*>([\s\S]*?)<\/div>"#
            )
            let description = descriptionRaw?
                .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression, range: nil)
                .decodingHTMLEntities()
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let indentText = moduleFull.captureGroup(at: 1, pattern: #"mod-indent-(\d+)"#)
            let indent = Int(indentText ?? "0") ?? 0

            modules.append(
                LMSModule(
                    id: moduleId,
                    name: modName,
                    description: description?.isEmpty == true ? nil : description,
                    type: type,
                    url: modUrl,
                    indent: indent
                )
            )
        }

        if modules.isEmpty {
            let cardPattern = #"<div[^>]*class="[^"]*activity-item[^"]*"[^>]*data-activityname="([^"]+)"[^>]*>"#
            let cardMatches = source.matches(pattern: cardPattern)

            for (cardIndex, cardMatch) in cardMatches.enumerated() {
                let moduleId = (sectionIndex + 1) * 10_000 + cardIndex + 1
                let start = cardMatch.fullRange.lowerBound
                let end = cardIndex + 1 < cardMatches.count ? cardMatches[cardIndex + 1].fullRange.lowerBound : source.endIndex
                let moduleBlock = String(source[start..<end])

                let modName = cardMatch.groups[safe: 0]?
                    .decodingHTMLEntities()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? "Элемент \(moduleId)"

                let modTypeStr = moduleBlock.captureGroup(at: 1, pattern: #"modtype_([^"\s]+)"#) ?? "unknown"
                let type = LMSModule.LMSModuleType(rawValue: modTypeStr) ?? .unknown

                let modHref =
                    moduleBlock.captureGroup(at: 1, pattern: #"<a[^>]*class="[^"]*aalink[^"]*"[^>]*href="([^"]+)""#)
                    ?? moduleBlock.captureGroup(at: 1, pattern: #"href="([^"]+)""#)
                let modUrl = modHref
                    .map { $0.decodingHTMLEntities() }
                    .flatMap { URL(string: $0, relativeTo: URL(string: "https://lms.bsuir.by"))?.absoluteURL }

                modules.append(
                    LMSModule(
                        id: moduleId,
                        name: modName,
                        description: nil,
                        type: type,
                        url: modUrl,
                        indent: 0
                    )
                )
            }
        }

        return modules
    }
}
