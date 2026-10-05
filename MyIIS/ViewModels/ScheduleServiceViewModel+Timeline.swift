import Foundation

extension ScheduleServiceViewModel {
    func loadMoreContinuousDaysIfNeeded(lastVisibleDayID: String) {
        guard mode == .group || mode == .teacher else { return }
        guard displayMode == .continuous else { return }
        let thresholdIDs = continuousTimelineDays.suffix(4).map(\.id)
        guard thresholdIDs.contains(lastVisibleDayID) else { return }
        appendContinuousChunkIfNeeded()
    }

    /// Prepares the lazy timeline around a user-selected date and returns the
    /// closest day containing lessons so ScrollViewReader can reveal it without blocking the UI.
    func prepareContinuousTimeline(around requestedDate: Date) async -> String? {
        guard let input = timelineBuildInput() else { return nil }
        timelineGenerationTask?.cancel()
        isLoadingContinuousChunk = false
        timelineRevision = UUID()
        let revision = timelineRevision

        let calendar = Calendar.current
        let requestedDay = calendar.startOfDay(for: requestedDate)
        let lowerBound = input.startDate.map { calendar.startOfDay(for: $0) } ?? requestedDay
        let upperBound = ScheduleTimelineBuilder.timelineEndBound(for: input, calendar: calendar, now: requestedDay)
        let targetDay = min(max(requestedDay, lowerBound), upperBound)
        let rangeStart = max(
            lowerBound,
            calendar.date(byAdding: .day, value: -3, to: targetDay) ?? targetDay
        )
        let rangeEnd = min(
            upperBound,
            calendar.date(
                byAdding: .day,
                value: ScheduleTimelineBuilder.continuousChunkSizeDays,
                to: targetDay
            ) ?? targetDay
        )

        let result = await Task.detached(priority: .userInitiated) {
            ScheduleTimelineBuilder.buildTimeline(
                input: input,
                from: rangeStart,
                through: rangeEnd
            )
        }.value
        guard !Task.isCancelled, revision == timelineRevision else { return nil }

        var merged = Dictionary(
            continuousTimelineDays.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest }
        )
        for day in result.days {
            merged[day.id] = day
        }
        continuousTimelineDays = merged.values.sorted { $0.date < $1.date }
        continuousCursorDate = max(continuousCursorDate ?? result.nextCursor, result.nextCursor)
        isContinuousEndReached = (continuousCursorDate ?? result.nextCursor) > upperBound

        return continuousTimelineDays.first(where: { $0.date >= targetDay })?.id
            ?? continuousTimelineDays.last?.id
    }

    func rebuildContinuousTimeline(reset: Bool) {
        timelineRevision = UUID()
        timelineGenerationTask?.cancel()
        isLoadingContinuousChunk = false
        if reset {
            continuousCursorDate = nil
            isContinuousEndReached = false
        }
        appendContinuousChunkIfNeeded(isReset: reset)
    }

    private func appendContinuousChunkIfNeeded(isReset: Bool = false) {
        guard let input = timelineBuildInput() else {
            continuousTimelineDays = []
            continuousCursorDate = nil
            isContinuousEndReached = false
            return
        }
        guard !isContinuousEndReached, !isLoadingContinuousChunk else { return }

        isLoadingContinuousChunk = true
        let cursor = isReset ? nil : continuousCursorDate
        let now = Date()
        let revision = timelineRevision
        timelineGenerationTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                ScheduleTimelineBuilder.buildTimelineChunk(
                    input: input,
                    cursor: cursor,
                    now: now
                )
            }.value
            guard let self, !Task.isCancelled, revision == self.timelineRevision else { return }

            self.continuousCursorDate = result.nextCursor
            self.isContinuousEndReached = result.reachedEnd
            self.isLoadingContinuousChunk = false
            if isReset {
                self.continuousTimelineDays = result.days
            } else if !result.days.isEmpty {
                var days = Dictionary(self.continuousTimelineDays.map { ($0.id, $0) },
                                      uniquingKeysWith: { _, latest in latest })
                for day in result.days { days[day.id] = day }
                self.continuousTimelineDays = days.values.sorted { $0.date < $1.date }
            }
            if let schedule = self.schedule {
                self.saveSnapshot()
                if cursor == nil {
                    self.updateClassScheduleWidgetSnapshot(from: schedule)
                }
            }
        }
    }

    private func timelineBuildInput() -> ScheduleTimelineBuilder.Input? {
        guard let schedule else { return nil }
        let selectedSubgroup: Int?
        switch subgroupFilter {
        case .all:
            selectedSubgroup = nil
        case .subgroup(let value):
            selectedSubgroup = value
        }
        let rawDisplay = defaults.string(
            forKey: ScheduleDisplayPreferences.otherSubgroupDisplayKey
        )
        let display = rawDisplay.flatMap(ScheduleOtherSubgroupDisplay.init(rawValue:))
            ?? .compact
        return ScheduleTimelineBuilder.Input(
            orderedDays: schedule.orderedDays.map { day in
                StudyDaySchedule(weekday: day.weekday, lessons: day.lessons.filter(shouldKeepLanguageLesson))
            },
            startDate: schedule.startDate,
            endDate: schedule.endDate,
            selectedSubgroup: selectedSubgroup,
            includesOtherSubgroups: display != .hidden
        )
    }

    private func continuousEndBound(
        for schedule: PublicScheduleResponse,
        calendar: Calendar,
        now: Date
    ) -> Date {
        let fallback = calendar.date(
            byAdding: .day,
            value: ScheduleTimelineBuilder.continuousFallbackHorizonDays,
            to: calendar.startOfDay(for: now)
        ) ?? now
        guard let endDate = schedule.endDate else { return fallback }
        return calendar.startOfDay(for: endDate)
    }

    private func lessonsForContinuousDay(weekday: StudyWeekday, weekNumber: Int, date: Date) -> [DisciplineSchedule] {
        guard let schedule else { return [] }

        let lessonList = schedule.orderedDays
            .first(where: { $0.weekday == weekday })?
            .lessons ?? []

        let weekScoped = lessonList
            .filter(shouldKeepLesson)
            .filter { $0.weekNumbers.isEmpty || $0.weekNumbers.contains(weekNumber) }

        return weekScoped.filter { Self.isLessonScheduledOnContinuousDay($0, date: date) }
    }

    nonisolated static func isLessonScheduledOnContinuousDay(_ lesson: DisciplineSchedule, date: Date) -> Bool {
        let hasExplicitDateConstraint = lesson.lessonDate != nil
            || lesson.startLessonDate != nil
            || lesson.endLessonDate != nil
        return !hasExplicitDateConstraint || lesson.isScheduled(on: date)
    }

    func updateContinuousDayPartitions() {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday.addingTimeInterval(86400)

        var past: [ScheduleContinuousDay] = []
        var upcoming: [ScheduleContinuousDay] = []
        past.reserveCapacity(continuousTimelineDays.count)
        upcoming.reserveCapacity(continuousTimelineDays.count)

        for day in continuousTimelineDays {
            let dayStart = calendar.startOfDay(for: day.date)
            if dayStart < startOfToday {
                past.append(day)
            } else if dayStart >= startOfTomorrow {
                upcoming.append(day)
            } else {
                if day.lessons.allSatisfy({ isExamPast($0, on: day.date, now: now, calendar: calendar) }) {
                    past.append(day)
                } else {
                    upcoming.append(day)
                }
            }
        }
        self.pastContinuousDays = past
        self.upcomingContinuousDays = upcoming
    }
}
