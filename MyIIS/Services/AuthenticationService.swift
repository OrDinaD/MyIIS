
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
    
    private let apiService: APIService
    private let logService: LogService
    private let credentialStore = CredentialStore.shared
    private static let cachedUserDefaultsKey = "MyIIS.cachedUser"
    private var token: String?
    
    init(apiService: APIService = APIService(), logService: LogService = .shared) {
        self.apiService = apiService
        self.logService = logService

        if let cachedUserData = UserDefaults.standard.data(forKey: Self.cachedUserDefaultsKey),
           let cachedUser = try? JSONDecoder().decode(User.self, from: cachedUserData) {
            self.currentUser = cachedUser
            logService.log("🔐 Restored cached user profile for \(cachedUser.fullName)")
        }

        Task { [weak self] in
            await self?.restoreSessionIfPossible()
        }
    }
    
    func login(
        username: String,
        password: String,
        persistCredentials: Bool = true,
        isSilent: Bool = false
    ) async {
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
            cacheUser(user)

            if persistCredentials {
                do {
                    try credentialStore.save(StoredCredentials(username: username, password: password))
                    logService.log("🔒 Credentials saved to Keychain.")
                } catch {
                    logService.log("⚠️ Failed to store credentials: \(error.localizedDescription)")
                }
            }

            logService.log("✅ User profile loaded: \(user.fullName)")
            
        } catch let error as APIError {
            self.errorMessage = error.localizedDescription
            logService.log("❌ API Error: \(error.localizedDescription)")

            if case .unauthorized = error {
                currentUser = nil
            }

            if isSilent, case .unauthorized = error {
                try? credentialStore.clear()
                clearCachedUser()
            }
        } catch {
            self.errorMessage = "Произошла непредвиденная ошибка."
            logService.log("❌ Unexpected Error: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func restoreSessionIfPossible() async {
        guard !isLoading else { return }
        
        do {
            guard let credentials = try credentialStore.retrieve() else {
                logService.log("ℹ️ No stored credentials found for auto-login.")
                return
            }
            
            logService.log("🔁 Attempting silent login with stored credentials.")
            await login(
                username: credentials.username,
                password: credentials.password,
                persistCredentials: true,
                isSilent: true
            )
        } catch {
            logService.log("⚠️ Failed to access stored credentials: \(error.localizedDescription)")
        }
    }
    
    private func cacheUser(_ user: User) {
        guard let encoded = try? JSONEncoder().encode(user) else {
            logService.log("⚠️ Failed to encode user for caching.")
            return
        }
        
        UserDefaults.standard.set(encoded, forKey: Self.cachedUserDefaultsKey)
    }
    
    private func clearCachedUser() {
        UserDefaults.standard.removeObject(forKey: Self.cachedUserDefaultsKey)
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
                group: loginResponse.group,
                specialityDepartmentEducationFormId: scheduleInfo?.specialityDepartmentEducationFormId
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
        clearCachedUser()
        
        do {
            try credentialStore.clear()
            logService.log("🔓 Stored credentials cleared.")
        } catch {
            logService.log("⚠️ Failed to clear stored credentials: \(error.localizedDescription)")
        }
        
        AttendanceWidgetDataStore.clear()
        logService.log("User logged out.")
    }
}
