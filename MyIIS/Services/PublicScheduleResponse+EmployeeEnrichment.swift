import Foundation

extension PublicScheduleResponse {
    func enrichingEmployees(using directory: [ScheduleEmployeeDirectoryEntry]) -> PublicScheduleResponse {
        guard !directory.isEmpty else { return self }

        let directoryByID = directory.reduce(into: [Int: ScheduleEmployeeDirectoryEntry]()) { result, entry in
            result[entry.id] = entry
        }
        let directoryByURLID = directory.reduce(into: [String: ScheduleEmployeeDirectoryEntry]()) { result, entry in
            guard let urlID = Self.nonEmpty(entry.urlId) else { return }
            result[urlID] = entry
        }

        func enrichedEmployee(_ employee: DisciplineEmployee) -> DisciplineEmployee {
            let directoryEntry = directoryByID[employee.id]
                ?? Self.nonEmpty(employee.urlId).flatMap { directoryByURLID[$0] }

            return DisciplineEmployee(
                id: employee.id,
                firstName: Self.nonEmpty(employee.firstName) ?? Self.nonEmpty(directoryEntry?.firstName),
                middleName: Self.nonEmpty(employee.middleName) ?? Self.nonEmpty(directoryEntry?.middleName),
                lastName: Self.nonEmpty(employee.lastName) ?? Self.nonEmpty(directoryEntry?.lastName),
                photoLink: Self.nonEmpty(employee.photoLink) ?? Self.nonEmpty(directoryEntry?.photoLink),
                degree: Self.nonEmpty(employee.degree) ?? Self.nonEmpty(directoryEntry?.degree),
                degreeAbbrev: employee.degreeAbbrev,
                rank: Self.nonEmpty(employee.rank) ?? Self.nonEmpty(directoryEntry?.rank),
                email: employee.email,
                urlId: Self.nonEmpty(employee.urlId) ?? Self.nonEmpty(directoryEntry?.urlId),
                calendarId: Self.nonEmpty(employee.calendarId) ?? Self.nonEmpty(directoryEntry?.calendarId),
                jobPositions: employee.jobPositions,
                isChief: employee.isChief
            )
        }

        func enrichedLesson(_ lesson: DisciplineSchedule) -> DisciplineSchedule {
            DisciplineSchedule(
                id: lesson.id,
                auditories: lesson.auditories,
                endLessonTime: lesson.endLessonTime,
                lessonTypeAbbrev: lesson.lessonTypeAbbrev,
                note: lesson.note,
                subgroup: lesson.subgroup,
                startLessonTime: lesson.startLessonTime,
                studentGroups: lesson.studentGroups,
                subject: lesson.subject,
                subjectFullName: lesson.subjectFullName,
                weekNumbers: lesson.weekNumbers,
                employees: lesson.employees.map(enrichedEmployee),
                lessonDate: lesson.lessonDate,
                startLessonDate: lesson.startLessonDate,
                endLessonDate: lesson.endLessonDate,
                isAnnouncement: lesson.isAnnouncement,
                isSplit: lesson.isSplit
            )
        }

        func enrichedSchedule(
            _ schedule: [StudyWeekday: [DisciplineSchedule]]
        ) -> [StudyWeekday: [DisciplineSchedule]] {
            schedule.mapValues { $0.map(enrichedLesson) }
        }

        return PublicScheduleResponse(
            employee: employee.map(enrichedEmployee),
            group: group,
            exams: exams.map(enrichedLesson),
            startDate: startDate,
            endDate: endDate,
            startExamsDate: startExamsDate,
            endExamsDate: endExamsDate,
            scheduleByWeekday: enrichedSchedule(scheduleByWeekday),
            previousScheduleByWeekday: enrichedSchedule(previousScheduleByWeekday),
            nextScheduleByWeekday: enrichedSchedule(nextScheduleByWeekday)
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}
