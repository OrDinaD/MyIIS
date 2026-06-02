//
//  SettingsService.swift
//  MyIIS
//
import Combine
import Foundation

@MainActor
final class SettingsService: SettingsServiceProtocol, ObservableObject {
    static let shared = SettingsService()

    private let authenticationService: AuthenticationService
    private let logService = LogService.shared

    @Published private(set) var storedUserSettings: UserSettings
    @Published private(set) var storedSecuritySettings: SecuritySettings
    @Published private(set) var storedNotificationSettings: NotificationSettings

    init(authenticationService: AuthenticationService? = nil) {
        self.authenticationService = authenticationService ?? .shared
        let userSettings = self.authenticationService.currentUser?.settings ?? .default
        self.storedUserSettings = userSettings
        self.storedSecuritySettings = .default
        self.storedNotificationSettings = .default
    }

    var currentUserSettings: UserSettings { storedUserSettings }
    var currentSecuritySettings: SecuritySettings { storedSecuritySettings }
    var currentNotificationSettings: NotificationSettings { storedNotificationSettings }

    func update(
        userSettings: UserSettings,
        security: SecuritySettings,
        notifications: NotificationSettings
    ) async throws {
        logService.log("SettingsService: updating settings...")
        try await simulateNetworkDelay()

        storedUserSettings = userSettings
        storedSecuritySettings = security
        storedNotificationSettings = notifications

        if let currentUser = authenticationService.currentUser {
            authenticationService.currentUser = currentUser.updatingSettings(userSettings)
        }

        logService.log("SettingsService: settings updated")
    }

    func changePassword(currentPassword: String, newPassword: String) async throws {
        logService.log("SettingsService: changing password")

        guard !currentPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SettingsError.invalidCurrentPassword
        }

        guard validatePasswordStrength(newPassword) else {
            throw SettingsError.weakPassword
        }

        try await simulateNetworkDelay()

        logService.log("SettingsService: password changed successfully")
    }

    func logout() {
        logService.log("SettingsService: logging out")
        authenticationService.logout()
    }

    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: 150_000_000)
    }

    private func validatePasswordStrength(_ password: String) -> Bool {
        guard password.count >= 8 else { return false }

        let uppercase = CharacterSet.uppercaseLetters
        let lowercase = CharacterSet.lowercaseLetters
        let digits = CharacterSet.decimalDigits

        let hasUppercase = password.rangeOfCharacter(from: uppercase) != nil
        let hasLowercase = password.rangeOfCharacter(from: lowercase) != nil
        let hasDigit = password.rangeOfCharacter(from: digits) != nil

        return hasUppercase && hasLowercase && hasDigit
    }
}
