import Foundation

// MARK: - API Data Models

struct LoginRequest: Codable {
    let username: String
    let password: String
}

// Реальный ответ от API БГУИР при логине
struct LoginResponse: Codable {
    let username: String
    let fio: String
    let email: String
    let authorities: [String]
    let accountType: String
    let phone: String
    let group: String
    let photoUrl: String?
    let isGroupHead: Bool
    let canStudentNote: Bool
    let hasNotConfirmedContact: Bool
    let hasProfiling: Bool
}

// Дополнительная информация о пользователе из /personal-information
struct PersonalInformation: Codable {
    let degree: Int?
    let email: String?
    let phone: String?
    let course: Int?
    let enablePractice: Bool?
    let practiceType: String?
    let kt: Bool?
    let re: Bool?
    let graduating: Bool?
    let summary: String?
    let rating: Int?
    let birthDay: String? // Формат: "yyyy-MM-dd"
    let settings: PersonalSettings?
}

struct PersonalSettings: Codable {
    let isPublicProfile: Bool
    let isSearchJob: Bool
    let isShowRating: Bool
}

// Информация из расписания группы
struct ScheduleResponse: Codable {
    let studentGroupDto: StudentGroupDto?
}

struct StudentGroupDto: Codable {
    let name: String
    let facultyId: Int
    let facultyAbbrev: String
    let facultyName: String
    let specialityName: String
    let specialityAbbrev: String
    let course: Int
}

// Упрощённая структура для передачи данных
struct ScheduleInfo {
    let facultyAbbrev: String
    let facultyName: String
    let specialityAbbrev: String
    let specialityName: String
    let course: Int
}

struct ErrorResponse: Codable {
    let msg: String
}

// MARK: - API Service

class APIService {

    private let baseURL = URL(string: "https://iis.bsuir.by/api/v1")!
    private let session = URLSession.shared
    private let logService = LogService.shared

    /// Аутентификация пользователя
    /// - Parameters:
    ///   - username: Логин пользователя
    ///   - password: Пароль пользователя
        /// - Returns: LoginResponse с данными пользователя
    func login(username: String, password: String) async throws -> LoginResponse {
            // Правильный путь: /auth/login
            let endpoint = baseURL.appendingPathComponent("auth").appendingPathComponent("login")
        let loginRequest = LoginRequest(username: username, password: password)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(loginRequest)

        logRequestDetails(request)

        return try await performRequest(request)
    }

    /// Получение дополнительной информации о пользователе
    /// Требует SESSION cookie (автоматически отправляется после логина)
    /// - Returns: PersonalInformation с дополнительными данными
    func getPersonalInformation() async throws -> PersonalInformation {
        let endpoint = baseURL.appendingPathComponent("personal-information")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        
        logRequestDetails(request)
        
        return try await performRequest(request)
    }
    
    /// Получение информации о факультете и специальности из расписания группы
    /// - Parameter group: Номер группы (например, "420603")
    /// - Returns: ScheduleInfo с данными о факультете и специальности
    func getScheduleInfo(group: String) async throws -> ScheduleInfo? {
        // Добавляем query параметр studentGroup
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("schedule"), resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = [
            URLQueryItem(name: "studentGroup", value: group)
        ]
        
        guard let url = urlComponents?.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        logRequestDetails(request)
        
        let scheduleResponse: ScheduleResponse = try await performRequest(request)
        
        // Преобразуем в упрощённую структуру
        guard let dto = scheduleResponse.studentGroupDto else {
            return nil
        }
        
        return ScheduleInfo(
            facultyAbbrev: dto.facultyAbbrev,
            facultyName: dto.facultyName,
            specialityAbbrev: dto.specialityAbbrev,
            specialityName: dto.specialityName,
            course: dto.course
        )
    }

    /// Получение зачётной книжки студента
    /// - Parameter studentId: Идентификатор студента (обычно совпадает с username)
    /// - Returns: Структура Gradebook с семестрами, дисциплинами и попытками
    func getGradebook(for studentId: String) async throws -> Gradebook {
        let endpoint = baseURL
            .appendingPathComponent("gradebook")
            .appendingPathComponent(studentId)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        logRequestDetails(request)

        let gradebook: Gradebook = try await performRequest(request)
        return gradebook.normalized()
    }

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            
            // Логируем ответ
            if let responseString = String(data: data, encoding: .utf8) {
                logService.log("Response Data: \(responseString)")
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            logService.log("Status Code: \(httpResponse.statusCode)")

            // Обработка различных кодов ответа
            switch httpResponse.statusCode {
            case 200...299:
                // Успешный ответ
                do {
                    let decoder = JSONDecoder()
                    return try decoder.decode(T.self, from: data)
                } catch {
                    logService.log("❌ Decoding Error: \(error)")
                    throw APIError.decodingError(error)
                }
                
            case 401:
                // Неверные учетные данные
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    logService.log("❌ 401 Unauthorized: \(errorResponse.msg)")
                    throw APIError.unauthorized(message: errorResponse.msg)
                } else {
                    throw APIError.unauthorized(message: "Неверный логин или пароль")
                }
                
            case 418:
                // IIS недоступен
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    logService.log("❌ 418 IIS Unavailable: \(errorResponse.msg)")
                    throw APIError.serviceUnavailable(message: errorResponse.msg)
                } else {
                    throw APIError.serviceUnavailable(message: "Сервис ИИС недоступен")
                }
                
            default:
                // Другие ошибки сервера
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    logService.log("❌ Server Error \(httpResponse.statusCode): \(errorResponse.msg)")
                    throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorResponse.msg)
                } else {
                    throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Ошибка сервера")
                }
            }
        } catch let error as APIError {
            throw error
        } catch {
            logService.log("❌ Network Error: \(error)")
            throw APIError.networkError(error)
        }
    }
    
    private func logRequestDetails(_ request: URLRequest) {
        logService.log("--- New Request ---")
        if let url = request.url?.absoluteString {
            logService.log("URL: \(url)")
        }
        if let method = request.httpMethod {
            logService.log("Method: \(method)")
        }
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            logService.log("Headers: \(headers)")
        }
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            logService.log("Body: \(bodyString)")
        }
        logService.log("------------------")
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized(message: String)
    case serviceUnavailable(message: String)
    case serverError(statusCode: Int, message: String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Неверный URL"
        case .invalidResponse:
            return "Неверный ответ от сервера"
        case .unauthorized(let message):
            return message
        case .serviceUnavailable(let message):
            return message
        case .serverError(let code, let message):
            return "Ошибка сервера (\(code)): \(message)"
        case .decodingError(let error):
            return "Ошибка парсинга данных: \(error.localizedDescription)"
        case .networkError(let error):
            return "Сетевая ошибка: \(error.localizedDescription)"
        }
    }
}
