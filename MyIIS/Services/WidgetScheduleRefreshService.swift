import Foundation

@MainActor
final class WidgetScheduleRefreshService {
    static let shared = WidgetScheduleRefreshService()
    private var revision = UUID()
    private var lastRefresh: Date?
    private var lastTarget: String?
    private let api = ServiceEndpointsAPI()

    func refresh(force: Bool = false) async {
        let defaults = WidgetScheduleSelection.defaults
        let target = WidgetScheduleSelection.target(in: defaults)
        guard let title = target.title else { return }
        let identity = target.teacherID.map { "teacher:\($0)" } ?? "group:\(title)"
        if !force, lastTarget == identity, let lastRefresh,
           Date().timeIntervalSince(lastRefresh) < 300 { return }
        let requestID = UUID()
        revision = requestID
        do {
            let response: PublicScheduleResponse
            if let teacherID = target.teacherID {
                response = try await api.fetchEmployeeSchedule(urlId: teacherID, preferCachedResponse: !force)
                guard response.employee?.fullName == title else { return }
            } else {
                response = try await api.fetchGroupSchedule(groupNumber: title, preferCachedResponse: !force)
                guard response.group?.name == title else { return }
            }
            let storedSubgroup = defaults.object(
                forKey: ScheduleServiceViewModel.subgroupFilterByGroupDefaultsKey + "." + title
            ) as? Int
            let subgroup = storedSubgroup.flatMap { $0 > 0 ? $0 : nil }
            let subjectTeachers = defaults.dictionary(
                forKey: ScheduleServiceViewModel.subjectSubgroupDefaultsKey + "." + title
            ) as? [String: Int] ?? [:]
            let languageTeacher = defaults.object(
                forKey: ScheduleServiceViewModel.languageSubgroupDefaultsKey + "." + title
            ) as? Int
            func keep(_ lesson: DisciplineSchedule) -> Bool {
                if let subgroup, lesson.subgroup != 0, lesson.subgroup != subgroup { return false }
                let key = ScheduleServiceViewModel.subjectKey(lesson)
                let teacher = ScheduleServiceViewModel.isLanguageSubject(key) ? languageTeacher : subjectTeachers[key]
                if lesson.subgroup == 0, let teacher, !lesson.employees.isEmpty {
                    return lesson.employees.contains { $0.id == teacher }
                }
                return true
            }
            let input = ScheduleTimelineBuilder.Input(
                orderedDays: response.orderedDays.map {
                    StudyDaySchedule(weekday: $0.weekday, lessons: $0.lessons.filter(keep))
                }, startDate: response.startDate,
                endDate: response.endDate, selectedSubgroup: nil, includesOtherSubgroups: false
            )
            let now = Date()
            let days = await Task.detached(priority: .utility) {
                ScheduleTimelineBuilder.buildTimelineChunk(input: input, cursor: nil, now: now).days
            }.value
            guard !Task.isCancelled, revision == requestID,
                  WidgetScheduleSelection.accepts(title, in: defaults) else { return }
            let events = days.flatMap { day in
                day.lessons.map { ScheduleServiceViewModel.widgetEvent(from: $0, on: day.date) }
            }.filter { $0.isUpcoming(at: now) }.sorted(by: ScheduleServiceViewModel.widgetEventSortingComparator)
            let snapshot = SessionScheduleWidgetSnapshot(
                groupName: title, startDate: response.startDate, endDate: response.endDate,
                events: Array(events.prefix(80)), updatedAt: now
            )
            ClassScheduleWidgetDataStore.save(snapshot)
            let exams = response.exams.filter(keep).map {
                ScheduleServiceViewModel.widgetEvent(from: $0, on: $0.lessonDate ?? $0.startLessonDate)
            }.filter { $0.isUpcoming(at: now) }.sorted(by: ScheduleServiceViewModel.widgetEventSortingComparator)
            SessionScheduleWidgetDataStore.save(SessionScheduleWidgetSnapshot(
                groupName: title, startDate: response.startExamsDate, endDate: response.endExamsDate,
                events: Array(exams.prefix(80)), updatedAt: now
            ))
            WatchScheduleConnectivityService.shared.send(snapshot)
            lastTarget = identity
            lastRefresh = now
        } catch {
            LogService.shared.log("Widget schedule refresh failed: \(error.localizedDescription)")
        }
    }

    func updateAccountGroup(_ group: String?) async {
        let defaults = WidgetScheduleSelection.defaults
        let normalized = WidgetScheduleSelection.nonEmpty(group)
        let previous = defaults.string(forKey: WidgetScheduleSelection.accountGroupKey)
        defaults.set(normalized, forKey: WidgetScheduleSelection.accountGroupKey)
        if previous != normalized {
            // Overrides belong to the account that chose them.
            defaults.removeObject(forKey: WidgetScheduleSelection.groupKey)
            defaults.removeObject(forKey: WidgetScheduleSelection.teacherIDKey)
            defaults.removeObject(forKey: WidgetScheduleSelection.teacherNameKey)
            ClassScheduleWidgetDataStore.clear()
            SessionScheduleWidgetDataStore.clear()
            WatchScheduleConnectivityService.shared.clear()
        }
        await refresh(force: previous != normalized)
    }
}
