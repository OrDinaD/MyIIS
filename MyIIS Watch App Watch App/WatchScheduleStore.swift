import Combine
import Foundation
import SwiftUI
import WatchConnectivity
import WidgetKit

enum WatchScheduleEventKind: String, Codable, Sendable {
    case announcement
    case exam
    case consultation
    case other
}

struct WatchScheduleEvent: Codable, Identifiable, Sendable {
    typealias Kind = WatchScheduleEventKind
    let id: String
    let date: Date?
    let startTime: String
    let endTime: String
    let title: String
    let subtitle: String?
    let location: String?
    let lessonType: String?
    let kind: Kind
    var subgroup: Int?
    var teacherName: String?
    var teacherPhotoLink: String?

    init(
        id: String,
        date: Date?,
        startTime: String,
        endTime: String,
        title: String,
        subtitle: String?,
        location: String?,
        lessonType: String?,
        kind: Kind,
        subgroup: Int? = nil,
        teacherName: String? = nil,
        teacherPhotoLink: String? = nil
    ) {
        self.id = id
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.title = title
        self.subtitle = subtitle
        self.location = location
        self.lessonType = lessonType
        self.kind = kind
        self.subgroup = subgroup
        self.teacherName = teacherName
        self.teacherPhotoLink = teacherPhotoLink
    }

    func interval(calendar: Calendar = .current) -> DateInterval? {
        guard let date else { return nil }
        let startParts = startTime.split(separator: ":").compactMap { Int($0) }
        let endParts = endTime.split(separator: ":").compactMap { Int($0) }
        guard startParts.count == 2, endParts.count == 2 else { return nil }

        var startComponents = calendar.dateComponents([.year, .month, .day], from: date)
        startComponents.hour = startParts[0]
        startComponents.minute = startParts[1]
        var endComponents = startComponents
        endComponents.hour = endParts[0]
        endComponents.minute = endParts[1]

        guard let start = calendar.date(from: startComponents),
              let end = calendar.date(from: endComponents),
              end > start else {
            return nil
        }
        return DateInterval(start: start, end: end)
    }

    func isCurrent(at date: Date) -> Bool {
        interval()?.contains(date) == true
    }

    func progress(at date: Date, calendar: Calendar = .current) -> Double {
        guard let interval = interval(calendar: calendar) else { return 0 }
        if date <= interval.start { return 0 }
        if date >= interval.end { return 1 }
        return date.timeIntervalSince(interval.start) / interval.duration
    }

    func shortLocation() -> String? {
        guard let location, !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        var text = location.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasSuffix(" к.") {
            text = String(text.dropLast(" к.".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if text.hasSuffix(" к") {
            text = String(text.dropLast(" к".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if text.hasSuffix(" корп.") {
            text = String(text.dropLast(" корп.".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if text.hasSuffix(" корпус") {
            text = String(text.dropLast(" корпус".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text.isEmpty ? nil : text
    }

    var accentColor: Color {
        let raw = (lessonType ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if raw.contains("лк") || raw.contains("лек") {
            return Color(red: 52/255, green: 199/255, blue: 89/255)
        } else if raw.contains("пз") || raw.contains("прак") {
            return Color(red: 255/255, green: 59/255, blue: 48/255)
        } else if raw.contains("лр") || raw.contains("лаб") {
            return Color(red: 255/255, green: 204/255, blue: 0/255)
        } else if raw.contains("конс") {
            return Color(red: 175/255, green: 82/255, blue: 222/255)
        } else if raw.contains("экз") || raw.contains("зач") {
            return Color(red: 255/255, green: 45/255, blue: 85/255)
        }
        return Color(red: 90/255, green: 200/255, blue: 250/255)
    }

    var lessonIcon: String {
        let raw = (lessonType ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if raw.contains("лк") || raw.contains("лек") {
            return "book.pages.fill"
        } else if raw.contains("пз") || raw.contains("прак") {
            return "pencil.and.ruler.fill"
        } else if raw.contains("лр") || raw.contains("лаб") {
            return "flask.fill"
        } else if raw.contains("конс") {
            return "person.2.wave.2.fill"
        } else if raw.contains("экз") || raw.contains("зач") {
            return "graduationcap.fill"
        }
        return "calendar"
    }

    var teacherPhotoURL: URL? {
        guard let link = teacherPhotoLink?.trimmingCharacters(in: .whitespacesAndNewlines), !link.isEmpty else {
            return nil
        }
        return URL(string: link)
    }

    var teacherInitials: String {
        guard let name = teacherName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return ""
        }
        let parts = name.split(whereSeparator: { $0.isWhitespace }).prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    var subgroupBadge: String? {
        guard let subgroup, subgroup > 0 else { return nil }
        return "\(subgroup) п/г"
    }
}

struct WatchDaySection: Identifiable {
    let id: String
    let title: String
    let isToday: Bool
    let events: [WatchScheduleEvent]
}

struct WatchScheduleSnapshot: Codable, Sendable {
    typealias Event = WatchScheduleEvent

    let groupName: String
    let startDate: Date?
    let endDate: Date?
    let events: [Event]
    let updatedAt: Date

    func upcomingEvents(at date: Date) -> [Event] {
        events
            .filter { ($0.interval()?.end ?? $0.date ?? .distantPast) >= date }
            .sorted {
                ($0.interval()?.start ?? $0.date ?? .distantFuture) <
                ($1.interval()?.start ?? $1.date ?? .distantFuture)
            }
    }

    func activeEvent(at date: Date) -> Event? {
        events.first { $0.isCurrent(at: date) }
    }

    func nextUpcomingEvent(after date: Date) -> Event? {
        events
            .filter { ($0.interval()?.start ?? $0.date ?? .distantPast) > date }
            .sorted { ($0.interval()?.start ?? .distantFuture) < ($1.interval()?.start ?? .distantFuture) }
            .first
    }

    func daySections(at date: Date, calendar: Calendar = .current) -> [WatchDaySection] {
        let upcoming = upcomingEvents(at: date)
        guard !upcoming.isEmpty else { return [] }

        var grouped: [Date: [Event]] = [:]
        for event in upcoming {
            let eventDate = event.interval(calendar: calendar)?.start ?? event.date ?? date
            let startOfDay = calendar.startOfDay(for: eventDate)
            grouped[startOfDay, default: []].append(event)
        }

        let sortedDays = grouped.keys.sorted()
        let today = calendar.startOfDay(for: date)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)

        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale.autoupdatingCurrent
        dayFormatter.dateFormat = "EEEE, d MMMM"

        return sortedDays.compactMap { day -> WatchDaySection? in
            guard let dayEvents = grouped[day], !dayEvents.isEmpty else { return nil }
            let title: String
            let isToday = (day == today)
            if isToday {
                title = NSLocalizedString("watch_section_today", value: "СЕГОДНЯ", comment: "")
            } else if let tomorrow, day == tomorrow {
                title = NSLocalizedString("watch_section_tomorrow", value: "ЗАВТРА", comment: "")
            } else {
                title = dayFormatter.string(from: day).uppercased()
            }
            return WatchDaySection(
                id: String(day.timeIntervalSinceReferenceDate),
                title: title,
                isToday: isToday,
                events: dayEvents.sorted { ($0.interval(calendar: calendar)?.start ?? .distantPast) < ($1.interval(calendar: calendar)?.start ?? .distantPast) }
            )
        }
    }
}

enum WatchScheduleStore {
    nonisolated static let appGroupIdentifier = "group.com.OrDinaD.MyIIS"
    nonisolated static let snapshotKey = "watch_class_schedule_snapshot_v1"
    nonisolated static let transferKey = "classScheduleSnapshot"
    nonisolated static let clearTransferKey = "clearClassScheduleSnapshot"

    static func save(_ data: Data) throws {
        guard let defaults = appGroupDefaults else {
            throw CocoaError(.fileNoSuchFile)
        }
        _ = try JSONDecoder().decode(WatchScheduleSnapshot.self, from: data)
        defaults.set(data, forKey: snapshotKey)
    }

    static func load() -> WatchScheduleSnapshot? {
        guard let data = appGroupDefaults?.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WatchScheduleSnapshot.self, from: data)
    }

    static func clear() {
        appGroupDefaults?.removeObject(forKey: snapshotKey)
    }

    private static var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }
}

@MainActor
final class WatchScheduleReceiver: NSObject, ObservableObject {
    static let shared = WatchScheduleReceiver()

    @Published private(set) var snapshot: WatchScheduleSnapshot?
    @Published private(set) var connectionError: String?

    override init() {
        snapshot = WatchScheduleStore.load()
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()

        accept(session.receivedApplicationContext)
    }

    private func accept(_ applicationContext: [String: Any]) {
        if applicationContext[WatchScheduleStore.clearTransferKey] as? Bool == true {
            WatchScheduleStore.clear()
            snapshot = nil
            connectionError = nil
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

        guard let data = applicationContext[WatchScheduleStore.transferKey] as? Data else { return }
        do {
            try WatchScheduleStore.save(data)
            snapshot = WatchScheduleStore.load()
            connectionError = nil
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            connectionError = error.localizedDescription
        }
    }
}

extension WatchScheduleReceiver: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                connectionError = error.localizedDescription
                return
            }
            accept(session.receivedApplicationContext)
        }
    }

#if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
#endif

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            accept(applicationContext)
        }
    }
}
