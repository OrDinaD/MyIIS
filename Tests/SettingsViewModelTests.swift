import XCTest
@testable import MyIIS

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testNotificationToggleSave() async {
        let mockService = SettingsServiceMock(
            userSettings: UserSettings(isPublicProfile: true, isSearchJob: false, isShowRating: true),
            security: SecuritySettings(isTwoFactorEnabled: false),
            notifications: NotificationSettings(academicUpdates: false, eventsAndNews: false)
        )

        let viewModel = SettingsViewModel(service: mockService)
        XCTAssertFalse(viewModel.hasPendingChanges)

        viewModel.setToggle(for: .academicNotifications, to: true)
        XCTAssertTrue(viewModel.academicNotificationsEnabled)
        XCTAssertTrue(viewModel.hasPendingChanges)

        await viewModel.saveChanges()

        XCTAssertEqual(mockService.updateCallCount, 1)
        XCTAssertTrue(mockService.currentNotificationSettings.academicUpdates)
        XCTAssertFalse(viewModel.hasPendingChanges)
    }

    func testChangePasswordSuccess() async {
        let mockService = SettingsServiceMock()
        let viewModel = SettingsViewModel(service: mockService)

        await viewModel.changePassword(
            currentPassword: "Current123",
            newPassword: "NewPassword1",
            confirmPassword: "NewPassword1"
        )

        XCTAssertEqual(mockService.changePasswordCallCount, 1)
        XCTAssertEqual(viewModel.alert?.title, "Пароль обновлен")
        XCTAssertFalse(viewModel.isPresentingChangePasswordSheet)
    }
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
