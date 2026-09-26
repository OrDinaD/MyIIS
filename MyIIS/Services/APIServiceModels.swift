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

// Профиль пользователя из /profiles/personal-profile
struct PersonalProfile: Codable {
    let firstName: String?
    let lastName: String?
    let middleName: String?
    let belarusianFirstName: String?
    let belarusianLastName: String?
    let belarusianMiddleName: String?
    let birthDate: String? // Формат: "dd.MM.yyyy"
    let photoUrl: String?
    let course: Int?
    let faculty: String?
    let speciality: String?
    let studentGroup: String?
    let rating: Int?
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
