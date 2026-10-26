import Foundation

@MainActor
final class WidgetScheduleRefreshService {
    static let shared = WidgetScheduleRefreshService()
    private var revision = UUID()
    private var lastRefresh: Date?
    private var lastTarget: String?
    private let api: ServiceEndpointsAPI
    private let defaults: UserDefaults
    private let publish: ((SessionScheduleWidgetSnapshot, SessionScheduleWidgetSnapshot) -> Void)?

    init(
        api: ServiceEndpointsAPI? = nil,
        defaults: UserDefaults? = nil,
        publish: ((SessionScheduleWidgetSnapshot, SessionScheduleWidgetSnapshot) -> Void)? = nil
    ) {
        self.api = api ?? ServiceEndpointsAPI()
        self.defaults = defaults ?? WidgetScheduleSelection.defaults
        self.publish = publish
    }

    func refresh(force: Bool = false) async {
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
                if let responseID = response.employee?.urlId, responseID != teacherID { return }
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
                  WidgetScheduleSelection.target(in: defaults) == target else { return }
            let events = days.flatMap { day in
                day.lessons.map { ScheduleServiceViewModel.widgetEvent(from: $0, on: day.date) }
            }.filter { $0.isUpcoming(at: now) }.sorted(by: ScheduleServiceViewModel.widgetEventSortingComparator)
            let snapshot = SessionScheduleWidgetSnapshot(
                groupName: title, startDate: response.startDate, endDate: response.endDate,
                events: Array(events.prefix(80)), updatedAt: now
            )
            let exams = response.exams.filter(keep).map {
                ScheduleServiceViewModel.widgetEvent(from: $0, on: $0.lessonDate ?? $0.startLessonDate)
            }.filter { $0.isUpcoming(at: now) }.sorted(by: ScheduleServiceViewModel.widgetEventSortingComparator)
            let examSnapshot = SessionScheduleWidgetSnapshot(
                groupName: title, startDate: response.startExamsDate, endDate: response.endExamsDate,
                events: Array(exams.prefix(80)), updatedAt: now
            )
            publishSnapshots(snapshot, exams: examSnapshot)
            lastTarget = identity
            lastRefresh = now
        } catch {
            LogService.shared.log("Widget schedule refresh failed: \(error.localizedDescription)")
        }
    }

    private func publishSnapshots(_ schedule: SessionScheduleWidgetSnapshot, exams: SessionScheduleWidgetSnapshot) {
        if let publish {
            publish(schedule, exams)
        } else {
            ClassScheduleWidgetDataStore.save(schedule)
            SessionScheduleWidgetDataStore.save(exams)
            WatchScheduleConnectivityService.shared.send(schedule)
        }
    }

    func updateAccountGroup(_ group: String?) async {
        let changed = WidgetScheduleSelection.updateAccountGroup(group, in: defaults)
        if changed {
            revision = UUID()
            lastRefresh = nil
            lastTarget = nil
            ClassScheduleWidgetDataStore.clear()
            SessionScheduleWidgetDataStore.clear()
            WatchScheduleConnectivityService.shared.clear()
        }
        await refresh(force: changed)
    }
}
