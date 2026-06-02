import Foundation

protocol PenaltiesServicing {
    func fetchPenalties() async throws -> [PenaltyRecord]
}

final class PenaltiesService: PenaltiesServicing {
    private let baseURL: URL
    private let session: URLSession
    private let logService = LogService.shared
    private let userDefaults = UserDefaults.standard

    private static let cachePrefix = "PenaltiesService.cache."

    private struct CachedEnvelope: Codable {
        let data: Data
        let cachedAt: Date
    }

    init(
        baseURL: URL = URLFactory.require("https://iis.bsuir.by/api/v1"),
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchPenalties() async throws -> [PenaltyRecord] {
        let endpoint = baseURL.appendingPathComponent("student-discipline-penalties")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        logRequest(request)

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            logService.log("Penalties status code: \(httpResponse.statusCode)")
            return try resolvePenalties(data: data, response: httpResponse, request: request)
        } catch let apiError as APIError {
            return try resolveFallback(for: request, error: apiError)
        } catch {
            return try resolveFallback(for: request, error: APIError.networkError(error))
        }
    }

    private func decodePenaltyRecords(from data: Data) throws -> [PenaltyRecord] {
        let decoder = JSONDecoder()
        return try decoder.decode([PenaltyRecord].self, from: data)
    }

    private func persistCache(data: Data, for request: URLRequest) {
        guard let key = cacheKey(for: request) else { return }
        let envelope = CachedEnvelope(data: data, cachedAt: Date())
        guard let payload = try? JSONEncoder().encode(envelope) else { return }
        _ = UserDefaultsPayloadStore.save(payload, forKey: key, in: userDefaults)
    }

    private func tryDecodeCachedResponse(for request: URLRequest, originalError: String) -> [PenaltyRecord]? {
        guard let key = cacheKey(for: request),
              let payload = UserDefaultsPayloadStore.load(forKey: key, from: userDefaults),
              let envelope = try? JSONDecoder().decode(CachedEnvelope.self, from: payload),
              let decoded = try? decodePenaltyRecords(from: envelope.data) else {
            return nil
        }

        let url = request.url?.absoluteString ?? "—"
        logService.log("⚠️ Penalties offline cache used for \(url). Original error: \(originalError)")
        return decoded
    }

    private func cacheKey(for request: URLRequest) -> String? {
        guard let url = request.url?.absoluteString else { return nil }
        let method = request.httpMethod?.uppercased() ?? "GET"
        let composite = "\(method)|\(url)"
        return Self.cachePrefix + Data(composite.utf8).base64EncodedString()
    }

    private func logRequest(_ request: URLRequest) {
        logService.log("--- Penalties Request ---")
        logService.log("URL: \(request.url?.absoluteString ?? "—")")
        logService.log("Method: \(request.httpMethod ?? "—")")
        logService.log("------------------------")
    }

    private func resolvePenalties(data: Data, response: HTTPURLResponse, request: URLRequest) throws -> [PenaltyRecord] {
        switch response.statusCode {
        case 200...299:
            if data.isEmpty {
                return []
            }
            persistCache(data: data, for: request)
            return try decodePenaltyRecords(from: data)
        case 401:
            throw APIError.unauthorized(message: "Сессия истекла. Пожалуйста, выполните вход снова.")
        case 418:
            throw APIError.serviceUnavailable(message: "Сервис дисциплинарных взысканий временно недоступен")
        default:
            let serverMessage = String(data: data, encoding: .utf8) ?? "Неизвестная ошибка"
            throw APIError.serverError(statusCode: response.statusCode, message: serverMessage)
        }
    }

    private func resolveFallback(for request: URLRequest, error: APIError) throws -> [PenaltyRecord] {
        if let cached = tryDecodeCachedResponse(for: request, originalError: error.localizedDescription) {
            return cached
        }
        if case .networkError(let wrappedError) = error {
            logService.log("Penalties fetch error: \(wrappedError.localizedDescription)")
        }
        throw error
    }
}
