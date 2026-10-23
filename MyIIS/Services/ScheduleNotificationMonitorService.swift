//
//  ScheduleNotificationMonitorService.swift
//  MyIIS
//

import CryptoKit
import Foundation
import UIKit
import UserNotifications

/// Сервис мониторинга изменений в расписании и объявлений группы с отправкой локальных уведомлений.
@MainActor
final class ScheduleNotificationMonitorService: NSObject {
    static let shared = ScheduleNotificationMonitorService()

    static let scheduleChangesEnabledKey = "services.schedule.notifications.scheduleChanges"
    static let announcementsEnabledKey = "services.schedule.notifications.announcements"
    private static let lastScheduleHashKey = "services.schedule.notifications.lastHash.v2"
    private static let seenAnnouncementIDsKey = "services.schedule.notifications.seenAnnouncements"
    private static let lastCheckTimestampKey = "services.schedule.notifications.lastCheck"

    private let defaults: UserDefaults
    private let api: ServiceEndpointsAPI
    private var inFlightChecks: [String: Task<UIBackgroundFetchResult, Never>] = [:]
    private var lastChecks: [String: Date] = [:]
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
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            if granted { UIApplication.shared.registerForRemoteNotifications() }
            return granted
        } catch {
            return false
        }
    }

    /// Проверка изменений для текущей группы пользователя.
    @discardableResult
    func checkForUpdates(
        forcedGroup: String? = nil,
        suppressLocalAlerts: Bool = false
    ) async -> UIBackgroundFetchResult {
        guard isScheduleChangesEnabled || isAnnouncementsEnabled else { return .noData }

        let targetGroup = forcedGroup
            ?? AuthenticationService.shared.currentUser?.education.group
            ?? defaults.string(forKey: "services.schedule.lastGroup")

        guard let group = targetGroup?.trimmingCharacters(in: .whitespacesAndNewlines), !group.isEmpty else {
            return .noData
        }
        if let task = inFlightChecks[group] { return await task.value }
        if forcedGroup == nil, let lastCheck = lastChecks[group], Date().timeIntervalSince(lastCheck) < 60 {
            return .noData
        }
        let task = Task { await performCheck(for: group, suppressLocalAlerts: suppressLocalAlerts) }
        inFlightChecks[group] = task
        let result = await task.value
        inFlightChecks[group] = nil
        if result != .failed { lastChecks[group] = Date() }
        return result
    }

    private func performCheck(for group: String, suppressLocalAlerts: Bool) async -> UIBackgroundFetchResult {
        var results: [UIBackgroundFetchResult] = []
        if isScheduleChangesEnabled {
            results.append(await checkScheduleChanges(for: group, suppressLocalAlerts: suppressLocalAlerts))
        }

        if isAnnouncementsEnabled {
            results.append(await checkGroupAnnouncements(for: group, suppressLocalAlerts: suppressLocalAlerts))
        }

        defaults.set(Date(), forKey: Self.lastCheckTimestampKey)
        if results.contains(.newData) { return .newData }
        return results.contains(.failed) ? .failed : .noData
    }

    // MARK: - Schedule Changes Check

    private func checkScheduleChanges(for group: String, suppressLocalAlerts: Bool) async -> UIBackgroundFetchResult {
        do {
            let response = try await api.fetchGroupSchedule(groupNumber: group, preferCachedResponse: false)
            let newHash = Self.computeScheduleSignature(response)
            let previousHash = defaults.string(forKey: "\(Self.lastScheduleHashKey).\(group)")

            if !suppressLocalAlerts, let previousHash, !previousHash.isEmpty, previousHash != newHash {
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
            return previousHash == newHash ? .noData : .newData
        } catch {
            return .failed
        }
    }

    // MARK: - Announcements Check

    private func checkGroupAnnouncements(for group: String, suppressLocalAlerts: Bool) async -> UIBackgroundFetchResult {
        do {
            let announcements = try await api.fetchAnnouncements(groupNumber: group)
            guard !announcements.isEmpty else { return .noData }

            var seenIDs = Set(defaults.stringArray(forKey: "\(Self.seenAnnouncementIDsKey).\(group)") ?? [])
            let isFirstRun = seenIDs.isEmpty
            let previousIDs = seenIDs

            for item in announcements {
                let id = item.stableID
                if !seenIDs.contains(id) {
                    seenIDs.insert(id)
                    if !isFirstRun, !suppressLocalAlerts {
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
            return previousIDs == seenIDs ? .noData : .newData
        } catch {
            return .failed
        }
    }

    // MARK: - Signature Helpers

    static func computeScheduleSignature(_ schedule: PublicScheduleResponse) -> String {
        var items = schedule.orderedDays.flatMap { day in
            day.lessons.map { lessonSignature($0, day: String(day.weekday.rawValue)) }
        }
        items += schedule.exams.map { lessonSignature($0, day: "exam") }
        items += [schedule.startDate, schedule.endDate, schedule.startExamsDate, schedule.endExamsDate]
            .map { String($0?.timeIntervalSince1970 ?? 0) }
        let data = (try? JSONEncoder().encode(items.sorted())) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func lessonSignature(_ lesson: DisciplineSchedule, day: String) -> String {
        let fields: [String] = [
            day, lesson.subject, lesson.subjectFullName ?? "", lesson.lessonTypeAbbrev,
            lesson.startLessonTime, lesson.endLessonTime, String(lesson.subgroup),
            lesson.auditories.sorted().joined(separator: "|"),
            lesson.weekNumbers.sorted().map(String.init).joined(separator: ","),
            lesson.employees.map { String($0.id) }.sorted().joined(separator: ","),
            lesson.note ?? "", String(lesson.lessonDate?.timeIntervalSince1970 ?? 0),
            String(lesson.startLessonDate?.timeIntervalSince1970 ?? 0),
            String(lesson.endLessonDate?.timeIntervalSince1970 ?? 0)
        ]
        let data = (try? JSONEncoder().encode(fields)) ?? Data()
        return data.base64EncodedString()
    }
}
