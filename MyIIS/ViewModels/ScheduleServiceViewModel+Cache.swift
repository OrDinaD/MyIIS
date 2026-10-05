import Foundation

extension ScheduleServiceViewModel {
    @discardableResult
    func applyCachedSnapshotIfAvailable() -> Bool {
        guard usesSharedSnapshotCache else {
            return false
        }
        guard let snapshot = Self.cachedSnapshot,
              snapshot.dataSource == dataSource else {
            return false
        }
        if dataSource == .api, snapshot.accountGroupName != accountGroupName {
            return false
        }
        shouldResetQueryOnModeChange = false
        mode = snapshot.mode
        shouldResetQueryOnModeChange = true
        query = snapshot.query
        schedule = snapshot.schedule
        currentWeekNumber = snapshot.currentWeekNumber
        weekFilter = snapshot.weekFilter

        if let savedModeRaw = defaults.string(forKey: Self.displayModeDefaultsKey),
           let savedMode = ScheduleDisplayMode(rawValue: savedModeRaw) {
            displayMode = savedMode
        } else {
            displayMode = snapshot.displayMode
        }

        if mode == .group {
            activeGroupNumber = snapshot.query
            subgroupFilter = restoredSubgroupFilter(for: snapshot.query)
            restoreLanguageSubgroup(for: snapshot.query)
        } else {
            activeGroupNumber = nil
            subgroupFilter = .all
        }

        continuousTimelineDays = snapshot.continuousTimelineDays
        if snapshot.subgroupFilter != subgroupFilter || snapshot.languageSubgroupTeacherID != languageSubgroupTeacherID
            || snapshot.subjectSubgroupTeacherIDs != subjectSubgroupTeacherIDs {
            rebuildContinuousTimeline(reset: true)
        }
        hasLoadedInitialData = false
        return true
    }

    static func clearCachedSnapshot() {
        cachedSnapshot = nil
    }

    func restorePersistedScheduleIfAvailable() {
        // 1. Explicit last group selection
        if mode == .group,
           let group = defaults.string(forKey: Self.lastGroupDefaultsKey)?.nilIfBlank,
           let cachedSchedule = api.cachedGroupSchedule(groupNumber: group) {
            applyRestoredGroupSchedule(cachedSchedule, groupNumber: group)
            return
        }

        // 2. Explicit last teacher selection
        if mode == .teacher,
           let urlId = defaults.string(forKey: Self.lastTeacherURLIDDefaultsKey)?.nilIfBlank,
           let cachedSchedule = api.cachedEmployeeSchedule(urlId: urlId) {
            let displayName = defaults.string(forKey: Self.lastTeacherNameDefaultsKey) ?? urlId
            let restored = ScheduleEmployeeDirectoryEntry(
                firstName: nil,
                lastName: nil,
                middleName: nil,
                degree: nil,
                rank: nil,
                photoLink: nil,
                calendarId: nil,
                id: Int.min,
                urlId: urlId,
                fio: displayName
            )
            applyEmployeeSchedule(cachedSchedule, week: nil, employee: restored, urlId: urlId)
            return
        }

        // 3. First pinned group
        if let firstPinned = pinnedGroupNames.first,
           let cachedSchedule = api.cachedGroupSchedule(groupNumber: firstPinned) {
            applyRestoredGroupSchedule(cachedSchedule, groupNumber: firstPinned)
            return
        }

        // 4. Account group (if logged in)
        if let accountGroup = accountGroupName,
           let cachedSchedule = api.cachedGroupSchedule(groupNumber: accountGroup) {
            applyRestoredGroupSchedule(cachedSchedule, groupNumber: accountGroup)
            return
        }
    }

    private func applyRestoredGroupSchedule(_ scheduleResponse: PublicScheduleResponse, groupNumber: String) {
        schedule = scheduleResponse
        currentWeekNumber = resolveCurrentWeekNumber(
            backendValue: nil,
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
        saveSnapshot()
        errorMessage = nil
        updateClassScheduleWidgetSnapshot(from: scheduleResponse)
        updateSessionScheduleWidgetSnapshot(from: scheduleResponse)
    }

    func saveSnapshot() {
        guard usesSharedSnapshotCache else { return }
        guard let schedule else { return }
        Self.cachedSnapshot = Snapshot(
            dataSource: dataSource,
            accountGroupName: accountGroupName,
            mode: mode,
            query: query,
            schedule: schedule,
            currentWeekNumber: currentWeekNumber,
            weekFilter: weekFilter,
            displayMode: displayMode,
            subgroupFilter: subgroupFilter,
            languageSubgroupTeacherID: languageSubgroupTeacherID,
            subjectSubgroupTeacherIDs: subjectSubgroupTeacherIDs,
            continuousTimelineDays: continuousTimelineDays
        )
    }
}
