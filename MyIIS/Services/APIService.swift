import Foundation

// MARK: - API Data Models

struct LoginRequest: Codable {
    let username: String
    let password: String
}

// Ответ от API, который содержит полный профиль студента
struct LoginResponse: Codable {
    let id: Int? 
    let username: String
    let fio: String
    let email: String?
    let photoUrl: String? // Декодируем как String, чтобы избежать ошибок парсинга URL
    let group: String?
    
    // Преобразуем `fio` в имя, фамилию и отчество
    var nameComponents: (lastName: String, firstName: String, middleName: String) {
        let components = fio.split(separator: " ").map(String.init)
        let lastName = components.first ?? ""
        let firstName = components.count > 1 ? components[1] : ""
        let middleName = components.count > 2 ? components[2] : ""
        return (lastName, firstName, middleName)
    }
}


// MARK: - API Service

@MainActor
class APIService {
    
    private let baseURL = URL(string: "https://iis.bsuir.by/api/v1")!
    private var session = URLSession.shared

    /// Выполняет вход и возвращает полную модель пользователя
    func login(username: String, password: String) async throws -> User {
        let loginRequest = LoginRequest(username: username, password: password)
        let loginURL = baseURL.appendingPathComponent("auth/login")
        
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(loginRequest)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            } else {
                throw APIError.serverError(httpResponse.statusCode)
            }
        }
        
        // Декодируем ответ напрямую в LoginResponse
        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        
        // Создаем и возвращаем модель User
        let name = loginResponse.nameComponents
        return User(
            id: UUID(), // API не возвращает UUID, генерируем свой
            username: loginResponse.username,
            firstName: name.firstName,
            lastName: name.lastName,
            middleName: name.middleName,
            email: loginResponse.email ?? "N/A",
            photoUrl: URL(string: loginResponse.photoUrl ?? ""),
            academicGroup: loginResponse.group
        )
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(Int)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Неверный URL"
        case .invalidResponse:
            return "Неверный ответ от сервера"
        case .unauthorized:
            return "Неверный логин или пароль"
        case .serverError(let code):
            return "Ошибка сервера: \(code)"
        case .decodingError(let error):
            return "Ошибка парсинга данных: \(error.localizedDescription)"
        case .networkError(let error):
            return "Сетевая ошибка: \(error.localizedDescription)"
        }
    }
}