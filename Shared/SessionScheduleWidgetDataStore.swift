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
        let kind: SessionScheduleWidgetEventKind
    }
}

enum SessionScheduleWidgetConstants {
    static let kind = "com.OrDinaD.MyIIS.sessionSchedule"
}

enum SessionScheduleWidgetDateFormatting {
    nonisolated static func numericDateText(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "dd.MM.yyyy"

        return "\(formatter.string(from: date))(\(weekdayShortText(from: date)))"
    }

    private nonisolated static func weekdayShortText(from date: Date) -> String {
        let weekdays = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"]
        let calendar = Calendar(identifier: .gregorian)
        let index = calendar.component(.weekday, from: date) - 1
        guard weekdays.indices.contains(index) else { return "" }
        return weekdays[index]
    }
}

enum SessionScheduleWidgetDataStore {
    private enum Key {
        static let snapshot = "session_schedule_widget_snapshot_v1"
    }

    private static var defaults: UserDefaults? {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) != nil else {
            return nil
        }
        return UserDefaults(suiteName: AppGroup.identifier)
    }

    static func save(_ snapshot: SessionScheduleWidgetSnapshot) {
        guard let defaults else { return }
        do {
            let data = try JSONEncoder().encode(snapshot)
            _ = UserDefaultsPayloadStore.save(data, forKey: Key.snapshot, in: defaults)
#if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: SessionScheduleWidgetConstants.kind)
#endif
        } catch {
            assertionFailure("Failed to encode SessionScheduleWidgetSnapshot: \(error)")
        }
    }

    static func loadSnapshot() -> SessionScheduleWidgetSnapshot? {
        guard let defaults,
              let data = UserDefaultsPayloadStore.load(forKey: Key.snapshot, from: defaults) else {
            return nil
        }
        return try? JSONDecoder().decode(SessionScheduleWidgetSnapshot.self, from: data)
    }

    static func clear() {
        guard let defaults else { return }
        defaults.removeObject(forKey: Key.snapshot)
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: SessionScheduleWidgetConstants.kind)
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
}
