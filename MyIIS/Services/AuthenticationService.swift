
//
//  AuthenticationService.swift
//  MyIIS
//
//  Created by Gemini on 13.10.25.
//

import Foundation
import Combine

@MainActor
class AuthenticationService: ObservableObject {
    
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    static let shared = AuthenticationService()
    
    private let apiService = APIService()
    private let logService = LogService.shared
    private var token: String?
    
    private init() {}
    
    func login(username: String, password: String) async {
        logService.log("Attempting to log in user: \(username)")
        isLoading = true
        errorMessage = nil
        
        do {
            logService.log("Sending login request to API...")
            let loginResponse = try await apiService.login(username: username, password: password)
            logService.log("✅ Successfully logged in!")
            
            // Получаем дополнительные данные профиля
            logService.log("Fetching additional profile data...")
            let personalInfo = try await apiService.getPersonalInformation()
            logService.log("✅ Personal information received")
            
            // Получаем данные из расписания (для факультета и специальности)
            logService.log("Fetching schedule to get faculty/speciality data...")
            let scheduleInfo = try await apiService.getScheduleInfo(group: loginResponse.group)
            logService.log("✅ Schedule information received")
            
            // Создаём User из всех полученных данных
            let user = convertToUser(
                loginResponse: loginResponse,
                personalInfo: personalInfo,
                scheduleInfo: scheduleInfo
            )
            self.currentUser = user
            logService.log("✅ User profile loaded: \(user.fullName)")
            
        } catch let error as APIError {
            self.errorMessage = error.localizedDescription
            logService.log("❌ API Error: \(error.localizedDescription)")
        } catch {
            self.errorMessage = "Произошла непредвиденная ошибка."
            logService.log("❌ Unexpected Error: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Конвертирует данные из API в модель User
    private func convertToUser(
        loginResponse: LoginResponse,
        personalInfo: PersonalInformation,
        scheduleInfo: ScheduleInfo?
    ) -> User {
        // Парсим ФИО
        let nameComponents = loginResponse.fio.components(separatedBy: " ")
        let lastName = nameComponents.first ?? ""
        let firstName = nameComponents.count > 1 ? nameComponents[1] : ""
        let middleName = nameComponents.count > 2 ? nameComponents[2] : ""
        
        // Форматируем дату рождения (если есть)
        var formattedBirthDay = "Не указана"
        if let birthDay = personalInfo.birthDay {
            // Конвертируем из формата ISO (yyyy-MM-dd) в читаемый
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: birthDay) {
                formatter.dateFormat = "d MMMM yyyy"
                formatter.locale = Locale(identifier: "ru_RU")
                formattedBirthDay = formatter.string(from: date)
            }
        }
        
        return User(
            id: Int(loginResponse.username) ?? 0,
            firstName: firstName,
            lastName: lastName,
            middleName: middleName,
            birthDay: formattedBirthDay,
            email: loginResponse.email,
            phone: loginResponse.phone,
            photo: loginResponse.photoUrl,
            summary: personalInfo.summary,
            rating: personalInfo.rating ?? 0,
            education: Education(
                faculty: scheduleInfo?.facultyAbbrev ?? loginResponse.group,
                course: personalInfo.course ?? 1,
                speciality: scheduleInfo?.specialityAbbrev ?? "Не указано",
                group: loginResponse.group
            ),
            skills: [], // Пока пустой массив - можно будет добавить позже
            references: [], // Пока пустой массив
            settings: UserSettings(
                isPublicProfile: personalInfo.settings?.isPublicProfile ?? true,
                isSearchJob: personalInfo.settings?.isSearchJob ?? false,
                isShowRating: personalInfo.settings?.isShowRating ?? false
            )
        )
    }
    func logout() {
        self.currentUser = nil
        self.token = nil
        logService.log("User logged out.")
    }
}
