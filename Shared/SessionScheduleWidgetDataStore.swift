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
        static let snapshot = "class_schedule_widget_snapshot_v1"
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
            ?? LocalScheduleWidgetSnapshotLoader.load()
    }

    @discardableResult
    static func refreshFromLocalSchedule() -> Bool {
        guard let snapshot = LocalScheduleWidgetSnapshotLoader.load() else {
#if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: ClassScheduleWidgetConstants.kind)
#endif
            return false
        }

        save(snapshot)
        return true
    }

    static func clear() {
        ScheduleWidgetSnapshotStore.clear(
            key: Key.snapshot,
            widgetKind: ClassScheduleWidgetConstants.kind
        )
    }
}

private struct LocalScheduleWidgetDocument: Decodable {
    let title: String
    let groupName: String?
    let timeZone: String
    let validFrom: String?
    let validThrough: String?
    let updatedAt: String?
    let events: [LocalScheduleWidgetEvent]
}

private struct LocalScheduleWidgetEvent: Decodable {
    let id: String
    let date: String
    let startTime: String
    let endTime: String
    let title: String
    let shortTitle: String?
    let type: String
    let location: String?
    let teacher: String?
    let isCancelled: Bool?
}

private enum LocalScheduleWidgetSnapshotLoader {
    private static let directoryName = "LocalSchedules"
    private static let fileName = "current.json"

    static func load() -> SessionScheduleWidgetSnapshot? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.identifier
        ) else {
            return nil
        }

        let fileURL = containerURL
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)

        guard let data = try? Data(contentsOf: fileURL),
              let document = try? JSONDecoder().decode(LocalScheduleWidgetDocument.self, from: data) else {
            return nil
        }

        let timeZone = TimeZone(identifier: document.timeZone) ?? .current
        let events = document.events.compactMap { event -> SessionScheduleWidgetSnapshot.Event? in
            guard event.isCancelled != true,
                  let date = day(from: event.date, timeZone: timeZone) else {
                return nil
            }

            let title = nonEmpty(event.shortTitle) ?? event.title
            let subtitle = [nonEmpty(event.type), nonEmpty(event.teacher)]
                .compactMap { $0 }
                .joined(separator: " · ")

            return SessionScheduleWidgetSnapshot.Event(
                id: event.id,
                date: date,
                startTime: event.startTime,
                endTime: event.endTime,
                title: title,
                subtitle: nonEmpty(subtitle),
                location: nonEmpty(event.location),
                lessonType: nonEmpty(event.type),
                kind: kind(for: event.type)
            )
        }
        .sorted {
            guard $0.date != $1.date else {
                return $0.startTime < $1.startTime
            }
            return ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture)
        }

        return SessionScheduleWidgetSnapshot(
            groupName: nonEmpty(document.groupName) ?? document.title,
            startDate: document.validFrom.flatMap { day(from: $0, timeZone: timeZone) },
            endDate: document.validThrough.flatMap { day(from: $0, timeZone: timeZone) },
            events: events,
            updatedAt: document.updatedAt.flatMap { ISO8601DateFormatter().date(from: $0) } ?? .now
        )
    }

    private static func day(from value: String, timeZone: TimeZone) -> Date? {
        let values = value.split(separator: "-").compactMap { Int($0) }
        guard values.count == 3 else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(
            from: DateComponents(
                timeZone: timeZone,
                year: values[0],
                month: values[1],
                day: values[2]
            )
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func kind(for type: String) -> SessionScheduleWidgetEventKind {
        switch type.lowercased() {
        case "announcement":
            return .announcement
        case "exam":
            return .exam
        case "consultation":
            return .consultation
        default:
            return .other
        }
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
