import Foundation

protocol DiplomaServicing {
    func fetchDiplomaProgress(for userIdentifier: String) async throws -> DiplomaProgress
}

final class DiplomaService: DiplomaServicing {

    private let baseURL = URL(string: "https://iis.bsuir.by/api/v1")!
    private let session: URLSession
    private let logService = LogService.shared

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

            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                return try decoder.decode(DiplomaProgress.self, from: data)
            case 401:
                let message = try Self.decodeErrorMessage(from: data)
                throw APIError.unauthorized(message: message ?? "Требуется авторизация")
            case 503:
                let message = try Self.decodeErrorMessage(from: data)
                throw APIError.serviceUnavailable(message: message ?? "Сервис временно недоступен")
            default:
                let message = try Self.decodeErrorMessage(from: data)
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: message ?? "Неизвестная ошибка")
            }
        } catch let error as APIError {
            logService.log("❌ Diploma API error: \(error.localizedDescription)")
            throw error
        } catch {
            logService.log("❌ Diploma network error: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }
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
