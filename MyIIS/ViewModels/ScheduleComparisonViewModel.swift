import Foundation
import Observation

struct ScheduleComparisonDay: Identifiable, Sendable {
    let date: Date
    let lessons: [DisciplineSchedule]
    let unavailable: Bool
    var id: Date { date }
}

@MainActor
@Observable
final class ScheduleComparisonViewModel {
    var groupNames: [String]
    var groups: [StudyGroup] = []
    private(set) var isDirectoryLoading = false
    private(set) var directoryError: String?
    var subgroups = [0, 0]
    var startDate = Calendar.current.startOfDay(for: Date())
    private(set) var schedules: [PublicScheduleResponse?]
    private(set) var errors: [String?] = [nil, nil]
    private(set) var loading = [false, false]
    private(set) var days: [[ScheduleComparisonDay]] = [[], []]
    private(set) var commonWindows: [Date: [String]] = [:]
    private(set) var rows: [ScheduleComparisonRow] = []
    @ObservationIgnored private let api = ServiceEndpointsAPI()
    @ObservationIgnored private var revisions = [UUID(), UUID()]
    @ObservationIgnored private var presentationRevision = UUID()

    init(group: String?, schedule: PublicScheduleResponse?, subgroup: ScheduleSubgroupFilter) {
        groupNames = [group ?? "", ""]
        schedules = [schedule, nil]
        if case .subgroup(let number) = subgroup { subgroups[0] = number }
    }

    func loadDirectory(force: Bool = false) async {
        guard !isDirectoryLoading, groups.isEmpty || force else { return }
        isDirectoryLoading = true
        directoryError = nil
        defer { isDirectoryLoading = false }
        do {
            let result = try await api.fetchAllStudentGroups(preferCachedResponse: !force)
            guard !Task.isCancelled else { return }
            groups = result.sorted { $0.name < $1.name }
        } catch {
            guard !Task.isCancelled else { return }
            directoryError = error.localizedDescription
        }
    }

    func subgroupOptions(_ side: Int) -> [Int] {
        let values = schedules[side]?.orderedDays.flatMap(\.lessons).map(\.subgroup) ?? []
        return [0] + Set(values.filter { $0 > 0 }).sorted()
    }

    func select(_ group: String, side: Int, subgroup: ScheduleSubgroupFilter = .all) async {
        let name = group.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let number: Int
        if case .subgroup(let value) = subgroup { number = max(0, value) } else { number = 0 }
        if groupNames[side] == name, schedules[side] != nil, errors[side] == nil {
            subgroups[side] = number
            await rebuild()
            return
        }
        groupNames[side] = name
        subgroups[side] = number
        schedules[side] = nil
        await load(side)
    }

    func load(_ side: Int, force: Bool = false) async {
        let name = groupNames[side]
        guard !name.isEmpty else { return }
        let revision = UUID()
        revisions[side] = revision
        loading[side] = true
        errors[side] = nil
        await rebuild()
        defer { if revisions[side] == revision { loading[side] = false } }
        do {
            let result = try await api.fetchGroupSchedule(groupNumber: name, preferCachedResponse: !force)
            guard !Task.isCancelled, revisions[side] == revision else { return }
            schedules[side] = result
        } catch {
            guard !Task.isCancelled, revisions[side] == revision else { return }
            errors[side] = error.localizedDescription
        }
        await rebuild()
    }

    func rebuild() async {
        let revision = UUID()
        presentationRevision = revision
        let responses = schedules.map { response in
            response.map { ScheduleComparisonBuilder.Input(response: $0) }
        }
        let selectedGroups = groupNames
        let filters = subgroups
        let date = startDate
        let failed = errors.map { $0 != nil }
        let output = await Task.detached(priority: .userInitiated) {
            let result = ScheduleComparisonBuilder.build(
                responses: responses, subgroups: filters, start: date, failed: failed
            )
            return (result, ScheduleComparisonBuilder.rows(for: result.days, groups: selectedGroups))
        }.value
        guard !Task.isCancelled, presentationRevision == revision else { return }
        days = output.0.days
        commonWindows = output.0.windows
        rows = output.1
    }
}

enum ScheduleComparisonBuilder {
    struct Input: Sendable {
        let orderedDays: [StudyDaySchedule]
        let startDate: Date?
        let endDate: Date?
        let exams: [DisciplineSchedule]

        @MainActor
        init(response: PublicScheduleResponse) {
            orderedDays = response.orderedDays
            startDate = response.startDate
            endDate = response.endDate
            exams = response.exams
        }
    }

    struct Result: Sendable {
        let days: [[ScheduleComparisonDay]]
        let windows: [Date: [String]]
    }

    nonisolated static func build(
        responses: [Input?], subgroups: [Int], start: Date, failed: [Bool]
    ) -> Result {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: start)
        let dates = (0..<1).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        var columns: [[ScheduleComparisonDay]] = []
        for side in 0..<2 {
            let response = responses[side]
            let input = response.map {
                ScheduleTimelineBuilder.Input(
                    orderedDays: $0.orderedDays.map { day in
                        StudyDaySchedule(weekday: day.weekday, lessons: day.lessons.filter {
                            subgroups[side] == 0 || $0.subgroup == 0 || $0.subgroup == subgroups[side]
                        })
                    }, startDate: $0.startDate, endDate: $0.endDate,
                    selectedSubgroup: subgroups[side] == 0 ? nil : subgroups[side],
                    includesOtherSubgroups: false
                )
            }
            let timeline = input.map {
                ScheduleTimelineBuilder.buildTimeline(input: $0, from: start, through: dates.last ?? start).days
            } ?? []
            let byDate = Dictionary(timeline.map { ($0.date, $0.lessons) }, uniquingKeysWith: { _, last in last })
            columns.append(dates.map { date in
                let outside = response.map {
                    ($0.startDate.map { date < calendar.startOfDay(for: $0) } ?? true)
                        || ($0.endDate.map { date > calendar.startOfDay(for: $0) } ?? true)
                        || ($0.orderedDays.isEmpty && $0.exams.isEmpty)
                } ?? true
                let exams = response?.exams.filter {
                    ($0.subgroup == 0 || subgroups[side] == 0 || $0.subgroup == subgroups[side])
                        && $0.isScheduled(on: date)
                } ?? []
                return ScheduleComparisonDay(
                    date: date,
                    lessons: ((outside ? [] : (byDate[date] ?? [])) + exams).sorted {
                        (minutes($0.startLessonTime) ?? 0) < (minutes($1.startLessonTime) ?? 0)
                    },
                    unavailable: outside || failed[side]
                )
            })
        }
        var windows: [Date: [String]] = [:]
        for index in dates.indices {
            let left = columns[0][index]
            let right = columns[1][index]
            guard !left.unavailable, !right.unavailable else { continue }
            windows[dates[index]] = freeWindows(left.lessons + right.lessons)
        }
        return Result(days: columns, windows: windows)
    }

    /// Conservative: malformed lesson times make the day's availability unknown.
    nonisolated static func freeWindows(_ lessons: [DisciplineSchedule]) -> [String]? {
        var busy: [(Int, Int)] = []
        for lesson in lessons {
            guard let start = minutes(lesson.startLessonTime),
                  let end = minutes(lesson.endLessonTime), end > start else { return nil }
            busy.append((start, end))
        }
        var cursor = 8 * 60
        let limit = 22 * 60
        var result: [String] = []
        for interval in busy.sorted(by: { $0.0 < $1.0 }) {
            let start = max(8 * 60, min(limit, interval.0))
            let end = max(8 * 60, min(limit, interval.1))
            if start - cursor >= 30 { result.append("\(time(cursor))–\(time(start))") }
            cursor = max(cursor, end)
        }
        if limit - cursor >= 30 { result.append("\(time(cursor))–\(time(limit))") }
        return result
    }

    private struct TimedLesson {
        let start: Int
        let end: Int
        let side: Int
        let lesson: DisciplineSchedule
    }

    nonisolated static func rows(for days: [[ScheduleComparisonDay]], groups: [String]) -> [ScheduleComparisonRow] {
        guard let left = days.first?.first, let right = days.last?.first else { return [] }
        let all = [left.lessons, right.lessons].enumerated().flatMap { side, lessons in
            lessons.compactMap { lesson -> TimedLesson? in
                guard let start = minutes(lesson.startLessonTime),
                      let end = minutes(lesson.endLessonTime), end > start else { return nil }
                return TimedLesson(start: start, end: end, side: side, lesson: lesson)
            }
        }.sorted { $0.start < $1.start }
        var result: [ScheduleComparisonRow] = []
        for item in all {
            if let last = result.last, item.start < last.end {
                var merged = last
                merged.end = max(last.end, item.end)
                merged.lessons[item.side].append(item.lesson)
                result[result.count - 1] = merged
            } else {
                var lessons: [[DisciplineSchedule]] = [[], []]
                lessons[item.side] = [item.lesson]
                result.append(ScheduleComparisonRow(start: item.start, end: item.end, lessons: lessons))
            }
        }
        for index in result.indices {
            var right = result[index].lessons[1]
            var left: [DisciplineSchedule] = []
            for lesson in result[index].lessons[0] {
                if let match = right.firstIndex(where: { shared(lesson, $0, groups: groups) }) {
                    result[index].sharedLessons.append(lesson)
                    right.remove(at: match)
                } else {
                    left.append(lesson)
                }
            }
            result[index].lessons = [left, right]
        }
        return result
    }

    nonisolated private static func shared(
        _ lhs: DisciplineSchedule, _ rhs: DisciplineSchedule, groups: [String]
    ) -> Bool {
        guard groups.count == 2,
              lhs.startLessonTime == rhs.startLessonTime, lhs.endLessonTime == rhs.endLessonTime,
              normalized(lhs.subject) == normalized(rhs.subject),
              lhs.lessonTypeAbbrev == rhs.lessonTypeAbbrev,
              lhs.subgroup == rhs.subgroup, lhs.note == rhs.note,
              !lhs.isAnnouncement, !rhs.isAnnouncement,
              Set(lhs.auditories) == Set(rhs.auditories),
              Set(lhs.employees.map(\.id)) == Set(rhs.employees.map(\.id)) else { return false }
        if groups[0] == groups[1] { return true }
        let leftGroups = Set(lhs.studentGroups.compactMap(\.name))
        let rightGroups = Set(rhs.studentGroups.compactMap(\.name))
        let listedTogether = Set(groups).isSubset(of: leftGroups) && Set(groups).isSubset(of: rightGroups)
        // Some group responses only list the requested group. Matching staff and room
        // at the same time provide an additional, conservative shared-class signal.
        let matchingStaffAndRoom = !lhs.employees.isEmpty && !lhs.auditories.isEmpty
        return listedTogether || matchingStaffAndRoom
    }

    nonisolated private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    nonisolated private static func minutes(_ value: String) -> Int? {
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return hour * 60 + minute
    }

    nonisolated private static func time(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}
