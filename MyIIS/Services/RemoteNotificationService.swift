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
    private var registrationTask: Task<Void, Never>?
    private var registrationIdentity: String?
    private static let confirmedIdentityKey = "services.apns.confirmedIdentity"
    private static let confirmedAtKey = "services.apns.confirmedAt"

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
        Task { @MainActor in
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
                if granted { UIApplication.shared.registerForRemoteNotifications() }
            } catch {
                LogService.shared.log("APNs authorization request failed: \(error.localizedDescription)")
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

        let identity = [token, validGroup, environment].joined(separator: "|")
        if let currentTask = registrationTask {
            let currentIdentity = registrationIdentity
            await currentTask.value
            if currentIdentity == identity { return }
            if registrationIdentity == currentIdentity {
                registrationTask = nil
                registrationIdentity = nil
            }
            await registerOnGateway(token: token, targetGroup: validGroup)
            return
        }
        if defaults.string(forKey: Self.confirmedIdentityKey) == identity,
           let confirmedAt = defaults.object(forKey: Self.confirmedAtKey) as? Date,
           Date().timeIntervalSince(confirmedAt) < 24 * 60 * 60 {
            return
        }
        registrationIdentity = identity
        let task = Task { await sendRegistration(token: token, group: validGroup, environment: environment, identity: identity) }
        registrationTask = task
        await task.value
        if registrationIdentity == identity {
            registrationTask = nil
            registrationIdentity = nil
        }
    }

    private func sendRegistration(token: String, group: String, environment: String, identity: String) async {
        let payload = ["device_token": token, "group": group, "platform": "ios", "environment": environment]
        var request = URLRequest(url: Self.registrationEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        for attempt in 0..<3 {
            do {
                let (_, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { return }
                if (200...299).contains(http.statusCode) {
                    defaults.set(group, forKey: Self.registeredGroupDefaultsKey)
                    defaults.set(identity, forKey: Self.confirmedIdentityKey)
                    defaults.set(Date(), forKey: Self.confirmedAtKey)
                    return
                }
                LogService.shared.log("APNs gateway registration HTTP \(http.statusCode)")
                guard http.statusCode == 429 || http.statusCode >= 500 else { return }
            } catch {
                guard !Task.isCancelled, (error as? URLError)?.code != .cancelled else { return }
                LogService.shared.log("APNs gateway registration failed: \(error.localizedDescription)")
            }
            guard attempt < 2 else { return }
            do { try await Task.sleep(for: .seconds(attempt + 1)) } catch { return }
        }
    }

    /// Обработка входящего удаленного пуша (в том числе фонового Silent Push).
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        let targetGroup = userInfo["group"] as? String

        // Запускаем проверку обновлений расписания и объявлений
        let hasAlert = (userInfo["aps"] as? [String: Any])?["alert"] != nil
        let result = await ScheduleNotificationMonitorService.shared.checkForUpdates(
            forcedGroup: targetGroup, suppressLocalAlerts: hasAlert
        )

        #if canImport(WidgetKit)
        // Обновляем таймлайн виджетов расписания
        WidgetCenter.shared.reloadAllTimelines()
        #endif

        return result
    }
}
