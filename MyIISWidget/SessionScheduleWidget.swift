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
        let entry = SessionScheduleWidgetEntry(date: .now, snapshot: SessionScheduleWidgetDataStore.loadSnapshot())
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date().addingTimeInterval(2 * 60 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct SessionScheduleWidgetView: View {
    @Environment(\.widgetFamily) private var family
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
            return 3
        default:
            return 5
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
        .applySessionWidgetBackground()
        .widgetURL(URL(string: "myiis://section/schedule"))
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            VStack(alignment: .leading, spacing: family == .systemLarge ? 7 : 6) {
                ForEach(groupedVisibleEvents) { day in
                    daySection(day)
                }
                if !hiddenEvents.isEmpty, family == .systemLarge {
                    footer
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(headerDateText)
                .font(headerDateFont)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Text(entry.groupName)

                Image(systemName: "person.2.fill")
                    .font(.system(size: family == .systemLarge ? 17 : 14,
                                  weight: .semibold))

                Text("2")
            }
            .font(headerGroupFont)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, family == .systemLarge ? 22 : 16)
        .frame(maxWidth: .infinity)
        .frame(height: headerHeight, alignment: .center)
        .background(headerGradient)
    }

    private var headerHeight: CGFloat {
        switch family {
        case .systemLarge:
            return 54
        case .systemMedium:
            return 44
        default:
            return 44
        }
    }

    private var headerDateFont: Font {
        .system(size: family == .systemLarge ? 22 : 18,
                weight: .bold,
                design: .rounded)
    }

    private var headerGroupFont: Font {
        .system(size: family == .systemLarge ? 20 : 17,
                weight: .semibold,
                design: .rounded)
    }

    private func daySection(_ day: SessionWidgetDay) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if day.id != groupedVisibleEvents.first?.id {
                Text(dateText(for: day.date))
                    .font(.system(size: family == .systemLarge ? 14 : 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
            }

            ForEach(day.events) { event in
                SessionWidgetEventRow(event: event, compact: family != .systemLarge)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(dateText(for: hiddenEvents.first?.date))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
            Circle()
                .fill(.white.opacity(0.55))
                .frame(width: 7, height: 7)
            Text(hiddenSummary)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
        }
        .padding(.top, 2)
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
            return Self.numericDateFormatter.string(from: firstDate)
        }
        return Self.numericDateFormatter.string(from: Date())
    }

    private var headerGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.90, green: 0.10, blue: 0.98),
                Color(red: 0.76, green: 0.22, blue: 0.98)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func dateText(for date: Date?) -> String {
        guard let date, date != Date.distantFuture else { return "Дата" }
        return Self.numericDateFormatter.string(from: date)
    }

    private static let numericDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "M/d/yyyy"
        return formatter
    }()
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

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            VStack(spacing: 0) {
                Text(event.startTime)
                Text(event.endTime)
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.white)
            .lineLimit(1)
            .frame(width: compact ? 42 : 46)

            HStack(spacing: compact ? 6 : 8) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(accentColor)
                    .frame(width: compact ? 4 : 5)

                VStack(alignment: .leading, spacing: compact ? 1 : 2) {
                    Text(displayTitle)
                        .font(.system(size: compact ? 13 : 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    if let subtitle = event.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: compact ? 10 : 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 5)
        .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var displayTitle: String {
        event.kind == .announcement ? "📣 \(event.title)" : event.title
    }

    private var accentColor: Color {
        switch event.kind {
        case .announcement:
            return Color.white.opacity(0.55)
        case .exam:
            return Color(red: 1.0, green: 0.20, blue: 0.24)
        case .consultation:
            return Color(red: 0.85, green: 0.12, blue: 0.95)
        case .other:
            return .blue
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
    }
}

#Preview(as: .systemLarge) {
    SessionScheduleWidget()
} timeline: {
    SessionScheduleWidgetEntry(date: .now, snapshot: SessionScheduleWidgetEntry.placeholderSnapshot)
}

private extension View {
    @ViewBuilder
    func applySessionWidgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) {
                Color(red: 0.08, green: 0.08, blue: 0.09)
            }
        } else {
            background(Color(red: 0.08, green: 0.08, blue: 0.09))
        }
    }
}
