import Foundation

extension ScheduleServiceViewModel {
    private func lessonInterval(
        for lesson: DisciplineSchedule,
        on date: Date,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date)? {
        guard let start = Self.parse(time: lesson.startLessonTime, on: date, calendar: calendar),
              let end = Self.parse(time: lesson.endLessonTime, on: date, calendar: calendar) else {
            return nil
        }
        if end > start {
            return (start, end)
        }
        return nil
    }

    nonisolated static func parse(time: String, on date: Date, calendar: Calendar = .current) -> Date? {
        let trimmed = time.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let components = trimmed.split(separator: ":")
        guard components.count >= 2,
              let hour = Int(components[0].trimmingCharacters(in: .whitespaces)),
              let minute = Int(components[1].trimmingCharacters(in: .whitespaces)),
              (0...23).contains(hour),
              (0...59).contains(minute)
        else {
            return nil
        }

        return calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: date
        )
    }

    func resolveCurrentWeekNumber(
        backendValue: Int?,
        termStartDate: Date?,
        now: Date = Date()
    ) -> Int? {
        if let backendValue, (1 ... 4).contains(backendValue) {
            return backendValue
        }

        if let termStartDate,
           let calculated = Self.rotatingWeekNumber(
               on: now,
               termStartDate: termStartDate
           ) {
            return calculated
        }

        return universityWeekNumber(on: now)
    }

    private func timelineWeekNumber(on date: Date) -> Int? {
        if let termStartDate = schedule?.startDate,
           let weekNumber = Self.rotatingWeekNumber(
               on: date,
               termStartDate: termStartDate
           ) {
            return weekNumber
        }
        return universityWeekNumber(on: date)
    }

    nonisolated static func rotatingWeekNumber(
        on date: Date,
        termStartDate: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Int? {
        var academicCalendar = calendar
        academicCalendar.firstWeekday = 2
        academicCalendar.minimumDaysInFirstWeek = 4

        guard let startOfTermWeek = Self.startOfWeek(
            for: termStartDate,
            calendar: academicCalendar
        ),
        let startOfTargetWeek = Self.startOfWeek(
            for: date,
            calendar: academicCalendar
        ),
        let distance = academicCalendar.dateComponents(
            [.weekOfYear],
            from: startOfTermWeek,
            to: startOfTargetWeek
        ).weekOfYear,
        distance >= 0 else {
            return nil
        }

        return (distance % 4) + 1
    }

    private func universityWeekNumber(on date: Date, now: Date = Date()) -> Int? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ru_BY")

        let components = calendar.dateComponents([.day, .month, .year], from: date)
        guard var septemberStart = calendar.date(from: DateComponents(year: components.year, month: 9, day: 1)),
              let julyStart = calendar.date(from: DateComponents(year: components.year, month: 7, day: 1)) else {
            return nil
        }

        if date < septemberStart,
           now < julyStart,
           let previousSeptemberStart = calendar.date(byAdding: .year, value: -1, to: septemberStart) {
            septemberStart = previousSeptemberStart
        }

        guard let startOfAnchorWeek = Self.startOfWeek(for: septemberStart, calendar: calendar),
              let startOfTargetWeek = Self.startOfWeek(for: date, calendar: calendar),
              let weeksDistance = calendar.dateComponents([.weekOfYear], from: startOfAnchorWeek, to: startOfTargetWeek).weekOfYear else {
            return nil
        }

        return (abs(weeksDistance) % 4) + 1
    }

    nonisolated  static func startOfWeek(for date: Date, calendar: Calendar) -> Date? {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components)
    }

    var currentStudyWeekday: StudyWeekday? {
        studyWeekday(for: Date())
    }

    func studyWeekday(for date: Date) -> StudyWeekday? {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch weekday {
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

    static func examSortingComparator(lhs: DisciplineSchedule, rhs: DisciplineSchedule) -> Bool {
        let leftDate = calendarDay(for: lhs) ?? Date.distantFuture
        let rightDate = calendarDay(for: rhs) ?? Date.distantFuture
        if leftDate != rightDate {
            return leftDate < rightDate
        }
        return DisciplineSchedule.sortingComparator(lhs: lhs, rhs: rhs)
    }

    static func calendarDay(for exam: DisciplineSchedule) -> Date? {
        guard let date = exam.lessonDate ?? exam.startLessonDate else { return nil }
        return Calendar.current.startOfDay(for: date)
    }

    func calendarDay(for exam: DisciplineSchedule) -> Date? {
        Self.calendarDay(for: exam)
    }

    func isLessonCurrent(
        _ lesson: DisciplineSchedule,
        on weekday: StudyWeekday,
        for date: Date? = nil,
        now: Date = Date()
    ) -> Bool {
        guard isCurrentContext(weekday: weekday, date: date, now: now) else { return false }
        let timelineDate = date ?? now
        guard let interval = lessonInterval(for: lesson, on: timelineDate) else { return false }
        return interval.start <= now && now <= interval.end
    }

    func currentLessonProgress(
        _ lesson: DisciplineSchedule,
        on weekday: StudyWeekday,
        for date: Date? = nil,
        now: Date = Date()
    ) -> Double? {
        guard isCurrentContext(weekday: weekday, date: date, now: now) else { return nil }
        let timelineDate = date ?? now
        guard let interval = lessonInterval(for: lesson, on: timelineDate) else { return nil }
        guard interval.start <= now, interval.end > interval.start else { return nil }
        guard now <= interval.end else { return nil }
        let all = interval.end.timeIntervalSince(interval.start)
        guard all > 0 else { return nil }
        return now.timeIntervalSince(interval.start) / all
    }

    func nextOccurrenceDate(
        for lesson: DisciplineSchedule,
        after referenceDate: Date = Date()
    ) -> Date? {
        let subject = lesson.subject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !subject.isEmpty else { return nil }

        let calendar = Calendar.current
        var nearestDate: Date?
        for day in continuousTimelineDays {
            if day.date.addingTimeInterval(86400) <= referenceDate {
                continue
            }
            for candidate in day.lessons where
                candidate.subject.caseInsensitiveCompare(subject) == .orderedSame &&
                candidate.lessonTypeAbbrev.caseInsensitiveCompare(lesson.lessonTypeAbbrev) == .orderedSame &&
                candidate.subgroup == lesson.subgroup {
                guard let interval = lessonInterval(for: candidate, on: day.date, calendar: calendar),
                      interval.start > referenceDate else {
                    continue
                }
                if let currentNearest = nearestDate {
                    if interval.start < currentNearest {
                        nearestDate = interval.start
                    }
                } else {
                    nearestDate = interval.start
                }
            }
        }
        return nearestDate
    }

    func isExamPast(
        _ exam: DisciplineSchedule,
        on date: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard date != Date.distantFuture else { return false }
        if let interval = lessonInterval(for: exam, on: date, calendar: calendar) {
            return interval.end < now
        }

        let startOfDay = calendar.startOfDay(for: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        return nextDay <= now
    }

    func isCurrentContext(weekday: StudyWeekday, date: Date?, now: Date) -> Bool {
        if let date {
            return Calendar.current.isDate(date, inSameDayAs: now)
        }

        guard let todayWeekday = currentStudyWeekday, todayWeekday == weekday else {
            return false
        }

        if case .week(let selectedWeek) = weekFilter,
           let currentWeekNumber,
           selectedWeek != currentWeekNumber {
            return false
        }

        return true
    }
}
