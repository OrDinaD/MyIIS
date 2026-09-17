import SwiftUI
import WidgetKit
#if canImport(RelevanceKit)
import RelevanceKit
#endif

// MARK: - Snapshot & Event Models

struct WatchWidgetSnapshot: Codable, Sendable {
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
        let kind: Kind
        var subgroup: Int?
        var teacherName: String?
        var teacherPhotoLink: String?

        // swiftlint:disable:next nesting
        enum Kind: String, Codable, Sendable {
            case announcement
            case exam
            case consultation
            case other
        }

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
            guard let start = calendar.date(from: startComponents) else { return nil }

            var endComponents = startComponents
            endComponents.hour = endParts[0]
            endComponents.minute = endParts[1]
            guard var end = calendar.date(from: endComponents) else { return nil }

            if end <= start {
                guard let nextDayEnd = calendar.date(byAdding: .day, value: 1, to: end) else { return nil }
                end = nextDayEnd
            }

            return DateInterval(start: start, end: end)
        }

        func isCurrent(at date: Date, calendar: Calendar = .current) -> Bool {
            interval(calendar: calendar)?.contains(date) == true
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
    }

    func relevantEvent(at date: Date, calendar: Calendar = .current) -> Event? {
        let active = events.first { $0.isCurrent(at: date, calendar: calendar) }
        if let active { return active }

        return events
            .compactMap { event -> (Event, Date)? in
                guard let start = event.interval(calendar: calendar)?.start, start > date else {
                    return nil
                }
                return (event, start)
            }
            .sorted { $0.1 < $1.1 }
            .first?
            .0
    }

    func activeEvent(at date: Date, calendar: Calendar = .current) -> Event? {
        events.first { $0.isCurrent(at: date, calendar: calendar) }
    }

    func nextUpcomingEvent(after date: Date, calendar: Calendar = .current) -> Event? {
        events
            .compactMap { event -> (Event, Date)? in
                guard let start = event.interval(calendar: calendar)?.start, start > date else {
                    return nil
                }
                return (event, start)
            }
            .sorted { $0.1 < $1.1 }
            .first?
            .0
    }

    func upcomingEvents(at date: Date, calendar: Calendar = .current) -> [Event] {
        events
            .filter { ($0.interval(calendar: calendar)?.end ?? $0.date ?? .distantPast) >= date }
            .sorted {
                let leftStart = $0.interval(calendar: calendar)?.start ?? $0.date ?? .distantFuture
                let rightStart = $1.interval(calendar: calendar)?.start ?? $1.date ?? .distantFuture
                return leftStart < rightStart
            }
    }

    static func placeholder(now: Date = .now) -> WatchWidgetSnapshot {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .minute, value: -25, to: now) ?? now
        let end = calendar.date(byAdding: .minute, value: 55, to: now) ?? now
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return WatchWidgetSnapshot(
            groupName: "420603",
            startDate: now,
            endDate: now,
            events: [
                Event(
                    id: "preview-current",
                    date: now,
                    startTime: formatter.string(from: start),
                    endTime: formatter.string(from: end),
                    title: "АМД",
                    subtitle: "Лекция",
                    location: "409-1 к.",
                    lessonType: "Лекция",
                    kind: .other
                )
            ],
            updatedAt: now
        )
    }

    static func upcomingPlaceholder(now: Date = .now) -> WatchWidgetSnapshot {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .minute, value: 35, to: now) ?? now
        let end = calendar.date(byAdding: .minute, value: 115, to: now) ?? now
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return WatchWidgetSnapshot(
            groupName: "420603",
            startDate: now,
            endDate: now,
            events: [
                Event(
                    id: "preview-upcoming",
                    date: now,
                    startTime: formatter.string(from: start),
                    endTime: formatter.string(from: end),
                    title: "Базы данных",
                    subtitle: "Практика",
                    location: "305-4",
                    lessonType: "ПЗ",
                    kind: .other
                )
            ],
            updatedAt: now
        )
    }
}

// MARK: - Store

enum WatchWidgetStore {
    static let appGroupIdentifier = "group.com.OrDinaD.MyIIS"
    static let snapshotKey = "watch_class_schedule_snapshot_v1"

    static func load() -> WatchWidgetSnapshot? {
        guard FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) != nil,
        let defaults = UserDefaults(suiteName: appGroupIdentifier),
        let data = defaults.data(forKey: snapshotKey) else {
            return nil
        }
        return try? JSONDecoder().decode(WatchWidgetSnapshot.self, from: data)
    }
}

// MARK: - Entry & Timeline Provider

struct ScheduleWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchWidgetSnapshot?

    var relevance: TimelineEntryRelevance? {
        guard let event = snapshot?.relevantEvent(at: date),
              let interval = event.interval() else {
            return nil
        }

        if interval.contains(date) {
            return TimelineEntryRelevance(score: 100, duration: max(interval.end.timeIntervalSince(date), 60))
        }

        let leadTime = interval.start.timeIntervalSince(date)
        guard leadTime <= 45 * 60, leadTime >= 0 else { return nil }
        return TimelineEntryRelevance(score: 80, duration: leadTime + interval.duration)
    }

    var currentEvent: WatchWidgetSnapshot.Event? {
        snapshot?.relevantEvent(at: date)
    }
}

struct ScheduleWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScheduleWidgetEntry {
        ScheduleWidgetEntry(date: .now, snapshot: .placeholder())
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (ScheduleWidgetEntry) -> Void
    ) {
        completion(
            ScheduleWidgetEntry(
                date: .now,
                snapshot: context.isPreview ? .placeholder() : WatchWidgetStore.load()
            )
        )
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<ScheduleWidgetEntry>) -> Void
    ) {
        let now = Date()
        let snapshot = WatchWidgetStore.load()
        var dates: Set<Date> = [now]

        for event in snapshot?.events ?? [] {
            guard let interval = event.interval() else { continue }
            if interval.start >= now {
                dates.insert(interval.start)
                let lead45 = interval.start.addingTimeInterval(-45 * 60)
                if lead45 >= now { dates.insert(lead45) }
                let lead15 = interval.start.addingTimeInterval(-15 * 60)
                if lead15 >= now { dates.insert(lead15) }
            }
            if interval.end >= now {
                dates.insert(interval.end)
            }
        }

        let entries = dates
            .filter { $0 >= now }
            .sorted()
            .prefix(64)
            .map { ScheduleWidgetEntry(date: $0, snapshot: snapshot) }

        let nextBoundary = dates.filter { $0 > now }.min()
        let fallback = Calendar.current.date(byAdding: .hour, value: 6, to: now)
            ?? now.addingTimeInterval(6 * 60 * 60)
        completion(Timeline(entries: Array(entries), policy: .after(nextBoundary ?? fallback)))
    }

#if os(watchOS)
    @available(watchOS 11.0, iOS 18.0, *)
    func relevance() async -> WidgetRelevance<Void> {
        let now = Date()
        let snapshot = WatchWidgetStore.load()
        let relevances = (snapshot?.events ?? []).compactMap { event -> WidgetRelevanceAttribute<Void>? in
            guard let interval = event.interval() else { return nil }
            guard interval.end > now else { return nil }
            let leadStart = interval.start.addingTimeInterval(-20 * 60)
            let contextInterval = DateInterval(start: leadStart, end: interval.end)
            return WidgetRelevanceAttribute(
                context: .date(interval.start)
            )
        }
        return WidgetRelevance(relevances)
    }
#endif
}

// MARK: - 1. Main Adaptive Schedule Widget View

struct ScheduleWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ScheduleWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circularContent
            case .accessoryInline:
                inlineContent
#if os(watchOS)
            case .accessoryCorner:
                cornerContent
#endif
            default:
                rectangularContent
            }
        }
        .privacySensitive()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Rectangular

    private var rectangularContent: some View {
        Group {
            if let event = entry.currentEvent {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .center, spacing: 4) {
                        Image(systemName: event.isCurrent(at: entry.date) ? "clock.fill" : "calendar")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(event.isCurrent(at: entry.date) ? event.accentColor : Color.orange)
                            .widgetAccentable()

                        statusTimeText(event)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        statusBadge(event)
                    }

                    Text(event.title)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    let details = detailsString(for: event)
                    if !details.isEmpty {
                        Text(details)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .widgetAccentable()

                    Text("watch_widget_no_events")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
    }

    // MARK: - Circular

    private var circularContent: some View {
        Group {
            if let event = entry.currentEvent {
                if event.isCurrent(at: entry.date), let interval = event.interval() {
                    ZStack {
                        ProgressView(timerInterval: interval.start ... interval.end, countsDown: false)
                            .progressViewStyle(.circular)
                            .tint(event.accentColor)
                            .widgetAccentable()
                            .labelsHidden()

                        Image(systemName: event.lessonIcon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(event.accentColor)
                            .widgetAccentable()
                    }
                    .accessibilityLabel(event.title)
                    .accessibilityValue(Text(timerInterval: interval.start ... interval.end, countsDown: true))
                } else {
                    Gauge(value: 0) {
                        Image(systemName: event.lessonIcon)
                            .widgetAccentable()
                    } currentValueLabel: {
                        Text(event.startTime)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                    }
                    .gaugeStyle(.accessoryCircular)
                    .tint(event.accentColor)
                    .widgetAccentable()
                    .accessibilityLabel(event.title)
                    .accessibilityValue(event.startTime)
                }
            } else {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .widgetAccentable()
                    .accessibilityLabel(Text("watch_widget_no_events"))
            }
        }
    }

    // MARK: - Inline

    private var inlineContent: some View {
        Group {
            if let event = entry.currentEvent {
                Text("\(event.startTime) \(event.title)")
                    .lineLimit(1)
            } else {
                Text("watch_widget_no_events_short")
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Corner (watchOS)

#if os(watchOS)
    private var cornerContent: some View {
        Group {
            if let event = entry.currentEvent {
                Text(event.isCurrent(at: entry.date) ? event.endTime : event.startTime)
                    .font(.headline.monospacedDigit())
                    .widgetLabel {
                        if let loc = event.shortLocation() {
                            Text("\(event.title) · \(loc)")
                        } else {
                            Text(event.title)
                        }
                    }
            } else {
                Image(systemName: "checkmark.circle")
                    .widgetLabel {
                        Text("watch_widget_no_events_short")
                    }
            }
        }
        .widgetAccentable()
    }
#endif

    // MARK: - Helpers

    @ViewBuilder
    private func statusTimeText(_ event: WatchWidgetSnapshot.Event) -> some View {
        if event.isCurrent(at: entry.date) {
            Text("\(String(localized: "watch_widget_until")) \(event.endTime)")
        } else {
            Text("\(String(localized: "watch_widget_at")) \(event.startTime)")
        }
    }

    @ViewBuilder
    private func statusBadge(_ event: WatchWidgetSnapshot.Event) -> some View {
        if event.isCurrent(at: entry.date) {
            Text(String(localized: "watch_widget_current_class"))
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(Capsule().fill(event.accentColor.opacity(0.2)))
                .foregroundStyle(event.accentColor)
                .widgetAccentable()
        } else if let interval = event.interval(), interval.start.timeIntervalSince(entry.date) <= 45 * 60 {
            Text(String(localized: "watch_widget_soon"))
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(Capsule().fill(Color.orange.opacity(0.2)))
                .foregroundStyle(Color.orange)
                .widgetAccentable()
        } else {
            Text("\(event.startTime)–\(event.endTime)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func detailsString(for event: WatchWidgetSnapshot.Event) -> String {
        [event.shortLocation(), event.lessonType]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

// MARK: - 2. Dedicated Next Class Widget View

struct NextClassWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ScheduleWidgetEntry

    private var nextEvent: WatchWidgetSnapshot.Event? {
        entry.snapshot?.nextUpcomingEvent(after: entry.date)
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circularBody
            case .accessoryInline:
                inlineBody
#if os(watchOS)
            case .accessoryCorner:
                cornerBody
#endif
            default:
                circularBody
            }
        }
        .privacySensitive()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var circularBody: some View {
        Group {
            if let event = nextEvent {
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: 1) {
                        Image(systemName: event.lessonIcon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(event.accentColor)
                            .widgetAccentable()

                        Text(event.startTime)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        if let room = event.shortLocation() {
                            Text(room)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .padding(2)
                }
            } else {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .widgetAccentable()
            }
        }
    }

    private var inlineBody: some View {
        Group {
            if let event = nextEvent {
                Text("→ \(event.startTime) \(event.title)")
                    .lineLimit(1)
            } else {
                Text("watch_widget_no_events_short")
                    .lineLimit(1)
            }
        }
    }

#if os(watchOS)
    private var cornerBody: some View {
        Group {
            if let event = nextEvent {
                Text(event.startTime)
                    .font(.headline.monospacedDigit())
                    .widgetLabel {
                        if let loc = event.shortLocation() {
                            Text("→ \(event.title) · \(loc)")
                        } else {
                            Text("→ \(event.title)")
                        }
                    }
            } else {
                Image(systemName: "checkmark.circle")
                    .widgetLabel {
                        Text("watch_widget_no_events_short")
                    }
            }
        }
        .widgetAccentable()
    }
#endif
}

// MARK: - 3. Dedicated Classroom Widget View

struct ClassRoomWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ScheduleWidgetEntry

    private var relevantEvent: WatchWidgetSnapshot.Event? {
        entry.currentEvent
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circularBody
            case .accessoryInline:
                inlineBody
#if os(watchOS)
            case .accessoryCorner:
                cornerBody
#endif
            default:
                circularBody
            }
        }
        .privacySensitive()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var circularBody: some View {
        Group {
            if let event = relevantEvent, let room = event.shortLocation() {
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: 0) {
                        Text(event.isCurrent(at: entry.date) ? String(localized: "watch_widget_current_class") : event.startTime)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(event.accentColor)
                            .widgetAccentable()

                        Text(room)
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)

                        Text(event.lessonType?.uppercased() ?? event.title)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(2)
                }
            } else {
                Image(systemName: "door.left.hand.open")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .widgetAccentable()
            }
        }
    }

    private var inlineBody: some View {
        Group {
            if let event = relevantEvent, let room = event.shortLocation() {
                Text("\(room) · \(event.title)")
                    .lineLimit(1)
            } else {
                Text("watch_widget_no_events_short")
                    .lineLimit(1)
            }
        }
    }

#if os(watchOS)
    private var cornerBody: some View {
        Group {
            if let event = relevantEvent, let room = event.shortLocation() {
                Text(room)
                    .font(.headline.weight(.heavy))
                    .widgetLabel {
                        Text("\(event.title) · \(event.startTime)")
                    }
            } else {
                Image(systemName: "door.left.hand.open")
                    .widgetLabel {
                        Text("watch_widget_no_events_short")
                    }
            }
        }
        .widgetAccentable()
    }
#endif
}

// MARK: - 4. Dedicated Class Progress Widget View

struct ClassProgressWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ScheduleWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circularBody
            case .accessoryInline:
                inlineBody
#if os(watchOS)
            case .accessoryCorner:
                cornerBody
#endif
            default:
                circularBody
            }
        }
        .privacySensitive()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var circularBody: some View {
        Group {
            if let event = entry.currentEvent, event.isCurrent(at: entry.date), let interval = event.interval() {
                let progress = event.progress(at: entry.date)
                let remainingMinutes = max(0, Int(ceil(interval.end.timeIntervalSince(entry.date) / 60.0)))
                Gauge(value: progress, in: 0...1) {
                    Image(systemName: event.lessonIcon)
                        .foregroundStyle(event.accentColor)
                } currentValueLabel: {
                    Text("\(remainingMinutes)m")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.7)
                }
                .gaugeStyle(.accessoryCircular)
                .tint(event.accentColor)
                .widgetAccentable()
            } else if let next = entry.snapshot?.nextUpcomingEvent(after: entry.date), let interval = next.interval() {
                let minutesUntil = max(0, Int(ceil(interval.start.timeIntervalSince(entry.date) / 60.0)))
                Gauge(value: 0, in: 0...1) {
                    Image(systemName: "hourglass")
                } currentValueLabel: {
                    Text("+\(minutesUntil)m")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.7)
                }
                .gaugeStyle(.accessoryCircular)
                .widgetAccentable()
            } else {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .widgetAccentable()
            }
        }
    }

    private var inlineBody: some View {
        Group {
            if let event = entry.currentEvent, event.isCurrent(at: entry.date), let interval = event.interval() {
                let remainingMinutes = max(0, Int(ceil(interval.end.timeIntervalSince(entry.date) / 60.0)))
                Text("\(event.title): \(remainingMinutes)m")
                    .lineLimit(1)
            } else if let next = entry.snapshot?.nextUpcomingEvent(after: entry.date), let interval = next.interval() {
                let minutesUntil = max(0, Int(ceil(interval.start.timeIntervalSince(entry.date) / 60.0)))
                Text("+\(minutesUntil)m: \(next.title)")
                    .lineLimit(1)
            } else {
                Text("watch_widget_no_events_short")
                    .lineLimit(1)
            }
        }
    }

#if os(watchOS)
    private var cornerBody: some View {
        Group {
            if let event = entry.currentEvent, event.isCurrent(at: entry.date), let interval = event.interval() {
                let remainingMinutes = max(0, Int(ceil(interval.end.timeIntervalSince(entry.date) / 60.0)))
                Text("\(remainingMinutes)m")
                    .font(.headline.monospacedDigit())
                    .widgetLabel {
                        Text("\(event.title) · \(event.endTime)")
                    }
            } else if let next = entry.snapshot?.nextUpcomingEvent(after: entry.date) {
                Text(next.startTime)
                    .font(.headline.monospacedDigit())
                    .widgetLabel {
                        Text("→ \(next.title)")
                    }
            } else {
                Image(systemName: "checkmark.circle")
                    .widgetLabel {
                        Text("watch_widget_no_events_short")
                    }
            }
        }
        .widgetAccentable()
    }
#endif
}

// MARK: - Widget Configurations

// 1. Adaptive Schedule Widget
// swiftlint:disable:next type_name
struct MyIIS_Watch_Widget: Widget {
    let kind = "com.OrDinaD.MyIIS.watch.schedule"

    private var supportedFamilies: [WidgetFamily] {
#if os(watchOS)
        [.accessoryRectangular, .accessoryCircular, .accessoryInline, .accessoryCorner]
#else
        [.accessoryRectangular, .accessoryCircular, .accessoryInline]
#endif
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScheduleWidgetProvider()) { entry in
            ScheduleWidgetView(entry: entry)
        }
        .configurationDisplayName("watch_widget_name")
        .description("watch_widget_description")
        .supportedFamilies(supportedFamilies)
    }
}

// 2. Next Class Widget
struct NextClassWatchWidget: Widget {
    let kind = "com.OrDinaD.MyIIS.watch.nextClass"

    private var supportedFamilies: [WidgetFamily] {
#if os(watchOS)
        [.accessoryCircular, .accessoryCorner, .accessoryInline]
#else
        [.accessoryCircular, .accessoryInline]
#endif
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScheduleWidgetProvider()) { entry in
            NextClassWidgetView(entry: entry)
        }
        .configurationDisplayName("watch_widget_next_class_name")
        .description("watch_widget_next_class_description")
        .supportedFamilies(supportedFamilies)
    }
}

// 3. Classroom Widget
struct ClassRoomWatchWidget: Widget {
    let kind = "com.OrDinaD.MyIIS.watch.classroom"

    private var supportedFamilies: [WidgetFamily] {
#if os(watchOS)
        [.accessoryCircular, .accessoryCorner, .accessoryInline]
#else
        [.accessoryCircular, .accessoryInline]
#endif
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScheduleWidgetProvider()) { entry in
            ClassRoomWidgetView(entry: entry)
        }
        .configurationDisplayName("watch_widget_room_name")
        .description("watch_widget_room_description")
        .supportedFamilies(supportedFamilies)
    }
}

// 4. Class Progress Widget
struct ClassProgressWatchWidget: Widget {
    let kind = "com.OrDinaD.MyIIS.watch.progress"

    private var supportedFamilies: [WidgetFamily] {
#if os(watchOS)
        [.accessoryCircular, .accessoryCorner, .accessoryInline]
#else
        [.accessoryCircular, .accessoryInline]
#endif
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScheduleWidgetProvider()) { entry in
            ClassProgressWidgetView(entry: entry)
        }
        .configurationDisplayName("watch_widget_progress_name")
        .description("watch_widget_progress_description")
        .supportedFamilies(supportedFamilies)
    }
}
