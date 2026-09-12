import SwiftUI
import WidgetKit

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

        // The nested enum is part of the existing wire DTO.
        // swiftlint:disable:next nesting
        enum Kind: String, Codable, Sendable {
            case announcement
            case exam
            case consultation
            case other
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

            // Handle lessons crossing midnight gracefully
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
            }
            return text.isEmpty ? nil : text
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

private enum WatchWidgetStore {
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

private struct ScheduleWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchWidgetSnapshot?

    var relevance: TimelineEntryRelevance? {
        guard let event = snapshot?.relevantEvent(at: date),
              let interval = event.interval() else {
            return nil
        }

        if interval.contains(date) {
            return TimelineEntryRelevance(score: 100, duration: interval.end.timeIntervalSince(date))
        }

        let leadTime = interval.start.timeIntervalSince(date)
        guard leadTime <= 45 * 60 else { return nil }
        return TimelineEntryRelevance(score: 80, duration: max(leadTime, 0) + interval.duration)
    }

    var currentEvent: WatchWidgetSnapshot.Event? {
        snapshot?.relevantEvent(at: date)
    }
}

private struct ScheduleWidgetProvider: TimelineProvider {
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
                let leadTime = interval.start.addingTimeInterval(-30 * 60)
                if leadTime >= now {
                    dates.insert(leadTime)
                }
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
}

private struct ScheduleWidgetView: View {
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

    // MARK: - Rectangular (Max 3 lines, high-contrast, clean hierarchy)

    private var rectangularContent: some View {
        Group {
            if let event = entry.currentEvent {
                VStack(alignment: .leading, spacing: 2) {
                    // Line 1: Status icon, time interval, and state pill
                    HStack(alignment: .center, spacing: 4) {
                        Image(systemName: event.isCurrent(at: entry.date) ? "clock.fill" : "calendar")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(event.isCurrent(at: entry.date) ? Color.green : Color.orange)
                            .widgetAccentable()

                        statusTimeText(event)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        statusBadge(event)
                    }

                    // Line 2: Subject Title (prominent semibold)
                    Text(event.title)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    // Line 3: Location and Lesson Type
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

    // MARK: - Circular (Concentric progress ring or gauge + crisp central icon/time)

    private var circularContent: some View {
        Group {
            if let event = entry.currentEvent {
                if event.isCurrent(at: entry.date), let interval = event.interval() {
                    ZStack {
                        ProgressView(timerInterval: interval.start ... interval.end, countsDown: false)
                            .progressViewStyle(.circular)
                            .tint(.green)
                            .widgetAccentable()
                            .labelsHidden()

                        Image(systemName: "clock.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                            .widgetAccentable()
                    }
                    .accessibilityLabel(event.title)
                    .accessibilityValue(Text(timerInterval: interval.start ... interval.end, countsDown: true))
                } else {
                    Gauge(value: 0) {
                        Image(systemName: "calendar")
                            .widgetAccentable()
                    } currentValueLabel: {
                        Text(event.startTime)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                    }
                    .gaugeStyle(.accessoryCircular)
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
                .background(Capsule().fill(Color.green.opacity(0.2)))
                .foregroundStyle(Color.green)
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
            Text("\(event.startTime)-\(event.endTime)")
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

// Target-generated widget type keeps the product name used by Xcode.
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

// MARK: - Previews

#Preview("Rectangular (Идёт пара)", as: .accessoryRectangular) {
    MyIIS_Watch_Widget()
} timeline: {
    ScheduleWidgetEntry(date: .now, snapshot: .placeholder())
}

#Preview("Rectangular (Следующая)", as: .accessoryRectangular) {
    MyIIS_Watch_Widget()
} timeline: {
    ScheduleWidgetEntry(date: .now, snapshot: .upcomingPlaceholder())
}

#Preview("Rectangular (Пусто)", as: .accessoryRectangular) {
    MyIIS_Watch_Widget()
} timeline: {
    ScheduleWidgetEntry(date: .now, snapshot: nil)
}

#Preview("Circular (Идёт пара)", as: .accessoryCircular) {
    MyIIS_Watch_Widget()
} timeline: {
    ScheduleWidgetEntry(date: .now, snapshot: .placeholder())
}

#Preview("Circular (Следующая)", as: .accessoryCircular) {
    MyIIS_Watch_Widget()
} timeline: {
    ScheduleWidgetEntry(date: .now, snapshot: .upcomingPlaceholder())
}

#Preview("Circular (Пусто)", as: .accessoryCircular) {
    MyIIS_Watch_Widget()
} timeline: {
    ScheduleWidgetEntry(date: .now, snapshot: nil)
}
