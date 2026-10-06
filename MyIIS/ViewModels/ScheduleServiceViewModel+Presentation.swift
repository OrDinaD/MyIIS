import Foundation

extension ScheduleServiceViewModel {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let dayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("dMMMM")
        return formatter
    }()

    private static let examDayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("dMMMMyy")
        return formatter
    }()

    private static let examPeriodFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("dMMMMyyyy")
        return formatter
    }()

    var weekFilters: [StudyWeekFilter] {
        if isSchedulePublicationPending { return [] }
        let weeks = schedule?.availableWeekNumbers ?? []
        guard !weeks.isEmpty else { return [] }
        return [.all] + weeks.map { .week($0) }
    }

    var filteredDays: [StudyDaySchedule] {
        guard let schedule, !isSchedulePublicationPending else { return [] }
        let dayItems = schedule.orderedDays
        switch weekFilter {
        case .all:
            return dayItems.compactMap { (day: StudyDaySchedule) -> StudyDaySchedule? in
                let rawLessons = day.lessons.filter(shouldKeepLesson)
                guard !rawLessons.isEmpty else { return nil }

                // Aggregate duplicate pairs across the 4 academic weeks
                var aggregated: [DisciplineSchedule] = []
                var seenIndexByKey: [String: Int] = [:]

                for lesson in rawLessons {
                    let key = [
                        lesson.subject.nilIfBlank ?? lesson.title,
                        lesson.startLessonTime,
                        lesson.endLessonTime,
                        lesson.location,
                        lesson.lessonTypeAbbrev,
                        String(lesson.subgroup),
                        lesson.employees.map { String($0.id) }.sorted().joined(separator: ",")
                    ].joined(separator: "|")

                    if let existingIndex = seenIndexByKey[key] {
                        var existing = aggregated[existingIndex]
                        let mergedWeeks = Array(Set(existing.weekNumbers + lesson.weekNumbers)).sorted()
                        existing.weekNumbers = mergedWeeks
                        aggregated[existingIndex] = existing
                    } else {
                        seenIndexByKey[key] = aggregated.count
                        var newLesson = lesson
                        if newLesson.weekNumbers.isEmpty {
                            newLesson.weekNumbers = [1, 2, 3, 4]
                        }
                        aggregated.append(newLesson)
                    }
                }

                let sorted = aggregated.sorted { lhs, rhs in
                    if lhs.startLessonTime != rhs.startLessonTime {
                        return lhs.startLessonTime < rhs.startLessonTime
                    }
                    return lhs.subgroup < rhs.subgroup
                }

                return StudyDaySchedule(weekday: day.weekday, lessons: sorted)
            }
        case .week(let number):
            return dayItems.compactMap { (day: StudyDaySchedule) -> StudyDaySchedule? in
                let filtered = day.lessons.filter {
                    ($0.weekNumbers.isEmpty || $0.weekNumbers.contains(number)) && shouldKeepLesson($0)
                }
                guard !filtered.isEmpty else { return nil }
                return StudyDaySchedule(weekday: day.weekday, lessons: filtered)
            }
        }
    }

    static func weeksBadgeText(for lesson: DisciplineSchedule) -> String? {
        let weeks = lesson.weekNumbers.sorted()
        guard !weeks.isEmpty else { return nil }
        if weeks == [1, 2, 3, 4] {
            return "1–4 нед."
        }
        if weeks == [1, 3] {
            return "1, 3 нед."
        }
        if weeks == [2, 4] {
            return "2, 4 нед."
        }
        if weeks.count == 1 {
            return "\(weeks[0]) нед."
        }
        return weeks.map(String.init).joined(separator: ", ") + " нед."
    }

    var filteredExams: [DisciplineSchedule] {
        guard let schedule else { return [] }
        return schedule.exams
            .filter(shouldKeepLesson)
            .sorted(by: Self.examSortingComparator)
    }

    var examDays: [ExamScheduleDay] {
        let grouped = Dictionary(grouping: filteredExams) { exam in
            calendarDay(for: exam) ?? Date.distantFuture
        }
        return grouped.keys.sorted().map { date in
            ExamScheduleDay(
                date: date,
                weekday: studyWeekday(for: date),
                lessons: grouped[date, default: []].sorted(by: Self.examSortingComparator)
            )
        }
    }

    var pastExamDays: [ExamScheduleDay] {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday.addingTimeInterval(86400)

        return examDays.filter { day in
            let dayStart = calendar.startOfDay(for: day.date)
            if dayStart < startOfToday {
                return true
            } else if dayStart >= startOfTomorrow {
                return false
            } else {
                return day.lessons.allSatisfy { isExamPast($0, on: day.date, now: now, calendar: calendar) }
            }
        }
    }

    var upcomingExamDays: [ExamScheduleDay] {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday.addingTimeInterval(86400)

        return examDays.filter { day in
            let dayStart = calendar.startOfDay(for: day.date)
            if dayStart < startOfToday {
                return false
            } else if dayStart >= startOfTomorrow {
                return true
            } else {
                return !day.lessons.allSatisfy { isExamPast($0, on: day.date, now: now, calendar: calendar) }
            }
        }
    }

    var displayedDays: [StudyDaySchedule] {
        let days = filteredDays
        guard let currentWeekday = currentStudyWeekday else { return days }

        return days.sorted { lhs, rhs in
            let leftDistance = (lhs.weekday.displayIndex - currentWeekday.displayIndex + 7) % 7
            let rightDistance = (rhs.weekday.displayIndex - currentWeekday.displayIndex + 7) % 7
            return leftDistance < rightDistance
        }
    }

    var continuousDays: [StudyDaySchedule] {
        displayedDays
    }

    var shouldShowWeekFilter: Bool {
        displayMode == .byDay && !weekFilters.isEmpty
    }

    var isCurrentModeEmpty: Bool {
        switch displayMode {
        case .continuous:
            return continuousTimelineDays.isEmpty
        case .byDay:
            return displayedDays.isEmpty
        case .exams:
            return filteredExams.isEmpty
        }
    }

    var currentModeEmptyTitle: String {
        if isSchedulePublicationPending {
            return NSLocalizedString("services_schedule_publication_pending_title", value: "Расписание составляется", comment: "")
        }
        if displayMode == .exams {
            return NSLocalizedString("services_schedule_exams_empty_title", value: "Экзаменов пока нет", comment: "")
        }
        return NSLocalizedString("services_schedule_empty_title", value: "Занятий нет", comment: "")
    }

    var currentModeEmptyText: String {
        if isSchedulePublicationPending {
            return NSLocalizedString("services_schedule_publication_pending", comment: "")
        }
        if displayMode == .exams {
            return NSLocalizedString("services_schedule_exams_empty_description", value: "В расписании экзамены и консультации пока не запланированы.", comment: "")
        }
        if displayMode == .continuous, isSchedulePastEnd {
            return NSLocalizedString("services_schedule_no_future_lessons", comment: "")
        }
        return NSLocalizedString("services_schedule_empty_week", comment: "")
    }

    var isSchedulePublicationPending: Bool {
        schedule?.isSchedulePublicationPending() == true
    }

    private var isSchedulePastEnd: Bool {
        guard let endDate = schedule?.endDate else { return false }
        let calendar = Calendar.current
        let endExclusive = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: endDate)
        ) ?? endDate
        return Date() >= endExclusive
    }

    func examDayTitle(for day: ExamScheduleDay) -> String {
        guard day.date != Date.distantFuture else {
            return NSLocalizedString("services_schedule_exams_no_date", comment: "")
        }

        let dateText = Self.examDayDateFormatter.string(from: day.date)
        let weekdayText = day.weekday?.shortTitle
        let prefix: String?
        if Calendar.current.isDateInToday(day.date) {
            prefix = NSLocalizedString("services_schedule_today_prefix", comment: "")
        } else if Calendar.current.isDateInTomorrow(day.date) {
            prefix = NSLocalizedString("services_schedule_tomorrow_prefix", comment: "")
        } else {
            prefix = nil
        }

        let chunks = [prefix, weekdayText, dateText].compactMap { $0?.nilIfBlank }
        return chunks.joined(separator: ", ")
    }

    func dayTitle(for day: StudyDaySchedule) -> String {
        day.weekday.localizedTitle
    }

    func continuousDayTitle(for day: ScheduleContinuousDay) -> String {
        let dateText = Self.dayDateFormatter.string(from: day.date)
        let weekText = String(format: NSLocalizedString("services_schedule_week_number", comment: ""), day.weekNumber)
        if Calendar.current.isDateInToday(day.date) {
            return "\(NSLocalizedString("services_schedule_today_prefix", comment: "")), \(day.weekday.shortTitle), \(dateText), \(weekText)"
        }
        return "\(day.weekday.shortTitle), \(dateText), \(weekText)"
    }

    var scheduleHeaderTitle: String {
        if let group = schedule?.group?.name.nilIfBlank {
            return group
        }
        if let employee = schedule?.employee?.fullName.nilIfBlank {
            return employee
        }
        if let selectedEmployee {
            return selectedEmployee.displayName
        }
        if schedule == nil, dataSource == .api {
            switch mode {
            case .group:
                if let group = initialGroupNumber { return group }
            case .teacher:
                if let name = defaults.string(forKey: Self.lastTeacherNameDefaultsKey)?.nilIfBlank
                    ?? pinnedTeachers.first?.name {
                    return name
                }
            }
        }
        return NSLocalizedString("services_schedule_title", comment: "")
    }

    var initialGroupNumber: String? {
        defaults.string(forKey: Self.lastGroupDefaultsKey)?.nilIfBlank
            ?? pinnedGroupNames.first
            ?? accountGroupName
    }

    var displayedGroupNumber: String? {
        guard mode == .group else { return nil }
        return schedule?.group?.name.nilIfBlank ?? (schedule == nil ? initialGroupNumber : nil)
    }

    var hasFinishedLessonsToday: Bool {
        let calendar = Calendar.current
        return pastContinuousDays.contains { calendar.isDateInToday($0.date) }
            && !upcomingContinuousDays.contains { calendar.isDateInToday($0.date) }
    }

    var scheduleHeaderSubtitle: String? {
        if displayMode == .exams {
            let title = NSLocalizedString("services_schedule_exams_short", comment: "")
            if let examPeriodText {
                return "🎓 \(title) · \(examPeriodText)"
            }
            return "🎓 \(title)"
        }
        return nil
    }
}

private extension ScheduleServiceViewModel {

    var periodText: String? {
        guard let schedule else { return nil }
        let rangeStart = schedule.startDate
        let rangeEnd = schedule.endDate
        guard let rangeStart, let rangeEnd else { return nil }
        return "\(Self.dateFormatter.string(from: rangeStart)) – \(Self.dateFormatter.string(from: rangeEnd))"
    }

    var examPeriodText: String? {
        guard let schedule else { return nil }
        let rangeStart = schedule.startExamsDate
        let rangeEnd = schedule.endExamsDate
        guard let rangeStart, let rangeEnd else { return nil }
        return "\(Self.examPeriodFormatter.string(from: rangeStart)) – \(Self.examPeriodFormatter.string(from: rangeEnd))"
    }
}

private extension StudyWeekday {
    var displayIndex: Int {
        switch self {
        case .monday: return 0
        case .tuesday: return 1
        case .wednesday: return 2
        case .thursday: return 3
        case .friday: return 4
        case .saturday: return 5
        case .sunday: return 6
        }
    }
}
