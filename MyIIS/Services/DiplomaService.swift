import Foundation

protocol DiplomaServicing {
    func fetchDiplomaProgress(for userIdentifier: String) async throws -> DiplomaProgress
}

final class DiplomaService: DiplomaServicing {

    private let baseURL = URLFactory.require("https://iis.bsuir.by/api/v1")
    private let session: URLSession
    private let logService = LogService.shared
    private let userDefaults = UserDefaults.standard

    private static let cachePrefix = "DiplomaService.cache."

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchDiplomaProgress(for userIdentifier: String) async throws -> DiplomaProgress {
        guard !userIdentifier.isEmpty else {
            throw APIError.invalidURL
        }

        var components = URLComponents(
            url: baseURL
                .appendingPathComponent("graduate-work")
                .appendingPathComponent("progress"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "student", value: userIdentifier)
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        logService.log("Fetching diploma progress for user: \(userIdentifier)")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            return try resolveProgress(data: data, response: httpResponse, request: request)
        } catch let error as APIError {
            if case .unauthorized = error {
                AuthenticationSessionEvents.reportUnauthorized()
            }
            return try resolveFallback(for: request, error: error)
        } catch {
            return try resolveFallback(for: request, error: APIError.networkError(error))
        }
    }

    private func decodeProgress(from data: Data) throws -> DiplomaProgress {
        let decoder = JSONDecoder()
        return try decoder.decode(DiplomaProgress.self, from: data)
    }

    private func persistCache(data: Data, for request: URLRequest) {
        OfflineResponseCache.persist(data: data, for: request, prefix: Self.cachePrefix, userDefaults: userDefaults)
    }

    private func tryDecodeCachedProgress(for request: URLRequest, originalError: String) -> DiplomaProgress? {
        guard let data = OfflineResponseCache.loadData(for: request, prefix: Self.cachePrefix, userDefaults: userDefaults),
              let decoded = try? decodeProgress(from: data) else {
            return nil
        }

        let url = request.url?.absoluteString ?? "—"
        logService.log("⚠️ Diploma offline cache used for \(url). Original error: \(originalError)")
        return decoded
    }

    private func resolveProgress(data: Data, response: HTTPURLResponse, request: URLRequest) throws -> DiplomaProgress {
        switch response.statusCode {
        case 200:
            persistCache(data: data, for: request)
            return try decodeProgress(from: data)
        case 401, 403:
            let message = try Self.decodeErrorMessage(from: data)
            throw APIError.unauthorized(message: message ?? "Требуется авторизация")
        case 503:
            let message = try Self.decodeErrorMessage(from: data)
            throw APIError.serviceUnavailable(message: message ?? "Сервис временно недоступен")
        default:
            let message = try Self.decodeErrorMessage(from: data)
            throw APIError.serverError(statusCode: response.statusCode, message: message ?? "Неизвестная ошибка")
        }
    }

    private func resolveFallback(for request: URLRequest, error: APIError) throws -> DiplomaProgress {
        if let cached = tryDecodeCachedProgress(for: request, originalError: error.localizedDescription) {
            return cached
        }
        logService.log("❌ Diploma error: \(error.localizedDescription)")
        throw error
    }

    private static func decodeErrorMessage(from data: Data) throws -> String? {
        guard !data.isEmpty else {
            return nil
        }
        let decoder = JSONDecoder()
        if let error = try? decoder.decode(ErrorResponse.self, from: data) {
            return error.msg
        }
        return String(data: data, encoding: .utf8)
    }
}

#if DEBUG
extension DiplomaService {
    static var preview: DiplomaService {
        DiplomaService()
    }
}
#endif
