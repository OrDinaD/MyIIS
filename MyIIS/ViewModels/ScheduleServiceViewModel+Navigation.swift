import Foundation

extension ScheduleServiceViewModel {
    func openTeacherSchedule(_ teacher: DisciplineEmployee) async {
        if dataSource == .localJSON {
            applyLocalTeacherSchedule(teacher)
            return
        }
        var targetURLID = teacher.urlId?.nilIfBlank
        if targetURLID == nil {
            targetURLID = employees.first { $0.id == teacher.id }?.urlId
        }
        if targetURLID == nil {
            targetURLID = employees.first {
                $0.displayName.localizedCaseInsensitiveCompare(teacher.fullName) == .orderedSame
            }?.urlId
        }
        guard let urlId = targetURLID, !urlId.isEmpty else { return }
        let mapped = ScheduleEmployeeDirectoryEntry(
            firstName: teacher.firstName,
            lastName: teacher.lastName,
            middleName: teacher.middleName,
            degree: teacher.degree,
            rank: teacher.rank,
            photoLink: teacher.photoLink,
            calendarId: teacher.calendarId,
            id: teacher.id,
            urlId: urlId,
            fio: teacher.fullName
        )
        await loadEmployee(mapped)
    }

    func openGroupSchedule(_ groupName: String) async {
        if dataSource == .localJSON, let localScheduleDocument {
            applyLocalSchedule(localScheduleDocument)
            return
        }
        let trimmed = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        shouldResetQueryOnModeChange = false
        mode = .group
        shouldResetQueryOnModeChange = true
        selectedEmployee = nil
        query = trimmed
        await loadGroup(trimmed)
    }

    func downloadScheduleReport() async -> URL? {
        guard let groupName = schedule?.group?.name.nilIfBlank ?? accountGroupName else {
            errorMessage = NSLocalizedString("services_schedule_report_group_missing", comment: "")
            return nil
        }
        guard !isDownloadingReport else { return nil }

        isDownloadingReport = true
        defer { isDownloadingReport = false }

        do {
            return try await api.downloadGroupScheduleReport(groupNumber: groupName)
        } catch is CancellationError {
            return nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }

    func setMode(_ newMode: ScheduleLookupMode, preservingQuery newQuery: String) {
        shouldResetQueryOnModeChange = false
        mode = newMode
        shouldResetQueryOnModeChange = true
        query = newQuery
        defaults.set(newMode.rawValue, forKey: Self.selectedModeDefaultsKey)
    }

    func applyGroupSchedule(_ scheduleResponse: PublicScheduleResponse, week: Int?, groupNumber: String) {
        schedule = scheduleResponse
        currentWeekNumber = resolveCurrentWeekNumber(
            backendValue: week,
            termStartDate: scheduleResponse.startDate
        )
        preferExamDisplayIfNeeded(for: scheduleResponse)
        applyDefaultWeekFilter()
        activeGroupNumber = groupNumber
        setMode(.group, preservingQuery: groupNumber)
        subgroupFilter = restoredSubgroupFilter(for: groupNumber)
        restoreLanguageSubgroup(for: groupNumber)
        sanitizeSubgroupFilter()
        rebuildContinuousTimeline(reset: true)
        persistGroupSelection(groupNumber)
        saveSnapshot()
        errorMessage = nil
        updateClassScheduleWidgetSnapshot(from: scheduleResponse)
        updateSessionScheduleWidgetSnapshot(from: scheduleResponse)
        scheduleExamRemindersIfAuthorized()
    }

    func applyEmployeeSchedule(
        _ scheduleResponse: PublicScheduleResponse,
        week: Int?,
        employee: ScheduleEmployeeDirectoryEntry,
        urlId: String
    ) {
        schedule = scheduleResponse
        currentWeekNumber = resolveCurrentWeekNumber(
            backendValue: week,
            termStartDate: scheduleResponse.startDate
        )
        setMode(.teacher, preservingQuery: employee.displayName)
        subgroupFilter = .all
        applyDefaultWeekFilter()
        rebuildContinuousTimeline(reset: true)
        persistTeacherSelection(urlId: urlId, displayName: employee.displayName)
        saveSnapshot()
        errorMessage = nil
    }

    func preferExamDisplayIfNeeded(for scheduleResponse: PublicScheduleResponse) {
        guard scheduleResponse.group != nil, !scheduleResponse.exams.isEmpty else { return }
        guard let startDate = scheduleResponse.startExamsDate,
              let endDate = scheduleResponse.endExamsDate else { return }

        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let startWindow = calendar.date(byAdding: .day, value: -2, to: calendar.startOfDay(for: startDate)) ?? startDate
        let endWindow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
        if (startWindow ... endWindow).contains(now) {
            displayMode = .exams
        }
    }

    func applyDefaultWeekFilter() {
        guard displayMode != .exams else {
            weekFilter = .all
            return
        }
        guard let currentWeekNumber, weekFilters.contains(.week(currentWeekNumber)) else {
            weekFilter = .all
            return
        }
        weekFilter = .week(currentWeekNumber)
    }
}
