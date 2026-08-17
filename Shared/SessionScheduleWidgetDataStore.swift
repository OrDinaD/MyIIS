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
        var subgroup: Int?
    }
}

enum SessionScheduleWidgetConstants {
    static let kind = "com.OrDinaD.MyIIS.sessionSchedule"
}

enum ClassScheduleWidgetConstants {
    static let kind = "com.OrDinaD.MyIIS.classSchedule"
}

struct ScheduleMidPairBreak: Equatable, Sendable {
    let startTime: String
    let endTime: String

    var compactText: String {
        "\(startTime)–\(endTime)"
    }
}

enum ScheduleMidPairBreakCalculator {
    nonisolated static func resolve(startTime: String, endTime: String) -> ScheduleMidPairBreak? {
        guard let startMinutes = minutes(from: startTime),
              let endMinutes = minutes(from: endTime),
              endMinutes > startMinutes else {
            return nil
        }

        let duration = endMinutes - startMinutes
        let teachingMinutes = duration - 5
        guard teachingMinutes > 0,
              teachingMinutes.isMultiple(of: 2) else {
            return nil
        }

        let academicHour = teachingMinutes / 2
        guard academicHour == 40 || academicHour == 45 else { return nil }

        let breakStart = startMinutes + academicHour
        return ScheduleMidPairBreak(
            startTime: formatted(minutes: breakStart),
            endTime: formatted(minutes: breakStart + 5)
        )
    }

    private nonisolated static func minutes(from value: String) -> Int? {
        let components = value.split(separator: ":")
        guard components.count == 2,
              let hours = Int(components[0]),
              let minutes = Int(components[1]),
              (0 ... 23).contains(hours),
              (0 ... 59).contains(minutes) else {
            return nil
        }
        return hours * 60 + minutes
    }

    private nonisolated static func formatted(minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

public enum ScheduleCardDensity: String, CaseIterable, Identifiable, Codable, Sendable {
    case regular
    case compact

    public var id: String { rawValue }

    public var localizedTitle: String {
        switch self {
        case .regular: return NSLocalizedString("schedule_density_regular", value: "Стандартная", comment: "")
        case .compact: return NSLocalizedString("schedule_density_compact", value: "Компактная", comment: "")
        }
    }
}

public enum ScheduleOtherSubgroupDisplay: String, CaseIterable, Identifiable, Codable, Sendable {
    case full
    case compact
    case hidden

    public var id: String { rawValue }

    public var localizedTitle: String {
        switch self {
        case .full: return NSLocalizedString("schedule_other_subgroup_full", value: "Показывать полностью", comment: "")
        case .compact: return NSLocalizedString("schedule_other_subgroup_compact", value: "Показывать компактно", comment: "")
        case .hidden: return NSLocalizedString("schedule_other_subgroup_hidden", value: "Скрывать", comment: "")
        }
    }
}

enum ScheduleDisplayPreferences {
    static let showsMidPairBreaksKey = "schedule.display.showsMidPairBreaks"
    static let hidePastLessonsKey = "schedule.display.hidePastLessons"
    static let cardDensityKey = "schedule.display.cardDensity"
    static let otherSubgroupDisplayKey = "schedule.display.otherSubgroup"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }

    static var showsMidPairBreaks: Bool {
        defaults.bool(forKey: showsMidPairBreaksKey)
    }

    static var hidePastLessons: Bool {
        if defaults.object(forKey: hidePastLessonsKey) == nil {
            return true
        }
        return defaults.bool(forKey: hidePastLessonsKey)
    }

    static var cardDensity: ScheduleCardDensity {
        if let raw = defaults.string(forKey: cardDensityKey), let density = ScheduleCardDensity(rawValue: raw) {
            return density
        }
        return .regular
    }

    static var otherSubgroupDisplay: ScheduleOtherSubgroupDisplay {
        if let raw = defaults.string(forKey: otherSubgroupDisplayKey), let option = ScheduleOtherSubgroupDisplay(rawValue: raw) {
            return option
        }
        return .compact
    }

    static func reloadClassScheduleWidget() {
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: ClassScheduleWidgetConstants.kind)
        WidgetCenter.shared.reloadTimelines(ofKind: SessionScheduleWidgetConstants.kind)
#endif
    }
}

enum SessionScheduleWidgetDateFormatting {
    nonisolated static func numericDateText(
        from date: Date,
        locale: Locale = .autoupdatingCurrent,
        calendar: Calendar = .autoupdatingCurrent
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.dateStyle = .short
        formatter.timeStyle = .none

        return "\(formatter.string(from: date))(\(weekdayShortText(from: date, locale: locale, calendar: calendar).capitalized))"
    }

    private nonisolated static func weekdayShortText(
        from date: Date,
        locale: Locale,
        calendar: Calendar
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        let weekdays = formatter.shortWeekdaySymbols ?? []
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
        UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }

    static func save(_ snapshot: SessionScheduleWidgetSnapshot, key: String, widgetKind: String) {
        guard let defaults else { return }
        do {
            let data = try JSONEncoder().encode(snapshot)
            defaults.set(data, forKey: key)
            _ = UserDefaultsPayloadStore.save(data, forKey: key, in: defaults)
#if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
#endif
        } catch {
            assertionFailure("Failed to encode SessionScheduleWidgetSnapshot: \(error)")
        }
    }

    static func load(key: String) -> SessionScheduleWidgetSnapshot? {
        guard let defaults else { return nil }
        if let data = defaults.data(forKey: key) ?? UserDefaultsPayloadStore.load(forKey: key, from: defaults) {
            return try? JSONDecoder().decode(SessionScheduleWidgetSnapshot.self, from: data)
        }
        return nil
    }

    static func clear(key: String, widgetKind: String) {
        guard let defaults else { return }
        defaults.removeObject(forKey: key)
        UserDefaultsPayloadStore.clear(forKey: key, from: defaults)
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
        guard let date else { return false }
        let eventDay = calendar.startOfDay(for: date)
        let referenceDay = calendar.startOfDay(for: referenceDate)
        return eventDay >= referenceDay
    }
}

public extension Notification.Name {
    static let scheduleResetToDefaultGroup = Notification.Name("scheduleResetToDefaultGroup")
}
