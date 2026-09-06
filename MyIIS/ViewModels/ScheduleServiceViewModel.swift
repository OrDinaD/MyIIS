//
//  ScheduleServiceViewModel.swift
//  MyIIS
//
// swiftlint:disable file_length
import Combine
import Foundation
import SwiftUI

public struct PinnedTeacher: Codable, Identifiable, Hashable, Sendable {
    public let urlId: String
    public let name: String
    public let photoLink: String?

    public var id: String { urlId }

    public init(urlId: String, name: String, photoLink: String? = nil) {
        self.urlId = urlId
        self.name = name
        self.photoLink = photoLink
    }
}

enum ScheduleLookupMode: String, CaseIterable, Identifiable {
    case group
    case teacher

    var id: String { rawValue }

    var title: String {
        switch self {
        case .group:
            return NSLocalizedString("services_schedule_mode_group", value: "Группа", comment: "")
        case .teacher:
            return NSLocalizedString("services_schedule_mode_teacher", value: "Преподаватель", comment: "")
        }
    }
}

enum ScheduleDisplayMode: String, CaseIterable, Identifiable {
    case continuous
    case byDay
    case exams

    var id: String { rawValue }

    var title: String {
        switch self {
        case .continuous:
            return NSLocalizedString("services_schedule_display_continuous", value: "Поток дней", comment: "")
        case .byDay:
            return NSLocalizedString("services_schedule_display_day", value: "По дням", comment: "")
        case .exams:
            return NSLocalizedString("services_schedule_display_exams", value: "Экзамены", comment: "")
        }
    }
}

enum ScheduleDataSource: String, CaseIterable, Identifiable {
    case api
    case localJSON

    var id: String { rawValue }

    var title: String {
        switch self {
        case .api:
            return NSLocalizedString("services_schedule_source_api", value: "ИИС БГУИР", comment: "")
        case .localJSON:
            return NSLocalizedString("services_schedule_source_local_json", value: "Локальный JSON", comment: "")
        }
    }
}

enum ScheduleSubgroupFilter: Hashable, Identifiable {
    case all
    case subgroup(Int)

    var id: String {
        switch self {
        case .all: return "all"
        case .subgroup(let value): return "subgroup_\(value)"
        }
    }

    var localizedTitle: String {
        switch self {
        case .all:
            return NSLocalizedString("services_schedule_subgroup_all", value: "Все подгруппы", comment: "")
        case .subgroup(let value):
            return String(format: NSLocalizedString("services_schedule_subgroup_format", value: "%d подгруппа", comment: ""), value)
        }
    }

    var shortTitle: String {
        switch self {
        case .all:
            return NSLocalizedString("services_schedule_subgroup_short_all", value: "Все", comment: "")
        case .subgroup(let value):
            return "\(value)"
        }
    }
}

struct ScheduleContinuousDay: Identifiable, Sendable {
    let date: Date
    let weekday: StudyWeekday
    let weekNumber: Int
    let lessons: [DisciplineSchedule]

    var id: String {
        "\(weekday.rawValue)|\(date.timeIntervalSince1970)|\(weekNumber)"
    }
}

struct ExamScheduleDay: Identifiable, Sendable {
    let date: Date
    let weekday: StudyWeekday?
    let lessons: [DisciplineSchedule]

    var id: String {
        "\(date.timeIntervalSince1970)"
    }
}

@Observable
@MainActor
// swiftlint:disable:next type_body_length
final class ScheduleServiceViewModel {
    var mode: ScheduleLookupMode = .group {
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
    var dataSource: ScheduleDataSource = .api {
        didSet {
            defaults.set(dataSource.rawValue, forKey: Self.dataSourceDefaultsKey)
        }
    }
    var query = "" {
        didSet { scheduleDebouncedSearchUpdate() }
    }
    private var debouncedQuery = ""
    var groups: [StudyGroup] = []
    var employees: [ScheduleEmployeeDirectoryEntry] = []
    var schedule: PublicScheduleResponse?
    private(set) var selectedEmployee: ScheduleEmployeeDirectoryEntry?
    var currentWeekNumber: Int?
    var weekFilter: StudyWeekFilter = .all
    var displayMode: ScheduleDisplayMode = .continuous {
        didSet { persistDisplayMode() }
    }
    var subgroupFilter: ScheduleSubgroupFilter = .all {
        didSet {
            persistSubgroupFilter()
            rebuildContinuousTimeline(reset: true)
            if let schedule {
                updateClassScheduleWidgetSnapshot(from: schedule)
                updateSessionScheduleWidgetSnapshot(from: schedule)
            }
        }
    }
    var isLoading = false
    var isDownloadingReport = false
    var errorMessage: String?
    var noticeMessage: String?
    private(set) var isShowingStaleDataWarning = false
    private(set) var staleErrorMessage: String?
    private(set) var continuousTimelineDays: [ScheduleContinuousDay] = [] {
        didSet {
            updateContinuousDayPartitions()
        }
    }
    private(set) var pastContinuousDays: [ScheduleContinuousDay] = []
    private(set) var upcomingContinuousDays: [ScheduleContinuousDay] = []
    private(set) var pinnedGroupNames: [String] = []
    private(set) var pinnedTeachers: [PinnedTeacher] = []
    private(set) var recentGroupNames: [String] = []
    private(set) var recentTeachers: [PinnedTeacher] = []

    private let api: ServiceEndpointsAPI
    private let authService: AuthenticationService
    private let defaults: UserDefaults
    private let usesSharedSnapshotCache: Bool
    private var hasLoadedInitialData = false
    private var shouldResetQueryOnModeChange = true
    private var isDirectoryLoading = false
    private var activeScheduleRequestID: UUID?
    private var continuousCursorDate: Date?
    private var isContinuousEndReached = false
    private var isLoadingContinuousChunk = false
    private var searchDebounceTask: Task<Void, Never>?
    private var timelineGenerationTask: Task<Void, Never>?
    private(set) var localScheduleDocument: LocalScheduleDocument?

    private static let displayModeDefaultsKey = "services.schedule.displayMode"
    private static let dataSourceDefaultsKey = "services.schedule.dataSource"
    private static let subgroupFilterDefaultsKey = "services.schedule.subgroupFilter"
    private static let selectedModeDefaultsKey = "services.schedule.selectedMode"
    private static let lastGroupDefaultsKey = "services.schedule.lastGroup"
    private static let lastTeacherURLIDDefaultsKey = "services.schedule.lastTeacherURLID"
    private static let lastTeacherNameDefaultsKey = "services.schedule.lastTeacherName"
    private static let pinnedGroupsDefaultsKey = "services.schedule.pinnedGroups"
    private static let pinnedTeachersDefaultsKey = "services.schedule.pinnedTeachers"
    private static let recentGroupsDefaultsKey = "services.schedule.recentGroups"
    private static let recentTeachersDefaultsKey = "services.schedule.recentTeachers"
    nonisolated private static let continuousChunkSizeDays = 28
    nonisolated private static let continuousFallbackHorizonDays = 120
    private static var cachedSnapshot: Snapshot?

    private struct Snapshot {
        let dataSource: ScheduleDataSource
        let accountGroupName: String?
        let mode: ScheduleLookupMode
        let query: String
        let schedule: PublicScheduleResponse
        let currentWeekNumber: Int?
        let weekFilter: StudyWeekFilter
        let displayMode: ScheduleDisplayMode
        let subgroupFilter: ScheduleSubgroupFilter
        let continuousTimelineDays: [ScheduleContinuousDay]
    }

    private struct TimelineBuildInput: Sendable {
        let orderedDays: [StudyDaySchedule]
        let startDate: Date?
        let endDate: Date?
        let selectedSubgroup: Int?
        let includesOtherSubgroups: Bool
    }

    private struct TimelineBuildResult: Sendable {
        let days: [ScheduleContinuousDay]
        let nextCursor: Date
        let reachedEnd: Bool
    }

    static func isPublicationPendingError(_ error: Error) -> Bool {
        guard let apiError = error as? APIError else { return false }
        switch apiError {
        case .serverError(_, let message), .serviceUnavailable(let message):
            return message.localizedCaseInsensitiveContains("формирование")
        default:
            return false
        }
    }

    init(
        api: ServiceEndpointsAPI? = nil,
        authService: AuthenticationService? = nil,
        defaults: UserDefaults? = nil
    ) {
        self.api = api ?? ServiceEndpointsAPI()
        self.authService = authService ?? .shared
        self.usesSharedSnapshotCache = defaults == nil
        self.defaults = defaults ?? (UserDefaults(suiteName: AppGroup.identifier) ?? .standard)

        if let modeRaw = self.defaults.string(forKey: Self.displayModeDefaultsKey),
           let restoredMode = ScheduleDisplayMode(rawValue: modeRaw) {
            displayMode = restoredMode
        }

        if let dataSourceRaw = self.defaults.string(forKey: Self.dataSourceDefaultsKey),
           let restoredDataSource = ScheduleDataSource(rawValue: dataSourceRaw) {
            // The retired fixture mode must never replace the user's real public schedule.
            dataSource = restoredDataSource == .localJSON ? .api : restoredDataSource
            if restoredDataSource == .localJSON {
                self.defaults.set(ScheduleDataSource.api.rawValue, forKey: Self.dataSourceDefaultsKey)
            }
        }

        if let selectedModeRaw = self.defaults.string(forKey: Self.selectedModeDefaultsKey),
           let selectedMode = ScheduleLookupMode(rawValue: selectedModeRaw) {
            mode = selectedMode
        }

        if let savedValue = self.defaults.object(forKey: Self.subgroupFilterDefaultsKey) as? Int {
            subgroupFilter = savedValue > 0 ? .subgroup(savedValue) : .all
        }

        pinnedGroupNames = self.defaults.stringArray(forKey: Self.pinnedGroupsDefaultsKey) ?? []
        recentGroupNames = self.defaults.stringArray(forKey: Self.recentGroupsDefaultsKey) ?? []
        pinnedTeachers = Self.loadStoredTeachers(forKey: Self.pinnedTeachersDefaultsKey, from: self.defaults)
        recentTeachers = Self.loadStoredTeachers(forKey: Self.recentTeachersDefaultsKey, from: self.defaults)

        if mode == .group, let lastGroup = self.defaults.string(forKey: Self.lastGroupDefaultsKey) {
            query = lastGroup
        } else if mode == .teacher, let lastTeacherName = self.defaults.string(forKey: Self.lastTeacherNameDefaultsKey) {
            query = lastTeacherName
        }

        if dataSource == .api {
            _ = applyCachedSnapshotIfAvailable()
        }
        debouncedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func loadStoredTeachers(forKey key: String, from defaults: UserDefaults) -> [PinnedTeacher] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([PinnedTeacher].self, from: data)) ?? []
    }

    private static func saveStoredTeachers(_ teachers: [PinnedTeacher], forKey key: String, in defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(teachers) {
            defaults.set(data, forKey: key)
        }
    }

    @discardableResult
    private func applyCachedSnapshotIfAvailable() -> Bool {
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

        if mode == .group,
           let savedValue = defaults.object(forKey: Self.subgroupFilterDefaultsKey) as? Int {
            subgroupFilter = savedValue > 0 ? .subgroup(savedValue) : .all
        } else if mode == .teacher {
            subgroupFilter = .all
        } else {
            subgroupFilter = snapshot.subgroupFilter
        }

        continuousTimelineDays = snapshot.continuousTimelineDays
        updateClassScheduleWidgetSnapshot(from: snapshot.schedule)
        updateSessionScheduleWidgetSnapshot(from: snapshot.schedule)
        hasLoadedInitialData = false
        return true
    }

    static func clearCachedSnapshot() {
        cachedSnapshot = nil
    }

    private func restorePersistedScheduleIfAvailable() {
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
        if let savedValue = defaults.object(forKey: Self.subgroupFilterDefaultsKey) as? Int {
            subgroupFilter = savedValue > 0 ? .subgroup(savedValue) : .all
        }
        sanitizeSubgroupFilter()
        rebuildContinuousTimeline(reset: true)
        setMode(.group, preservingQuery: groupNumber)
        saveSnapshot()
        errorMessage = nil
        updateClassScheduleWidgetSnapshot(from: scheduleResponse)
        updateSessionScheduleWidgetSnapshot(from: scheduleResponse)
    }

    private func scheduleDebouncedSearchUpdate() {
        searchDebounceTask?.cancel()
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchDebounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            debouncedQuery = value
        }
    }

    func loadInitialData() async {
        guard !hasLoadedInitialData else { return }
        if dataSource == .localJSON {
            loadLocalSchedule()
            hasLoadedInitialData = true
            return
        }

        await Task.yield()
        if schedule == nil {
            restorePersistedScheduleIfAvailable()
        }
        await loadDirectoryIfNeeded(force: false)

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

        hasLoadedInitialData = true
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

    private func handleScheduleLoadError(
        _ error: Error,
        fallbackSchedule: PublicScheduleResponse?,
        applyFallback: (PublicScheduleResponse) -> Void
    ) {
        if let fallbackSchedule {
            applyFallback(fallbackSchedule)
            staleErrorMessage = userFacingScheduleError(error)
            isShowingStaleDataWarning = true
            errorMessage = nil
            return
        }

        let technicalDescription = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        if isScheduleMissingMessage(technicalDescription) {
            errorMessage = NSLocalizedString("services_schedule_publication_pending", comment: "")
        } else {
            errorMessage = userFacingScheduleError(error)
        }
    }

    private func userFacingScheduleError(_ error: Error) -> String {
        if let urlError = (error as? APIError).flatMap({ apiError -> URLError? in
            guard case .networkError(let underlying) = apiError else { return nil }
            return underlying as? URLError
        }), urlError.code == .notConnectedToInternet {
            return NSLocalizedString(
                "schedule_error_offline",
                value: "Нет подключения к интернету. Сохранённое расписание будет доступно после первой успешной загрузки.",
                comment: ""
            )
        }

        return NSLocalizedString(
            "schedule_error_temporary",
            value: "Не удалось загрузить расписание. Проверьте подключение и попробуйте ещё раз.",
            comment: ""
        )
    }

    private func isScheduleMissingMessage(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("распис")
            || normalized.contains("schedule")
            || normalized.contains("расклад")
            || normalized.contains("розклад")
    }

    private func clearStaleDataWarning() {
        errorMessage = nil
        staleErrorMessage = nil
        isShowingStaleDataWarning = false
    }

    func openTeacherSchedule(_ teacher: DisciplineEmployee) async {
        if dataSource == .localJSON {
            applyLocalTeacherSchedule(teacher)
            return
        }
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

    func enableExamRemindersFromUserAction() async {
        guard let groupName = schedule?.group?.name.nilIfBlank ?? accountGroupName else {
            errorMessage = NSLocalizedString("services_schedule_report_group_missing", comment: "")
            return
        }
        let count = await ExamReminderNotificationService.shared.scheduleFromUserAction(
            exams: filteredExams,
            groupName: groupName
        )
        if count > 0 {
            noticeMessage = String(format: NSLocalizedString("services_schedule_reminders_enabled", comment: ""), count)
        } else {
            noticeMessage = NSLocalizedString("services_schedule_reminders_empty", comment: "")
        }
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

    // MARK: - Pinned & Recent Management

    func isGroupPinned(_ name: String) -> Bool {
        pinnedGroupNames.contains(name.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func togglePinnedGroup(_ group: StudyGroup) {
        togglePinnedGroupName(group.name)
    }

    func togglePinnedGroupName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if pinnedGroupNames.contains(trimmed) {
            pinnedGroupNames.removeAll { $0 == trimmed }
        } else {
            pinnedGroupNames.insert(trimmed, at: 0)
        }

        defaults.set(Array(pinnedGroupNames.prefix(12)), forKey: Self.pinnedGroupsDefaultsKey)
    }

    func isTeacherPinned(_ urlId: String) -> Bool {
        pinnedTeachers.contains(where: { $0.urlId == urlId })
    }

    func togglePinnedTeacher(_ employee: ScheduleEmployeeDirectoryEntry) {
        guard let urlId = employee.urlId, !urlId.isEmpty else { return }
        togglePinnedTeacher(PinnedTeacher(urlId: urlId, name: employee.displayName, photoLink: employee.photoLink))
    }

    func togglePinnedTeacher(_ teacher: PinnedTeacher) {
        if let idx = pinnedTeachers.firstIndex(where: { $0.urlId == teacher.urlId }) {
            pinnedTeachers.remove(at: idx)
        } else {
            pinnedTeachers.insert(teacher, at: 0)
        }
        pinnedTeachers = Array(pinnedTeachers.prefix(12))
        Self.saveStoredTeachers(pinnedTeachers, forKey: Self.pinnedTeachersDefaultsKey, in: defaults)
    }

    func recordRecentGroup(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recentGroupNames.removeAll { $0 == trimmed }
        recentGroupNames.insert(trimmed, at: 0)
        recentGroupNames = Array(recentGroupNames.prefix(6))
        defaults.set(recentGroupNames, forKey: Self.recentGroupsDefaultsKey)
    }

    func recordRecentTeacher(_ employee: ScheduleEmployeeDirectoryEntry) {
        guard let urlId = employee.urlId, !urlId.isEmpty else { return }
        let teacher = PinnedTeacher(urlId: urlId, name: employee.displayName, photoLink: employee.photoLink)
        recentTeachers.removeAll { $0.urlId == urlId }
        recentTeachers.insert(teacher, at: 0)
        recentTeachers = Array(recentTeachers.prefix(6))
        Self.saveStoredTeachers(recentTeachers, forKey: Self.recentTeachersDefaultsKey, in: defaults)
    }

    // MARK: - Apply Schedules

    func applyGroupSchedule(_ scheduleResponse: PublicScheduleResponse, week: Int?, groupNumber: String) {
        schedule = scheduleResponse
        currentWeekNumber = resolveCurrentWeekNumber(
            backendValue: week,
            termStartDate: scheduleResponse.startDate
        )
        preferExamDisplayIfNeeded(for: scheduleResponse)
        applyDefaultWeekFilter()
        setMode(.group, preservingQuery: groupNumber)
        if let savedValue = defaults.object(forKey: Self.subgroupFilterDefaultsKey) as? Int {
            subgroupFilter = savedValue > 0 ? .subgroup(savedValue) : .all
        }
        sanitizeSubgroupFilter()
        rebuildContinuousTimeline(reset: true)
        persistGroupSelection(groupNumber)
        saveSnapshot()
        errorMessage = nil
        updateClassScheduleWidgetSnapshot(from: scheduleResponse)
        updateSessionScheduleWidgetSnapshot(from: scheduleResponse)
        scheduleExamRemindersIfAuthorized()
    }

    private func applyEmployeeSchedule(
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

    func loadMoreContinuousDaysIfNeeded(lastVisibleDayID: String) {
        guard mode == .group || mode == .teacher else { return }
        guard displayMode == .continuous else { return }
        guard continuousTimelineDays.last?.id == lastVisibleDayID else { return }
        appendContinuousChunkIfNeeded()
    }

    /// Prepares the lazy timeline around a user-selected date and returns the
    /// closest day containing lessons so ScrollViewReader can reveal it without blocking the UI.
    func prepareContinuousTimeline(around requestedDate: Date) async -> String? {
        guard let input = timelineBuildInput() else { return nil }

        let calendar = Calendar.current
        let requestedDay = calendar.startOfDay(for: requestedDate)
        let lowerBound = input.startDate.map { calendar.startOfDay(for: $0) } ?? requestedDay
        let upperBound = Self.timelineEndBound(for: input, calendar: calendar, now: requestedDay)
        let targetDay = min(max(requestedDay, lowerBound), upperBound)
        let rangeStart = max(
            lowerBound,
            calendar.date(byAdding: .day, value: -3, to: targetDay) ?? targetDay
        )
        let rangeEnd = min(
            upperBound,
            calendar.date(
                byAdding: .day,
                value: Self.continuousChunkSizeDays,
                to: targetDay
            ) ?? targetDay
        )

        let result = await Task.detached(priority: .userInitiated) {
            Self.buildTimeline(
                input: input,
                from: rangeStart,
                through: rangeEnd
            )
        }.value
        guard !Task.isCancelled else { return nil }

        var merged = Dictionary(
            uniqueKeysWithValues: continuousTimelineDays.map { ($0.id, $0) }
        )
        for day in result.days {
            merged[day.id] = day
        }
        continuousTimelineDays = merged.values.sorted { $0.date < $1.date }

        return continuousTimelineDays.first(where: { $0.date >= targetDay })?.id
            ?? continuousTimelineDays.last?.id
    }

    private func rebuildContinuousTimeline(reset: Bool) {
        timelineGenerationTask?.cancel()
        isLoadingContinuousChunk = false
        if reset {
            continuousTimelineDays = []
            continuousCursorDate = nil
            isContinuousEndReached = false
        }
        appendContinuousChunkIfNeeded()
    }

    private func appendContinuousChunkIfNeeded() {
        guard let input = timelineBuildInput() else {
            continuousTimelineDays = []
            continuousCursorDate = nil
            isContinuousEndReached = false
            return
        }
        guard !isContinuousEndReached, !isLoadingContinuousChunk else { return }

        isLoadingContinuousChunk = true
        let cursor = continuousCursorDate
        let now = Date()
        timelineGenerationTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Self.buildTimelineChunk(
                    input: input,
                    cursor: cursor,
                    now: now
                )
            }.value
            guard let self, !Task.isCancelled else { return }

            self.continuousCursorDate = result.nextCursor
            self.isContinuousEndReached = result.reachedEnd
            self.isLoadingContinuousChunk = false
            if !result.days.isEmpty {
                self.continuousTimelineDays.append(contentsOf: result.days)
            }
            if let schedule = self.schedule {
                self.saveSnapshot()
                if cursor == nil {
                    self.updateClassScheduleWidgetSnapshot(from: schedule)
                }
            }
        }
    }

    private func timelineBuildInput() -> TimelineBuildInput? {
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
        return TimelineBuildInput(
            orderedDays: schedule.orderedDays,
            startDate: schedule.startDate,
            endDate: schedule.endDate,
            selectedSubgroup: selectedSubgroup,
            includesOtherSubgroups: display != .hidden
        )
    }

    nonisolated private static func buildTimelineChunk(
        input: TimelineBuildInput,
        cursor: Date?,
        now: Date
    ) -> TimelineBuildResult {
        let calendar = Calendar.current
        let startBound = input.startDate.map { calendar.startOfDay(for: $0) }
        let endBound = timelineEndBound(for: input, calendar: calendar, now: now)
        let initialStart = calendar.date(byAdding: .day, value: -2, to: now) ?? now
        let proposedStart = cursor ?? calendar.startOfDay(for: initialStart)
        let start = max(startBound ?? proposedStart, proposedStart)
        let proposedEnd = calendar.date(
            byAdding: .day,
            value: continuousChunkSizeDays - 1,
            to: start
        ) ?? start
        let end = min(proposedEnd, endBound)
        let result = buildTimeline(input: input, from: start, through: end)
        let nextCursor = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        return TimelineBuildResult(
            days: result.days,
            nextCursor: nextCursor,
            reachedEnd: nextCursor > endBound
        )
    }

    nonisolated private static func buildTimeline(
        input: TimelineBuildInput,
        from start: Date,
        through end: Date
    ) -> TimelineBuildResult {
        let calendar = Calendar.current
        let lessonsByWeekday = Dictionary(
            uniqueKeysWithValues: input.orderedDays.map { ($0.weekday, $0.lessons) }
        )
        var cursor = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        var generated: [ScheduleContinuousDay] = []

        while cursor <= endDay {
            if let weekday = timelineWeekday(for: cursor),
               let weekNumber = timelineWeekNumber(
                   on: cursor,
                   termStartDate: input.startDate
               ) {
                let lessons = (lessonsByWeekday[weekday] ?? []).filter { lesson in
                    let keepsSubgroup: Bool
                    if let selectedSubgroup = input.selectedSubgroup {
                        keepsSubgroup = lesson.subgroup == 0
                            || lesson.subgroup == selectedSubgroup
                            || input.includesOtherSubgroups
                    } else {
                        keepsSubgroup = true
                    }
                    let keepsWeek = lesson.weekNumbers.isEmpty
                        || lesson.weekNumbers.contains(weekNumber)
                    return keepsSubgroup
                        && keepsWeek
                        && isLessonScheduledOnContinuousDay(lesson, date: cursor)
                }
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
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? endDay.addingTimeInterval(1)
        }

        return TimelineBuildResult(
            days: generated,
            nextCursor: cursor,
            reachedEnd: cursor > endDay
        )
    }

    nonisolated private static func timelineEndBound(
        for input: TimelineBuildInput,
        calendar: Calendar,
        now: Date
    ) -> Date {
        let fallback = calendar.date(
            byAdding: .day,
            value: continuousFallbackHorizonDays,
            to: calendar.startOfDay(for: now)
        ) ?? now
        return input.endDate.map { calendar.startOfDay(for: $0) } ?? fallback
    }

    nonisolated private static func timelineWeekday(for date: Date) -> StudyWeekday? {
        switch Calendar.current.component(.weekday, from: date) {
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

    nonisolated private static func timelineWeekNumber(
        on date: Date,
        termStartDate: Date?
    ) -> Int? {
        if let termStartDate,
           let week = rotatingWeekNumber(
               on: date,
               termStartDate: termStartDate
           ) {
            return week
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ru_BY")
        let components = calendar.dateComponents([.month, .year], from: date)
        guard var septemberStart = calendar.date(
            from: DateComponents(year: components.year, month: 9, day: 1)
        ), let julyStart = calendar.date(
            from: DateComponents(year: components.year, month: 7, day: 1)
        ) else {
            return nil
        }
        if date < septemberStart,
           date < julyStart,
           let previousSeptember = calendar.date(
               byAdding: .year,
               value: -1,
               to: septemberStart
           ) {
            septemberStart = previousSeptember
        }
        guard let anchorWeek = startOfWeek(for: septemberStart, calendar: calendar),
              let targetWeek = startOfWeek(for: date, calendar: calendar),
              let distance = calendar.dateComponents(
                  [.weekOfYear],
                  from: anchorWeek,
                  to: targetWeek
              ).weekOfYear else {
            return nil
        }
        return (abs(distance) % 4) + 1
    }

    private func continuousEndBound(
        for schedule: PublicScheduleResponse,
        calendar: Calendar,
        now: Date
    ) -> Date {
        let fallback = calendar.date(
            byAdding: .day,
            value: Self.continuousFallbackHorizonDays,
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

    private func preferExamDisplayIfNeeded(for scheduleResponse: PublicScheduleResponse) {
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

    private func scheduleExamRemindersIfAuthorized() {
        guard let groupName = schedule?.group?.name.nilIfBlank else { return }
        let exams = filteredExams
        Task {
            await ExamReminderNotificationService.shared.scheduleIfAuthorized(
                exams: exams,
                groupName: groupName
            )
        }
    }

    private func updateClassScheduleWidgetSnapshot(from scheduleResponse: PublicScheduleResponse) {
        let resolvedName = scheduleResponse.group?.name.nilIfBlank
            ?? scheduleResponse.employee?.fullName.nilIfBlank
            ?? selectedEmployee?.displayName
            ?? query.nilIfBlank
        guard let groupName = resolvedName, !groupName.isEmpty else { return }
        if dataSource == .api, let accountGroupName, accountGroupName != groupName, scheduleResponse.employee == nil {
            return
        }

        let now = Date()
        var events = continuousTimelineDays
            .flatMap { day in
                day.lessons
                    .filter { shouldKeepLessonForWidget($0) }
                    .map { Self.widgetEvent(from: $0, on: day.date) }
            }
            .filter { $0.isUpcoming(at: now) }
            .sorted(by: Self.widgetEventSortingComparator)

        if events.isEmpty {
            var calendar = Calendar(identifier: .gregorian)
            calendar.firstWeekday = 2
            let today = calendar.startOfDay(for: now)
            let weekdayComponent = calendar.component(.weekday, from: today)
            let currentWeekdayOrdinal = (weekdayComponent + 5) % 7
            let mondayOfCurrentWeek = calendar.date(byAdding: .day, value: -currentWeekdayOrdinal, to: today) ?? today
            let referenceMonday = currentWeekdayOrdinal == 6
                ? (calendar.date(byAdding: .day, value: 7, to: mondayOfCurrentWeek) ?? mondayOfCurrentWeek)
                : mondayOfCurrentWeek

            var fallbackEvents: [SessionScheduleWidgetSnapshot.Event] = []
            for day in scheduleResponse.orderedDays {
                let dayOffset: Int
                switch day.weekday {
                case .monday: dayOffset = 0
                case .tuesday: dayOffset = 1
                case .wednesday: dayOffset = 2
                case .thursday: dayOffset = 3
                case .friday: dayOffset = 4
                case .saturday: dayOffset = 5
                case .sunday: dayOffset = 6
                }
                let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: referenceMonday) ?? today
                for lesson in day.lessons where shouldKeepLessonForWidget(lesson) {
                    let event = Self.widgetEvent(from: lesson, on: dayDate)
                    fallbackEvents.append(event)
                }
            }
            events = fallbackEvents.sorted(by: Self.widgetEventSortingComparator)
        }

        let snapshot = SessionScheduleWidgetSnapshot(
            groupName: groupName,
            startDate: scheduleResponse.startDate,
            endDate: scheduleResponse.endDate,
            events: Array(events.prefix(80)),
            updatedAt: Date()
        )
        ClassScheduleWidgetDataStore.save(snapshot)
        WatchScheduleConnectivityService.shared.activate()
        WatchScheduleConnectivityService.shared.send(snapshot)
    }

    private func shouldKeepLessonForWidget(_ lesson: DisciplineSchedule) -> Bool {
        guard case .subgroup(let value) = subgroupFilter else { return true }
        return lesson.subgroup == 0 || lesson.subgroup == value
    }

    private func updateSessionScheduleWidgetSnapshot(from scheduleResponse: PublicScheduleResponse) {
        let resolvedName = scheduleResponse.group?.name.nilIfBlank
            ?? scheduleResponse.employee?.fullName.nilIfBlank
            ?? selectedEmployee?.displayName
            ?? query.nilIfBlank
        guard let groupName = resolvedName, !groupName.isEmpty else { return }
        if dataSource == .api, let accountGroupName, accountGroupName != groupName, scheduleResponse.employee == nil {
            return
        }

        let now = Date()
        let events = scheduleResponse.exams
            .filter { shouldKeepLessonForWidget($0) }
            .sorted(by: Self.examSortingComparator)
            .map { Self.widgetEvent(from: $0, on: $0.lessonDate ?? $0.startLessonDate) }
            .filter { $0.isUpcoming(at: now) }

        let snapshot = SessionScheduleWidgetSnapshot(
            groupName: groupName,
            startDate: scheduleResponse.startExamsDate,
            endDate: scheduleResponse.endExamsDate,
            events: events,
            updatedAt: Date()
        )
        SessionScheduleWidgetDataStore.save(snapshot)
    }

    private static func widgetEvent(
        from lesson: DisciplineSchedule,
        on date: Date?
    ) -> SessionScheduleWidgetSnapshot.Event {
        let title = lesson.isAnnouncement
            ? lesson.title.replacingOccurrences(of: "📣 ", with: "")
            : (lesson.subject.nilIfBlank ?? lesson.title)
        let subtitle = [lesson.lessonTypeAbbrev.nilIfBlank, lesson.location.nilIfBlank, lesson.note.nilIfBlank]
            .compactMap { $0 }
            .joined(separator: ", ")
            .nilIfBlank
        return SessionScheduleWidgetSnapshot.Event(
            id: "\(lesson.id)|\(date?.timeIntervalSince1970 ?? 0)",
            date: date,
            startTime: lesson.startLessonTime,
            endTime: lesson.endLessonTime,
            title: title,
            subtitle: subtitle,
            location: lesson.location.nilIfBlank,
            lessonType: lesson.lessonTypeAbbrev.nilIfBlank,
            kind: widgetEventKind(for: lesson),
            subgroup: lesson.subgroup > 0 ? lesson.subgroup : nil
        )
    }

    private static func widgetEventSortingComparator(
        lhs: SessionScheduleWidgetSnapshot.Event,
        rhs: SessionScheduleWidgetSnapshot.Event
    ) -> Bool {
        let leftDate = lhs.interval()?.start ?? lhs.date ?? .distantFuture
        let rightDate = rhs.interval()?.start ?? rhs.date ?? .distantFuture
        if leftDate != rightDate {
            return leftDate < rightDate
        }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private static func widgetEventKind(for lesson: DisciplineSchedule) -> SessionScheduleWidgetEventKind {
        if lesson.isAnnouncement { return .announcement }
        let type = lesson.lessonTypeAbbrev.lowercased()
        if type.contains("экзам") { return .exam }
        if type.contains("конс") { return .consultation }
        return .other
    }

    private func applyDefaultWeekFilter() {
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

    private func loadDirectoryIfNeeded(force: Bool) async {
        let shouldLoadGroups = mode == .group && (groups.isEmpty || force)
        let shouldLoadEmployees = mode == .teacher && (employees.isEmpty || force)
        guard shouldLoadGroups || shouldLoadEmployees else {
            hasLoadedInitialData = true
            return
        }

        guard !isDirectoryLoading else { return }

        if shouldLoadGroups, let cachedGroups = api.cachedStudentGroups() {
            groups = cachedGroups.sorted { $0.name < $1.name }
        }
        if shouldLoadEmployees, let cachedEmployees = api.cachedEmployees() {
            employees = Self.filteredEmployeeDirectory(cachedEmployees)
        }

        isDirectoryLoading = true
        updateLoadingState()
        defer {
            isDirectoryLoading = false
            updateLoadingState()
            hasLoadedInitialData = true
        }

        do {
            if shouldLoadGroups {
                groups = try await api.fetchAllStudentGroups(preferCachedResponse: !force)
                    .sorted { $0.name < $1.name }
            }
            if shouldLoadEmployees {
                employees = Self.filteredEmployeeDirectory(
                    try await api.fetchAllEmployees(preferCachedResponse: !force)
                )
            }
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = userFacingScheduleError(error)
        }
    }

    private func updateLoadingState() {
        isLoading = isDirectoryLoading || activeScheduleRequestID != nil
    }

    private static func filteredEmployeeDirectory(
        _ entries: [ScheduleEmployeeDirectoryEntry]
    ) -> [ScheduleEmployeeDirectoryEntry] {
        entries
            .filter { ($0.urlId?.isEmpty == false) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private func sanitizeSubgroupFilter() {
        guard mode == .group else {
            subgroupFilter = .all
            return
        }
        if !subgroupFilters.contains(subgroupFilter) {
            subgroupFilter = .all
        }
    }

    func isOtherSubgroupLesson(_ lesson: DisciplineSchedule) -> Bool {
        guard case .subgroup(let selected) = subgroupFilter else { return false }
        return lesson.subgroup > 0 && lesson.subgroup != selected
    }

    func refreshSubgroupPresentation() {
        rebuildContinuousTimeline(reset: true)
    }

    private func shouldKeepLesson(_ lesson: DisciplineSchedule) -> Bool {
        guard case .subgroup(let value) = subgroupFilter else { return true }
        if lesson.subgroup == 0 || lesson.subgroup == value {
            return true
        }
        let raw = defaults.string(forKey: ScheduleDisplayPreferences.otherSubgroupDisplayKey)
        let display = raw.flatMap(ScheduleOtherSubgroupDisplay.init(rawValue:)) ?? .compact
        return display != .hidden
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
        guard mode == .group else { return }
        switch subgroupFilter {
        case .all:
            defaults.set(0, forKey: Self.subgroupFilterDefaultsKey)
        case .subgroup(let value):
            defaults.set(value, forKey: Self.subgroupFilterDefaultsKey)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let dayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("dMMMM")
        return formatter
    }()

    private static let examDayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("dMMMMyy")
        return formatter
    }()

    private static let examPeriodFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("dMMMMyyyy")
        return formatter
    }()

    private func resolveCurrentWeekNumber(
        backendValue: Int?,
        termStartDate: Date?,
        now: Date = Date()
    ) -> Int? {
        if let backendValue, (1 ... 4).contains(backendValue) {
            return backendValue
        }

        if let termStartDate,
           let calculated = Self.rotatingWeekNumber(
               on: now,
               termStartDate: termStartDate
           ) {
            return calculated
        }

        return universityWeekNumber(on: now)
    }

    private func timelineWeekNumber(on date: Date) -> Int? {
        if let termStartDate = schedule?.startDate,
           let weekNumber = Self.rotatingWeekNumber(
               on: date,
               termStartDate: termStartDate
           ) {
            return weekNumber
        }
        return universityWeekNumber(on: date)
    }

    nonisolated static func rotatingWeekNumber(
        on date: Date,
        termStartDate: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Int? {
        var academicCalendar = calendar
        academicCalendar.firstWeekday = 2
        academicCalendar.minimumDaysInFirstWeek = 4

        guard let startOfTermWeek = Self.startOfWeek(
            for: termStartDate,
            calendar: academicCalendar
        ),
        let startOfTargetWeek = Self.startOfWeek(
            for: date,
            calendar: academicCalendar
        ),
        let distance = academicCalendar.dateComponents(
            [.weekOfYear],
            from: startOfTermWeek,
            to: startOfTargetWeek
        ).weekOfYear,
        distance >= 0 else {
            return nil
        }

        return (distance % 4) + 1
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

        guard let startOfAnchorWeek = Self.startOfWeek(for: septemberStart, calendar: calendar),
              let startOfTargetWeek = Self.startOfWeek(for: date, calendar: calendar),
              let weeksDistance = calendar.dateComponents([.weekOfYear], from: startOfAnchorWeek, to: startOfTargetWeek).weekOfYear else {
            return nil
        }

        return (abs(weeksDistance) % 4) + 1
    }

    nonisolated private static func startOfWeek(for date: Date, calendar: Calendar) -> Date? {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components)
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

    private static func examSortingComparator(lhs: DisciplineSchedule, rhs: DisciplineSchedule) -> Bool {
        let leftDate = calendarDay(for: lhs) ?? Date.distantFuture
        let rightDate = calendarDay(for: rhs) ?? Date.distantFuture
        if leftDate != rightDate {
            return leftDate < rightDate
        }
        return DisciplineSchedule.sortingComparator(lhs: lhs, rhs: rhs)
    }

    private static func calendarDay(for exam: DisciplineSchedule) -> Date? {
        guard let date = exam.lessonDate ?? exam.startLessonDate else { return nil }
        return Calendar.current.startOfDay(for: date)
    }

    private func calendarDay(for exam: DisciplineSchedule) -> Date? {
        Self.calendarDay(for: exam)
    }

    private func saveSnapshot() {
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
            continuousTimelineDays: continuousTimelineDays
        )
    }

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

    private func loadLocalSchedule() {
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

extension StudyWeekFilter {
    var localizedTitle: String {
        switch self {
        case .all:
            return NSLocalizedString("services_schedule_subgroup_short_all", value: "Все", comment: "")
        case .week(let value):
            return "\(value)"
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
        let needle = debouncedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else {
            return prioritizedGroups(groups)
        }

        let normalizedNeedle = Self.normalizeSearchString(needle)
        let compactNeedle = normalizedNeedle.replacingOccurrences(of: " ", with: "")
        let scored = groups.compactMap { group -> (group: StudyGroup, rank: Int)? in
            let normalizedName = Self.normalizeSearchString(group.name)
            let compactName = normalizedName.replacingOccurrences(of: " ", with: "")
            let normalizedSpec = Self.normalizeSearchString(group.specialityName ?? "")

            let isExact = compactName == compactNeedle || normalizedName == normalizedNeedle
            let isPrefix = compactName.hasPrefix(compactNeedle) || normalizedName.hasPrefix(normalizedNeedle)
            let isSubstring = compactName.contains(compactNeedle) || normalizedName.contains(normalizedNeedle) || normalizedSpec.contains(normalizedNeedle)
            let isFuzzy = Self.isFuzzyMatch(needle: compactNeedle, text: compactName) || Self.isFuzzyMatch(needle: normalizedNeedle, text: normalizedName)

            guard isExact || isPrefix || isSubstring || isFuzzy else {
                return nil
            }

            var rank = 10
            if isExact {
                rank = 0
            } else if isPrefix {
                rank = group.name == accountGroupName ? 1 : (pinnedGroupNames.contains(group.name) ? 2 : 3)
            } else if isSubstring {
                rank = group.name == accountGroupName ? 4 : (pinnedGroupNames.contains(group.name) ? 5 : 6)
            } else if isFuzzy {
                rank = 7
            }

            return (group, rank)
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
                return lhs.group.name < rhs.group.name
            }
            .prefix(35)
            .map(\.group)
    }

    private func prioritizedGroups(_ source: [StudyGroup], limit: Int = 30) -> [StudyGroup] {
        var seen: Set<String> = []
        var result: [StudyGroup] = []

        func append(_ group: StudyGroup?) {
            guard let group, seen.insert(group.name).inserted else { return }
            result.append(group)
        }

        if let accountGroupName {
            append(source.first { $0.name == accountGroupName })
        }
        for name in pinnedGroupNames {
            append(source.first { $0.name == name })
        }
        for name in recentGroupNames {
            append(source.first { $0.name == name })
        }
        for group in source {
            append(group)
            if result.count >= limit { break }
        }
        return Array(result.prefix(limit))
    }

    var filteredEmployees: [ScheduleEmployeeDirectoryEntry] {
        let needle = debouncedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard needle.count >= 2 else {
            return recentAndPinnedEmployeeSuggestions
        }
        return matchingEmployees(for: needle, limit: 15)
    }

    var recentAndPinnedEmployeeSuggestions: [ScheduleEmployeeDirectoryEntry] {
        var result: [ScheduleEmployeeDirectoryEntry] = []
        var seen: Set<String> = []

        func append(urlId: String?, displayName: String) {
            guard let urlId, !urlId.isEmpty, seen.insert(urlId).inserted else { return }
            if let found = employees.first(where: { $0.urlId == urlId }) {
                result.append(found)
            } else {
                result.append(
                    ScheduleEmployeeDirectoryEntry(
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
                )
            }
        }

        for teacher in pinnedTeachers {
            append(urlId: teacher.urlId, displayName: teacher.name)
        }
        for teacher in recentTeachers {
            append(urlId: teacher.urlId, displayName: teacher.name)
        }
        if let lastUrlId = defaults.string(forKey: Self.lastTeacherURLIDDefaultsKey)?.nilIfBlank {
            let lastName = defaults.string(forKey: Self.lastTeacherNameDefaultsKey) ?? lastUrlId
            append(urlId: lastUrlId, displayName: lastName)
        }

        return Array(result.prefix(8))
    }

    private func matchingEmployees(for query: String, limit: Int) -> [ScheduleEmployeeDirectoryEntry] {
        let tokens = normalizedSearchTokens(from: query)
        guard !tokens.isEmpty else { return [] }

        let scored = employees.compactMap { employee -> (employee: ScheduleEmployeeDirectoryEntry, rank: Int)? in
            let normalizedFio = Self.normalizeSearchString(employee.displayName)
            let employeeTokens = Self.tokens(from: normalizedFio)

            // Exact match
            if tokens.count == 1 && (normalizedFio == tokens[0] || employee.urlId == tokens[0]) {
                return (employee, 0)
            }

            // All search tokens are prefixes of words in FIO
            let allTokensMatch = tokens.allSatisfy { token in
                employeeTokens.contains { $0.hasPrefix(token) }
            }
            if allTokensMatch {
                let rank = isTeacherPinned(employee.urlId ?? "") ? 1 : 2
                return (employee, rank)
            }

            // Any token substring match
            let substringMatch = tokens.allSatisfy { normalizedFio.contains($0) }
            if substringMatch {
                let rank = isTeacherPinned(employee.urlId ?? "") ? 3 : 4
                return (employee, rank)
            }

            // Fuzzy match
            if tokens.allSatisfy({ token in
                employeeTokens.contains { Self.isFuzzyMatch(needle: token, text: $0) }
            }) {
                return (employee, 5)
            }

            return nil
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
                return lhs.employee.displayName.localizedCaseInsensitiveCompare(rhs.employee.displayName) == .orderedAscending
            }
            .prefix(limit)
            .map(\.employee)
    }

    private func normalizedSearchTokens(from query: String) -> [String] {
        query
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: { $0.isWhitespace || $0 == "." || $0 == "," || $0 == "-" })
            .map(String.init)
            .map(Self.normalizeSearchString)
            .filter { !$0.isEmpty }
    }

    private static func normalizeSearchString(_ string: String) -> String {
        string
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func tokens(from string: String) -> [String] {
        string
            .split(whereSeparator: { $0.isWhitespace || $0 == "." || $0 == "," || $0 == "-" })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private static func isFuzzyMatch(needle: String, text: String) -> Bool {
        guard needle.count >= 3 else { return false }
        if text.contains(needle) { return true }
        let distance = levenshteinDistance(needle, String(text.prefix(needle.count + 1)))
        return distance <= 1
    }

    private static func levenshteinDistance(_ source: String, _ target: String) -> Int {
        let sourceChars = Array(source)
        let targetChars = Array(target)
        let sourceLength = sourceChars.count
        let targetLength = targetChars.count
        var distances = Array(repeating: Array(repeating: 0, count: targetLength + 1), count: sourceLength + 1)

        for sourceIndex in 0 ... sourceLength { distances[sourceIndex][0] = sourceIndex }
        for targetIndex in 0 ... targetLength { distances[0][targetIndex] = targetIndex }

        for sourceIndex in 1 ... sourceLength {
            for targetIndex in 1 ... targetLength {
                if sourceChars[sourceIndex - 1] == targetChars[targetIndex - 1] {
                    distances[sourceIndex][targetIndex] = distances[sourceIndex - 1][targetIndex - 1]
                } else {
                    let insertionCost = distances[sourceIndex][targetIndex - 1]
                    let deletionCost = distances[sourceIndex - 1][targetIndex]
                    let substitutionCost = distances[sourceIndex - 1][targetIndex - 1]
                    distances[sourceIndex][targetIndex] = 1 + min(insertionCost, deletionCost, substitutionCost)
                }
            }
        }
        return distances[sourceLength][targetLength]
    }

    var isTeacherSearchQueryTooShort: Bool {
        mode == .teacher
            && query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2
            && recentAndPinnedEmployeeSuggestions.isEmpty
    }

    var weekFilters: [StudyWeekFilter] {
        if isSchedulePublicationPending { return [] }
        let weeks = schedule?.availableWeekNumbers ?? []
        guard !weeks.isEmpty else { return [] }
        return [.all] + weeks.map { .week($0) }
    }

    var filteredDays: [StudyDaySchedule] {
        guard let schedule, !isSchedulePublicationPending else { return [] }
        let dayItems = schedule.orderedDays
        switch weekFilter {
        case .all:
            return dayItems.compactMap { (day: StudyDaySchedule) -> StudyDaySchedule? in
                let rawLessons = day.lessons.filter(shouldKeepLesson)
                guard !rawLessons.isEmpty else { return nil }

                // Aggregate duplicate pairs across the 4 academic weeks
                var aggregated: [DisciplineSchedule] = []
                var seenIndexByKey: [String: Int] = [:]

                for lesson in rawLessons {
                    let key = [
                        lesson.subject.nilIfBlank ?? lesson.title,
                        lesson.startLessonTime,
                        lesson.endLessonTime,
                        lesson.location,
                        lesson.lessonTypeAbbrev,
                        String(lesson.subgroup),
                        lesson.employees.map(\.fullName).joined(separator: ",")
                    ].joined(separator: "|")

                    if let existingIndex = seenIndexByKey[key] {
                        var existing = aggregated[existingIndex]
                        let mergedWeeks = Array(Set(existing.weekNumbers + lesson.weekNumbers)).sorted()
                        existing.weekNumbers = mergedWeeks
                        aggregated[existingIndex] = existing
                    } else {
                        seenIndexByKey[key] = aggregated.count
                        var newLesson = lesson
                        if newLesson.weekNumbers.isEmpty {
                            newLesson.weekNumbers = [1, 2, 3, 4]
                        }
                        aggregated.append(newLesson)
                    }
                }

                let sorted = aggregated.sorted { lhs, rhs in
                    if lhs.startLessonTime != rhs.startLessonTime {
                        return lhs.startLessonTime < rhs.startLessonTime
                    }
                    return lhs.subgroup < rhs.subgroup
                }

                return StudyDaySchedule(weekday: day.weekday, lessons: sorted)
            }
        case .week(let number):
            return dayItems.compactMap { (day: StudyDaySchedule) -> StudyDaySchedule? in
                let filtered = day.lessons.filter {
                    ($0.weekNumbers.isEmpty || $0.weekNumbers.contains(number)) && shouldKeepLesson($0)
                }
                guard !filtered.isEmpty else { return nil }
                return StudyDaySchedule(weekday: day.weekday, lessons: filtered)
            }
        }
    }

    static func weeksBadgeText(for lesson: DisciplineSchedule) -> String? {
        let weeks = lesson.weekNumbers.sorted()
        guard !weeks.isEmpty else { return nil }
        if weeks == [1, 2, 3, 4] {
            return "1–4 нед."
        }
        if weeks == [1, 3] {
            return "1, 3 нед."
        }
        if weeks == [2, 4] {
            return "2, 4 нед."
        }
        if weeks.count == 1 {
            return "\(weeks[0]) нед."
        }
        return weeks.map(String.init).joined(separator: ", ") + " нед."
    }

    var filteredExams: [DisciplineSchedule] {
        guard let schedule else { return [] }
        return schedule.exams
            .filter(shouldKeepLesson)
            .sorted(by: Self.examSortingComparator)
    }

    var examDays: [ExamScheduleDay] {
        let grouped = Dictionary(grouping: filteredExams) { exam in
            calendarDay(for: exam) ?? Date.distantFuture
        }
        return grouped.keys.sorted().map { date in
            ExamScheduleDay(
                date: date,
                weekday: studyWeekday(for: date),
                lessons: grouped[date, default: []].sorted(by: Self.examSortingComparator)
            )
        }
    }

    var pastExamDays: [ExamScheduleDay] {
        examDays.filter { day in
            day.lessons.allSatisfy { isExamPast($0, on: day.date) }
        }
    }

    var upcomingExamDays: [ExamScheduleDay] {
        examDays.filter { day in
            !day.lessons.allSatisfy { isExamPast($0, on: day.date) }
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

    private func updateContinuousDayPartitions() {
        var past: [ScheduleContinuousDay] = []
        var upcoming: [ScheduleContinuousDay] = []
        for day in continuousTimelineDays {
            if day.lessons.allSatisfy({ isExamPast($0, on: day.date) }) {
                past.append(day)
            } else {
                upcoming.append(day)
            }
        }
        self.pastContinuousDays = past
        self.upcomingContinuousDays = upcoming
    }

    var subgroupFilters: [ScheduleSubgroupFilter] {
        guard let schedule, !isSchedulePublicationPending else { return [.all] }
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
        mode != .teacher && displayMode != .exams && subgroupFilters.count > 1
    }

    var shouldShowWeekFilter: Bool {
        displayMode == .byDay && !weekFilters.isEmpty
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

    var currentModeEmptyTitle: String {
        if isSchedulePublicationPending {
            return NSLocalizedString("services_schedule_publication_pending_title", value: "Расписание составляется", comment: "")
        }
        if displayMode == .exams {
            return NSLocalizedString("services_schedule_exams_empty_title", value: "Экзаменов пока нет", comment: "")
        }
        return NSLocalizedString("services_schedule_empty_title", value: "Занятий нет", comment: "")
    }

    var currentModeEmptyText: String {
        if isSchedulePublicationPending {
            return NSLocalizedString("services_schedule_publication_pending", comment: "")
        }
        if displayMode == .exams {
            return NSLocalizedString("services_schedule_exams_empty_description", value: "В расписании экзамены и консультации пока не запланированы.", comment: "")
        }
        if displayMode == .continuous, isSchedulePastEnd {
            return NSLocalizedString("services_schedule_no_future_lessons", comment: "")
        }
        return NSLocalizedString("services_schedule_empty_week", comment: "")
    }

    var isSchedulePublicationPending: Bool {
        schedule?.isSchedulePublicationPending() == true
    }

    private var isSchedulePastEnd: Bool {
        guard let endDate = schedule?.endDate else { return false }
        let calendar = Calendar.current
        let endExclusive = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: endDate)
        ) ?? endDate
        return Date() >= endExclusive
    }

    func examDayTitle(for day: ExamScheduleDay) -> String {
        guard day.date != Date.distantFuture else {
            return NSLocalizedString("services_schedule_exams_no_date", comment: "")
        }

        let dateText = Self.examDayDateFormatter.string(from: day.date)
        let weekdayText = day.weekday?.shortTitle
        let prefix: String?
        if Calendar.current.isDateInToday(day.date) {
            prefix = NSLocalizedString("services_schedule_today_prefix", comment: "")
        } else if Calendar.current.isDateInTomorrow(day.date) {
            prefix = NSLocalizedString("services_schedule_tomorrow_prefix", comment: "")
        } else {
            prefix = nil
        }

        let chunks = [prefix, weekdayText, dateText].compactMap { $0?.nilIfBlank }
        return chunks.joined(separator: ", ")
    }

    func dayTitle(for day: StudyDaySchedule) -> String {
        day.weekday.localizedTitle
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

    func isExamPast(_ exam: DisciplineSchedule, on date: Date, now: Date = Date()) -> Bool {
        guard date != Date.distantFuture else { return false }
        if let interval = lessonInterval(for: exam, on: date) {
            return interval.end < now
        }

        let startOfDay = Calendar.current.startOfDay(for: date)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        return nextDay <= now
    }

    var scheduleHeaderTitle: String {
        if let group = schedule?.group?.name.nilIfBlank {
            return group
        }
        if let employee = schedule?.employee?.fullName.nilIfBlank {
            return employee
        }
        if let selectedEmployee {
            return selectedEmployee.displayName
        }
        return NSLocalizedString("services_schedule_title", comment: "")
    }

    var scheduleHeaderSubtitle: String? {
        if displayMode == .exams {
            let title = NSLocalizedString("services_schedule_exams_short", comment: "")
            if let examPeriodText {
                return "🎓 \(title) · \(examPeriodText)"
            }
            return "🎓 \(title)"
        }
        return nil
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

    var examPeriodText: String? {
        guard let schedule else { return nil }
        let rangeStart = schedule.startExamsDate
        let rangeEnd = schedule.endExamsDate
        guard let rangeStart, let rangeEnd else { return nil }
        return "\(Self.examPeriodFormatter.string(from: rangeStart)) – \(Self.examPeriodFormatter.string(from: rangeEnd))"
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
