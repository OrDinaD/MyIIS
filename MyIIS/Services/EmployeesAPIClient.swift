import Foundation

enum EmployeesAPIError: Error {
    case invalidURL
    case invalidResponse
    case badStatusCode(Int)
}

struct EmployeesAPIClient: Sendable {
    static let shared = EmployeesAPIClient()
    private let baseURL = "https://iis.bsuir.by/api/v1"

    func fetchDepartmentsTree() async throws -> [DepartmentTreeNodeDTO] {
        guard let url = URL(string: "\(baseURL)/departments/tree") else {
            throw EmployeesAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmployeesAPIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw EmployeesAPIError.badStatusCode(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode([DepartmentTreeNodeDTO].self, from: data)
    }

    func fetchEmployees(forDepartment urlId: String) async throws -> [EmployeeSummaryDTO] {
        guard var components = URLComponents(string: "\(baseURL)/employees") else {
            throw EmployeesAPIError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "departmentUrlId", value: urlId)]
        guard let url = components.url else { throw EmployeesAPIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmployeesAPIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw EmployeesAPIError.badStatusCode(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode([EmployeeSummaryDTO].self, from: data)
    }

    func fetchEmployeeDetails(urlId: String) async throws -> EmployeeDetailsDTO {
        guard var components = URLComponents(string: "\(baseURL)/employees/details-url") else {
            throw EmployeesAPIError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "urlId", value: urlId)]
        guard let url = components.url else { throw EmployeesAPIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmployeesAPIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw EmployeesAPIError.badStatusCode(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(EmployeeDetailsDTO.self, from: data)
    }
}
