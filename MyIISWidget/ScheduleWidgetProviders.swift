//
//  ScheduleWidgetProviders.swift
//  MyIISWidgetExtension
//

import SwiftUI
import WidgetKit

struct ClassPreviewValue {
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
        snapshot?.groupName ?? String(localized: "Расписание")
    }

    var upcomingEvents: [SessionScheduleWidgetSnapshot.Event] {
        upcomingEvents(from: date)
    }

    func upcomingEvents(
        from referenceDate: Date,
        calendar: Calendar = .current
    ) -> [SessionScheduleWidgetSnapshot.Event] {
        snapshot?.upcomingEvents(at: referenceDate, calendar: calendar) ?? []
    }

    static var placeholderSnapshot: SessionScheduleWidgetSnapshot {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(byAdding: .day, value: -1, to: now)
        let end = calendar.date(byAdding: .day, value: 14, to: now)
        return SessionScheduleWidgetSnapshot(
            groupName: String(localized: "Расписание"),
            startDate: start,
            endDate: end,
            events: [
                .init(
                    id: "announcement-1",
                    date: now,
                    startTime: "14:00",
                    endTime: "16:00",
                    title: String(localized: "Объявление"),
                    subtitle: String(localized: "Консультация, рецензирование"),
                    location: nil,
                    lessonType: String(localized: "Объявление"),
                    kind: .announcement
                ),
                .init(
                    id: "tppo-exam",
                    date: calendar.date(byAdding: .day, value: 3, to: now),
                    startTime: "08:30",
                    endTime: "14:00",
                    title: "ТППО",
                    subtitle: "604-5 к",
                    location: "604-5 к",
                    lessonType: String(localized: "Экзамен"),
                    kind: .exam
                )
            ],
            updatedAt: now
        )
    }

    static var classPreviewSnapshot: SessionScheduleWidgetSnapshot {
        let calendar = Calendar.current
        let now = Date()
        let day = calendar.startOfDay(for: now)
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
            groupName: String(localized: "Расписание"),
            startDate: day,
            endDate: day,
            events: events,
            updatedAt: now
        )
    }
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
        let result = ScheduleWidgetTimelinePolicy.makeTimelineEntries(snapshot: snapshot) { date, snap in
            SessionScheduleWidgetEntry(date: date, snapshot: snap)
        }
        completion(Timeline(entries: result.entries, policy: .after(result.nextRefresh)))
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
        completion(
            SessionScheduleWidgetEntry(
                date: .now,
                snapshot: ClassScheduleWidgetDataStore.loadSnapshot()
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SessionScheduleWidgetEntry>) -> Void) {
        let snapshot = ClassScheduleWidgetDataStore.loadSnapshot()
        let result = ScheduleWidgetTimelinePolicy.makeTimelineEntries(snapshot: snapshot) { date, snap in
            SessionScheduleWidgetEntry(date: date, snapshot: snap)
        }
        completion(Timeline(entries: result.entries, policy: .after(result.nextRefresh)))
    }
}

enum ScheduleWidgetStyle {
    case classes
    case session
}

struct SessionWidgetDay: Identifiable {
    let date: Date
    let events: [SessionScheduleWidgetSnapshot.Event]

    var id: String {
        String(Int(date.timeIntervalSince1970))
    }
}

extension View {
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
