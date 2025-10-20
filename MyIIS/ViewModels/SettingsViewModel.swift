//
//  SettingsViewModel.swift
//  MyIIS
//
//  Created by ChatGPT on 2024-03-15.
//

import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var isPublicProfile: Bool
    @Published var isJobSearchEnabled: Bool
    @Published var isRatingVisible: Bool
    @Published var isTwoFactorEnabled: Bool
    @Published var academicNotificationsEnabled: Bool
    @Published var eventNotificationsEnabled: Bool

    @Published var isSaving: Bool = false
    @Published var isProcessingPasswordChange: Bool = false
    @Published var hasPendingChanges: Bool = false
    @Published var isPresentingChangePasswordSheet: Bool = false
    @Published var alert: AlertItem?
    @Published var didLogout: Bool = false

    private let service: SettingsServiceProtocol
    private var originalUserSettings: UserSettings
    private var originalSecuritySettings: SecuritySettings
    private var originalNotificationSettings: NotificationSettings

    struct AlertItem: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    init(service: SettingsServiceProtocol = SettingsService.shared) {
        self.service = service

        let userSettings = service.currentUserSettings
        let securitySettings = service.currentSecuritySettings
        let notificationSettings = service.currentNotificationSettings

        self.isPublicProfile = userSettings.isPublicProfile
        self.isJobSearchEnabled = userSettings.isSearchJob
        self.isRatingVisible = userSettings.isShowRating
        self.isTwoFactorEnabled = securitySettings.isTwoFactorEnabled
        self.academicNotificationsEnabled = notificationSettings.academicUpdates
        self.eventNotificationsEnabled = notificationSettings.eventsAndNews

        self.originalUserSettings = userSettings
        self.originalSecuritySettings = securitySettings
        self.originalNotificationSettings = notificationSettings

        evaluatePendingChanges()
    }

    let sections: [SettingsSection] = SettingsSection.allCases

    func items(for section: SettingsSection) -> [SettingsItem] {
        SettingsItem.allCases.filter { $0.section == section }
    }

    func setToggle(for item: SettingsItem, to newValue: Bool) {
        switch item {
        case .publicProfile:
            isPublicProfile = newValue
        case .jobSearch:
            isJobSearchEnabled = newValue
        case .showRating:
            isRatingVisible = newValue
        case .twoFactorAuth:
            isTwoFactorEnabled = newValue
        case .academicNotifications:
            academicNotificationsEnabled = newValue
        case .eventNotifications:
            eventNotificationsEnabled = newValue
        case .changePassword, .logout:
            break
        }

        evaluatePendingChanges()
    }

    func saveChanges() async {
        guard !isSaving else { return }

        isSaving = true
        defer { isSaving = false }

        let userSettings = UserSettings(
            isPublicProfile: isPublicProfile,
            isSearchJob: isJobSearchEnabled,
            isShowRating: isRatingVisible
        )
        let securitySettings = SecuritySettings(isTwoFactorEnabled: isTwoFactorEnabled)
        let notificationSettings = NotificationSettings(
            academicUpdates: academicNotificationsEnabled,
            eventsAndNews: eventNotificationsEnabled
        )

        do {
            try await service.update(
                userSettings: userSettings,
                security: securitySettings,
                notifications: notificationSettings
            )

            originalUserSettings = userSettings
            originalSecuritySettings = securitySettings
            originalNotificationSettings = notificationSettings

            evaluatePendingChanges()
            alert = AlertItem(title: "Готово", message: "Настройки успешно сохранены")
        } catch {
            handleError(error)
        }
    }

    func presentChangePassword() {
        isPresentingChangePasswordSheet = true
    }

    func changePassword(currentPassword: String, newPassword: String, confirmPassword: String) async {
        guard !isProcessingPasswordChange else { return }

        guard newPassword == confirmPassword else {
            alert = AlertItem(title: "Ошибка", message: SettingsError.passwordsDoNotMatch.errorDescription ?? "Пароли не совпадают")
            return
        }

        isProcessingPasswordChange = true
        defer { isProcessingPasswordChange = false }

        do {
            try await service.changePassword(currentPassword: currentPassword, newPassword: newPassword)
            alert = AlertItem(title: "Пароль обновлен", message: "Пароль успешно изменен")
            isPresentingChangePasswordSheet = false
        } catch {
            handleError(error)
        }
    }

    func logout() {
        service.logout()
        didLogout = true
    }

    private func evaluatePendingChanges() {
        let currentUserSettings = UserSettings(
            isPublicProfile: isPublicProfile,
            isSearchJob: isJobSearchEnabled,
            isShowRating: isRatingVisible
        )
        let currentSecuritySettings = SecuritySettings(isTwoFactorEnabled: isTwoFactorEnabled)
        let currentNotificationSettings = NotificationSettings(
            academicUpdates: academicNotificationsEnabled,
            eventsAndNews: eventNotificationsEnabled
        )

        hasPendingChanges =
            currentUserSettings != originalUserSettings ||
            currentSecuritySettings != originalSecuritySettings ||
            currentNotificationSettings != originalNotificationSettings
    }

    private func handleError(_ error: Error) {
        if let settingsError = error as? SettingsError {
            alert = AlertItem(title: "Ошибка", message: settingsError.errorDescription ?? "Произошла ошибка")
        } else {
            alert = AlertItem(title: "Ошибка", message: error.localizedDescription)
        }
    }
}

private extension SettingsItem {
    static var allCases: [SettingsItem] {
        [
            .publicProfile,
            .jobSearch,
            .showRating,
            .changePassword,
            .twoFactorAuth,
            .academicNotifications,
            .eventNotifications,
            .logout
        ]
    }
}
