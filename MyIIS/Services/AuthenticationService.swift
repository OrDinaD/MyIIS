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
    @Published private(set) var isRestoringSession = false
    @Published private(set) var isSessionReady = false

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
    private static let isRunningScreenshotTests =
        isRunningUITests && ProcessInfo.processInfo.environment["UI_SCREENSHOT_MODE"] == "1"

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
            UserDefaults.standard.set(true, forKey: FirstLaunchView.completionKey)

            if Self.isRunningScreenshotTests {
                Task { [weak self] in
                    await self?.login(
                        username: APIService.demoUsername,
                        password: APIService.demoPassword,
                        persistCredentials: false
                    )
                }
            }
        } else if let cachedUserData = UserDefaultsPayloadStore.load(forKey: Self.cachedUserDefaultsKey, from: UserDefaults.standard),
           let cachedUser = try? JSONDecoder().decode(User.self, from: cachedUserData) {
            self.currentUser = cachedUser
            self.isSessionReady = true
            self.logService.log("🔐 Restored cached user profile for \(cachedUser.fullName)")
        }

        guard allowSessionRestore, !Self.isRunningInPreviews, !Self.isRunningUnitTests, !Self.isRunningUITests else {
            self.logService.log("ℹ️ Session auto-restore skipped (preview, tests, or disabled).")
            return
        }

        self.isRestoringSession = true
        Task { [weak self] in
            await self?.restoreSessionIfPossible()
        }
    }

    func checkServerStatus() async -> Bool {
        do {
            let request = URLRequest(url: URL(string: "https://iis.bsuir.by/api/v1/faculties")!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5.0)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return (200 ... 299).contains(httpResponse.statusCode)
            }
            return false
        } catch {
            return false
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
        let hasCachedSession = isSilent && currentUser != nil
        isSessionReady = hasCachedSession
        errorMessage = nil
        var didAuthenticateWithServer = false

        do {
            logService.log("Sending login request to API...")
            let loginResponse = try await apiService.login(username: username, password: password)
            didAuthenticateWithServer = true
            logService.log("✅ Successfully logged in!")

            if hasCachedSession {
                isSessionReady = true
                isRestoringSession = false
            }

            logService.log("Fetching profile data...")
            let personalProfile = try await apiService.getPersonalProfile()
            logService.log("✅ Profile data received")
            completeLogin(
                loginResponse: loginResponse,
                personalProfile: personalProfile,
                credentials: StoredCredentials(username: username, password: password),
                persistCredentials: persistCredentials,
                isSilent: isSilent
            )
        } catch let error as APIError {
            handleLoginAPIError(
                error,
                hasCachedSession: hasCachedSession,
                didAuthenticateWithServer: didAuthenticateWithServer,
                isSilent: isSilent
            )
        } catch {
            handleUnexpectedLoginError(error, hasCachedSession: hasCachedSession)
        }

        isLoading = false
        isRestoringSession = false
    }

    func restoreSessionIfPossible() async {
        guard !isLoading else {
            isRestoringSession = false
            return
        }

        do {
            guard let credentials = try credentialStore.retrieve() else {
                logService.log("ℹ️ No stored credentials found for auto-login.")
                isSessionReady = currentUser != nil
                isRestoringSession = false
                return
            }

            logService.log("🔁 Attempting silent login with stored credentials.")
            await login(
                username: credentials.username,
                password: credentials.password,
                persistCredentials: false,
                isSilent: true
            )
        } catch {
            isSessionReady = currentUser != nil
            isRestoringSession = false
            logService.log("⚠️ Failed to access stored credentials: \(error.localizedDescription)")
        }
    }

    private func completeLogin(
        loginResponse: LoginResponse,
        personalProfile: PersonalProfile,
        credentials: StoredCredentials,
        persistCredentials: Bool,
        isSilent: Bool
    ) {
        let user = convertToUser(
            loginResponse: loginResponse,
            personalProfile: personalProfile
        )
        currentUser = user
        isSessionReady = true

        if !isSilent {
            AppRouter.shared.selectedTab = AppRouter.isSectionOrTabEnabled("home") ? .home : .profile
        }

        cacheUser(user)
        MyIISDataStore.update(userGroup: user.education.group)

        if persistCredentials {
            do {
                try credentialStore.save(credentials)
                logService.log("🔒 Credentials saved to Keychain.")
            } catch {
                logService.log("⚠️ Failed to store credentials: \(error.localizedDescription)")
            }
        }

        logService.log("✅ User profile loaded: \(user.fullName)")
        AcademicChangeNotificationService.shared.checkWhenAppBecomesActive()
    }

    private func handleLoginAPIError(
        _ error: APIError,
        hasCachedSession: Bool,
        didAuthenticateWithServer: Bool,
        isSilent: Bool
    ) {
        logService.log("❌ API Error: \(error.localizedDescription)")

        guard case .unauthorized = error else {
            if hasCachedSession {
                keepCachedSession(after: error)
            } else {
                isSessionReady = false
                errorMessage = error.localizedDescription
            }
            return
        }

        if hasCachedSession, didAuthenticateWithServer {
            keepCachedSession(after: error)
            return
        }

        isSessionReady = false
        errorMessage = error.localizedDescription
        currentUser = nil

        if isSilent {
            try? credentialStore.clear()
            clearCachedUser()
        }
    }

    private func handleUnexpectedLoginError(_ error: Error, hasCachedSession: Bool) {
        if hasCachedSession {
            keepCachedSession(after: error)
        } else {
            isSessionReady = false
            errorMessage = NSLocalizedString("common_unexpected_error", comment: "")
        }
        logService.log("❌ Unexpected Error: \(error.localizedDescription)")
    }

    private func keepCachedSession(after error: Error) {
        isSessionReady = true
        errorMessage = nil
        logService.log(
            "⚠️ Keeping cached session after background refresh failed: \(error.localizedDescription)"
        )
    }

    private func cacheUser(_ user: User) {
        guard let encoded = try? JSONEncoder().encode(user) else {
            logService.log("⚠️ Failed to encode user for caching.")
            return
        }

        UserDefaultsPayloadStore.save(encoded, forKey: Self.cachedUserDefaultsKey, in: UserDefaults.standard)
    }

    private func clearCachedUser() {
        UserDefaultsPayloadStore.clear(forKey: Self.cachedUserDefaultsKey, from: UserDefaults.standard)
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
        var formattedBirthDay = NSLocalizedString("common_not_specified_feminine", comment: "")
        if let birthDate = personalProfile.birthDate {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "dd.MM.yyyy"
            if let date = formatter.date(from: birthDate) {
                formatter.locale = .autoupdatingCurrent
                formatter.dateFormat = "d MMMM yyyy"
                formattedBirthDay = formatter.string(from: date)
            }
        }

        return User(
            id: Int(loginResponse.username) ?? (APIService.isDemoMode ? 1 : 0),
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
                speciality: personalProfile.speciality ?? NSLocalizedString("common_not_specified_neuter", comment: ""),
                group: personalProfile.studentGroup ?? loginResponse.group,
                specialityDepartmentEducationFormId: nil
            ),
            skills: [], // Пока пустой массив - можно будет добавить позже
            references: [], // Пока пустой массив
            settings: .default,
            isHeadman: loginResponse.isGroupHead,
            canStudentNote: loginResponse.canStudentNote
        )
    }
    func logout() {
        self.currentUser = nil
        self.token = nil
        self.isSessionReady = false
        self.isRestoringSession = false
        APIService.resetDemoMode()
        APIService.clearResponseCache()
        AppRouter.shared.resetForLogout()
        clearCachedUser()

        do {
            try credentialStore.clear()
            logService.log("🔓 Stored credentials cleared.")
        } catch {
            logService.log("⚠️ Failed to clear stored credentials: \(error.localizedDescription)")
        }

        AttendanceWidgetDataStore.clear()
        MyIISDataStore.clear()
        UserDefaultsPayloadStore.clearAll()
        logService.log("User logged out.")
    }
}
