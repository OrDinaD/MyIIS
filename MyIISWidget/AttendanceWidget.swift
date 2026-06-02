//
//  AttendanceWidget.swift
//  MyIISWidgetExtension
//
import WidgetKit
import SwiftUI

struct AttendanceWidgetEntry: TimelineEntry {
    let date: Date
    let month: String
    let hours: Int
}

struct AttendanceWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> AttendanceWidgetEntry {
        AttendanceWidgetEntry(date: .now, month: Self.placeholderMonth, hours: 4)
    }

    func getSnapshot(in context: Context, completion: @escaping (AttendanceWidgetEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        let snapshot = AttendanceWidgetDataStore.loadSnapshot()
        completion(Self.entry(from: snapshot) ?? placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AttendanceWidgetEntry>) -> Void) {
        let snapshot = AttendanceWidgetDataStore.loadSnapshot()
        let entry = Self.entry(from: snapshot) ?? placeholder(in: context)
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(60 * 30)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private static func entry(from snapshot: AttendanceWidgetSnapshot?) -> AttendanceWidgetEntry? {
        guard let snapshot else { return nil }
        return AttendanceWidgetEntry(
            date: .now,
            month: snapshot.monthTitle,
            hours: snapshot.unexcusedHours
        )
    }

    private static var placeholderMonth: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.setLocalizedDateFormatFromTemplate("LLLL")
        return formatter.string(from: Date()).capitalized
    }
}

struct AttendanceWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AttendanceWidgetEntry

    private var numberColor: Color {
        if entry.hours >= 10 { return .red }
        if entry.hours >= 5 { return .yellow }
        return .primary
    }

    private var unitColor: Color {
        entry.hours >= 5 ? numberColor : .secondary
    }

    private var titleFont: Font {
        switch family {
        case .systemSmall:
            return .caption
        default:
            return .caption
        }
    }

    private var monthFont: Font {
        switch family {
        case .systemSmall:
            return .subheadline.weight(.semibold)
        default:
            return .headline
        }
    }

    private var valueNumberFont: Font {
        switch family {
        case .systemSmall:
            return .system(size: 30, weight: .heavy, design: .rounded)
        default:
            return .system(size: 38, weight: .heavy, design: .rounded)
        }
    }

    private var unitFont: Font {
        switch family {
        case .systemSmall:
            return .headline
        default:
            return .title3
        }
    }

    private var iconSize: CGFloat {
        switch family {
        case .systemSmall:
            return 28
        default:
            return 34
        }
    }

    private var padding: CGFloat {
        switch family {
        case .systemSmall:
            return 12
        default:
            return 16
        }
    }

    var body: some View {
        content
            .padding(padding)
            .applyWidgetBackground()
            .widgetURL(Self.attendanceURL)
    }

    private static let attendanceURL = URL(string: "myiis://section/attendance")!

    @ViewBuilder
    private var content: some View {
        if family == .systemSmall {
            smallContent
        } else {
            mediumContent
        }
    }

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: iconSize, weight: .semibold))
                    .widgetAccentable()
                    .foregroundStyle(.secondary)
                Text("Пропуски")
                    .font(titleFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(entry.month)
                .font(monthFont)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(entry.hours, format: .number)
                    .font(valueNumberFont)
                    .monospacedDigit()
                    .foregroundStyle(numberColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: true, vertical: false)
                Text("ч.")
                    .font(unitFont)
                    .foregroundStyle(unitColor)
                    .lineLimit(1)
            }
            .accessibilityLabel("\(entry.hours) часов")
        }
    }

    private var mediumContent: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: iconSize, weight: .semibold))
                .widgetAccentable()
                .foregroundStyle(.secondary)
                .frame(width: iconSize + 4, height: iconSize + 4)

            VStack(alignment: .leading, spacing: 2) {
                Text("Пропуски за")
                    .font(titleFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(entry.month)
                    .font(monthFont)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(entry.hours, format: .number)
                    .font(valueNumberFont)
                    .monospacedDigit()
                    .foregroundStyle(numberColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: true, vertical: false)
                Text("ч.")
                    .font(unitFont)
                    .foregroundStyle(unitColor)
                    .lineLimit(1)
            }
            .accessibilityLabel("\(entry.hours) часов")
            .layoutPriority(2)
        }
    }
}

struct AttendanceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AttendanceWidgetConstants.kind, provider: AttendanceWidgetProvider()) { entry in
            AttendanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Пропуски")
        .description("Показывает пропуски за месяц.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct AttendanceWidgetBundle: WidgetBundle {
    var body: some Widget {
        AttendanceWidget()
    }
}

#Preview(as: .systemSmall) {
    AttendanceWidget()
} timeline: {
    AttendanceWidgetEntry(date: .now, month: "Октябрь", hours: 4)
}

private extension View {
    @ViewBuilder
    func applyWidgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) {
                Color.clear
            }
        } else {
            background(Color.clear)
        }
    }
}
