//
//  RemoteNotificationService.swift
//  MyIIS
//

import Foundation
import UIKit
import UserNotifications
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Сервис регистрации и обработки удаленных пуш-уведомлений Apple (APNs).
@MainActor
final class RemoteNotificationService: NSObject {
    static let shared = RemoteNotificationService()

    static let deviceTokenDefaultsKey = "services.apns.deviceToken"
    static let registeredGroupDefaultsKey = "services.apns.registeredGroup"
    static let registrationEndpoint = URL(string: "https://bsuir.ordinad.xyz/api/v1/notifications/register")!

    private let defaults: UserDefaults
    private let session: URLSession

    init(
        defaults: UserDefaults? = nil,
        session: URLSession = .shared
    ) {
        self.defaults = defaults ?? (UserDefaults(suiteName: AppGroup.identifier) ?? .standard)
        self.session = session
        super.init()
    }

    /// Текущий сохраненный APNs токен устройства в hex-формате.
    var currentDeviceToken: String? {
        defaults.string(forKey: Self.deviceTokenDefaultsKey)
    }

    /// Последняя группа, для которой был зарегистрирован токен.
    var lastRegisteredGroup: String? {
        defaults.string(forKey: Self.registeredGroupDefaultsKey)
    }

    /// Запрос разрешения на уведомления и регистрация устройства в APNs.
    func requestAuthorizationAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            Task { @MainActor in
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    /// Обработка успешного получения APNs токена от iOS.
    func handleDeviceToken(_ deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        defaults.set(tokenString, forKey: Self.deviceTokenDefaultsKey)

        Task {
            await registerOnGateway(token: tokenString)
        }
    }

    /// Отправляет токен на сервер для текущей группы пользователя (или принудительно переданной).
    func registerOnGateway(token: String? = nil, targetGroup: String? = nil) async {
        guard let token = token ?? currentDeviceToken, !token.isEmpty else { return }

        let group = targetGroup
            ?? AuthenticationService.shared.currentUser?.education.group
            ?? defaults.string(forKey: "services.schedule.lastGroup")

        guard let validGroup = group?.trimmingCharacters(in: .whitespacesAndNewlines), !validGroup.isEmpty else {
            return
        }

        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif

        let payload: [String: Any] = [
            "device_token": token,
            "group": validGroup,
            "platform": "ios",
            "environment": environment
        ]

        var request = URLRequest(url: Self.registrationEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                defaults.set(validGroup, forKey: Self.registeredGroupDefaultsKey)
            }
        } catch {
            // Игнорируем сетевые сбои регистрации токена (повторится при следующем запуске)
        }
    }

    /// Обработка входящего удаленного пуша (в том числе фонового Silent Push).
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        let targetGroup = userInfo["group"] as? String

        // Запускаем проверку обновлений расписания и объявлений
        await ScheduleNotificationMonitorService.shared.checkForUpdates(forcedGroup: targetGroup)

        #if canImport(WidgetKit)
        // Обновляем таймлайн виджетов расписания
        WidgetCenter.shared.reloadAllTimelines()
        #endif

        return .newData
    }
}
