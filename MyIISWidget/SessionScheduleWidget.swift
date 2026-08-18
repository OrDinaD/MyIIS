//
//  SessionScheduleWidget.swift
//  MyIISWidgetExtension
//
// swiftlint:disable file_length
import SwiftUI
import WidgetKit

private struct ClassPreviewValue {
    let startTime: String
    let endTime: String
    let title: String
    let location: String
    let lessonType: String
}

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
        guard let snapshot else { return [] }
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
                title: String(localized: "Объявление"),
                subtitle: String(localized: "Сдача задолженностей, рецензирование"),
                location: nil,
                lessonType: String(localized: "Объявление"),
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
                lessonType: String(localized: "Экзамен"),
                kind: .exam
            )
        ],
        updatedAt: Date()
    )

    static let classPreviewSnapshot: SessionScheduleWidgetSnapshot = {
        let day = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))
        let values = [
            ClassPreviewValue(startTime: "10:05", endTime: "11:30", title: "АМД", location: "605-5 к.", lessonType: "ЛР"),
            ClassPreviewValue(startTime: "12:00", endTime: "13:25", title: "ОМО", location: "224-5 к.", lessonType: "ЛР"),
            ClassPreviewValue(startTime: "13:35", endTime: "15:00", title: "ФизК", location: "ПЗ", lessonType: "ПЗ"),
            ClassPreviewValue(startTime: "15:30", endTime: "16:55", title: "САиИО", location: "414-5 к.", lessonType: "ЛК"),
            ClassPreviewValue(startTime: "17:05", endTime: "18:30", title: "СУБД", location: "604-5 к.", lessonType: "ПЗ")
        ]
        let events = values.enumerated().map { index, value in
            SessionScheduleWidgetSnapshot.Event(
                id: "class-preview-\(index)",
                date: day,
                startTime: value.startTime,
                endTime: value.endTime,
                title: value.title,
                subtitle: value.lessonType,
                location: value.location,
                lessonType: value.lessonType,
                kind: .other
            )
        }
        return SessionScheduleWidgetSnapshot(
            groupName: "420603",
            startDate: day,
            endDate: day,
            events: events,
            updatedAt: Date()
        )
    }()
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
        SessionScheduleWidgetEntry(date: .now, snapshot: SessionScheduleWidgetEntry.classPreviewSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (SessionScheduleWidgetEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        completion(SessionScheduleWidgetEntry(date: .now, snapshot: ClassScheduleWidgetDataStore.loadSnapshot() ?? SessionScheduleWidgetEntry.classPreviewSnapshot))
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
            if style == .classes {
                let allEvents = entry.upcomingEvents
                let firstDate = allEvents.first?.date
                let spansDays = allEvents.prefix(3).contains { $0.date != firstDate }
                return spansDays ? 2 : 3
            }
            return 2
        case .systemLarge:
            return style == .classes ? 5 : 4
        default:
            return 1
        }
    }

    var body: some View {
        Group {
            if entry.snapshot == nil {
                if family == .accessoryInline {
                    Label(String(localized: "Расписание не загружено"), systemImage: "calendar.badge.exclamationmark")
                        .lineLimit(1)
                } else if family == .accessoryRectangular {
                    Label(String(localized: "Расписание не загружено"), systemImage: "calendar.badge.exclamationmark")
                        .font(.headline.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 4)
                } else {
                    emptyContent
                }
            } else if family == .accessoryInline {
                accessoryInlineContent
            } else if family == .accessoryRectangular {
                accessoryContent
            } else if visibleEvents.isEmpty {
                noUpcomingContent
            } else if style == .classes {
                classContent
            } else {
                content
            }
        }
        .dynamicTypeSize(.medium ... .large)
        .applySessionWidgetBackground(color: widgetBackgroundColor)
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
            if family == .systemSmall {
                classSmallContent
            } else {
                VStack(spacing: 0) {
                    header
                        .layoutPriority(10)

                    VStack(spacing: family == .systemLarge ? 5 : 4) {
                        ForEach(groupedVisibleEvents) { day in
                            if day.id != groupedVisibleEvents.first?.id {
                                classDaySeparator(for: day.date)
                            }

                            ForEach(day.events) { event in
                                classEventTile(for: event)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, family == .systemLarge ? 12 : 10)
                    .padding(.top, family == .systemLarge ? 4 : 3)
                    .padding(.bottom, family == .systemLarge ? 6 : 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        }
    }

    private func classDaySeparator(for date: Date?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: family == .systemLarge ? 9 : 8, weight: .semibold))
                Text(daySeparatorText(for: date))
                    .font(.system(size: family == .systemLarge ? 11 : 10, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                Spacer(minLength: 4)
            }
            .foregroundStyle(Color.white.opacity(0.85))

            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(height: 1)
        }
        .padding(.horizontal, 2)
        .padding(.top, family == .systemLarge ? 10 : 4)
        .padding(.bottom, family == .systemLarge ? 3 : 2)
    }

    private func daySeparatorText(for date: Date?) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "dd.MM.yy"
        let dateString = formatter.string(from: date)
        formatter.dateFormat = "EE"
        let weekdayString = formatter.string(from: date).lowercased().replacingOccurrences(of: ".", with: "")
        return "\(dateString) (\(weekdayString))"
    }

    private var classSmallContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(entry.groupName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer(minLength: 2)

                if let event = visibleEvents.first {
                    if event.isActive(at: entry.date) {
                        Text("СЕЙЧАС")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(classAccentColor(for: event).opacity(0.35), in: Capsule())
                            .foregroundStyle(classAccentColor(for: event))
                    } else {
                        Text(event.startTime)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .padding(.bottom, 6)

            if let event = visibleEvents.first {
                let accent = classAccentColor(for: event)
                let isActive = event.isActive(at: entry.date)

                HStack(spacing: 8) {
                    classProgressBar(for: event, accent: accent, isActive: isActive)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(event.title)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            if let subgroup = event.subgroup, subgroup > 0 {
                                Text("[\(subgroup)]")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                        }

                        Text("\(event.startTime)–\(event.endTime)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.75))

                        Text(classLocationText(for: event))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                }

                if let nextEvent = visibleEvents.dropFirst().first {
                    Spacer(minLength: 2)
                    HStack(spacing: 4) {
                        Text("Далее:")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("\(nextEvent.startTime) \(nextEvent.title)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    .padding(.top, 2)
                }
            } else {
                Spacer()
                Text("Занятий нет")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var accessoryInlineContent: some View {
        Group {
            if let event = visibleEvents.first {
                let status = SessionScheduleWidgetPresentation.accessoryStatus(for: event, at: entry.date)
                let location = SessionScheduleWidgetPresentation.accessorySubtitle(for: event)

                ViewThatFits(in: .horizontal) {
                    inlineLabel("\(status) · \(event.title) · \(location)")
                    inlineLabel("\(status) · \(event.title)")
                    Text(verbatim: "\(status) · \(event.title)")
                    Text(verbatim: status)
                }
                .lineLimit(1)
                .privacySensitive()
            } else {
                Label("Нет пар", systemImage: "checkmark.circle")
                    .lineLimit(1)
            }
        }
        .widgetAccentable()
    }

    private func inlineLabel(_ title: String) -> some View {
        Label {
            Text(verbatim: title)
        } icon: {
            Image(systemName: "calendar")
        }
    }

    private var accessoryContent: some View {
        Group {
            if let event = visibleEvents.first {
                HStack(spacing: 8) {
                    Capsule()
                        .fill(classAccentColor(for: event))
                        .frame(width: 4)
                        .widgetAccentable()

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Image(systemName: event.isActive(at: entry.date) ? "clock.fill" : "calendar")
                                .font(.caption2.weight(.semibold))
                            Text(SessionScheduleWidgetPresentation.accessoryStatus(for: event, at: entry.date))
                                .font(.caption2.weight(.semibold))
                                .monospacedDigit()
                                .lineLimit(1)
                        }
                        .foregroundStyle(.secondary)
                        .widgetAccentable()

                        Text(event.title)
                            .font(.headline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                            .privacySensitive()

                        Text(SessionScheduleWidgetPresentation.accessorySubtitle(for: event))
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(.secondary)
                            .privacySensitive()
                    }
                }
                .padding(.horizontal, 4)
            } else {
                Label("Нет пар", systemImage: "checkmark.circle")
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func classEventTile(for event: SessionScheduleWidgetSnapshot.Event) -> some View {
        let accent = classAccentColor(for: event)
        let isActive = event.isActive(at: entry.date)

        return HStack(spacing: family == .systemLarge ? 9 : 7) {
            classTimeColumn(for: event)
            classProgressBar(for: event, accent: accent, isActive: isActive)
            classDetails(for: event, accent: accent)
        }
        .padding(.horizontal, family == .systemLarge ? 8 : 7)
        .padding(.vertical, family == .systemLarge ? 5 : 3.5)
        .background(
            isActive
                ? Color.white.opacity(0.14)
                : Color.white.opacity(0.08),
            in: RoundedRectangle(cornerRadius: family == .systemLarge ? 10 : 8, style: .continuous)
        )
    }

    private func classTimeColumn(for event: SessionScheduleWidgetSnapshot.Event) -> some View {
        VStack(spacing: 1) {
            Text(event.startTime)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            Text(event.endTime)
                .foregroundStyle(.white.opacity(0.72))
        }
        .font(.system(
            size: family == .systemLarge ? 13 : 11.5,
            weight: .regular,
            design: .monospaced
        ))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(width: family == .systemLarge ? 50 : 44)
    }

    private func classProgressBar(
        for event: SessionScheduleWidgetSnapshot.Event,
        accent: Color,
        isActive: Bool
    ) -> some View {
        GeometryReader { proxy in
            Group {
                if isActive, let interval = event.interval() {
                    ProgressView(timerInterval: interval.start ... interval.end, countsDown: false)
                        .labelsHidden()
                        .tint(accent)
                        .rotationEffect(.degrees(90))
                        .frame(width: proxy.size.height, height: 6)
                        .position(x: 3, y: proxy.size.height / 2)
                } else {
                    Capsule()
                        .fill(accent)
                }
            }
            .mask {
                if classBreak(for: event) != nil {
                    VStack(spacing: 3) {
                        Capsule()
                        Capsule()
                    }
                } else {
                    Capsule()
                }
            }
        }
        .frame(width: 6)
        .widgetAccentable()
        .accessibilityHidden(true)
    }

    private func classDetails(
        for event: SessionScheduleWidgetSnapshot.Event,
        accent: Color
    ) -> some View {
        let midPairBreak = classBreak(for: event)

        return VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(event.title)
                    .font(.system(
                        size: family == .systemLarge ? 16 : 14.5,
                        weight: .bold,
                        design: .rounded
                    ))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.66)
                    .privacySensitive()

                if let subgroup = event.subgroup, subgroup > 0 {
                    Text("[\(subgroup)]")
                        .font(.system(size: family == .systemLarge ? 9 : 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }

            HStack(spacing: 7) {
                Text(classLocationText(for: event))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .privacySensitive()

                if let midPairBreak, family == .systemLarge {
                    Text(midPairBreak.compactText)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(accent.opacity(0.9))
                        .lineLimit(1)
                        .widgetAccentable()
                }
            }
            .font(.system(size: family == .systemLarge ? 11 : 10.5, weight: .medium))
            .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func classLocationText(for event: SessionScheduleWidgetSnapshot.Event) -> String {
        SessionScheduleWidgetPresentation.normalizedLocation(event.location)
            ?? nonEmpty(event.lessonType)
            ?? String(localized: "Аудитория не указана")
    }

    private func classBreak(for event: SessionScheduleWidgetSnapshot.Event) -> ScheduleMidPairBreak? {
        guard ScheduleDisplayPreferences.showsMidPairBreaks else { return nil }
        return ScheduleMidPairBreakCalculator.resolve(
            startTime: event.startTime,
            endTime: event.endTime
        )
    }

    private func classAccentColor(for event: SessionScheduleWidgetSnapshot.Event) -> Color {
        ScheduleColorPreferences.color(for: event.lessonType ?? event.subtitle)
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private var widgetBackgroundColor: Color {
        if style == .session {
            return Color(red: 0.04, green: 0.08, blue: 0.10)
        }
        switch family {
        case .accessoryInline, .accessoryRectangular:
            return .clear
        default:
            return Color(red: 0.025, green: 0.027, blue: 0.035)
        }
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
        if style == .classes {
            return family == .systemLarge ? 38 : 34
        }
        return family == .systemLarge ? 42 : 40
    }

    private var headerDateFont: Font {
        .system(size: style == .classes ? (family == .systemLarge ? 15 : 14) : (family == .systemLarge ? 16 : 15),
                weight: .bold,
                design: .rounded)
    }

    private var headerGroupFont: Font {
        .system(size: style == .classes ? (family == .systemLarge ? 16 : 15) : (family == .systemLarge ? 17 : 16),
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
            title: String(localized: "Расписание не загружено"),
            subtitle: String(localized: "Откройте расписание в приложении, чтобы загрузить данные.")
        )
    }

    private var noUpcomingContent: some View {
        widgetMessageContent(
            icon: "calendar.badge.clock",
            title: String(localized: "Ближайших событий нет"),
            subtitle: String(localized: "Последний кэш расписания сохранен для офлайн-доступа.")
        )
    }

    private var messagePrimaryColor: Color {
        style == .session ? .white : .primary
    }

    private var messageSecondaryColor: Color {
        style == .session ? .white.opacity(0.68) : .secondary
    }

    private func widgetMessageContent(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 0) {
            header
                .layoutPriority(10)

            VStack(alignment: .leading, spacing: 10) {
                Spacer(minLength: 0)
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(messageSecondaryColor)
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(messagePrimaryColor)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(messageSecondaryColor)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, contentHorizontalPadding)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
            return String(
                format: String(localized: "%@ и еще %lld"),
                shownTitles.joined(separator: ", "),
                rest
            )
        }
        return shownTitles.joined(separator: ", ")
    }

    private var headerDateText: String {
        let date = visibleEvents.first?.date ?? Date()
        if style == .classes {
            let formatter = DateFormatter()
            formatter.locale = .autoupdatingCurrent
            formatter.dateFormat = "dd.MM"
            let dateString = formatter.string(from: date)
            formatter.dateFormat = "EE"
            let weekdayString = formatter.string(from: date).capitalized.replacingOccurrences(of: ".", with: "")
            return "\(dateString) (\(weekdayString))"
        }
        return SessionScheduleWidgetDateFormatting.numericDateText(from: date)
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
        guard let date, date != Date.distantFuture else { return String(localized: "Дата") }
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
        .description("Показывает ближайшие пары: время, предмет и аудиторию.")
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
        .containerBackgroundRemovable()
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
        .containerBackgroundRemovable()
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

#Preview("Пары Medium", as: .systemMedium) {
    ClassScheduleWidget()
} timeline: {
    SessionScheduleWidgetEntry(
        date: SessionScheduleWidgetEntry.classPreviewSnapshot.startDate ?? .now,
        snapshot: SessionScheduleWidgetEntry.classPreviewSnapshot
    )
}

#Preview("Пары Large", as: .systemLarge) {
    ClassScheduleWidget()
} timeline: {
    SessionScheduleWidgetEntry(
        date: SessionScheduleWidgetEntry.classPreviewSnapshot.startDate ?? .now,
        snapshot: SessionScheduleWidgetEntry.classPreviewSnapshot
    )
}

#Preview("Пары Lock Screen", as: .accessoryRectangular) {
    ClassScheduleWidget()
} timeline: {
    SessionScheduleWidgetEntry(
        date: SessionScheduleWidgetEntry.placeholderSnapshot.startDate ?? .now,
        snapshot: SessionScheduleWidgetEntry.placeholderSnapshot
    )
}

#Preview("Пары над временем", as: .accessoryInline) {
    ClassScheduleWidget()
} timeline: {
    SessionScheduleWidgetEntry(
        date: SessionScheduleWidgetEntry.placeholderSnapshot.startDate ?? .now,
        snapshot: SessionScheduleWidgetEntry.placeholderSnapshot
    )
}

private extension View {
    @ViewBuilder
    func applySessionWidgetBackground(color: Color) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) {
                color
            }
        } else {
            background(color)
        }
    }
}
