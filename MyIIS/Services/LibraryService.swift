import Foundation

protocol LibraryServicing {
    func fetchCatalog(searchQuery: String?) async throws -> [LibraryItem]
    func fetchActiveLoans() async throws -> [BorrowHistoryEntry]
    func fetchBorrowHistory() async throws -> [BorrowHistoryEntry]
}

final class LibraryService: LibraryServicing {
    private let apiService: APIService
    private let logService = LogService.shared
    private let baseURL = URL(string: "https://iis.bsuir.by/api/v1/library")!

    init(apiService: APIService = APIService()) {
        self.apiService = apiService
    }

    func fetchCatalog(searchQuery: String?) async throws -> [LibraryItem] {
        var components = URLComponents(url: baseURL.appendingPathComponent("catalog"), resolvingAgainstBaseURL: false)
        if let query = searchQuery?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty {
            components?.queryItems = [URLQueryItem(name: "search", value: query)]
        }

        guard let url = components?.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        logService.log("Fetching library catalog with query: \(searchQuery ?? "")")

        let response: CatalogResponse = try await apiService.execute(request)
        return response.items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func fetchActiveLoans() async throws -> [BorrowHistoryEntry] {
        let endpoint = baseURL
            .appendingPathComponent("loans")
            .appendingPathComponent("active")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        logService.log("Fetching active library loans")

        let response: HistoryResponse = try await apiService.execute(request)
        let entries = response.items.filter { $0.isActive }
        return entries.sorted(by: { $0.borrowedAt > $1.borrowedAt })
    }

    func fetchBorrowHistory() async throws -> [BorrowHistoryEntry] {
        let endpoint = baseURL
            .appendingPathComponent("loans")
            .appendingPathComponent("history")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        logService.log("Fetching full borrow history")

        let response: HistoryResponse = try await apiService.execute(request)
        return response.items.sorted(by: { $0.borrowedAt > $1.borrowedAt })
    }
}

private struct CatalogResponse: Decodable {
    let items: [LibraryItem]

    init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer(),
           let array = try? singleValue.decode([LibraryItem].self) {
            self.items = array
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let items = try? container.decode([LibraryItem].self, forKey: .items) {
            self.items = items
        } else if let content = try? container.decode([LibraryItem].self, forKey: .content) {
            self.items = content
        } else {
            self.items = []
        }
    }

    private enum CodingKeys: String, CodingKey {
        case items
        case content
    }
}

private struct HistoryResponse: Decodable {
    let items: [BorrowHistoryEntry]

    init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer(),
           let array = try? singleValue.decode([BorrowHistoryEntry].self) {
            self.items = array
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let items = try? container.decode([BorrowHistoryEntry].self, forKey: .items) {
            self.items = items
        } else if let content = try? container.decode([BorrowHistoryEntry].self, forKey: .content) {
            self.items = content
        } else {
            self.items = []
        }
    }

    private enum CodingKeys: String, CodingKey {
        case items
        case content
    }
}
