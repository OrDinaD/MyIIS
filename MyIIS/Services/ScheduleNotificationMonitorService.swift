//
//  ScheduleNotificationMonitorService.swift
//  MyIIS
//

import Foundation
import UIKit
import UserNotifications

/// Сервис мониторинга изменений в расписании и объявлений группы с отправкой локальных уведомлений.
@MainActor
final class ScheduleNotificationMonitorService: NSObject {
    static let shared = ScheduleNotificationMonitorService()

    static let scheduleChangesEnabledKey = "services.schedule.notifications.scheduleChanges"
    static let announcementsEnabledKey = "services.schedule.notifications.announcements"
    private static let scheduleSnapshotKey = "services.schedule.notifications.snapshot.v1"
    private static let legacyScheduleHashKey = "services.schedule.notifications.lastHash.v2"
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
            let response = try await api.fetchGroupSchedule(
                groupNumber: group, preferCachedResponse: false, allowsOfflineFallback: false
            )
            let snapshot = ScheduleNotificationSnapshot(response)
            guard !snapshot.lessons.isEmpty else { return .noData }

            let key = "\(Self.scheduleSnapshotKey).\(group)"
            let previous = UserDefaultsPayloadStore.load(forKey: key, from: defaults)
                .flatMap { try? JSONDecoder().decode(ScheduleNotificationSnapshot.self, from: $0) }
            guard previous != snapshot else { return .noData }
            let data = try JSONEncoder().encode(snapshot)
            UserDefaultsPayloadStore.save(data, forKey: key, in: defaults)
            defaults.removeObject(forKey: "\(Self.legacyScheduleHashKey).\(group)")

            guard !suppressLocalAlerts, let previous,
                  let summary = snapshot.summary(since: previous) else { return .newData }
            let content = UNMutableNotificationContent()
            content.title = summary.title
            content.subtitle = String(localized: "Группа \(group)")
            content.body = summary.body
            content.sound = .default
            content.badge = 1
            content.threadIdentifier = "schedule-\(group)"
            content.userInfo = ["destination": AppSection.schedule.rawValue]

            let request = UNNotificationRequest(
                identifier: "schedule-change-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            try? await notificationCenter.add(request)
            return .newData
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

}

struct ScheduleNotificationSnapshot: Codable, Equatable {
    enum Period: String, Codable { case current, next, exam }

    struct Key: Codable, Hashable {
        let period: Period
        let subject: String
        let kind: String
        let subgroup: Int
    }

    struct Lesson: Codable, Hashable {
        let key: Key
        let weekday: String?
        let date: Date?
        let firstDate: Date?
        let lastDate: Date?
        let start: String
        let end: String
        let rooms: String
        let weeks: [Int]
        let teachers: [Int]
        let note: String

        init(_ lesson: DisciplineSchedule, period: Period, weekday: StudyWeekday? = nil) {
            key = Key(period: period, subject: lesson.title, kind: lesson.lessonTypeAbbrev, subgroup: lesson.subgroup)
            self.weekday = weekday?.rawValue
            date = lesson.lessonDate
            firstDate = lesson.startLessonDate
            lastDate = lesson.endLessonDate
            start = lesson.startLessonTime
            end = lesson.endLessonTime
            rooms = Set(lesson.auditories.map(Self.cleaned).filter { !$0.isEmpty }).sorted().joined(separator: ", ")
            let activeWeeks = Set(lesson.weekNumbers.filter { (1...4).contains($0) })
            weeks = activeWeeks.count == 4 ? [] : activeWeeks.sorted()
            teachers = Set(lesson.employees.map(\.id).filter { $0 > 0 }).sorted()
            note = Self.cleaned(lesson.note ?? "")
        }

        var slot: String {
            let day = date.map(ScheduleNotificationSnapshot.dayLabel) ?? StudyWeekday(rawValue: weekday ?? "")?.localizedTitle
            return [day, start.nilIfBlank].compactMap { $0 }.joined(separator: " ")
        }

        var label: String {
            let subject = key.kind.isEmpty || key.subject == key.kind ? key.subject : "\(key.subject) (\(key.kind))"
            let subgroup = key.subgroup > 0 ? String(localized: "подгр. \(key.subgroup)") : nil
            let period = key.period == .next ? String(localized: "след. период") : nil
            return [slot.nilIfBlank, subject, subgroup, period].compactMap { $0 }.joined(separator: " · ")
        }

        var roomLabel: String {
            rooms.isEmpty ? "" : String(localized: ", ауд. \(rooms)")
        }

        func details(since old: Self) -> String {
            var changes: [String] = []
            if slot != old.slot {
                changes.append("\(old.slot) → \(slot)")
            } else if end != old.end {
                changes.append(String(localized: "окончание: \(old.end.nilIfBlank ?? "—") → \(end.nilIfBlank ?? "—")"))
            }
            if rooms != old.rooms {
                changes.append(String(localized: "ауд. \(old.rooms.nilIfBlank ?? "—") → \(rooms.nilIfBlank ?? "—")"))
            }
            if weeks != old.weeks {
                changes.append(String(localized: "учебные недели: \(Self.weekLabel(old.weeks)) → \(Self.weekLabel(weeks))"))
            }
            if firstDate != old.firstDate || lastDate != old.lastDate {
                let first = firstDate.map(ScheduleNotificationSnapshot.dayLabel) ?? "—"
                let last = lastDate.map(ScheduleNotificationSnapshot.dayLabel) ?? "—"
                changes.append(String(localized: "период: \(first) – \(last)"))
            }
            if teachers != old.teachers {
                changes.append(String(localized: "изменился преподаватель"))
            }
            if note != old.note {
                changes.append(note.isEmpty ? String(localized: "примечание убрано") : String(localized: "примечание: \(note)"))
            }
            return changes.joined(separator: "; ")
        }

        private static func weekLabel(_ weeks: [Int]) -> String {
            weeks.isEmpty ? String(localized: "все") : weeks.map(String.init).joined(separator: ", ")
        }

        private static func cleaned(_ value: String) -> String {
            value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }
    }

    struct Summary {
        let title: String
        let body: String
    }

    let lessons: Set<Lesson>
    let examStart: Date?
    let examEnd: Date?

    init(_ schedule: PublicScheduleResponse) {
        lessons = Set(
            schedule.notificationDays.flatMap { day in
                day.lessons.filter { !$0.isAnnouncement }.map { Lesson($0, period: .current, weekday: day.weekday) }
            } + schedule.notificationNextDays.flatMap { day in
                day.lessons.filter { !$0.isAnnouncement }.map { Lesson($0, period: .next, weekday: day.weekday) }
            } + schedule.exams.filter { !$0.isAnnouncement }.map { Lesson($0, period: .exam) }
        )
        examStart = schedule.startExamsDate
        examEnd = schedule.endExamsDate
    }

    func summary(since old: Self) -> Summary? {
        guard !lessons.isEmpty, !old.lessons.isEmpty else { return nil }
        let added = Dictionary(grouping: lessons.subtracting(old.lessons), by: \.key)
        let removed = Dictionary(grouping: old.lessons.subtracting(lessons), by: \.key)
        let keys = Set(added.keys).union(removed.keys)
        var examLines: [String] = []
        var otherLines: [String] = []
        for key in keys {
            let lines = Self.changeLines(added: added[key] ?? [], removed: removed[key] ?? [])
            if key.period == .exam {
                examLines += lines
            } else {
                otherLines += lines
            }
        }

        let publishedExams = has(.exam) && !old.has(.exam)
        let publishedNext = has(.next) && !old.has(.next)
        let title: String
        if publishedExams {
            title = String(localized: "Опубликовано расписание сессии")
        } else if publishedNext {
            title = String(localized: "Опубликовано расписание на следующий период")
        } else if !examLines.isEmpty && otherLines.isEmpty {
            title = String(localized: "Изменение в расписании сессии")
        } else {
            title = String(localized: "Изменение в расписании")
        }

        var body: [String] = []
        if has(.exam), let examStart, let examEnd,
           publishedExams || examStart != old.examStart || examEnd != old.examEnd {
            body.append(String(localized: "Сессия: \(Self.dayLabel(examStart)) – \(Self.dayLabel(examEnd))"))
        }
        let lines = examLines.sorted() + otherLines.sorted()
        guard !lines.isEmpty || !body.isEmpty else { return nil }
        body += lines.prefix(2).map { $0.count > 150 ? String($0.prefix(149)) + "…" : $0 }
        if lines.count > 2 {
            body.append(String(localized: "И ещё: \(lines.count - 2)"))
        }
        return Summary(title: title, body: body.joined(separator: "\n"))
    }

    private func has(_ period: Period) -> Bool {
        lessons.contains { $0.key.period == period }
    }

    private static func changeLines(added: [Lesson], removed: [Lesson]) -> [String] {
        if added.count == 1, removed.count == 1, let new = added.first, let old = removed.first {
            let details = new.details(since: old)
            if !details.isEmpty {
                return ["\(new.label): \(details)"]
            }
        }
        return added.map { String(localized: "Добавлено: \($0.label)\($0.roomLabel)") }
            + removed.map { String(localized: "Убрано: \($0.label)\($0.roomLabel)") }
    }

    private static func dayLabel(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }
}
