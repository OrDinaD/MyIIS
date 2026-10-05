import Foundation

extension ScheduleServiceViewModel {
    // MARK: - Local JSON Support

    func prepareForAPISource() {
        if localScheduleDocument != nil {
            clearLocalSchedule()
        }
    }

    func clearLocalSchedule() {
        localScheduleDocument = nil
        schedule = nil
        selectedEmployee = nil
        currentWeekNumber = nil
        errorMessage = nil
        continuousTimelineDays = []
        rebuildContinuousTimeline(reset: true)
    }

    func loadLocalSchedule() {
        guard let document = localScheduleDocument ?? (try? LocalScheduleStore.loadBundledExample()) else {
            errorMessage = NSLocalizedString("services_schedule_local_not_found", comment: "")
            return
        }
        localScheduleDocument = document
        applyLocalSchedule(document)
    }

    func applyLocalSchedule(_ document: LocalScheduleDocument) {
        dataSource = .localJSON
        localScheduleDocument = document
        let apiSchedule = document.apiSchedule()
        schedule = apiSchedule
        currentWeekNumber = 1
        preferExamDisplayIfNeeded(for: apiSchedule)
        applyDefaultWeekFilter()
        sanitizeSubgroupFilter()
        rebuildContinuousTimeline(reset: true)
        setMode(.group, preservingQuery: document.groupName ?? document.title)
        saveSnapshot()
        errorMessage = nil
    }

    func applyLocalTeacherSchedule(_ teacher: DisciplineEmployee) {
        guard let document = localScheduleDocument else { return }
        let teacherSchedule = document.apiSchedule(teacherID: teacher.id)
        let entry = document.teacherDirectoryEntry(id: teacher.id) ?? ScheduleEmployeeDirectoryEntry(
            firstName: teacher.firstName,
            lastName: teacher.lastName,
            middleName: teacher.middleName,
            degree: teacher.degree,
            rank: teacher.rank,
            photoLink: teacher.photoLink,
            calendarId: teacher.calendarId,
            id: teacher.id,
            urlId: teacher.urlId ?? "",
            fio: teacher.fullName
        )
        schedule = teacherSchedule
        currentWeekNumber = 1
        setMode(.teacher, preservingQuery: entry.displayName)
        subgroupFilter = .all
        applyDefaultWeekFilter()
        rebuildContinuousTimeline(reset: true)
        saveSnapshot()
        errorMessage = nil
    }
}
