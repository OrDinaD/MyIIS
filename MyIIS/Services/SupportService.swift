import Foundation

enum SupportAPIError: Error {
    case invalidURL
    case badRequest
    case unauthorized
    case notFound
    case invalidResponse
    case networkError(Error)
    case custom(String)
}

struct SupportAttachment {
    let filename: String
    let data: Data
    let mimeType: String
}

class SupportService {
    static let shared = SupportService()
    
    private let session: URLSession
    private let baseURL = URL(string: "https://iis.bsuir.by/api/v1")!
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func getCategories() async throws -> [BugReportCategoryDTO] {
        let url = baseURL.appendingPathComponent("bug-report/categories")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        
        let decoder = JSONDecoder()
        return try decoder.decode([BugReportCategoryDTO].self, from: data)
    }
    
    func autocomplete(request autocompleteReq: AutocompleteRequest) async throws -> AutocompleteResponse {
        let url = baseURL.appendingPathComponent("autocomplete")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(autocompleteReq)
        
        let (data, response) = try await session.data(for: request)
        if let httpRes = response as? HTTPURLResponse {
            if httpRes.statusCode == 401 {
                throw SupportAPIError.unauthorized
            } else if httpRes.statusCode == 404 {
                throw SupportAPIError.notFound
            }
        }
        try validateResponse(response)
        
        return try JSONDecoder().decode(AutocompleteResponse.self, from: data)
    }
    
    func autocompleteByPersonalInfo(request infoReq: AutocompletePersonalInfoRequest) async throws -> AutocompletePersonalInfoResponse {
        let url = baseURL.appendingPathComponent("autocomplete/by-personal-info")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(infoReq)
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        
        return try JSONDecoder().decode(AutocompletePersonalInfoResponse.self, from: data)
    }
    
    func searchDepartments(query: String) async throws -> [DepartmentFilterResponse] {
        var components = URLComponents(url: baseURL.appendingPathComponent("departments/filter"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "searchValue", value: query)]
        guard let url = components.url else { throw SupportAPIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        
        return try JSONDecoder().decode([DepartmentFilterResponse].self, from: data)
    }
    
    func searchAuditories(query: String) async throws -> [AuditoryFilterResponse] {
        var components = URLComponents(url: baseURL.appendingPathComponent("auditories/filter"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "searchValue", value: query)]
        guard let url = components.url else { throw SupportAPIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        
        return try JSONDecoder().decode([AuditoryFilterResponse].self, from: data)
    }
    
    func submitBugReport(parameters: [String: String], files: [SupportAttachment]) async throws {
        let url = baseURL.appendingPathComponent("bug-report")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        for (key, value) in parameters {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        for (index, file) in files.enumerated() {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"files[\(index)]\"; filename=\"\(file.filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(file.mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(file.data)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupportAPIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw SupportAPIError.badRequest
        }
    }
}
