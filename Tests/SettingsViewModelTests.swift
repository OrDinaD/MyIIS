import Foundation

struct SettingsViewModelTestFailure: Error {
    let message: String
}

@MainActor
final class SettingsServiceMock: SettingsServiceProtocol {
    var currentUserSettings: UserSettings
    var currentSecuritySettings: SecuritySettings
    var currentNotificationSettings: NotificationSettings

    private(set) var updateCallCount = 0
    private(set) var changePasswordCallCount = 0
    private(set) var logoutCallCount = 0

    var changePasswordError: Error?

    init(
        userSettings: UserSettings = .default,
        security: SecuritySettings = .default,
        notifications: NotificationSettings = .default
    ) {
        self.currentUserSettings = userSettings
        self.currentSecuritySettings = security
        self.currentNotificationSettings = notifications
    }

    func update(userSettings: UserSettings, security: SecuritySettings, notifications: NotificationSettings) async throws {
        updateCallCount += 1
        currentUserSettings = userSettings
        currentSecuritySettings = security
        currentNotificationSettings = notifications
    }

    func changePassword(currentPassword: String, newPassword: String) async throws {
        changePasswordCallCount += 1
        if let error = changePasswordError {
            throw error
        }
    }

    func logout() {
        logoutCallCount += 1
    }
}

@main
enum SettingsViewModelTests {
    static func main() async {
        do {
            try await testNotificationToggleSave()
            try await testChangePasswordSuccess()
            print("SettingsViewModel tests passed")
        } catch {
            fputs("SettingsViewModel tests failed: \(error)\n", stderr)
            exit(1)
        }
    }

    static func assert(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String) throws {
        if !condition() {
            throw SettingsViewModelTestFailure(message: message())
        }
    }

    static func testNotificationToggleSave() async throws {
        let mockService = SettingsServiceMock(
            userSettings: UserSettings(isPublicProfile: true, isSearchJob: false, isShowRating: true),
            security: SecuritySettings(isTwoFactorEnabled: false),
            notifications: NotificationSettings(academicUpdates: false, eventsAndNews: false)
        )

        let viewModel = SettingsViewModel(service: mockService)
        try assert(viewModel.hasPendingChanges == false, "Не должно быть несохраненных изменений сразу после инициализации")

        viewModel.setToggle(for: .academicNotifications, to: true)
        try assert(viewModel.academicNotificationsEnabled == true, "Переключатель уведомлений должен стать активным")
        try assert(viewModel.hasPendingChanges == true, "После изменения настроек должно появиться несохраненное состояние")

        await viewModel.saveChanges()

        try assert(mockService.updateCallCount == 1, "Ожидалось одно обновление настроек")
        try assert(mockService.currentNotificationSettings.academicUpdates == true, "Сервис должен получить обновленное значение уведомлений")
        try assert(viewModel.hasPendingChanges == false, "После сохранения несохраненные изменения должны исчезнуть")
    }

    static func testChangePasswordSuccess() async throws {
        let mockService = SettingsServiceMock()
        let viewModel = SettingsViewModel(service: mockService)

        await viewModel.changePassword(currentPassword: "Current123", newPassword: "NewPassword1", confirmPassword: "NewPassword1")

        try assert(mockService.changePasswordCallCount == 1, "Метод смены пароля должен вызываться")
        try assert(viewModel.alert?.title == "Пароль обновлен", "После успешной смены пароля должно показываться подтверждение")
        try assert(viewModel.isPresentingChangePasswordSheet == false, "Лист смены пароля должен закрываться")
    }
}
