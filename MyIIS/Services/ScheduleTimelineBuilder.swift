import Foundation

/// Builds immutable timeline chunks off the main actor; owns no UI state.
enum ScheduleTimelineBuilder {
    nonisolated static let continuousChunkSizeDays = 28
    nonisolated static let continuousFallbackHorizonDays = 120

    struct Input: Sendable {
        let orderedDays: [StudyDaySchedule]
        let startDate: Date?
        let endDate: Date?
        let selectedSubgroup: Int?
        let includesOtherSubgroups: Bool
    }

    struct Result: Sendable {
        let days: [ScheduleContinuousDay]
        let nextCursor: Date
        let reachedEnd: Bool
    }

    nonisolated static func buildTimelineChunk(
        input: Input,
        cursor: Date?,
        now: Date
    ) -> Result {
        let calendar = Calendar.current
        let startBound = input.startDate.map { calendar.startOfDay(for: $0) }
        let endBound = timelineEndBound(for: input, calendar: calendar, now: now)
        let initialStart = calendar.date(byAdding: .day, value: -2, to: now) ?? now
        let proposedStart = cursor ?? calendar.startOfDay(for: initialStart)
        let start = max(startBound ?? proposedStart, proposedStart)
        let proposedEnd = calendar.date(
            byAdding: .day,
            value: continuousChunkSizeDays - 1,
            to: start
        ) ?? start
        let end = min(proposedEnd, endBound)
        let result = buildTimeline(input: input, from: start, through: end)
        let nextCursor = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        return Result(
            days: result.days,
            nextCursor: nextCursor,
            reachedEnd: nextCursor > endBound
        )
    }

    nonisolated static func buildTimeline(
        input: Input,
        from start: Date,
        through end: Date
    ) -> Result {
        let calendar = Calendar.current
        let lessonsByWeekday = Dictionary(
            uniqueKeysWithValues: input.orderedDays.map { ($0.weekday, $0.lessons) }
        )
        var cursor = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        var generated: [ScheduleContinuousDay] = []

        while cursor <= endDay {
            if let weekday = timelineWeekday(for: cursor),
               let weekNumber = timelineWeekNumber(
                   on: cursor,
                   termStartDate: input.startDate
               ) {
                let lessons = (lessonsByWeekday[weekday] ?? []).filter { lesson in
                    let keepsSubgroup: Bool
                    if let selectedSubgroup = input.selectedSubgroup {
                        keepsSubgroup = ScheduleServiceViewModel.isLanguageLesson(lesson) || lesson.subgroup == 0
                            || lesson.subgroup == selectedSubgroup
                            || input.includesOtherSubgroups
                    } else {
                        keepsSubgroup = true
                    }
                    let keepsWeek = lesson.weekNumbers.isEmpty
                        || lesson.weekNumbers.contains(weekNumber)
                    return keepsSubgroup
                        && keepsWeek
                        && ScheduleServiceViewModel.isLessonScheduledOnContinuousDay(lesson, date: cursor)
                }
                if !lessons.isEmpty {
                    generated.append(
                        ScheduleContinuousDay(
                            date: cursor,
                            weekday: weekday,
                            weekNumber: weekNumber,
                            lessons: lessons
                        )
                    )
                }
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? endDay.addingTimeInterval(1)
        }

        return Result(
            days: generated,
            nextCursor: cursor,
            reachedEnd: cursor > endDay
        )
    }

    nonisolated static func timelineEndBound(
        for input: Input,
        calendar: Calendar,
        now: Date
    ) -> Date {
        let fallback = calendar.date(
            byAdding: .day,
            value: continuousFallbackHorizonDays,
            to: calendar.startOfDay(for: now)
        ) ?? now
        return input.endDate.map { calendar.startOfDay(for: $0) } ?? fallback
    }

    nonisolated static func timelineWeekday(for date: Date) -> StudyWeekday? {
        switch Calendar.current.component(.weekday, from: date) {
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        case 1: return .sunday
        default: return nil
        }
    }

    nonisolated static func timelineWeekNumber(
        on date: Date,
        termStartDate: Date?
    ) -> Int? {
        if let termStartDate,
           let week = ScheduleServiceViewModel.rotatingWeekNumber(
               on: date,
               termStartDate: termStartDate
           ) {
            return week
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ru_BY")
        let components = calendar.dateComponents([.month, .year], from: date)
        guard var septemberStart = calendar.date(
            from: DateComponents(year: components.year, month: 9, day: 1)
        ), let julyStart = calendar.date(
            from: DateComponents(year: components.year, month: 7, day: 1)
        ) else {
            return nil
        }
        if date < septemberStart,
           date < julyStart,
           let previousSeptember = calendar.date(
               byAdding: .year,
               value: -1,
               to: septemberStart
           ) {
            septemberStart = previousSeptember
        }
        guard let anchorWeek = ScheduleServiceViewModel.startOfWeek(for: septemberStart, calendar: calendar),
              let targetWeek = ScheduleServiceViewModel.startOfWeek(for: date, calendar: calendar),
              let distance = calendar.dateComponents(
                  [.weekOfYear],
                  from: anchorWeek,
                  to: targetWeek
              ).weekOfYear else {
            return nil
        }
        return (abs(distance) % 4) + 1
    }
}
