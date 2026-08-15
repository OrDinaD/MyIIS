//
//  SessionScheduleWidgetDataStore.swift
//  MyIIS
//
import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum SessionScheduleWidgetEventKind: String, Codable, Sendable {
    case announcement
    case exam
    case consultation
    case other
}

struct SessionScheduleWidgetSnapshot: Codable, Sendable {
    let groupName: String
    let startDate: Date?
    let endDate: Date?
    let events: [Event]
    let updatedAt: Date

    struct Event: Codable, Identifiable, Sendable {
        let id: String
        let date: Date?
        let startTime: String
        let endTime: String
        let title: String
        let subtitle: String?
        let location: String?
        let lessonType: String?
        let kind: SessionScheduleWidgetEventKind
    }
}

enum SessionScheduleWidgetConstants {
    static let kind = "com.OrDinaD.MyIIS.sessionSchedule"
}

enum ClassScheduleWidgetConstants {
    static let kind = "com.OrDinaD.MyIIS.classSchedule"
}

enum SessionScheduleWidgetDateFormatting {
    nonisolated static func numericDateText(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateStyle = .short
        formatter.timeStyle = .none

        return "\(formatter.string(from: date))(\(weekdayShortText(from: date).capitalized))"
    }

    private nonisolated static func weekdayShortText(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.calendar = Calendar(identifier: .gregorian)
        let weekdays = formatter.shortWeekdaySymbols ?? []
        let calendar = Calendar(identifier: .gregorian)
        let index = calendar.component(.weekday, from: date) - 1
        guard weekdays.indices.contains(index) else { return "" }
        return weekdays[index]
    }
}

enum SessionScheduleWidgetPresentation {
    nonisolated static func accessoryStatus(
        for event: SessionScheduleWidgetSnapshot.Event,
        at date: Date,
        calendar: Calendar = .current
    ) -> String {
        if event.isActive(at: date, calendar: calendar) {
            return String(format: String(localized: "До %@"), event.endTime)
        }
        return String(format: String(localized: "В %@"), event.startTime)
    }

    nonisolated static func accessorySubtitle(
        for event: SessionScheduleWidgetSnapshot.Event
    ) -> String {
        normalizedLocation(event.location)
            ?? nonEmpty(event.lessonType)
            ?? event.endTime
    }

    nonisolated static func normalizedLocation(_ value: String?) -> String? {
        guard let value = nonEmpty(value) else { return nil }
        let normalized = value
            .replacingOccurrences(of: " к.", with: "")
            .replacingOccurrences(of: " к", with: "")
            .replacingOccurrences(of: " корпус", with: "")
            .replacingOccurrences(of: "Корпус ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private nonisolated static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

enum SessionScheduleWidgetDataStore {
    private enum Key {
        static let snapshot = "session_schedule_widget_snapshot_v1"
    }

    static func save(_ snapshot: SessionScheduleWidgetSnapshot) {
        ScheduleWidgetSnapshotStore.save(
            snapshot,
            key: Key.snapshot,
            widgetKind: SessionScheduleWidgetConstants.kind
        )
    }

    static func loadSnapshot() -> SessionScheduleWidgetSnapshot? {
        ScheduleWidgetSnapshotStore.load(key: Key.snapshot)
    }

    static func clear() {
        ScheduleWidgetSnapshotStore.clear(
            key: Key.snapshot,
            widgetKind: SessionScheduleWidgetConstants.kind
        )
    }
}

enum ClassScheduleWidgetDataStore {
    private enum Key {
        // v2 intentionally invalidates snapshots that could have been overwritten
        // by the retired local-JSON refresh intent.
        static let snapshot = "class_schedule_widget_snapshot_v2"
    }

    static func save(_ snapshot: SessionScheduleWidgetSnapshot) {
        ScheduleWidgetSnapshotStore.save(
            snapshot,
            key: Key.snapshot,
            widgetKind: ClassScheduleWidgetConstants.kind
        )
    }

    static func loadSnapshot() -> SessionScheduleWidgetSnapshot? {
        ScheduleWidgetSnapshotStore.load(key: Key.snapshot)
    }

    static func clear() {
        ScheduleWidgetSnapshotStore.clear(
            key: Key.snapshot,
            widgetKind: ClassScheduleWidgetConstants.kind
        )
    }
}

private enum ScheduleWidgetSnapshotStore {
    private static var defaults: UserDefaults? {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) != nil else {
            return nil
        }
        return UserDefaults(suiteName: AppGroup.identifier)
    }

    static func save(_ snapshot: SessionScheduleWidgetSnapshot, key: String, widgetKind: String) {
        guard let defaults else { return }
        do {
            let data = try JSONEncoder().encode(snapshot)
            _ = UserDefaultsPayloadStore.save(data, forKey: key, in: defaults)
#if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
#endif
        } catch {
            assertionFailure("Failed to encode SessionScheduleWidgetSnapshot: \(error)")
        }
    }

    static func load(key: String) -> SessionScheduleWidgetSnapshot? {
        guard let defaults,
              let data = UserDefaultsPayloadStore.load(forKey: key, from: defaults) else {
            return nil
        }
        return try? JSONDecoder().decode(SessionScheduleWidgetSnapshot.self, from: data)
    }

    static func clear(key: String, widgetKind: String) {
        guard let defaults else { return }
        defaults.removeObject(forKey: key)
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
#endif
    }
}

extension SessionScheduleWidgetSnapshot.Event {
    nonisolated func interval(calendar: Calendar = .current) -> DateInterval? {
        guard let date else { return nil }

        func makeDate(from time: String) -> Date? {
            let parts = time.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }

            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = parts[0]
            components.minute = parts[1]
            return calendar.date(from: components)
        }

        guard let start = makeDate(from: startTime),
              let end = makeDate(from: endTime),
              end > start else {
            return nil
        }

        return DateInterval(start: start, end: end)
    }

    nonisolated func progress(at now: Date, calendar: Calendar = .current) -> CGFloat? {
        guard let interval = interval(calendar: calendar) else { return nil }

        if now < interval.start { return 0 }
        if now >= interval.end { return 1 }

        let value = now.timeIntervalSince(interval.start) / interval.duration
        return CGFloat(min(max(value, 0), 1))
    }

    nonisolated func isActive(at now: Date, calendar: Calendar = .current) -> Bool {
        guard let interval = interval(calendar: calendar) else { return false }
        return interval.contains(now)
    }

    nonisolated func isUpcoming(at referenceDate: Date, calendar: Calendar = .current) -> Bool {
        if let interval = interval(calendar: calendar) {
            return interval.end >= referenceDate
        }
        guard let date else { return true }
        let eventDay = calendar.startOfDay(for: date)
        let referenceDay = calendar.startOfDay(for: referenceDate)
        return eventDay >= referenceDay
    }
}
