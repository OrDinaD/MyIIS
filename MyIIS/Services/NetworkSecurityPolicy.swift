import Foundation

enum NetworkSecurityError: LocalizedError {
    case untrustedURL

    var errorDescription: String? {
        switch self {
        case .untrustedURL:
            return "Заблокирован переход на недоверенный адрес."
        }
    }
}

enum NetworkSecurityPolicy {
    static let iisHost = "iis.bsuir.by"
    static let lmsHost = "lms.bsuir.by"
    static let iisBaseURL = URLFactory.require("https://iis.bsuir.by")
    static let lmsBaseURL = URLFactory.require("https://lms.bsuir.by")

    static func isSecureURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https"
            && url.host?.isEmpty == false
            && url.user == nil
            && url.password == nil
    }

    static func isTrustedLMSURL(_ url: URL) -> Bool {
        isSecureURL(url)
            && url.host?.lowercased() == lmsHost
            && (url.port == nil || url.port == 443)
    }

    static func secureURL(_ rawValue: String, relativeTo baseURL: URL = lmsBaseURL) -> URL? {
        let decoded = rawValue.decodingHTMLEntities()
        guard let url = URL(string: decoded, relativeTo: baseURL)?.absoluteURL,
              isSecureURL(url) else {
            return nil
        }
        return url
    }

    static func trustedLMSURL(_ rawValue: String, relativeTo baseURL: URL = lmsBaseURL) -> URL? {
        guard let url = secureURL(rawValue, relativeTo: baseURL),
              isTrustedLMSURL(url) else {
            return nil
        }
        return url
    }

    static func sanitizedFilename(_ candidate: String?, fallback: String) -> String {
        let fallbackName = sanitizedLeaf(fallback)
        guard let candidate else {
            return fallbackName.isEmpty ? "download" : fallbackName
        }

        let name = sanitizedLeaf(candidate.removingPercentEncoding ?? candidate)
        return name.isEmpty ? (fallbackName.isEmpty ? "download" : fallbackName) : name
    }

    static func removeCookies(
        forHost host: String,
        from storage: HTTPCookieStorage = .shared
    ) {
        let normalizedHost = host.lowercased()
        for cookie in storage.cookies ?? [] {
            let domain = cookie.domain
                .lowercased()
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            if domain == normalizedHost || domain.hasSuffix(".\(normalizedHost)") {
                storage.deleteCookie(cookie)
            }
        }
    }

    static func makeLMSConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = .shared
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .onlyFromMainDocumentDomain
        return configuration
    }

    private static func sanitizedLeaf(_ value: String) -> String {
        let normalizedSeparators = value.replacingOccurrences(of: "\\", with: "/")
        let leaf = normalizedSeparators
            .split(separator: "/", omittingEmptySubsequences: true)
            .last
            .map(String.init) ?? ""

        let forbidden = CharacterSet.controlCharacters.union(
            CharacterSet(charactersIn: ":*?\"<>|")
        )
        let replaced = leaf.unicodeScalars.map { scalar in
            forbidden.contains(scalar) ? "_" : String(scalar)
        }.joined()

        let trimmed = replaced.trimmingCharacters(in: .whitespacesAndNewlines)
        let visible = trimmed.drop(while: { $0 == "." })
        return String(visible.prefix(180))
    }
}
