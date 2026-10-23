import Foundation

enum SchedulePhotoRouting {
    nonisolated static func canonicalURL(_ url: URL) -> URL {
        guard ["iis.bsuir.by", "bsuir.ordinad.xyz"].contains(url.host ?? ""),
              url.path.hasPrefix("/api/v1/employees/photo/"),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        components.scheme = "https"
        components.host = "iis.bsuir.by"
        components.queryItems = components.queryItems?.filter { $0.name != "format" }
        if components.queryItems?.isEmpty == true { components.queryItems = nil }
        return components.url ?? url
    }

    nonisolated static func gatewayURL(for url: URL) -> URL? {
        guard url.host == "iis.bsuir.by", url.path.hasPrefix("/api/v1/employees/photo/"),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        components.host = "bsuir.ordinad.xyz"
        components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "format", value: "jpeg")]
        return components.url
    }
}
