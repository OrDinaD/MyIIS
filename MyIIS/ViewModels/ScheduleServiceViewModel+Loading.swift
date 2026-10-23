import Foundation

extension ScheduleServiceViewModel {
    func loadInitialData() async {
        guard !hasLoadedInitialData else { return }
        if dataSource == .localJSON {
            loadLocalSchedule()
            hasLoadedInitialData = true
            return
        }

        await Task.yield()
        if schedule == nil, dataSource == .api {
            _ = applyCachedSnapshotIfAvailable()
        }
        if schedule == nil {
            restorePersistedScheduleIfAvailable()
        }
        let restoredSchedule = schedule != nil
        if schedule == nil {
            if mode == .group, let group = defaults.string(forKey: Self.lastGroupDefaultsKey)?.nilIfBlank ?? pinnedGroupNames.first ?? accountGroupName {
                await loadGroup(group)
            } else if mode == .teacher, let urlId = defaults.string(forKey: Self.lastTeacherURLIDDefaultsKey)?.nilIfBlank ?? pinnedTeachers.first?.urlId {
                if let employee = employees.first(where: { $0.urlId == urlId }) {
                    await loadEmployee(employee)
                } else {
                    let fallback = ScheduleEmployeeDirectoryEntry(
                        firstName: nil,
                        lastName: nil,
                        middleName: nil,
                        degree: nil,
                        rank: nil,
                        photoLink: nil,
                        calendarId: nil,
                        id: Int.min,
                        urlId: urlId,
                        fio: defaults.string(forKey: Self.lastTeacherNameDefaultsKey) ?? urlId
                    )
                    await loadEmployee(fallback)
                }
            }
        }

        if restoredSchedule {
            if mode == .group, let group = displayedGroupNumber {
                await loadGroup(group)
            } else if let employee = selectedEmployee {
                await loadEmployee(employee)
            }
        }
        hasLoadedInitialData = true
        await loadDirectoryIfNeeded(force: false)
    }

    func refreshData() async {
        clearStaleDataWarning()
        if dataSource == .localJSON {
            loadLocalSchedule()
            return
        }
        await loadDirectoryIfNeeded(force: false)
        switch mode {
        case .group:
            let targetGroup = schedule?.group?.name.nilIfBlank
                ?? defaults.string(forKey: Self.lastGroupDefaultsKey)?.nilIfBlank
                ?? pinnedGroupNames.first
                ?? accountGroupName
            if let targetGroup {
                await loadGroup(targetGroup, forceRefresh: true)
            }
        case .teacher:
            if let employee = selectedEmployee {
                await loadEmployee(employee, forceRefresh: true)
            } else if let urlId = defaults.string(forKey: Self.lastTeacherURLIDDefaultsKey)?.nilIfBlank ?? pinnedTeachers.first?.urlId {
                if let found = employees.first(where: { $0.urlId == urlId }) {
                    await loadEmployee(found, forceRefresh: true)
                }
            }
        }
    }

    func resetToDefaultOrPinnedSchedule() async {
        let primaryGroup = accountGroupName?.nilIfBlank
            ?? pinnedGroupNames.first?.nilIfBlank
            ?? defaults.string(forKey: Self.lastGroupDefaultsKey)?.nilIfBlank

        if let primaryGroup {
            await openGroupSchedule(primaryGroup)
        } else if let firstPinnedTeacher = pinnedTeachers.first {
            await openPinnedTeacher(firstPinnedTeacher)
        }
    }

    func openPinnedTeacher(_ teacher: PinnedTeacher) async {
        shouldResetQueryOnModeChange = false
        mode = .teacher
        shouldResetQueryOnModeChange = true
        query = teacher.name
        if let employee = employees.first(where: { $0.urlId == teacher.urlId }) {
            await loadEmployee(employee)
        } else {
            let fallbackTeacher = ScheduleEmployeeDirectoryEntry(
                firstName: nil,
                lastName: nil,
                middleName: nil,
                degree: nil,
                rank: nil,
                photoLink: teacher.photoLink,
                calendarId: nil,
                id: Int.min,
                urlId: teacher.urlId,
                fio: teacher.name
            )
            await loadEmployee(fallbackTeacher)
        }
    }

    func loadGroup(_ groupName: String, forceRefresh: Bool = false) async {
        let trimmed = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let requestID = UUID()
        activeScheduleRequestID = requestID
        updateLoadingState()
        recordRecentGroup(trimmed)
        if !forceRefresh, let cached = api.cachedGroupSchedule(groupNumber: trimmed) {
            applyGroupSchedule(cached, week: nil, groupNumber: trimmed)
        }

        defer {
            if activeScheduleRequestID == requestID {
                activeScheduleRequestID = nil
                updateLoadingState()
            }
        }

        do {
            async let scheduleRequest = api.fetchGroupSchedule(
                groupNumber: trimmed,
                preferCachedResponse: !forceRefresh
            )
            async let weekRequest = api.fetchCurrentWeek(preferCachedResponse: !forceRefresh)
            let response = try await scheduleRequest
            let week = try? await weekRequest
            guard activeScheduleRequestID == requestID else { return }
            applyGroupSchedule(response, week: week, groupNumber: trimmed)
        } catch is CancellationError {
            return
        } catch {
            guard activeScheduleRequestID == requestID else { return }
            handleScheduleLoadError(
                error,
                fallbackSchedule: api.cachedGroupSchedule(groupNumber: trimmed),
                applyFallback: { [weak self] cached in
                    self?.applyGroupSchedule(cached, week: nil, groupNumber: trimmed)
                }
            )
        }
    }

    func loadEmployee(
        _ employee: ScheduleEmployeeDirectoryEntry,
        forceRefresh: Bool = false
    ) async {
        guard let urlId = employee.urlId, !urlId.isEmpty else {
            errorMessage = NSLocalizedString("services_schedule_teacher_not_found", comment: "")
            return
        }

        let requestID = UUID()
        activeScheduleRequestID = requestID
        updateLoadingState()
        selectedEmployee = employee
        recordRecentTeacher(employee)
        if !forceRefresh, let cached = api.cachedEmployeeSchedule(urlId: urlId) {
            applyEmployeeSchedule(cached, week: nil, employee: employee, urlId: urlId)
        }

        defer {
            if activeScheduleRequestID == requestID {
                activeScheduleRequestID = nil
                updateLoadingState()
            }
        }

        do {
            async let scheduleRequest = api.fetchEmployeeSchedule(
                urlId: urlId,
                preferCachedResponse: !forceRefresh
            )
            async let weekRequest = api.fetchCurrentWeek(preferCachedResponse: !forceRefresh)
            let response = try await scheduleRequest
            let week = try? await weekRequest
            guard activeScheduleRequestID == requestID else { return }
            applyEmployeeSchedule(response, week: week, employee: employee, urlId: urlId)
        } catch is CancellationError {
            return
        } catch {
            guard activeScheduleRequestID == requestID else { return }
            handleScheduleLoadError(
                error,
                fallbackSchedule: api.cachedEmployeeSchedule(urlId: urlId),
                applyFallback: { [weak self] cached in
                    self?.applyEmployeeSchedule(cached, week: nil, employee: employee, urlId: urlId)
                }
            )
        }
    }
}
