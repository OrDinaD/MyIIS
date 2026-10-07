//
//  ScheduleNotificationMonitorService.swift
//  MyIIS
//

import Foundation
import UserNotifications

/// Сервис мониторинга изменений в расписании и объявлений группы с отправкой локальных уведомлений.
@MainActor
final class ScheduleNotificationMonitorService: NSObject {
    static let shared = ScheduleNotificationMonitorService()

    static let scheduleChangesEnabledKey = "services.schedule.notifications.scheduleChanges"
    static let announcementsEnabledKey = "services.schedule.notifications.announcements"
    private static let lastScheduleHashKey = "services.schedule.notifications.lastHash"
    private static let seenAnnouncementIDsKey = "services.schedule.notifications.seenAnnouncements"
    private static let lastCheckTimestampKey = "services.schedule.notifications.lastCheck"

    private let defaults: UserDefaults
    private let api: ServiceEndpointsAPI
    private let notificationCenter = UNUserNotificationCenter.current()

    init(
        defaults: UserDefaults? = nil,
        api: ServiceEndpointsAPI = ServiceEndpointsAPI()
    ) {
        self.defaults = defaults ?? (UserDefaults(suiteName: AppGroup.identifier) ?? .standard)
        self.api = api
        super.init()
    }

    var isScheduleChangesEnabled: Bool {
        get {
            if defaults.object(forKey: Self.scheduleChangesEnabledKey) == nil {
                return true
            }
            return defaults.bool(forKey: Self.scheduleChangesEnabledKey)
        }
        set {
            defaults.set(newValue, forKey: Self.scheduleChangesEnabledKey)
            if newValue {
                Task { await requestAuthorization() }
            }
        }
    }

    var isAnnouncementsEnabled: Bool {
        get {
            if defaults.object(forKey: Self.announcementsEnabledKey) == nil {
                return true
            }
            return defaults.bool(forKey: Self.announcementsEnabledKey)
        }
        set {
            defaults.set(newValue, forKey: Self.announcementsEnabledKey)
            if newValue {
                Task { await requestAuthorization() }
            }
        }
    }

    /// Запрос разрешения на отправку локальных уведомлений.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Проверка изменений для текущей группы пользователя.
    func checkForUpdates(forcedGroup: String? = nil) async {
        guard isScheduleChangesEnabled || isAnnouncementsEnabled else { return }

        let targetGroup = forcedGroup
            ?? AuthenticationService.shared.currentUser?.education.group
            ?? defaults.string(forKey: "services.schedule.lastGroup")

        guard let group = targetGroup?.trimmingCharacters(in: .whitespacesAndNewlines), !group.isEmpty else {
            return
        }

        if isScheduleChangesEnabled {
            await checkScheduleChanges(for: group)
        }

        if isAnnouncementsEnabled {
            await checkGroupAnnouncements(for: group)
        }

        defaults.set(Date(), forKey: Self.lastCheckTimestampKey)
    }

    // MARK: - Schedule Changes Check

    private func checkScheduleChanges(for group: String) async {
        do {
            let response = try await api.fetchGroupSchedule(groupNumber: group, preferCachedResponse: false)
            let newHash = Self.computeScheduleSignature(response)
            let previousHash = defaults.string(forKey: "\(Self.lastScheduleHashKey).\(group)")

            if let previousHash, !previousHash.isEmpty, previousHash != newHash {
                // Найдено изменение в расписании!
                let content = UNMutableNotificationContent()
                content.title = NSLocalizedString("schedule_change_alert_title", value: "Изменение в расписании", comment: "")
                content.body = String(
                    format: NSLocalizedString(
                        "schedule_change_alert_body",
                        value: "Обновлено расписание занятий для группы %@. Проверьте актуальные аудитории.",
                        comment: ""
                    ),
                    group
                )
                content.sound = .default
                content.badge = 1

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "schedule_change_\(group)_\(Date().timeIntervalSince1970)",
                    content: content,
                    trigger: trigger
                )
                try? await notificationCenter.add(request)
            }

            defaults.set(newHash, forKey: "\(Self.lastScheduleHashKey).\(group)")
        } catch {
            // Игнорируем сетевые ошибки при фоновой проверке
        }
    }

    // MARK: - Announcements Check

    private func checkGroupAnnouncements(for group: String) async {
        do {
            let announcements = try await api.fetchAnnouncements(groupNumber: group)
            guard !announcements.isEmpty else { return }

            var seenIDs = Set(defaults.stringArray(forKey: "\(Self.seenAnnouncementIDsKey).\(group)") ?? [])
            let isFirstRun = seenIDs.isEmpty

            for item in announcements {
                let id = item.stableID
                if !seenIDs.contains(id) {
                    seenIDs.insert(id)
                    if !isFirstRun {
                        // Отправляем уведомление о новом объявлении
                        let content = UNMutableNotificationContent()
                        content.title = String(
                            format: NSLocalizedString(
                                "group_announcement_alert_title",
                                value: "Объявление для группы %@",
                                comment: ""
                            ),
                            group
                        )
                        content.body = item.primaryText
                        content.sound = .default

                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                        let request = UNNotificationRequest(
                            identifier: "announcement_\(id)",
                            content: content,
                            trigger: trigger
                        )
                        try? await notificationCenter.add(request)
                    }
                }
            }

            defaults.set(Array(seenIDs), forKey: "\(Self.seenAnnouncementIDsKey).\(group)")
        } catch {
            // Игнорируем ошибки сети
        }
    }

    // MARK: - Signature Helpers

    static func computeScheduleSignature(_ schedule: PublicScheduleResponse) -> String {
        var items: [String] = []
        for day in schedule.orderedDays {
            for lesson in day.lessons {
                let lessonSig = "\(day.weekday.rawValue)_\(lesson.startLessonTime)_\(lesson.subject)_\(lesson.auditories.joined(separator: ","))_\(lesson.lessonTypeAbbrev)"
                items.append(lessonSig)
            }
        }
        return items.sorted().joined(separator: ";")
    }
}
