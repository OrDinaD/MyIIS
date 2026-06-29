//
//  SessionScheduleWidget.swift
//  MyIISWidgetExtension
//
// swiftlint:disable file_length
import SwiftUI
import WidgetKit

struct SessionScheduleWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: SessionScheduleWidgetSnapshot?

    var groupName: String {
        snapshot?.groupName ?? "420603"
    }

    var upcomingEvents: [SessionScheduleWidgetSnapshot.Event] {
        upcomingEvents(from: date)
    }

    func upcomingEvents(
        from referenceDate: Date,
        calendar: Calendar = .current
    ) -> [SessionScheduleWidgetSnapshot.Event] {
        guard let snapshot else { return Self.placeholderSnapshot.events }
        return snapshot.events.filter { event in
            event.isUpcoming(at: referenceDate, calendar: calendar)
        }
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
                lessonType: "Объявление",
                kind: .announcement
            ),
            .init(
                id: "tppo-exam",
                date: Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 12)),
                startTime: "08:30",
                endTime: "14:00",
                title: "ТППО",
                subtitle: "604-5 к",
                location: "604-5 к",
                lessonType: "Экзамен",
                kind: .exam
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

        let dates = Self.makeTimelineDates(snapshot: snapshot, from: now)
        let entries = dates.map {
            SessionScheduleWidgetEntry(date: $0, snapshot: snapshot)
        }

        let nextRefresh = Self.nextRefreshDate(snapshot: snapshot, from: now)

        completion(Timeline(entries: entries, policy: .after(nextRefresh)))
    }

    static func makeTimelineDates(
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
                    if let next = calendar.date(byAdding: .minute, value: 5, to: cursor) {
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
            .prefix(64)
            .map { $0 }
    }

    static func nextRefreshDate(
        snapshot: SessionScheduleWidgetSnapshot?,
        from now: Date,
        calendar: Calendar = .current
    ) -> Date {
        let fallbackMinutes = snapshot == nil ? 30 : 120
        let fallback = calendar.date(byAdding: .minute, value: fallbackMinutes, to: now)
            ?? now.addingTimeInterval(TimeInterval(fallbackMinutes * 60))

        guard let snapshot else { return fallback }
        let nextBoundary = snapshot.events
            .flatMap { event -> [Date] in
                guard let interval = event.interval(calendar: calendar) else { return [] }
                return [interval.start, interval.end]
            }
            .filter { $0 > now }
            .sorted()
            .first

        guard let nextBoundary else { return fallback }
        return min(nextBoundary, fallback)
    }
}

struct ClassScheduleWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SessionScheduleWidgetEntry {
        SessionScheduleWidgetEntry(date: .now, snapshot: SessionScheduleWidgetEntry.placeholderSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (SessionScheduleWidgetEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        completion(SessionScheduleWidgetEntry(date: .now, snapshot: ClassScheduleWidgetDataStore.loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SessionScheduleWidgetEntry>) -> Void) {
        let snapshot = ClassScheduleWidgetDataStore.loadSnapshot()
        let now = Date()
        let dates = SessionScheduleWidgetProvider.makeTimelineDates(snapshot: snapshot, from: now)
        let entries = dates.map { SessionScheduleWidgetEntry(date: $0, snapshot: snapshot) }
        let nextRefresh = SessionScheduleWidgetProvider.nextRefreshDate(snapshot: snapshot, from: now)
        completion(Timeline(entries: entries, policy: .after(nextRefresh)))
    }
}

enum ScheduleWidgetStyle {
    case classes
    case session
}

// swiftlint:disable:next type_body_length
struct SessionScheduleWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetContentMargins) private var widgetContentMargins
    let entry: SessionScheduleWidgetEntry
    var style: ScheduleWidgetStyle = .session

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
            if family == .accessoryRectangular {
                accessoryContent
            } else if entry.snapshot == nil {
                emptyContent
            } else if visibleEvents.isEmpty {
                noUpcomingContent
            } else if style == .classes {
                classContent
            } else {
                content
            }
        }
        .dynamicTypeSize(.medium ... .large)
        .applySessionWidgetBackground(isFilled: style == .session)
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

    private var classContent: some View {
        Group {
            if let event = visibleEvents.first {
                VStack(spacing: classVerticalSpacing) {
                    Text(classTimeText(for: event))
                        .font(.system(size: classTimeFontSize, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 0)

                    HStack(spacing: 10) {
                        minimalProgressStrip(for: event)

                        VStack(spacing: 4) {
                            Image(systemName: classTypeIcon(for: event))
                                .font(.system(size: classIconSize, weight: .semibold))
                                .foregroundStyle(classAccentColor(for: event))
                                .widgetAccentable()

                            Text(event.title)
                                .font(.system(size: classTitleFontSize, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(family == .systemLarge ? 2 : 1)
                                .minimumScaleFactor(0.62)
                                .privacySensitive()
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Spacer(minLength: 0)

                    Text(classLocationText(for: event))
                        .font(.system(size: classLocationFontSize, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .privacySensitive()
                }
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.vertical, family == .systemLarge ? 18 : 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                noUpcomingContent
            }
        }
    }

    private var accessoryContent: some View {
        ZStack(alignment: .leading) {
            AccessoryWidgetBackground()

            if let event = visibleEvents.first {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2.weight(.semibold))
                        Text(accessoryStatus(for: event))
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                    .widgetAccentable()

                    Text(event.title)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .privacySensitive()

                    Text(accessorySubtitle(for: event))
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .foregroundStyle(.secondary)
                        .privacySensitive()
                }
                .padding(.horizontal, 6)
            } else {
                Text("Нет ближайших событий")
                    .font(.headline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .padding(.horizontal, 6)
            }
        }
    }

    private var classVerticalSpacing: CGFloat {
        family == .systemLarge ? 10 : 8
    }

    private var classTimeFontSize: CGFloat {
        family == .systemLarge ? 18 : 15
    }

    private var classTitleFontSize: CGFloat {
        family == .systemLarge ? 25 : 21
    }

    private var classLocationFontSize: CGFloat {
        family == .systemLarge ? 17 : 14
    }

    private var classIconSize: CGFloat {
        family == .systemLarge ? 24 : 20
    }

    private func classTimeText(for event: SessionScheduleWidgetSnapshot.Event) -> String {
        if event.isActive(at: entry.date) {
            return "Сейчас до \(event.endTime)"
        }
        return "\(event.startTime)-\(event.endTime)"
    }

    private func classLocationText(for event: SessionScheduleWidgetSnapshot.Event) -> String {
        let source = nonEmpty(event.location) ?? nonEmpty(event.subtitle) ?? "Аудитория не указана"
        return source
            .replacingOccurrences(of: " к.", with: "")
            .replacingOccurrences(of: " к", with: "")
            .replacingOccurrences(of: " корпус", with: "")
            .replacingOccurrences(of: "Корпус ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func minimalProgressStrip(for event: SessionScheduleWidgetSnapshot.Event) -> some View {
        GeometryReader { proxy in
            let progress = event.isActive(at: entry.date) ? (event.progress(at: entry.date) ?? 0) : 0

            ZStack(alignment: .top) {
                Capsule()
                    .fill(classAccentColor(for: event).opacity(0.22))

                Capsule()
                    .fill(classAccentColor(for: event))
                    .frame(height: max(6, proxy.size.height * progress))
            }
            .widgetAccentable()
        }
        .frame(width: 5, height: family == .systemLarge ? 76 : 58)
    }

    private func classTypeIcon(for event: SessionScheduleWidgetSnapshot.Event) -> String {
        let type = (event.lessonType ?? event.subtitle ?? "").lowercased()
        if event.kind == .exam || type.contains("экзам") { return "graduationcap.fill" }
        if event.kind == .consultation || type.contains("конс") { return "bubble.left.and.text.bubble.right.fill" }
        if type.contains("лр") || type.contains("лаб") { return "flask.fill" }
        if type.contains("пз") || type.contains("практ") { return "pencil.and.list.clipboard" }
        if type.contains("лк") || type.contains("лек") { return "book.closed.fill" }
        if event.kind == .announcement { return "megaphone.fill" }
        return "calendar"
    }

    private func classAccentColor(for event: SessionScheduleWidgetSnapshot.Event) -> Color {
        let type = (event.lessonType ?? event.subtitle ?? "").lowercased()
        if event.kind == .exam || type.contains("экзам") { return Color(red: 1.0, green: 0.34, blue: 0.24) }
        if event.kind == .consultation || type.contains("конс") { return Color(red: 0.56, green: 0.32, blue: 0.92) }
        if type.contains("лр") || type.contains("лаб") { return Color(red: 0.10, green: 0.72, blue: 0.44) }
        if type.contains("пз") || type.contains("практ") { return Color(red: 0.98, green: 0.63, blue: 0.18) }
        if type.contains("лк") || type.contains("лек") { return Color(red: 0.16, green: 0.48, blue: 0.96) }
        if event.kind == .announcement { return Color(red: 0.96, green: 0.72, blue: 0.22) }
        return Color(red: 0.24, green: 0.72, blue: 0.86)
    }

    private func accessoryStatus(for event: SessionScheduleWidgetSnapshot.Event) -> String {
        if event.isActive(at: entry.date) {
            return "Сейчас до \(event.endTime)"
        }
        return "Следующая в \(event.startTime)"
    }

    private func accessorySubtitle(for event: SessionScheduleWidgetSnapshot.Event) -> String {
        let chunks = [nonEmpty(event.location), nonEmpty(event.subtitle)].compactMap { $0 }
        let value = chunks.joined(separator: " • ")
        return nonEmpty(value) ?? event.endTime
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
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
        widgetMessageContent(
            icon: "calendar.badge.exclamationmark",
            title: "Открой расписание в приложении",
            subtitle: "После первой загрузки виджет будет обновляться из кэша."
        )
    }

    private var noUpcomingContent: some View {
        widgetMessageContent(
            icon: "calendar.badge.clock",
            title: "Ближайших событий нет",
            subtitle: "Последний кэш расписания сохранен для офлайн-доступа."
        )
    }

    private func widgetMessageContent(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Spacer(minLength: 0)
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
            Text(subtitle)
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
            .widgetAccentable()

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
                    .widgetAccentable()

                if let subtitle = event.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14,
                                      weight: .regular,
                                      design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                        .allowsTightening(true)
                        .widgetAccentable()
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
            .widgetAccentable()
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

struct ClassScheduleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: ClassScheduleWidgetConstants.kind, provider: ClassScheduleWidgetProvider()) { entry in
            SessionScheduleWidgetView(entry: entry, style: .classes)
        }
        .configurationDisplayName("Пары")
        .description("Показывает ближайшую пару вашей группы: время, предмет и аудиторию.")
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

struct SessionScheduleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SessionScheduleWidgetConstants.kind, provider: SessionScheduleWidgetProvider()) { entry in
            SessionScheduleWidgetView(entry: entry)
        }
        .configurationDisplayName("Сессия")
        .description("Показывает ближайшие экзамены, консультации и объявления вашей группы.")
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryRectangular])
        .contentMarginsDisabled()
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

#Preview("Пары Lock Screen", as: .accessoryRectangular) {
    ClassScheduleWidget()
} timeline: {
    SessionScheduleWidgetEntry(date: .now, snapshot: SessionScheduleWidgetEntry.placeholderSnapshot)
}

private extension View {
    @ViewBuilder
    func applySessionWidgetBackground(isFilled: Bool) -> some View {
        let backgroundColor = isFilled ? Color(red: 0.04, green: 0.08, blue: 0.10) : Color.clear
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) {
                backgroundColor
            }
        } else {
            background(backgroundColor)
        }
    }
}
