import Combine
import SwiftUI

enum ScheduleLookupMode: String, CaseIterable {
    case group
    case teacher
}

enum ScheduleDisplayMode: String, CaseIterable, Identifiable {
    case continuous
    case byDay
    case exams

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .continuous:
            return NSLocalizedString("services_schedule_display_continuous", comment: "")
        case .byDay:
            return NSLocalizedString("services_schedule_display_day", comment: "")
        case .exams:
            return NSLocalizedString("services_schedule_display_exams", comment: "")
        }
    }

    var icon: String {
        switch self {
        case .continuous:
            return "calendar.day.timeline.leading"
        case .byDay:
            return "calendar"
        case .exams:
            return "graduationcap"
        }
    }
}

enum ScheduleSubgroupFilter: Hashable, Identifiable {
    case all
    case subgroup(Int)

    var id: String {
        switch self {
        case .all:
            return "all"
        case .subgroup(let value):
            return "subgroup-\(value)"
        }
    }

    var localizedTitle: String {
        switch self {
        case .all:
            return NSLocalizedString("services_schedule_subgroup_all", comment: "")
        case .subgroup(let value):
            return String(format: NSLocalizedString("services_schedule_subgroup_number", comment: ""), value)
        }
    }

    var localizedCompactTitle: String {
        switch self {
        case .all:
            return NSLocalizedString("services_schedule_subgroup_short_all", comment: "")
        case .subgroup(let value):
            return String(format: NSLocalizedString("services_schedule_subgroup_short_number", comment: ""), value)
        }
    }
}

struct ScheduleContinuousDay: Identifiable {
    let date: Date
    let weekday: StudyWeekday
    let weekNumber: Int
    let lessons: [DisciplineSchedule]

    var id: String {
        String(Int(date.timeIntervalSince1970))
    }
}

@MainActor
final class ScheduleServiceViewModel: ObservableObject {
    @Published var mode: ScheduleLookupMode = .group {
        didSet {
            if oldValue != mode {
                defaults.set(mode.rawValue, forKey: Self.selectedModeDefaultsKey)
                if shouldResetQueryOnModeChange {
                    query = ""
                }
                Task { await loadDirectoryIfNeeded(force: false) }
            }
        }
    }
    @Published var query = ""
    @Published var groups: [StudyGroup] = []
    @Published var employees: [ScheduleEmployeeDirectoryEntry] = []
    @Published var schedule: PublicScheduleResponse?
    @Published var currentWeekNumber: Int?
    @Published var weekFilter: StudyWeekFilter = .all
    @Published var displayMode: ScheduleDisplayMode = .byDay {
        didSet { persistDisplayMode() }
    }
    @Published var subgroupFilter: ScheduleSubgroupFilter = .all {
        didSet {
            persistSubgroupFilter()
            rebuildContinuousTimeline(reset: true)
        }
    }
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var continuousTimelineDays: [ScheduleContinuousDay] = []

    private let api: ServiceEndpointsAPI
    private let authService: AuthenticationService
    private let defaults: UserDefaults
    private var hasLoadedInitialData = false
    private var shouldResetQueryOnModeChange = true
    private var continuousCursorDate: Date?
    private var isContinuousEndReached = false
    private var isLoadingContinuousChunk = false

    private static let displayModeDefaultsKey = "services.schedule.displayMode"
    private static let subgroupFilterDefaultsKey = "services.schedule.subgroupFilter"
    private static let selectedModeDefaultsKey = "services.schedule.selectedMode"
    private static let lastGroupDefaultsKey = "services.schedule.lastGroup"
    private static let lastTeacherURLIDDefaultsKey = "services.schedule.lastTeacherURLID"
    private static let lastTeacherNameDefaultsKey = "services.schedule.lastTeacherName"
    private static let continuousChunkSizeDays = 28

    init(
        api: ServiceEndpointsAPI? = nil,
        authService: AuthenticationService = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.api = api ?? ServiceEndpointsAPI()
        self.authService = authService
        self.defaults = defaults

        if let modeRaw = defaults.string(forKey: Self.displayModeDefaultsKey),
           let restoredMode = ScheduleDisplayMode(rawValue: modeRaw) {
            displayMode = restoredMode
        }

        if let selectedModeRaw = defaults.string(forKey: Self.selectedModeDefaultsKey),
           let selectedMode = ScheduleLookupMode(rawValue: selectedModeRaw) {
            mode = selectedMode
        }

        if let savedValue = defaults.object(forKey: Self.subgroupFilterDefaultsKey) as? Int {
            subgroupFilter = savedValue > 0 ? .subgroup(savedValue) : .all
        }

        if mode == .group, let lastGroup = defaults.string(forKey: Self.lastGroupDefaultsKey) {
            query = lastGroup
        } else if mode == .teacher, let lastTeacherName = defaults.string(forKey: Self.lastTeacherNameDefaultsKey) {
            query = lastTeacherName
        }
    }

    func loadInitialDataIfNeeded() async {
        guard !hasLoadedInitialData else { return }
        hasLoadedInitialData = true

        await loadDirectoryIfNeeded(force: false)

        if let group = accountGroupName {
            await loadGroup(group)
            return
        }

        if mode == .group, let lastGroup = defaults.string(forKey: Self.lastGroupDefaultsKey)?.nilIfBlank {
            await loadGroup(lastGroup)
            return
        }

        if mode == .teacher,
           let lastTeacherURLID = defaults.string(forKey: Self.lastTeacherURLIDDefaultsKey)?.nilIfBlank {
            let restored = ScheduleEmployeeDirectoryEntry(
                firstName: nil,
                lastName: nil,
                middleName: nil,
                degree: nil,
                rank: nil,
                photoLink: nil,
                calendarId: nil,
                id: Int.min,
                urlId: lastTeacherURLID,
                fio: defaults.string(forKey: Self.lastTeacherNameDefaultsKey)
            )
            await loadEmployee(restored)
        }
    }

    func reloadDirectory() async {
        await loadDirectoryIfNeeded(force: true)
    }

    func refreshData() async {
        await loadDirectoryIfNeeded(force: true)

        switch mode {
        case .group:
            if let selectedGroup = schedule?.group?.name.nilIfBlank ?? query.nilIfBlank {
                await loadGroup(selectedGroup)
            }
        case .teacher:
            if let urlId = schedule?.employee?.urlId.nilIfBlank {
                let name = schedule?.employee?.fullName ?? defaults.string(forKey: Self.lastTeacherNameDefaultsKey) ?? urlId
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
                    fio: name
                )
                await loadEmployee(restored)
            }
        }
    }

    func loadByQuery() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = NSLocalizedString("services_schedule_query_required", comment: "")
            return
        }

        switch mode {
        case .group:
            await loadGroup(trimmed)
        case .teacher:
            if let direct = filteredEmployees.first(where: { $0.urlId == trimmed || $0.displayName.compare(trimmed, options: .caseInsensitive) == .orderedSame }) {
                await loadEmployee(direct)
            } else {
                errorMessage = NSLocalizedString("services_schedule_teacher_pick_hint", comment: "")
            }
        }
    }

    func loadGroup(_ groupNumber: String) async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let scheduleResponse = try await api.fetchGroupSchedule(groupNumber: groupNumber)
            let week = try? await api.fetchCurrentWeek()
            schedule = scheduleResponse
            currentWeekNumber = resolveCurrentWeekNumber(
                backendValue: week,
                termStartDate: scheduleResponse.startDate
            )
            applyDefaultWeekFilter()
            sanitizeSubgroupFilter()
            rebuildContinuousTimeline(reset: true)
            setMode(.group, preservingQuery: groupNumber)
            persistGroupSelection(groupNumber)
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func loadEmployee(_ employee: ScheduleEmployeeDirectoryEntry) async {
        guard let urlId = employee.urlId, !urlId.isEmpty else {
            errorMessage = NSLocalizedString("services_schedule_teacher_missing_urlid", comment: "")
            return
        }
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let scheduleResponse = try await api.fetchEmployeeSchedule(urlId: urlId)
            let week = try? await api.fetchCurrentWeek()
            schedule = scheduleResponse
            currentWeekNumber = resolveCurrentWeekNumber(
                backendValue: week,
                termStartDate: scheduleResponse.startDate
            )
            applyDefaultWeekFilter()
            sanitizeSubgroupFilter()
            rebuildContinuousTimeline(reset: true)
            setMode(.teacher, preservingQuery: employee.displayName)
            persistTeacherSelection(urlId: urlId, displayName: employee.displayName)
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func openTeacherSchedule(_ teacher: DisciplineEmployee) async {
        guard let urlId = teacher.urlId, !urlId.isEmpty else { return }
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
        await loadGroup(groupName)
    }

    private func setMode(_ newMode: ScheduleLookupMode, preservingQuery newQuery: String) {
        shouldResetQueryOnModeChange = false
        mode = newMode
        shouldResetQueryOnModeChange = true
        query = newQuery
        defaults.set(newMode.rawValue, forKey: Self.selectedModeDefaultsKey)
    }

    private func persistGroupSelection(_ group: String) {
        defaults.set(group, forKey: Self.lastGroupDefaultsKey)
        defaults.removeObject(forKey: Self.lastTeacherURLIDDefaultsKey)
        defaults.removeObject(forKey: Self.lastTeacherNameDefaultsKey)
    }

    private func persistTeacherSelection(urlId: String, displayName: String) {
        defaults.set(urlId, forKey: Self.lastTeacherURLIDDefaultsKey)
        defaults.set(displayName, forKey: Self.lastTeacherNameDefaultsKey)
    }

    func loadMoreContinuousDaysIfNeeded(lastVisibleDayID: String) {
        guard mode == .group || mode == .teacher else { return }
        guard displayMode == .continuous else { return }
        guard continuousTimelineDays.last?.id == lastVisibleDayID else { return }
        appendContinuousChunkIfNeeded()
    }

    private func rebuildContinuousTimeline(reset: Bool) {
        guard schedule != nil else {
            continuousTimelineDays = []
            continuousCursorDate = nil
            isContinuousEndReached = false
            return
        }

        if reset {
            continuousTimelineDays = []
            continuousCursorDate = nil
            isContinuousEndReached = false
        }

        appendContinuousChunkIfNeeded()
    }

    private func appendContinuousChunkIfNeeded() {
        guard let schedule else { return }
        guard !isContinuousEndReached, !isLoadingContinuousChunk else { return }

        isLoadingContinuousChunk = true
        defer { isLoadingContinuousChunk = false }

        let calendar = Calendar.current
        let now = Date()
        let startBound = schedule.startDate.map { calendar.startOfDay(for: $0) }
        let initialStart = calendar.date(byAdding: .day, value: -2, to: now) ?? now
        var cursor = continuousCursorDate ?? calendar.startOfDay(for: initialStart)

        if let startBound, cursor < startBound {
            cursor = startBound
        }

        var generated: [ScheduleContinuousDay] = []
        var processedDays = 0

        while processedDays < Self.continuousChunkSizeDays {
            guard let weekday = studyWeekday(for: cursor),
                  let weekNumber = universityWeekNumber(on: cursor) else {
                processedDays += 1
                cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
                continue
            }

            let lessons = lessonsForContinuousDay(weekday: weekday, weekNumber: weekNumber, date: cursor)
            if !lessons.isEmpty {
                generated.append(
                    ScheduleContinuousDay(
                        date: cursor,
                        weekday: weekday,
                        weekNumber: weekNumber,
                        lessons: lessons
                    )
                )
            }

            processedDays += 1
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
        }

        continuousCursorDate = cursor
        if !generated.isEmpty {
            continuousTimelineDays.append(contentsOf: generated)
        }
    }

    private func lessonsForContinuousDay(weekday: StudyWeekday, weekNumber: Int, date: Date) -> [DisciplineSchedule] {
        guard let schedule else { return [] }

        let lessonList = schedule.orderedDays
            .first(where: { $0.weekday == weekday })?
            .lessons ?? []

        let weekScoped = lessonList
            .filter(shouldKeepLesson)
            .filter { $0.weekNumbers.isEmpty || $0.weekNumbers.contains(weekNumber) }

        let dated = weekScoped.filter { isLessonScheduledOnDate($0, date: date) }
        if !dated.isEmpty {
            return dated
        }

        // If API date ranges are stale or missing, keep a rolling weekly ribbon.
        return weekScoped
    }

    private func isLessonScheduledOnDate(_ lesson: DisciplineSchedule, date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)

        if let explicitDate = lesson.lessonDate {
            return calendar.isDate(explicitDate, inSameDayAs: day)
        }

        if let start = lesson.startLessonDate, let end = lesson.endLessonDate {
            let startDay = calendar.startOfDay(for: start)
            let endDay = calendar.startOfDay(for: end)
            return (startDay ... endDay).contains(day)
        }

        if let start = lesson.startLessonDate {
            return day >= calendar.startOfDay(for: start)
        }

        if let end = lesson.endLessonDate {
            return day <= calendar.startOfDay(for: end)
        }

        return true
    }

    private func applyDefaultWeekFilter() {
        guard let currentWeekNumber, weekFilters.contains(.week(currentWeekNumber)) else {
            weekFilter = .all
            return
        }
        weekFilter = .week(currentWeekNumber)
    }

    private func loadDirectoryIfNeeded(force: Bool) async {
        let shouldLoadGroups = mode == .group && (groups.isEmpty || force)
        let shouldLoadEmployees = mode == .teacher && (employees.isEmpty || force)
        guard shouldLoadGroups || shouldLoadEmployees else {
            hasLoadedInitialData = true
            return
        }

        if isLoading { return }
        isLoading = true
        defer {
            isLoading = false
            hasLoadedInitialData = true
        }

        do {
            if shouldLoadGroups {
                groups = try await api.fetchAllStudentGroups()
                    .sorted { $0.name < $1.name }
            }
            if shouldLoadEmployees {
                employees = try await api.fetchAllEmployees()
                    .filter { ($0.urlId?.isEmpty == false) }
                    .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            }
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func sanitizeSubgroupFilter() {
        if !subgroupFilters.contains(subgroupFilter) {
            subgroupFilter = .all
        }
    }

    private func shouldKeepLesson(_ lesson: DisciplineSchedule) -> Bool {
        switch subgroupFilter {
        case .all:
            return true
        case .subgroup(let value):
            return lesson.subgroup == 0 || lesson.subgroup == value
        }
    }

    private func lessonInterval(for lesson: DisciplineSchedule, on date: Date) -> (start: Date, end: Date)? {
        guard let start = parse(time: lesson.startLessonTime, on: date),
              let end = parse(time: lesson.endLessonTime, on: date) else {
            return nil
        }
        if end > start {
            return (start, end)
        }
        return nil
    }

    private func parse(time: String, on date: Date) -> Date? {
        let components = time.split(separator: ":")
        guard components.count >= 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return nil
        }
        return Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: date
        )
    }

    private func persistDisplayMode() {
        defaults.set(displayMode.rawValue, forKey: Self.displayModeDefaultsKey)
    }

    private func persistSubgroupFilter() {
        switch subgroupFilter {
        case .all:
            defaults.set(0, forKey: Self.subgroupFilterDefaultsKey)
        case .subgroup(let value):
            defaults.set(value, forKey: Self.subgroupFilterDefaultsKey)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private func resolveCurrentWeekNumber(backendValue: Int?, termStartDate: Date?) -> Int? {
        if let backendValue, (1 ... 4).contains(backendValue) {
            return backendValue
        }

        if let calculated = universityWeekNumber(on: Date()) {
            return calculated
        }

        guard let termStartDate else { return nil }
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.startOfDay(for: termStartDate)
        let now = calendar.startOfDay(for: Date())
        guard let distance = calendar.dateComponents([.weekOfYear], from: start, to: now).weekOfYear else {
            return nil
        }
        return ((abs(distance) % 4) + 1)
    }

    private func universityWeekNumber(on date: Date, now: Date = Date()) -> Int? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ru_BY")

        let components = calendar.dateComponents([.day, .month, .year], from: date)
        guard var septemberStart = calendar.date(from: DateComponents(year: components.year, month: 9, day: 1)),
              let julyStart = calendar.date(from: DateComponents(year: components.year, month: 7, day: 1)) else {
            return nil
        }

        if date < septemberStart,
           now < julyStart,
           let previousSeptemberStart = calendar.date(byAdding: .year, value: -1, to: septemberStart) {
            septemberStart = previousSeptemberStart
        }

        guard let startOfAnchorWeek = startOfWeek(for: septemberStart, calendar: calendar),
              let startOfTargetWeek = startOfWeek(for: date, calendar: calendar),
              let weeksDistance = calendar.dateComponents([.weekOfYear], from: startOfAnchorWeek, to: startOfTargetWeek).weekOfYear else {
            return nil
        }

        return (abs(weeksDistance) % 4) + 1
    }

    private func startOfWeek(for date: Date, calendar: Calendar) -> Date? {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components)
    }

    private var selectedWeekNumber: Int? {
        if case .week(let number) = weekFilter {
            return number
        }
        return nil
    }

    private var currentStudyWeekday: StudyWeekday? {
        studyWeekday(for: Date())
    }

    private func studyWeekday(for date: Date) -> StudyWeekday? {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch weekday {
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        case 1: return .sunday
        default: return nil
        }
    }

    private func date(for weekday: StudyWeekday, selectedWeekNumber: Int) -> Date? {
        guard let currentWeekNumber, let currentWeekday = currentStudyWeekday else {
            return nil
        }

        let weekDelta = selectedWeekNumber - currentWeekNumber
        let dayDelta = weekday.displayIndex - currentWeekday.displayIndex
        let totalDays = weekDelta * 7 + dayDelta
        return Calendar.current.date(byAdding: .day, value: totalDays, to: Date())
    }

    private static let dayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter
    }()
}

extension StudyWeekFilter {
    var localizedTitle: String {
        switch self {
        case .all:
            return NSLocalizedString("services_schedule_week_all", comment: "")
        case .week(let value):
            return String(format: NSLocalizedString("services_schedule_week_number", comment: ""), value)
        }
    }
}

extension ScheduleServiceViewModel {
    var accountGroupName: String? {
        authService.currentUser?.education.group.nilIfBlank
    }

    var searchPlaceholder: String {
        switch mode {
        case .group:
            return NSLocalizedString("services_schedule_group_placeholder", comment: "")
        case .teacher:
            return NSLocalizedString("services_schedule_teacher_placeholder", comment: "")
        }
    }

    var filteredGroups: [StudyGroup] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else {
            if let accountGroupName,
               let accountGroup = groups.first(where: { $0.name == accountGroupName }) {
                let withoutAccount = groups.filter { $0.name != accountGroupName }
                return [accountGroup] + Array(withoutAccount.prefix(29))
            }
            return Array(groups.prefix(30))
        }
        return groups.filter { group in
            group.name.localizedCaseInsensitiveContains(needle)
            || (group.specialityName?.localizedCaseInsensitiveContains(needle) ?? false)
        }
    }

    var filteredEmployees: [ScheduleEmployeeDirectoryEntry] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else {
            return Array(employees.prefix(8))
        }
        return employees.filter { employee in
            employee.displayName.localizedCaseInsensitiveContains(needle)
                || (employee.urlId?.localizedCaseInsensitiveContains(needle) ?? false)
        }
    }

    var weekFilters: [StudyWeekFilter] {
        let weeks = schedule?.availableWeekNumbers ?? []
        guard !weeks.isEmpty else { return [] }
        return [.all] + weeks.map { .week($0) }
    }

    var filteredDays: [StudyDaySchedule] {
        guard let schedule else { return [] }
        let dayItems = schedule.orderedDays
        switch weekFilter {
        case .all:
            return dayItems.compactMap { day in
                let filtered = day.lessons.filter(shouldKeepLesson)
                guard !filtered.isEmpty else { return nil }
                return StudyDaySchedule(weekday: day.weekday, lessons: filtered)
            }
        case .week(let number):
            return dayItems.compactMap { day in
                let filtered = day.lessons.filter {
                    ($0.weekNumbers.isEmpty || $0.weekNumbers.contains(number)) && shouldKeepLesson($0)
                }
                guard !filtered.isEmpty else { return nil }
                return StudyDaySchedule(weekday: day.weekday, lessons: filtered)
            }
        }
    }

    var filteredExams: [DisciplineSchedule] {
        guard let schedule else { return [] }
        switch weekFilter {
        case .all:
            return schedule.exams.filter(shouldKeepLesson)
        case .week(let number):
            return schedule.exams.filter { ($0.weekNumbers.isEmpty || $0.weekNumbers.contains(number)) && shouldKeepLesson($0) }
        }
    }

    var displayedDays: [StudyDaySchedule] {
        let days = filteredDays
        guard let currentWeekday = currentStudyWeekday else { return days }

        return days.sorted { lhs, rhs in
            let leftDistance = (lhs.weekday.displayIndex - currentWeekday.displayIndex + 7) % 7
            let rightDistance = (rhs.weekday.displayIndex - currentWeekday.displayIndex + 7) % 7
            return leftDistance < rightDistance
        }
    }

    var continuousDays: [StudyDaySchedule] {
        displayedDays
    }

    var subgroupFilters: [ScheduleSubgroupFilter] {
        guard let schedule else { return [.all] }
        let lessonSubgroups = schedule.orderedDays
            .flatMap(\.lessons)
            .map(\.subgroup)
        let examSubgroups = schedule.exams.map(\.subgroup)
        let allSubgroups = (lessonSubgroups + examSubgroups).filter { $0 > 0 }
        let unique = Array(Set(allSubgroups)).sorted()
        guard !unique.isEmpty else { return [.all] }
        return [.all] + unique.map { .subgroup($0) }
    }

    var showsSubgroupPicker: Bool {
        subgroupFilters.count > 1
    }

    var shouldShowWeekFilter: Bool {
        displayMode != .continuous && !weekFilters.isEmpty
    }

    var isCurrentModeEmpty: Bool {
        switch displayMode {
        case .continuous:
            return continuousTimelineDays.isEmpty
        case .byDay:
            return displayedDays.isEmpty
        case .exams:
            return filteredExams.isEmpty
        }
    }

    func dayTitle(for day: StudyDaySchedule) -> String {
        if let selectedWeek = selectedWeekNumber,
           let dayDate = date(for: day.weekday, selectedWeekNumber: selectedWeek) {
            let dateText = Self.dayDateFormatter.string(from: dayDate)
            let weekText = String(format: NSLocalizedString("services_schedule_week_number", comment: ""), selectedWeek)
            if Calendar.current.isDateInToday(dayDate) {
                return "\(NSLocalizedString("services_schedule_today_prefix", comment: "")), \(day.weekday.shortTitle), \(dateText), \(weekText)"
            }
            return "\(day.weekday.shortTitle), \(dateText), \(weekText)"
        }

        if case .week(let value) = weekFilter {
            let weekText = String(format: NSLocalizedString("services_schedule_week_number", comment: ""), value)
            return "\(day.weekday.rawValue), \(weekText)"
        }
        return day.weekday.rawValue
    }

    func continuousDayTitle(for day: ScheduleContinuousDay) -> String {
        let dateText = Self.dayDateFormatter.string(from: day.date)
        let weekText = String(format: NSLocalizedString("services_schedule_week_number", comment: ""), day.weekNumber)
        if Calendar.current.isDateInToday(day.date) {
            return "\(NSLocalizedString("services_schedule_today_prefix", comment: "")), \(day.weekday.shortTitle), \(dateText), \(weekText)"
        }
        return "\(day.weekday.shortTitle), \(dateText), \(weekText)"
    }

    func isLessonCurrent(
        _ lesson: DisciplineSchedule,
        on weekday: StudyWeekday,
        for date: Date? = nil,
        now: Date = Date()
    ) -> Bool {
        guard isCurrentContext(weekday: weekday, date: date, now: now) else { return false }
        let timelineDate = date ?? now
        guard let interval = lessonInterval(for: lesson, on: timelineDate) else { return false }
        return interval.start <= now && now <= interval.end
    }

    func currentLessonProgress(
        _ lesson: DisciplineSchedule,
        on weekday: StudyWeekday,
        for date: Date? = nil,
        now: Date = Date()
    ) -> Double? {
        guard isCurrentContext(weekday: weekday, date: date, now: now) else { return nil }
        let timelineDate = date ?? now
        guard let interval = lessonInterval(for: lesson, on: timelineDate) else { return nil }
        guard interval.start <= now, interval.end > interval.start else { return nil }
        guard now <= interval.end else { return nil }
        let all = interval.end.timeIntervalSince(interval.start)
        guard all > 0 else { return nil }
        return now.timeIntervalSince(interval.start) / all
    }

    var scheduleHeaderTitle: String {
        if let group = schedule?.group?.name, !group.isEmpty {
            return "Группа \(group)"
        }
        if let employee = schedule?.employee?.fullName, !employee.isEmpty {
            return employee
        }
        return NSLocalizedString("services_schedule_title", comment: "")
    }

    var scheduleHeaderSubtitle: String {
        var chunks: [String] = []
        if let period = periodText {
            chunks.append(period)
        }
        if let currentWeekNumber {
            chunks.append(String(format: NSLocalizedString("services_schedule_current_week", comment: ""), currentWeekNumber))
        }
        return chunks.isEmpty ? NSLocalizedString("services_schedule_subtitle", comment: "") : chunks.joined(separator: " • ")
    }
}

private extension ScheduleServiceViewModel {
    func isCurrentContext(weekday: StudyWeekday, date: Date?, now: Date) -> Bool {
        if let date {
            return Calendar.current.isDate(date, inSameDayAs: now)
        }

        guard let todayWeekday = currentStudyWeekday, todayWeekday == weekday else {
            return false
        }

        if case .week(let selectedWeek) = weekFilter,
           let currentWeekNumber,
           selectedWeek != currentWeekNumber {
            return false
        }

        return true
    }

    var periodText: String? {
        guard let schedule else { return nil }
        let rangeStart = schedule.startDate
        let rangeEnd = schedule.endDate
        guard let rangeStart, let rangeEnd else { return nil }
        return "\(Self.dateFormatter.string(from: rangeStart)) – \(Self.dateFormatter.string(from: rangeEnd))"
    }
}

private extension StudyWeekday {
    var displayIndex: Int {
        switch self {
        case .monday: return 0
        case .tuesday: return 1
        case .wednesday: return 2
        case .thursday: return 3
        case .friday: return 4
        case .saturday: return 5
        case .sunday: return 6
        }
    }
}

extension Optional where Wrapped == String {
    var nilIfBlank: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
