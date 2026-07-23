import Foundation
import UniformTypeIdentifiers

protocol DormitoryServicing {
    func fetchApplications() async throws -> [DormitoryQueueApplication]
    func fetchPrivilegeRecords() async throws -> [DormitoryPrivilegeRecord]
    func createApplication(documentURL: URL?) async throws -> DormitoryQueueApplication
    func updateApplication(_ application: DormitoryQueueApplication, documentAction: DormitoryDocumentUpdateAction) async throws -> DormitoryQueueApplication
    func downloadDocument(forRequestID requestID: Int, suggestedFileName: String?) async throws -> URL
    func downloadApplicationForm(forApplicationID applicationID: Int) async throws -> URL
}

enum DormitoryServiceError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case forbidden
    case downloadFailed(statusCode: Int)
    case fileReadFailed

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
        case .fileReadFailed:
            return "Не удалось прочитать выбранный файл."
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

    func createApplication(documentURL: URL?) async throws -> DormitoryQueueApplication {
        let endpoint = baseURL
            .appendingPathComponent("dormitory-queue-application")
            .appendingPathComponent("create")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"

        if let documentURL {
            let dataURL = try dataURLString(for: documentURL)
            request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data(dataURL.utf8)
        }

        return try await apiService.execute(request)
    }

    func updateApplication(
        _ application: DormitoryQueueApplication,
        documentAction: DormitoryDocumentUpdateAction
    ) async throws -> DormitoryQueueApplication {
        let endpoint = baseURL
            .appendingPathComponent("dormitory-queue-application")
            .appendingPathComponent("update")

        let docContent: String?
        switch documentAction {
        case .unchanged:
            docContent = nil
        case .remove:
            docContent = "empty"
        case .replace(let url):
            docContent = try dataURLString(for: url)
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(application.updatePayload(docContent: docContent))

        return try await apiService.execute(request)
    }

    func downloadDocument(forRequestID requestID: Int, suggestedFileName: String?) async throws -> URL {
        guard let url = Self.documentURL(forRequestID: requestID) else {
            throw DormitoryServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        return try await downloadFile(
            request,
            fallbackFileName: suggestedFileName ?? "dormitory_document_\(requestID)"
        )
    }

    func downloadApplicationForm(forApplicationID applicationID: Int) async throws -> URL {
        guard let url = Self.applicationFormURL(forApplicationID: applicationID) else {
            throw DormitoryServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", forHTTPHeaderField: "Accept")

        return try await downloadFile(request, fallbackFileName: "Заявление.xlsx")
    }

    static func documentURL(forRequestID requestID: Int) -> URL? {
        var components = URLComponents(string: "https://iis.bsuir.by/api/v1/dormitory-queue-application/download-document-by-request-id")
        components?.queryItems = [
            URLQueryItem(name: "request-id", value: String(requestID))
        ]
        return components?.url
    }

    static func applicationFormURL(forApplicationID applicationID: Int) -> URL? {
        var components = URLComponents(string: "https://iis.bsuir.by/api/v1/dormitory-queue-application/download-excel-by-application-id")
        components?.queryItems = [
            URLQueryItem(name: "dormitory-queue-id", value: String(applicationID))
        ]
        return components?.url
    }

    private func downloadFile(_ request: URLRequest, fallbackFileName: String) async throws -> URL {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DormitoryServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ... 299:
            break
        case 403:
            throw DormitoryServiceError.forbidden
        default:
            throw DormitoryServiceError.downloadFailed(statusCode: httpResponse.statusCode)
        }

        let fileName = resolvedFileName(from: httpResponse, fallback: fallbackFileName)
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

    private func dataURLString(for fileURL: URL) throws -> String {
        let didAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: fileURL) else {
            throw DormitoryServiceError.fileReadFailed
        }

        let mimeType = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType
            ?? "application/octet-stream"
        return "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    private func resolvedFileName(from response: HTTPURLResponse, fallback: String) -> String {
        if let fileName = response.value(forHTTPHeaderField: "file-name"), !fileName.isEmpty {
            return fileName.removingPercentEncoding ?? fileName
        }

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

    func createApplication(documentURL: URL?) async throws -> DormitoryQueueApplication {
        DormitoryQueueApplication.preview[0]
    }

    func updateApplication(
        _ application: DormitoryQueueApplication,
        documentAction: DormitoryDocumentUpdateAction
    ) async throws -> DormitoryQueueApplication {
        application
    }

    func downloadDocument(forRequestID requestID: Int, suggestedFileName: String?) async throws -> URL {
        let fileName = suggestedFileName ?? "document-\(requestID).jpg"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        if !FileManager.default.fileExists(atPath: url.path) {
            try Data("Preview".utf8).write(to: url)
        }
        return url
    }

    func downloadApplicationForm(forApplicationID applicationID: Int) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Заявление-\(applicationID).xlsx")
        if !FileManager.default.fileExists(atPath: url.path) {
            try Data().write(to: url)
        }
        return url
    }
}
#endif
