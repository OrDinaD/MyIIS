//
//  ClassScheduleWidgetViews.swift
//  MyIISWidgetExtension
//

import SwiftUI
import WidgetKit

struct ClassScheduleWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode
    let entry: SessionScheduleWidgetEntry

    private var eventLimit: Int {
        switch family {
        case .systemSmall:
            return 1
        case .systemMedium:
            let allEvents = entry.upcomingEvents
            let firstDate = allEvents.first?.date
            let spansDays = allEvents.prefix(3).contains { $0.date != firstDate }
            return spansDays ? 2 : 3
        case .systemLarge:
            return 5
        default:
            return 1
        }
    }

    private var visibleEvents: [SessionScheduleWidgetSnapshot.Event] {
        Array(entry.upcomingEvents.prefix(eventLimit))
    }

    private var groupedVisibleEvents: [SessionWidgetDay] {
        let grouped = Dictionary(grouping: visibleEvents) { event in
            event.date.map { Calendar.current.startOfDay(for: $0) } ?? Date.distantFuture
        }
        return grouped.keys.sorted().map { date in
            SessionWidgetDay(date: date, events: grouped[date, default: []])
        }
    }

    var body: some View {
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

                            ForEach(day.events, id: \.presentationIdentity) { event in
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

    private var headerHeight: CGFloat {
        family == .systemLarge ? 38 : 34
    }

    private var headerDateFont: Font {
        .system(size: family == .systemLarge ? 15 : 14, weight: .bold, design: .rounded)
    }

    private var headerGroupFont: Font {
        .system(size: family == .systemLarge ? 16 : 15, weight: .semibold, design: .rounded)
    }

    private var headerDateText: String {
        let date = visibleEvents.first?.date ?? Date()
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "dd.MM"
        let dateString = formatter.string(from: date)
        formatter.dateFormat = "EE"
        let weekdayString = formatter.string(from: date).capitalized.replacingOccurrences(of: ".", with: "")
        return "\(dateString) (\(weekdayString))"
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
            .foregroundStyle(secondaryTextColor)

            Rectangle()
                .fill(separatorColor)
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
                    .foregroundStyle(primaryTextColor)
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
                            .foregroundStyle(secondaryTextColor)
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
                                .foregroundStyle(primaryTextColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            if let subgroup = event.subgroup, subgroup > 0 {
                                Text("[\(subgroup)]")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(secondaryTextColor)
                            }
                        }

                        Text("\(event.startTime)–\(event.endTime)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(secondaryTextColor)

                        Text(classLocationText(for: event))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(secondaryTextColor)
                            .lineLimit(1)
                    }
                }

                if let nextEvent = visibleEvents.dropFirst().first {
                    Spacer(minLength: 2)
                    HStack(spacing: 4) {
                        Text("Далее:")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(tertiaryTextColor)
                        Text("\(nextEvent.startTime) \(nextEvent.title)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(primaryTextColor)
                            .lineLimit(1)
                    }
                    .padding(.top, 2)
                }
            } else {
                Spacer()
                Text("Занятий нет")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(secondaryTextColor)
                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                .foregroundStyle(primaryTextColor)
            Text(event.endTime)
                .foregroundStyle(secondaryTextColor)
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
                    ProgressView(timerInterval: interval.start ... interval.end, countsDown: true)
                        .labelsHidden()
                        .tint(accent)
                        .rotationEffect(.degrees(-90))
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
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.66)
                    .privacySensitive()

                if let subgroup = event.subgroup, subgroup > 0 {
                    Text("[\(subgroup)]")
                        .font(.system(size: family == .systemLarge ? 9 : 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(secondaryTextColor)
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
            .foregroundStyle(secondaryTextColor)
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
}
