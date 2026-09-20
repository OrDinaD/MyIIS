//
//  ScheduleServiceViewModel+Widgets.swift
//  MyIIS
//

import Foundation

extension ScheduleServiceViewModel {
    func enableExamRemindersFromUserAction() async {
        guard let groupName = schedule?.group?.name.nilIfBlank ?? accountGroupName else {
            errorMessage = NSLocalizedString("services_schedule_report_group_missing", comment: "")
            return
        }
        let count = await ExamReminderNotificationService.shared.scheduleFromUserAction(
            exams: filteredExams,
            groupName: groupName
        )
        if count > 0 {
            noticeMessage = String(format: NSLocalizedString("services_schedule_reminders_enabled", comment: ""), count)
        } else {
            noticeMessage = NSLocalizedString("services_schedule_reminders_empty", comment: "")
        }
    }

    func scheduleExamRemindersIfAuthorized() {
        guard let groupName = schedule?.group?.name.nilIfBlank else { return }
        let exams = filteredExams
        Task {
            await ExamReminderNotificationService.shared.scheduleIfAuthorized(
                exams: exams,
                groupName: groupName
            )
        }
    }

    func updateClassScheduleWidgetSnapshot(from scheduleResponse: PublicScheduleResponse) {
        let resolvedName = scheduleResponse.group?.name.nilIfBlank
            ?? scheduleResponse.employee?.fullName.nilIfBlank
            ?? selectedEmployee?.displayName
            ?? query.nilIfBlank
        guard let groupName = resolvedName, !groupName.isEmpty else { return }
        if dataSource == .api, let accountGroupName, accountGroupName != groupName, scheduleResponse.employee == nil {
            return
        }

        let now = Date()
        var events = continuousTimelineDays
            .flatMap { day in
                day.lessons
                    .filter { shouldKeepLessonForWidget($0) }
                    .map { Self.widgetEvent(from: $0, on: day.date) }
            }
            .filter { $0.isUpcoming(at: now) }
            .sorted(by: Self.widgetEventSortingComparator)

        if events.isEmpty {
            var calendar = Calendar(identifier: .gregorian)
            calendar.firstWeekday = 2
            let today = calendar.startOfDay(for: now)
            let weekdayComponent = calendar.component(.weekday, from: today)
            let currentWeekdayOrdinal = (weekdayComponent + 5) % 7
            let mondayOfCurrentWeek = calendar.date(byAdding: .day, value: -currentWeekdayOrdinal, to: today) ?? today
            let referenceMonday = currentWeekdayOrdinal == 6
                ? (calendar.date(byAdding: .day, value: 7, to: mondayOfCurrentWeek) ?? mondayOfCurrentWeek)
                : mondayOfCurrentWeek

            var fallbackEvents: [SessionScheduleWidgetSnapshot.Event] = []
            for day in scheduleResponse.orderedDays {
                let dayOffset: Int
                switch day.weekday {
                case .monday: dayOffset = 0
                case .tuesday: dayOffset = 1
                case .wednesday: dayOffset = 2
                case .thursday: dayOffset = 3
                case .friday: dayOffset = 4
                case .saturday: dayOffset = 5
                case .sunday: dayOffset = 6
                }
                let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: referenceMonday) ?? today
                for lesson in day.lessons where shouldKeepLessonForWidget(lesson) {
                    let event = Self.widgetEvent(from: lesson, on: dayDate)
                    fallbackEvents.append(event)
                }
            }
            events = fallbackEvents.sorted(by: Self.widgetEventSortingComparator)
        }

        let snapshot = SessionScheduleWidgetSnapshot(
            groupName: groupName,
            startDate: scheduleResponse.startDate,
            endDate: scheduleResponse.endDate,
            events: Array(events.prefix(80)),
            updatedAt: Date()
        )
        ClassScheduleWidgetDataStore.save(snapshot)
        WatchScheduleConnectivityService.shared.activate()
        WatchScheduleConnectivityService.shared.send(snapshot)
    }

    func shouldKeepLessonForWidget(_ lesson: DisciplineSchedule) -> Bool {
        guard case .subgroup(let value) = subgroupFilter else { return true }
        return lesson.subgroup == 0 || lesson.subgroup == value
    }

    func updateSessionScheduleWidgetSnapshot(from scheduleResponse: PublicScheduleResponse) {
        let resolvedName = scheduleResponse.group?.name.nilIfBlank
            ?? scheduleResponse.employee?.fullName.nilIfBlank
            ?? selectedEmployee?.displayName
            ?? query.nilIfBlank
        guard let groupName = resolvedName, !groupName.isEmpty else { return }
        if dataSource == .api, let accountGroupName, accountGroupName != groupName, scheduleResponse.employee == nil {
            return
        }

        let now = Date()
        let events = scheduleResponse.exams
            .filter { shouldKeepLessonForWidget($0) }
            .sorted(by: Self.examSortingComparator)
            .map { Self.widgetEvent(from: $0, on: $0.lessonDate ?? $0.startLessonDate) }
            .filter { $0.isUpcoming(at: now) }

        let snapshot = SessionScheduleWidgetSnapshot(
            groupName: groupName,
            startDate: scheduleResponse.startExamsDate,
            endDate: scheduleResponse.endExamsDate,
            events: events,
            updatedAt: Date()
        )
        SessionScheduleWidgetDataStore.save(snapshot)
    }

    static func widgetEvent(
        from lesson: DisciplineSchedule,
        on date: Date?
    ) -> SessionScheduleWidgetSnapshot.Event {
        let title = lesson.isAnnouncement
            ? lesson.title.replacingOccurrences(of: "📣 ", with: "")
            : (lesson.subject.nilIfBlank ?? lesson.title)
        let subtitle = [lesson.lessonTypeAbbrev.nilIfBlank, lesson.location.nilIfBlank, lesson.note.nilIfBlank]
            .compactMap { $0 }
            .joined(separator: ", ")
            .nilIfBlank
        let primaryEmployee = lesson.employees.first(where: { !$0.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        let teacherPhotoURL = primaryEmployee.flatMap {
            ScheduleEmployeePhotoURL.make(photoLink: $0.photoLink, employeeID: $0.id)
        }
        return SessionScheduleWidgetSnapshot.Event(
            id: "\(lesson.id)|\(date?.timeIntervalSince1970 ?? 0)",
            date: date,
            startTime: lesson.startLessonTime,
            endTime: lesson.endLessonTime,
            title: title,
            subtitle: subtitle,
            location: lesson.location.nilIfBlank,
            lessonType: lesson.lessonTypeAbbrev.nilIfBlank,
            kind: widgetEventKind(for: lesson),
            subgroup: lesson.subgroup > 0 ? lesson.subgroup : nil,
            teacherName: primaryEmployee?.fullName.nilIfBlank,
            teacherPhotoLink: teacherPhotoURL?.absoluteString
        )
    }

    static func widgetEventSortingComparator(
        lhs: SessionScheduleWidgetSnapshot.Event,
        rhs: SessionScheduleWidgetSnapshot.Event
    ) -> Bool {
        let leftDate = lhs.interval()?.start ?? lhs.date ?? .distantFuture
        let rightDate = rhs.interval()?.start ?? rhs.date ?? .distantFuture
        if leftDate != rightDate {
            return leftDate < rightDate
        }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    static func widgetEventKind(for lesson: DisciplineSchedule) -> SessionScheduleWidgetEventKind {
        if lesson.isAnnouncement { return .announcement }
        let type = lesson.lessonTypeAbbrev.lowercased()
        if type.contains("экзам") { return .exam }
        if type.contains("конс") { return .consultation }
        return .other
    }
}
