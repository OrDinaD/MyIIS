//
//  AuthenticationService.swift
//  MyIIS
//
import Combine
import Foundation

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
    private let allowSessionRestore: Bool
    private static let isRunningInPreviews =
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    private static let isRunningUnitTests =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    private static let isRunningUITests =
        ProcessInfo.processInfo.arguments.contains("-ui_testing") || ProcessInfo.processInfo.arguments.contains("-UITesting")

    init(
        apiService: APIService? = nil,
        logService: LogService? = nil,
        allowSessionRestore: Bool = true
    ) {
        self.apiService = apiService ?? APIService()
        self.logService = logService ?? LogService.shared
        self.allowSessionRestore = allowSessionRestore

        if Self.isRunningUITests {
            self.currentUser = nil
            try? self.credentialStore.clear()
            self.clearCachedUser()
            UserDefaults.standard.set(true, forKey: "hasSeenLaunchReveal") // Пропускаем анимацию в UI тестах
        } else if let cachedUserData = UserDefaults.standard.data(forKey: Self.cachedUserDefaultsKey),
           let cachedUser = try? JSONDecoder().decode(User.self, from: cachedUserData) {
            self.currentUser = cachedUser
            self.logService.log("🔐 Restored cached user profile for \(cachedUser.fullName)")
        }

        guard allowSessionRestore, !Self.isRunningInPreviews, !Self.isRunningUnitTests, !Self.isRunningUITests else {
            self.logService.log("ℹ️ Session auto-restore skipped (preview, tests, or disabled).")
            return
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

            // Получаем профиль только через профильный endpoint
            logService.log("Fetching profile data...")
            let personalProfile = try await apiService.getPersonalProfile()
            logService.log("✅ Profile data received")

            // Создаём User из всех полученных данных
            let user = convertToUser(
                loginResponse: loginResponse,
                personalProfile: personalProfile
            )
            self.currentUser = user
            if !isSilent {
                AppRouter.shared.selectedTab = .home
            }
            cacheUser(user)
            MyIISDataStore.update(userGroup: user.education.group)

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
        personalProfile: PersonalProfile
    ) -> User {
        let nameComponents = loginResponse.fio.components(separatedBy: " ")
        let fallbackLastName = nameComponents.first ?? ""
        let fallbackFirstName = nameComponents.count > 1 ? nameComponents[1] : ""
        let fallbackMiddleName = nameComponents.count > 2 ? nameComponents[2] : ""

        let firstName = personalProfile.firstName ?? fallbackFirstName
        let lastName = personalProfile.lastName ?? fallbackLastName
        let middleName = personalProfile.middleName ?? fallbackMiddleName

        // Форматируем дату рождения из dd.MM.yyyy в человекочитаемый формат
        var formattedBirthDay = "Не указана"
        if let birthDate = personalProfile.birthDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yyyy"
            if let date = formatter.date(from: birthDate) {
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
            belarusianFirstName: personalProfile.belarusianFirstName,
            belarusianLastName: personalProfile.belarusianLastName,
            belarusianMiddleName: personalProfile.belarusianMiddleName,
            birthDay: formattedBirthDay,
            email: loginResponse.email,
            phone: loginResponse.phone,
            photo: personalProfile.photoUrl ?? loginResponse.photoUrl,
            summary: nil,
            rating: personalProfile.rating ?? 0,
            education: Education(
                faculty: personalProfile.faculty ?? loginResponse.group,
                course: personalProfile.course ?? 1,
                speciality: personalProfile.speciality ?? "Не указано",
                group: personalProfile.studentGroup ?? loginResponse.group,
                specialityDepartmentEducationFormId: nil
            ),
            skills: [], // Пока пустой массив - можно будет добавить позже
            references: [], // Пока пустой массив
            settings: .default
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
        MyIISDataStore.clear()
        logService.log("User logged out.")
    }
}
