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
    let specialityDepartmentEducationFormId: Int?
    let specialityName: String
    let specialityAbbrev: String
    let course: Int
    let id: Int?
    let educationDegree: Int?
}

// Упрощённая структура для передачи данных
struct ScheduleInfo {
    let facultyAbbrev: String
    let facultyName: String
    let specialityAbbrev: String
    let specialityName: String
    let course: Int
    let specialityDepartmentEducationFormId: Int?
    let studentGroupId: Int?
    let educationDegree: Int?
}

struct OmissionApplication: Decodable, Identifiable {
    let id: Int
    let status: String
    let number: Int
    let createdDate: Date
    let rejectionReason: String?
    let omissionCertificateType: String
    let dateFrom: Date
    let dateTo: Date
    let placeOfStay: String?
    let signature: String?

    private enum CodingKeys: String, CodingKey {
        case id, status, number, rejectionReason, omissionCertificateType, placeOfStay, signature
        case createdDate, dateFrom, dateTo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        status = try container.decode(String.self, forKey: .status)
        number = try container.decode(Int.self, forKey: .number)
        rejectionReason = try container.decodeIfPresent(String.self, forKey: .rejectionReason)
        omissionCertificateType = try container.decode(String.self, forKey: .omissionCertificateType)
        placeOfStay = try container.decodeIfPresent(String.self, forKey: .placeOfStay)
        signature = try container.decodeIfPresent(String.self, forKey: .signature)
        createdDate = try container.decodeMillisecondsDate(forKey: .createdDate)
        dateFrom = try container.decodeMillisecondsDate(forKey: .dateFrom)
        dateTo = try container.decodeMillisecondsDate(forKey: .dateTo)
    }
}

struct OmissionCertificate: Decodable, Identifiable {
    let id: Int
    let dateFrom: Date
    let dateTo: Date
    let note: String?
    let name: String
    let term: String

    private enum CodingKeys: String, CodingKey {
        case id, note, name, term
        case dateFrom, dateTo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        name = try container.decode(String.self, forKey: .name)
        term = try container.decode(String.self, forKey: .term)
        dateFrom = try container.decodeMillisecondsDate(forKey: .dateFrom)
        dateTo = try container.decodeMillisecondsDate(forKey: .dateTo)
    }
}

struct OmissionsByStudentResponse: Decodable {
    let omissionDtoList: [OmissionCertificate]
    let faculty: String
}

struct MonthlyOmissionCount: Decodable, Identifiable {
    let month: String
    let omissionCount: Int

    var id: String { month }
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
            course: dto.course,
            specialityDepartmentEducationFormId: dto.specialityDepartmentEducationFormId,
            studentGroupId: dto.id,
            educationDegree: dto.educationDegree
        )
    }

    /// Получение полного учебного плана группы со списком дисциплин и расписанием
    /// - Parameter group: Номер учебной группы
    /// - Returns: Структура StudyPlan с данными расписания
    func getStudyPlan(for group: String) async throws -> StudyPlan {
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

        return try await performRequest(request)
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

    /// Получение рейтинга студентов по номеру группы
    /// - Parameter group: Номер учебной группы
    /// - Returns: Список студентов с показателями рейтинга
    func getRating(group: String) async throws -> [StudentRating] {
        let trimmedGroup = group.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGroup.isEmpty else {
            throw APIError.serverError(statusCode: 400, message: "Не указан номер группы")
        }

        guard let scheduleInfo = try await getScheduleInfo(group: trimmedGroup),
              let specialityId = scheduleInfo.specialityDepartmentEducationFormId else {
            throw APIError.serverError(
                statusCode: 400,
                message: "Не удалось определить данные специальности для группы \(trimmedGroup)"
            )
        }

        return try await getRatingDirect(specialityId: specialityId, course: scheduleInfo.course)
    }

    /// Оптимизированное получение рейтинга напрямую с параметрами
    /// Используется когда specialityId и course уже известны (например, из кэша User)
    /// - Parameters:
    ///   - specialityId: ID формы обучения специальности
    ///   - course: Номер курса
    /// - Returns: Список студентов с показателями рейтинга
    func getRatingDirect(specialityId: Int, course: Int) async throws -> [StudentRating] {
        var urlComponents = URLComponents(
            url: baseURL.appendingPathComponent("rating"),
            resolvingAgainstBaseURL: false
        )
        urlComponents?.queryItems = [
            URLQueryItem(name: "sdef", value: "\(specialityId)"),
            URLQueryItem(name: "course", value: "\(course)")
        ]

        guard let url = urlComponents?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        logRequestDetails(request)

        let remoteRatings: [RemoteStudentRating] = try await performRequest(request)
        return remoteRatings.map { $0.toStudentRating() }
    }

    private struct RemoteStudentRating: Decodable {
        let studentCardNumber: String
        let average: Double?
        let hours: Int?
        let averageShift: Double?
        let checkpoints: [RatingCheckpoint]

        enum CodingKeys: String, CodingKey {
            case studentCardNumber
            case average
            case hours
            case averageShift
            case firstAverage, firstHours
            case secondAverage, secondHours
            case thirdAverage, thirdHours
            case fourthAverage, fourthHours
            case fifthAverage, fifthHours
            case sixthAverage, sixthHours
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            studentCardNumber = try container.decode(String.self, forKey: .studentCardNumber)
            average = try container.decodeIfPresent(Double.self, forKey: .average)
            hours = try container.decodeIfPresent(Int.self, forKey: .hours)
            averageShift = try container.decodeIfPresent(Double.self, forKey: .averageShift)

            let descriptor: [(CodingKeys, CodingKeys, Int)] = [
                (.firstAverage, .firstHours, 1),
                (.secondAverage, .secondHours, 2),
                (.thirdAverage, .thirdHours, 3),
                (.fourthAverage, .fourthHours, 4),
                (.fifthAverage, .fifthHours, 5),
                (.sixthAverage, .sixthHours, 6)
            ]

            checkpoints = try descriptor.compactMap { averageKey, hoursKey, number in
                let avg = try container.decodeIfPresent(Double.self, forKey: averageKey)
                let missed = try container.decodeIfPresent(Int.self, forKey: hoursKey)
                if avg == nil && missed == nil {
                    return nil
                }
                return RatingCheckpoint(number: number, averageGrade: avg, missedHours: missed)
            }
        }

        func toStudentRating() -> StudentRating {
            StudentRating(
                recordBookNumber: studentCardNumber,
                studentName: nil,
                averageGrade: average,
                missedHours: hours,
                averageShift: averageShift,
                checkpoints: checkpoints
            )
        }
    }

    /// Заявки на пропуски по ОРВИ (ОРН)
    func getOmissionApplications() async throws -> [OmissionApplication] {
        let endpoint = baseURL.appendingPathComponent("omissions-by-student-application")
        let request = URLRequest(url: endpoint)
        logRequestDetails(request)
        return try await performRequest(request)
    }

    /// Количество пропусков студента по месяцам семестра
    func getMonthlyOmissionCounts() async throws -> [MonthlyOmissionCount] {
        let endpoint = baseURL.appendingPathComponent("omission-count-by-student-for-semester")
        let request = URLRequest(url: endpoint)
        logRequestDetails(request)
        return try await performRequest(request)
    }

    /// Информация о справках и пропусках по уважительной причине
    func getOmissionsByStudent() async throws -> OmissionsByStudentResponse {
        let endpoint = baseURL.appendingPathComponent("omissions-by-student")
        let request = URLRequest(url: endpoint)
        logRequestDetails(request)
        return try await performRequest(request)
    }

    func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        try await performRequest(request)
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

private extension KeyedDecodingContainer {
    func decodeMillisecondsDate(forKey key: K) throws -> Date {
        let timestamp = try decode(Double.self, forKey: key)
        return Date(timeIntervalSince1970: timestamp / 1000)
    }
}
