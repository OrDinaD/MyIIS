import Foundation

protocol PenaltiesServicing {
    func fetchPenalties() async throws -> [PenaltyRecord]
}

final class PenaltiesService: PenaltiesServicing {
    private let baseURL: URL
    private let session: URLSession
    private let logService = LogService.shared

    init(
        baseURL: URL = URL(string: "https://iis.bsuir.by/api/v1")!,
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

            switch httpResponse.statusCode {
            case 200...299:
                if data.isEmpty {
                    return []
                }
                let decoder = JSONDecoder()
                return try decoder.decode([PenaltyRecord].self, from: data)
            case 204:
                return []
            case 401:
                throw APIError.unauthorized(message: "Сессия истекла. Пожалуйста, выполните вход снова.")
            case 418:
                throw APIError.serviceUnavailable(message: "Сервис дисциплинарных взысканий временно недоступен")
            default:
                let serverMessage = String(data: data, encoding: .utf8) ?? "Неизвестная ошибка"
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: serverMessage)
            }
        } catch let apiError as APIError {
            throw apiError
        } catch {
            logService.log("Penalties fetch error: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }
    }

    private func logRequest(_ request: URLRequest) {
        logService.log("--- Penalties Request ---")
        logService.log("URL: \(request.url?.absoluteString ?? "—")")
        logService.log("Method: \(request.httpMethod ?? "—")")
        logService.log("------------------------")
    }
}
