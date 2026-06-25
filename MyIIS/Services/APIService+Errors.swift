import Foundation

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized(message: String)
    case serviceUnavailable(message: String)
    case serverError(statusCode: Int, message: String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString("api_error_invalid_url", value: "Неверный URL", comment: "")
        case .invalidResponse:
            return NSLocalizedString("api_error_invalid_response", value: "Неверный ответ от сервера", comment: "")
        case .unauthorized(let message):
            return message
        case .serviceUnavailable(let message):
            return message
        case .serverError(let code, let message):
            let prefix = NSLocalizedString("api_error_server", value: "Ошибка сервера", comment: "")
            return "\(prefix) (\(code)): \(message)"
        case .decodingError(let error):
            let prefix = NSLocalizedString("api_error_decoding_prefix", value: "Ошибка парсинга данных", comment: "")
            return "\(prefix): \(error.localizedDescription)"
        case .networkError(let error):
            return Self.formattedNetworkError(error)
        }
    }

    private static func formattedNetworkError(_ error: Error) -> String {
        if let urlError = error as? URLError {
            let prefix = NSLocalizedString("api_error_network_prefix", value: "Сетевая ошибка", comment: "")
            var details: [String] = [
                "\(prefix): \(urlError.localizedDescription)",
                "URLError code: \(urlError.code.rawValue) (\(urlError.code))"
            ]

            if let failingURL = urlError.failingURL {
                details.append("URL: \(failingURL.absoluteString)")
            }

            return details.joined(separator: "\n")
        }

        let nsError = error as NSError
        let prefix = NSLocalizedString("api_error_network_prefix", value: "Сетевая ошибка", comment: "")
        return [
            "\(prefix): \(error.localizedDescription)",
            "Domain: \(nsError.domain)",
            "Code: \(nsError.code)"
        ].joined(separator: "\n")
    }
}

extension KeyedDecodingContainer {
    func decodeMillisecondsDate(forKey key: K) throws -> Date {
        if let timestampMs = try? decode(Double.self, forKey: key) {
            return Date(timeIntervalSince1970: timestampMs / 1000)
        }

        if let timestampMs = try? decode(Int.self, forKey: key) {
            return Date(timeIntervalSince1970: Double(timestampMs) / 1000)
        }

        if let raw = try? decode(String.self, forKey: key) {
            if let millis = Double(raw) {
                return Date(timeIntervalSince1970: millis / 1000)
            }

            if let parsed = DateFormatter.iso8601WithFractional.date(from: raw) ?? DateFormatter.iso8601.date(from: raw) {
                return parsed
            }

            if let parsed = DateFormatter.attendanceApiDateTimeMillis.date(from: raw)
                ?? DateFormatter.attendanceApiDateTimeCentis.date(from: raw)
                ?? DateFormatter.attendanceApiDateTimeNoFraction.date(from: raw) {
                return parsed
            }

            if let parsed = DateFormatter.attendanceApiDate.date(from: raw) {
                return parsed
            }
        }

        throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Unsupported date format")
    }
}

private extension DateFormatter {
    static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let attendanceApiDateTimeMillis: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return formatter
    }()

    static let attendanceApiDateTimeCentis: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SS"
        return formatter
    }()

    static let attendanceApiDateTimeNoFraction: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    static let attendanceApiDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
