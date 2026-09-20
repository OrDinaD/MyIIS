//
//  SessionScheduleWidget.swift
//  MyIISWidgetExtension
//

import SwiftUI
import WidgetKit

struct SessionScheduleWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetContentMargins) private var widgetContentMargins
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode
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
            return style == .classes ? 3 : 2
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
                ClassScheduleWidgetView(entry: entry)
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

    private func classAccentColor(for event: SessionScheduleWidgetSnapshot.Event) -> Color {
        ScheduleColorPreferences.color(for: event.lessonType ?? event.subtitle)
    }

    private var widgetBackgroundColor: Color {
        switch widgetRenderingMode {
        case .fullColor:
            break
        default:
            return .clear
        }

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
        family == .systemLarge ? 42 : 40
    }

    private var headerDateFont: Font {
        .system(size: family == .systemLarge ? 16 : 15, weight: .bold, design: .rounded)
    }

    private var headerGroupFont: Font {
        .system(size: family == .systemLarge ? 17 : 16, weight: .semibold, design: .rounded)
    }

    @ViewBuilder
    private var headerBackground: some View {
        switch widgetRenderingMode {
        case .fullColor:
            headerGradient
        default:
            Color.clear
        }
    }

    private var headerForegroundColor: Color {
        switch widgetRenderingMode {
        case .fullColor:
            return .white
        default:
            return .primary
        }
    }

    private var primaryTextColor: Color {
        switch widgetRenderingMode {
        case .fullColor:
            return .white
        default:
            return .primary
        }
    }

    private var secondaryTextColor: Color {
        switch widgetRenderingMode {
        case .fullColor:
            return Color.white.opacity(0.75)
        default:
            return .secondary
        }
    }

    private var tertiaryTextColor: Color {
        switch widgetRenderingMode {
        case .fullColor:
            return Color.white.opacity(0.55)
        default:
            return Color.secondary.opacity(0.8)
        }
    }

    private var separatorColor: Color {
        switch widgetRenderingMode {
        case .fullColor:
            return Color.white.opacity(0.18)
        default:
            return Color.primary.opacity(0.15)
        }
    }

    private var header: some View {
        ZStack {
            headerBackground

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
            .foregroundStyle(headerForegroundColor)
            .widgetAccentable()
            .padding(.horizontal, family == .systemLarge ? 16 : 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: headerHeight)
        .clipped()
    }

    private func daySection(_ day: SessionWidgetDay) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if groupedVisibleEvents.count > 1 || family == .systemLarge {
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.system(size: 9, weight: .semibold))
                    Text(dateText(for: day.date))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                    Spacer(minLength: 4)
                }
                .foregroundStyle(secondaryTextColor)
                .widgetAccentable()
            }

            ForEach(day.events, id: \.presentationIdentity) { event in
                SessionWidgetEventRow(
                    event: event,
                    compact: family != .systemLarge,
                    now: entry.date
                )
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 5) {
            Image(systemName: "ellipsis")
                .font(.system(size: 10, weight: .bold))
            Text(hiddenSummary)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(tertiaryTextColor)
        .widgetAccentable()
        .padding(.horizontal, 2)
    }

    private var emptyContent: some View {
        widgetMessageContent(
            icon: "calendar.badge.exclamationmark",
            title: String(localized: "Расписание не загружено"),
            subtitle: String(localized: "Откройте MyIIS, чтобы обновить расписание")
        )
    }

    private var noUpcomingContent: some View {
        widgetMessageContent(
            icon: "sparkles",
            title: String(localized: "Нет событий"),
            subtitle: String(localized: "На ближайшие дни событий не найдено")
        )
    }

    private var messagePrimaryColor: Color {
        switch widgetRenderingMode {
        case .fullColor:
            return .white
        default:
            return .primary
        }
    }

    private var messageSecondaryColor: Color {
        switch widgetRenderingMode {
        case .fullColor:
            return Color.white.opacity(0.70)
        default:
            return .secondary
        }
    }

    private func widgetMessageContent(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(messagePrimaryColor)
                .widgetAccentable()

            Text(title)
                .font(.headline)
                .foregroundStyle(messagePrimaryColor)
                .multilineTextAlignment(.center)
                .widgetAccentable()

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(messageSecondaryColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .widgetAccentable()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
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

private struct SessionWidgetEventRow: View {
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode
    let event: SessionScheduleWidgetSnapshot.Event
    let compact: Bool
    let now: Date

    private var primaryTextColor: Color {
        switch widgetRenderingMode {
        case .fullColor:
            return .white
        default:
            return .primary
        }
    }

    private var secondaryTextColor: Color {
        switch widgetRenderingMode {
        case .fullColor:
            return Color.white.opacity(0.72)
        default:
            return .secondary
        }
    }

    var body: some View {
        HStack(spacing: compact ? 8 : 9) {
            VStack(spacing: 0) {
                Text(event.startTime)
                Text(event.endTime)
            }
            .font(.system(size: compact ? 15 : 14,
                          weight: .medium,
                          design: .monospaced))
            .foregroundStyle(primaryTextColor)
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
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .allowsTightening(true)
                    .widgetAccentable()

                if let subtitle = event.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14,
                                      weight: .regular,
                                      design: .rounded))
                        .foregroundStyle(secondaryTextColor)
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

#Preview("Пары Medium (Идет пара)", as: .systemMedium) {
    ClassScheduleWidget()
} timeline: {
    let base = Calendar.current.startOfDay(for: .now)
    let activeTime = Calendar.current.date(byAdding: .minute, value: 10 * 60 + 35, to: base) ?? .now
    SessionScheduleWidgetEntry(
        date: activeTime,
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
