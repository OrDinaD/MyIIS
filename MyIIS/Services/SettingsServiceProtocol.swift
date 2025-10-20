//
//  SettingsServiceProtocol.swift
//  MyIIS
//
//  Created by ChatGPT on 2024-03-15.
//

import Foundation

@MainActor
protocol SettingsServiceProtocol: AnyObject {
    var currentUserSettings: UserSettings { get }
    var currentSecuritySettings: SecuritySettings { get }
    var currentNotificationSettings: NotificationSettings { get }

    func update(
        userSettings: UserSettings,
        security: SecuritySettings,
        notifications: NotificationSettings
    ) async throws

    func changePassword(currentPassword: String, newPassword: String) async throws
    func logout()
}
