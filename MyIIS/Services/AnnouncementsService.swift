import Foundation

protocol AnnouncementsServicing {
    func fetchCategories() async throws -> [AnnouncementCategory]
    func fetchAnnouncements(
        page: Int,
        pageSize: Int,
        categoryID: String?,
        onlyUnread: Bool,
        searchQuery: String?
    ) async throws -> AnnouncementPage
    func markAnnouncementsRead(ids: [String]) async throws
    func markAnnouncementRead(id: String) async throws
}

struct AnnouncementPage: Decodable, Equatable {
    let items: [Announcement]
    let page: Int
    let pageSize: Int
    let totalItems: Int
    let totalPages: Int

    var hasMore: Bool {
        guard totalPages > 0 else {
            return false
        }
        return page + 1 < totalPages
    }

    init(items: [Announcement], page: Int, pageSize: Int, totalItems: Int, totalPages: Int) {
        self.items = items
        self.page = page
        self.pageSize = pageSize
        self.totalItems = totalItems
        self.totalPages = totalPages
    }

    private enum CodingKeys: String, CodingKey {
        case items
        case content
        case page
        case pageNumber
        case pageSize
        case size
        case totalItems
        case totalElements
        case totalPages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let decodedItems = try container.decodeIfPresent([Announcement].self, forKey: .items) {
            items = decodedItems
        } else {
            items = try container.decodeIfPresent([Announcement].self, forKey: .content) ?? []
        }
        page = try container.decodeIfPresent(Int.self, forKey: .page)
            ?? container.decodeIfPresent(Int.self, forKey: .pageNumber)
            ?? 0
        pageSize = try container.decodeIfPresent(Int.self, forKey: .pageSize)
            ?? container.decodeIfPresent(Int.self, forKey: .size)
            ?? items.count
        totalItems = try container.decodeIfPresent(Int.self, forKey: .totalItems)
            ?? container.decodeIfPresent(Int.self, forKey: .totalElements)
            ?? items.count
        if let decodedTotalPages = try container.decodeIfPresent(Int.self, forKey: .totalPages) {
            totalPages = decodedTotalPages
        } else if pageSize > 0 {
            totalPages = Int(ceil(Double(totalItems) / Double(pageSize)))
        } else {
            totalPages = 0
        }
    }
}

enum AnnouncementsServiceError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case requestFailed(statusCode: Int, body: String?)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Некорректный URL для объявлений"
        case .invalidResponse:
            return "Сервер вернул некорректный ответ"
        case let .requestFailed(statusCode, body):
            if let body, !body.isEmpty {
                return "Ошибка сервера (\(statusCode)): \(body)"
            }
            return "Ошибка сервера (\(statusCode))"
        case .decodingFailed:
            return "Не удалось декодировать ответ сервера"
        }
    }
}

final class AnnouncementsService: AnnouncementsServicing {
    private let baseURL = URL(string: "https://iis.bsuir.by/api/v1")!
    private let session: URLSession
    private let logService: LogService

    init(session: URLSession = .shared, logService: LogService = .shared) {
        self.session = session
        self.logService = logService
    }

    func fetchCategories() async throws -> [AnnouncementCategory] {
        let endpoint = baseURL
            .appendingPathComponent("announcements")
            .appendingPathComponent("categories")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        logService.log("Запрос категорий объявлений")

        let (data, response) = try await session.data(for: request)
        _ = try validate(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            var categories = try decoder.decode([AnnouncementCategory].self, from: data)
            if categories.isEmpty {
                return [.all]
            }
            if let index = categories.firstIndex(where: { $0.id == AnnouncementCategory.all.id }) {
                let allCategory = categories.remove(at: index)
                categories.insert(allCategory, at: 0)
            } else {
                categories.insert(.all, at: 0)
            }
            var seen = Set<String>()
            let unique = categories.filter { category in
                let inserted = seen.insert(category.id).inserted
                return inserted
            }
            return unique
        } catch {
            logService.log("Ошибка декодирования категорий объявлений: \(error)")
            throw AnnouncementsServiceError.decodingFailed
        }
    }

    func fetchAnnouncements(
        page: Int,
        pageSize: Int,
        categoryID: String?,
        onlyUnread: Bool,
        searchQuery: String?
    ) async throws -> AnnouncementPage {
        guard var components = URLComponents(url: baseURL.appendingPathComponent("announcements"), resolvingAgainstBaseURL: false) else {
            throw AnnouncementsServiceError.invalidURL
        }

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "size", value: String(pageSize))
        ]

        if let categoryID, !categoryID.isEmpty, categoryID != AnnouncementCategory.all.id {
            queryItems.append(URLQueryItem(name: "categoryId", value: categoryID))
        }

        if onlyUnread {
            queryItems.append(URLQueryItem(name: "onlyUnread", value: "true"))
        }

        if let searchQuery, !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: searchQuery))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw AnnouncementsServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        logService.log("Загрузка объявлений: page=\(page), size=\(pageSize), category=\(categoryID ?? "-"), unread=\(onlyUnread)")

        let (data, response) = try await session.data(for: request)
        _ = try validate(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(AnnouncementPage.self, from: data)
        } catch {
            logService.log("Ошибка декодирования объявлений: \(error)")
            throw AnnouncementsServiceError.decodingFailed
        }
    }

    func markAnnouncementsRead(ids: [String]) async throws {
        guard !ids.isEmpty else {
            return
        }

        let endpoint = baseURL
            .appendingPathComponent("announcements")
            .appendingPathComponent("read")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["ids": ids], options: [])

        logService.log("Отметка объявлений прочитанными: \(ids.joined(separator: ", "))")

        let (data, response) = try await session.data(for: request)
        _ = try validate(response: response, data: data)
    }

    func markAnnouncementRead(id: String) async throws {
        try await markAnnouncementsRead(ids: [id])
    }

    private func validate(response: URLResponse, data: Data) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnnouncementsServiceError.invalidResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw AnnouncementsServiceError.requestFailed(statusCode: httpResponse.statusCode, body: body)
        }

        return httpResponse
    }
}
