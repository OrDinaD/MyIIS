import Combine
import Foundation

@MainActor
final class DisciplinesService: ObservableObject {
    static let shared = DisciplinesService()

    @Published var disciplines: [DisciplineListEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let baseURL = URLFactory.require("https://iis.bsuir.by/api/v1")
    private let session: URLSession
    private let decoder = JSONDecoder()

    private init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchDisciplines(sdefId: Int, course: Int, term: Int?, isForeign: Bool = false) async {
        isLoading = true
        errorMessage = nil
        disciplines = []
        defer { isLoading = false }

        var queryItems = [
            URLQueryItem(name: "id", value: String(sdefId)),
            URLQueryItem(name: "course", value: String(course)),
            URLQueryItem(name: "isForeign", value: String(isForeign))
        ]

        if let term {
            queryItems.append(URLQueryItem(name: "term", value: String(term)))
        }

        do {
            let response: [DisciplineListEntry] = try await performGet(
                path: ["list-disciplines"],
                queryItems: queryItems
            )
            disciplines = response
        } catch is CancellationError {
            return
        } catch {
            disciplines = []
            errorMessage = userFacingMessage(for: error)
        }
    }

    func reset() {
        disciplines = []
        errorMessage = nil
        isLoading = false
    }

    private func performGet<T: Decodable>(
        path: [String],
        queryItems: [URLQueryItem]
    ) async throws -> T {
        var endpoint = baseURL
        for component in path {
            endpoint.appendPathComponent(component)
        }

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DisciplinesServiceError.badResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw DisciplinesServiceError.server(statusCode: httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw DisciplinesServiceError.decoding(error)
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        switch error {
        case let serviceError as DisciplinesServiceError:
            return serviceError.localizedDescription
        case let urlError as URLError where urlError.code == .notConnectedToInternet:
            return "Нет подключения к интернету. Проверьте сеть и повторите попытку."
        case let urlError as URLError where urlError.code == .timedOut:
            return "Сервер не ответил вовремя. Попробуйте ещё раз."
        default:
            return "Не удалось загрузить список дисциплин. Попробуйте ещё раз."
        }
    }
}

private enum DisciplinesServiceError: LocalizedError {
    case badResponse
    case server(statusCode: Int)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .badResponse:
            return "IIS вернул некорректный ответ."
        case .server(let statusCode):
            return "Сервер IIS вернул ошибку \(statusCode)."
        case .decoding:
            return "Ответ IIS со списком дисциплин имеет неожиданный формат."
        }
    }
}
