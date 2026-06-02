import Foundation

protocol DormitoryServicing {
    func fetchApplications() async throws -> [DormitoryQueueApplication]
    func fetchPrivilegeRecords() async throws -> [DormitoryPrivilegeRecord]
    func downloadDocument(forRequestID requestID: Int, suggestedFileName: String?) async throws -> URL
}

enum DormitoryServiceError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case forbidden
    case downloadFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Не удалось сформировать запрос к сервису общежития."
        case .invalidResponse:
            return "Получен некорректный ответ сервера при загрузке документа."
        case .forbidden:
            return "Нет доступа к документу. Попробуйте заново войти в аккаунт."
        case .downloadFailed(let statusCode):
            return "Не удалось загрузить документ (код \(statusCode))."
        }
    }
}

final class DormitoryService: DormitoryServicing {
    private let baseURL = URLFactory.require("https://iis.bsuir.by/api/v1")
    private let apiService: APIService

    init(apiService: APIService = APIService()) {
        self.apiService = apiService
    }

    func fetchApplications() async throws -> [DormitoryQueueApplication] {
        let endpoint = baseURL.appendingPathComponent("dormitory-queue-application")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        return try await apiService.execute(request)
    }

    func fetchPrivilegeRecords() async throws -> [DormitoryPrivilegeRecord] {
        let endpoint = baseURL
            .appendingPathComponent("dormitory-queue-application")
            .appendingPathComponent("privileges")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        return try await apiService.execute(request)
    }

    func downloadDocument(forRequestID requestID: Int, suggestedFileName: String?) async throws -> URL {
        guard let url = Self.documentURL(forRequestID: requestID) else {
            throw DormitoryServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DormitoryServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 403:
            throw DormitoryServiceError.forbidden
        default:
            throw DormitoryServiceError.downloadFailed(statusCode: httpResponse.statusCode)
        }

        let fileName = resolvedFileName(
            from: httpResponse,
            fallback: suggestedFileName ?? "dormitory_document_\(requestID)"
        )

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(fileName)

        try FileManager.default.createDirectory(
            at: tempURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: tempURL, options: [.atomic])
        return tempURL
    }

    static func documentURL(forRequestID requestID: Int) -> URL? {
        var components = URLComponents(string: "https://iis.bsuir.by/api/v1/dormitory-queue-application/download-document-by-request-id")
        components?.queryItems = [
            URLQueryItem(name: "request-id", value: String(requestID))
        ]
        return components?.url
    }

    private func resolvedFileName(from response: HTTPURLResponse, fallback: String) -> String {
        guard
            let contentDisposition = response.value(forHTTPHeaderField: "Content-Disposition"),
            let range = contentDisposition.range(of: "filename=", options: .caseInsensitive)
        else {
            return fallback
        }

        let raw = String(contentDisposition[range.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))

        return raw.isEmpty ? fallback : raw
    }
}

#if DEBUG
final class DormitoryPreviewService: DormitoryServicing {
    func fetchApplications() async throws -> [DormitoryQueueApplication] {
        DormitoryQueueApplication.preview
    }

    func fetchPrivilegeRecords() async throws -> [DormitoryPrivilegeRecord] {
        DormitoryPrivilegeRecord.preview
    }

    func downloadDocument(forRequestID requestID: Int, suggestedFileName: String?) async throws -> URL {
        let fileName = suggestedFileName ?? "document-\(requestID).jpg"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        if !FileManager.default.fileExists(atPath: url.path) {
            try Data("Preview".utf8).write(to: url)
        }
        return url
    }
}
#endif
