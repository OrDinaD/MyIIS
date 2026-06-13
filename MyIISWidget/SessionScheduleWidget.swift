//
//  SessionScheduleWidget.swift
//  MyIISWidgetExtension
//
import SwiftUI
import WidgetKit

struct SessionScheduleWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: SessionScheduleWidgetSnapshot?

    var groupName: String {
        snapshot?.groupName ?? "420603"
    }

    var upcomingEvents: [SessionScheduleWidgetSnapshot.Event] {
        guard let snapshot else { return Self.placeholderSnapshot.events }
        let today = Calendar.current.startOfDay(for: Date())
        let future = snapshot.events.filter { event in
            guard let date = event.date else { return true }
            return Calendar.current.startOfDay(for: date) >= today
        }
        return future.isEmpty ? snapshot.events : future
    }

    static let placeholderSnapshot = SessionScheduleWidgetSnapshot(
        groupName: "420603",
        startDate: Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 8)),
        endDate: Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 2)),
        events: [
            .init(
                id: "announcement-1",
                date: Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 8)),
                startTime: "14:00",
                endTime: "16:00",
                title: "Объявление",
                subtitle: "Сдача задолженностей, рецензирование",
                location: nil,
                kind: .announcement
            ),
            .init(
                id: "announcement-2",
                date: Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 8)),
                startTime: "16:00",
                endTime: "18:00",
                title: "Объявление",
                subtitle: "601а-5 к, Зачет по САиИО",
                location: "601а-5 к",
                kind: .announcement
            ),
            .init(
                id: "tppo-consultation",
                date: Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 11)),
                startTime: "12:00",
                endTime: "13:00",
                title: "ТППО",
                subtitle: "604-5 к",
                location: "604-5 к",
                kind: .consultation
            ),
            .init(
                id: "tppo-exam",
                date: Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 12)),
                startTime: "08:30",
                endTime: "14:00",
                title: "ТППО",
                subtitle: "604-5 к",
                location: "604-5 к",
                kind: .exam
            ),
            .init(
                id: "db-consultation",
                date: Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 16)),
                startTime: "14:00",
                endTime: "15:00",
                title: "БД",
                subtitle: "604-5 к",
                location: "604-5 к",
                kind: .consultation
            )
        ],
        updatedAt: Date()
    )
}

struct SessionScheduleWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SessionScheduleWidgetEntry {
        SessionScheduleWidgetEntry(date: .now, snapshot: SessionScheduleWidgetEntry.placeholderSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (SessionScheduleWidgetEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        completion(SessionScheduleWidgetEntry(date: .now, snapshot: SessionScheduleWidgetDataStore.loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SessionScheduleWidgetEntry>) -> Void) {
        let snapshot = SessionScheduleWidgetDataStore.loadSnapshot()
        let now = Date()

        let dates = makeTimelineDates(snapshot: snapshot, from: now)
        let entries = dates.map {
            SessionScheduleWidgetEntry(date: $0, snapshot: snapshot)
        }

        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 2, to: now)
            ?? now.addingTimeInterval(2 * 60 * 60)

        completion(Timeline(entries: entries, policy: .after(nextRefresh)))
    }

    private func makeTimelineDates(
        snapshot: SessionScheduleWidgetSnapshot?,
        from now: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        guard let snapshot else { return [now] }

        var dates: Set<Date> = [now]

        for event in snapshot.events {
            guard let interval = event.interval(calendar: calendar) else { continue }

            if interval.end >= now {
                dates.insert(interval.start)
                dates.insert(interval.end)

                var cursor = max(interval.start, now)
                while cursor < interval.end {
                    if let next = calendar.date(byAdding: .minute, value: 15, to: cursor) {
                        dates.insert(next)
                        cursor = next
                    } else {
                        break
                    }
                }
            }
        }

        return dates
            .filter { $0 >= now }
            .sorted()
            .prefix(24)
            .map { $0 }
    }
}

struct SessionScheduleWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetContentMargins) private var widgetContentMargins
    let entry: SessionScheduleWidgetEntry

    private var visibleEvents: [SessionScheduleWidgetSnapshot.Event] {
        Array(entry.upcomingEvents.prefix(eventLimit))
    }

    private var hiddenEvents: [SessionScheduleWidgetSnapshot.Event] {
        Array(entry.upcomingEvents.dropFirst(eventLimit))
    }

    private var eventLimit: Int {
        switch family {
        case .systemSmall:
            return 1
        case .systemMedium:
            return 2
        default:
            return 4
        }
    }

    var body: some View {
        Group {
            if entry.snapshot == nil {
                emptyContent
            } else {
                content
            }
        }
        .dynamicTypeSize(.medium ... .large)
        .applySessionWidgetBackground()
        .widgetURL(URL(string: "myiis://section/schedule"))
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
                .layoutPriority(10)

            VStack(alignment: .leading, spacing: sectionSpacing) {
                ForEach(groupedVisibleEvents) { day in
                    daySection(day)
                }

                if showsFooter {
                    Spacer(minLength: 0)
                    footer
                } else {
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, contentHorizontalPadding)
            .padding(.top, contentTopPadding)
            .padding(.bottom, contentBottomPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var showsFooter: Bool {
        !hiddenEvents.isEmpty && family == .systemLarge
    }

    private var sectionSpacing: CGFloat {
        family == .systemLarge ? 3 : 4
    }

    private var contentHorizontalPadding: CGFloat {
        min(max(widgetContentMargins.leading, 14), family == .systemLarge ? 20 : 16)
    }

    private var contentTopPadding: CGFloat {
        family == .systemLarge ? 7 : 5
    }

    private var contentBottomPadding: CGFloat {
        family == .systemLarge ? 8 : 6
    }

    private var headerHeight: CGFloat {
        family == .systemLarge ? 42 : 40
    }

    private var headerDateFont: Font {
        .system(size: family == .systemLarge ? 16 : 15,
                weight: .bold,
                design: .rounded)
    }

    private var headerGroupFont: Font {
        .system(size: family == .systemLarge ? 17 : 16,
                weight: .semibold,
                design: .rounded)
    }

    private var header: some View {
        ZStack {
            headerGradient

            HStack(spacing: 8) {
                Text(headerDateText)
                    .font(headerDateFont)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .allowsTightening(true)

                Spacer(minLength: 8)

                Text(entry.groupName)
                    .font(headerGroupFont)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, family == .systemLarge ? 16 : 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: headerHeight)
        .clipped()
    }

    private func daySection(_ day: SessionWidgetDay) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if day.id != groupedVisibleEvents.first?.id {
                Text(dateText(for: day.date))
                    .font(.system(size: family == .systemLarge ? 13 : 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
            }

            ForEach(day.events) { event in
                SessionWidgetEventRow(event: event, compact: family != .systemLarge, now: entry.date)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Text(dateText(for: hiddenEvents.first?.date))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Circle()
                .fill(.white.opacity(0.55))
                .frame(width: 6, height: 6)
            Text(hiddenSummary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .allowsTightening(true)
        }
        .padding(.top, 1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Spacer(minLength: 0)
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
            Text("Открой расписание сессии в приложении")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
            Text("После первой загрузки виджет будет обновляться из кэша.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.bottom, 14)
    }

    private var groupedVisibleEvents: [SessionWidgetDay] {
        let grouped = Dictionary(grouping: visibleEvents) { event in
            event.date.map { Calendar.current.startOfDay(for: $0) } ?? Date.distantFuture
        }
        return grouped.keys.sorted().map { date in
            SessionWidgetDay(date: date, events: grouped[date, default: []])
        }
    }

    private var hiddenSummary: String {
        let titles = hiddenEvents.map(\.title).filter { !$0.isEmpty }
        let shownTitles = Array(titles.prefix(3))
        let rest = max(0, titles.count - shownTitles.count)
        if rest > 0 {
            return "\(shownTitles.joined(separator: ", ")) и еще \(rest)"
        }
        return shownTitles.joined(separator: ", ")
    }

    private var headerDateText: String {
        if let firstDate = visibleEvents.first?.date {
            return SessionScheduleWidgetDateFormatting.numericDateText(from: firstDate)
        }
        return SessionScheduleWidgetDateFormatting.numericDateText(from: Date())
    }

    private var headerGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.62, blue: 0.70),
                Color(red: 0.08, green: 0.36, blue: 0.88)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func dateText(for date: Date?) -> String {
        guard let date, date != Date.distantFuture else { return "Дата" }
        return SessionScheduleWidgetDateFormatting.numericDateText(from: date)
    }
}

private struct SessionWidgetDay: Identifiable {
    let date: Date
    let events: [SessionScheduleWidgetSnapshot.Event]

    var id: String {
        String(Int(date.timeIntervalSince1970))
    }
}

private struct SessionWidgetEventRow: View {
    let event: SessionScheduleWidgetSnapshot.Event
    let compact: Bool
    let now: Date

    var body: some View {
        HStack(spacing: compact ? 8 : 9) {
            VStack(spacing: 0) {
                Text(event.startTime)
                Text(event.endTime)
            }
            .font(.system(size: compact ? 15 : 14,
                          weight: .medium,
                          design: .monospaced))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.76)
            .frame(width: compact ? 58 : 54)

            progressStrip

            VStack(alignment: .leading, spacing: 0) {
                Text(displayTitle)
                    .font(.system(size: compact ? 18 : 17,
                                  weight: .bold,
                                  design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .allowsTightening(true)

                if let subtitle = event.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14,
                                      weight: .regular,
                                      design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                        .allowsTightening(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: compact ? 44 : 42)
    }

    private var progressStrip: some View {
        GeometryReader { proxy in
            let progress = event.isActive(at: now) ? (event.progress(at: now) ?? 0) : 1

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(accentColor.opacity(event.isActive(at: now) ? 0.28 : 1.0))

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(accentColor)
                    .frame(height: proxy.size.height * progress)
            }
        }
        .frame(width: compact ? 5 : 6, height: compact ? 38 : 36)
    }

    private var displayTitle: String {
        event.kind == .announcement ? "📣 \(event.title)" : event.title
    }

    private var accentColor: Color {
        switch event.kind {
        case .announcement:
            return Color(red: 0.96, green: 0.78, blue: 0.27)
        case .exam:
            return Color(red: 1.0, green: 0.40, blue: 0.24)
        case .consultation:
            return Color(red: 0.12, green: 0.78, blue: 0.70)
        case .other:
            return Color(red: 0.27, green: 0.54, blue: 0.96)
        }
    }
}

struct SessionScheduleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SessionScheduleWidgetConstants.kind, provider: SessionScheduleWidgetProvider()) { entry in
            SessionScheduleWidgetView(entry: entry)
        }
        .configurationDisplayName("Сессия")
        .description("Показывает ближайшие экзамены, консультации и объявления вашей группы.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(false)
    }
}

#Preview("Сессия Medium", as: .systemMedium) {
    SessionScheduleWidget()
} timeline: {
    SessionScheduleWidgetEntry(date: .now, snapshot: SessionScheduleWidgetEntry.placeholderSnapshot)
}

#Preview("Сессия Large", as: .systemLarge) {
    SessionScheduleWidget()
} timeline: {
    SessionScheduleWidgetEntry(date: .now, snapshot: SessionScheduleWidgetEntry.placeholderSnapshot)
}

private extension View {
    @ViewBuilder
    func applySessionWidgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) {
                Color(red: 0.04, green: 0.08, blue: 0.10)
            }
        } else {
            background(Color(red: 0.04, green: 0.08, blue: 0.10))
        }
    }
}
