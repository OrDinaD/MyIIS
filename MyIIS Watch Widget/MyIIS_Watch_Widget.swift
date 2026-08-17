import SwiftUI
import WidgetKit

private struct WatchWidgetSnapshot: Codable, Sendable {
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

            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = startParts[0]
            components.minute = startParts[1]
            guard let start = calendar.date(from: components) else { return nil }
            components.hour = endParts[0]
            components.minute = endParts[1]
            guard let end = calendar.date(from: components), end > start else { return nil }
            return DateInterval(start: start, end: end)
        }

        func isCurrent(at date: Date) -> Bool {
            interval()?.contains(date) == true
        }

        func progress(at date: Date) -> Double {
            guard let interval = interval() else { return 0 }
            if date <= interval.start { return 0 }
            if date >= interval.end { return 1 }
            return date.timeIntervalSince(interval.start) / interval.duration
        }
    }

    func upcomingEvents(at date: Date) -> [Event] {
        events
            .filter { ($0.interval()?.end ?? $0.date ?? .distantPast) >= date }
            .sorted {
                ($0.interval()?.start ?? $0.date ?? .distantFuture) <
                ($1.interval()?.start ?? $1.date ?? .distantFuture)
            }
    }

    static func placeholder(now: Date = .now) -> WatchWidgetSnapshot {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .minute, value: -20, to: now) ?? now
        let end = calendar.date(byAdding: .minute, value: 65, to: now) ?? now
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return WatchWidgetSnapshot(
            groupName: "Летняя школа",
            startDate: now,
            endDate: now,
            events: [
                Event(
                    id: "preview",
                    date: now,
                    startTime: formatter.string(from: start),
                    endTime: formatter.string(from: end),
                    title: "SwiftUI",
                    subtitle: "Лекция",
                    location: "301",
                    lessonType: "Лекция",
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
        guard let event = snapshot?.upcomingEvents(at: date).first,
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
        snapshot?.upcomingEvents(at: date).first
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
                dates.insert(interval.start.addingTimeInterval(-30 * 60))
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

    private var rectangularContent: some View {
        Group {
            if let event = entry.currentEvent {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Image(systemName: event.isCurrent(at: entry.date) ? "clock.fill" : "calendar")
                            statusText(event)
                                .monospacedDigit()
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .widgetAccentable()

                        Text(event.title)
                            .font(.headline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Text([event.location, event.lessonType].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(
                            event.isCurrent(at: entry.date)
                                ? String(localized: "watch_widget_current_class")
                                : String(localized: "watch_widget_upcoming_class_short")
                        )
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(event.isCurrent(at: entry.date) ? Color.green : Color.orange)

                        Text("\(event.startTime)-\(event.endTime)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            } else {
                Label("watch_widget_no_events", systemImage: "checkmark.circle")
                    .font(.headline)
            }
        }
    }

    private var circularContent: some View {
        Group {
            if let event = entry.currentEvent {
                if event.isCurrent(at: entry.date), let interval = event.interval() {
                    ProgressView(timerInterval: interval.start ... interval.end, countsDown: false)
                        .labelsHidden()
                        .tint(.green)
                        .widgetAccentable()
                        .accessibilityLabel(event.title)
                        .accessibilityValue(Text(timerInterval: interval.start ... interval.end, countsDown: true))
                } else {
                    Gauge(value: 0) {
                        Image(systemName: "calendar")
                    } currentValueLabel: {
                        Text(event.startTime)
                            .font(.caption2.monospacedDigit())
                            .minimumScaleFactor(0.5)
                    }
                    .gaugeStyle(.accessoryCircular)
                    .widgetAccentable()
                    .accessibilityLabel(event.title)
                    .accessibilityValue(event.startTime)
                }
            } else {
                Image(systemName: "checkmark")
            }
        }
    }

    private var inlineContent: some View {
        Group {
            if let event = entry.currentEvent {
                Text("\(event.startTime) \(event.title)")
                    .lineLimit(1)
            } else {
                Text("watch_widget_no_events")
            }
        }
    }

#if os(watchOS)
    private var cornerContent: some View {
        Group {
            if let event = entry.currentEvent {
                Text(event.isCurrent(at: entry.date) ? event.endTime : event.startTime)
                    .font(.headline.monospacedDigit())
                    .widgetLabel {
                        Text(event.title)
                    }
            } else {
                Image(systemName: "checkmark")
                    .widgetLabel {
                        Text("watch_widget_no_events")
                    }
            }
        }
        .widgetAccentable()
    }
#endif

    @ViewBuilder
    private func statusText(_ event: WatchWidgetSnapshot.Event) -> some View {
        if event.isCurrent(at: entry.date) {
            HStack(spacing: 2) {
                Text("watch_widget_until")
                Text(event.endTime)
            }
        } else {
            Text(event.startTime)
        }
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

#Preview(as: .accessoryRectangular) {
    MyIIS_Watch_Widget()
} timeline: {
    ScheduleWidgetEntry(date: .now, snapshot: .placeholder())
}

#Preview(as: .accessoryCircular) {
    MyIIS_Watch_Widget()
} timeline: {
    ScheduleWidgetEntry(date: .now, snapshot: .placeholder())
}
