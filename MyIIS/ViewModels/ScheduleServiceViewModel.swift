import Foundation
import Observation

/// Owns observable schedule state. Behavior is grouped in focused extensions;
/// internal members are shared only within the app module.
@Observable
@MainActor
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
    var debouncedQuery = ""
    var groups: [StudyGroup] = []
    var employees: [ScheduleEmployeeDirectoryEntry] = []
    var schedule: PublicScheduleResponse? {
        didSet {
            timelineRevision = UUID()
            subjectSubgroups = Self.makeSubjectSubgroups(schedule)
            languageSubgroupOptions = subjectSubgroups.first { Self.isLanguageSubject($0.id) }?.options ?? []
        }
    }
    var selectedEmployee: ScheduleEmployeeDirectoryEntry?
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
    var subjectSubgroups: [ScheduleSubjectSubgroups] = []
    var subjectSubgroupTeacherIDs: [String: Int] = [:]
    static let subjectSubgroupDefaultsKey = "services.schedule.subjectSubgroups.group"
    var languageSubgroupOptions: [ScheduleLanguageSubgroup] = []
    var languageSubgroupTeacherID: Int? {
        didSet {
            if !isRestoringLanguageSubgroup, mode == .group, let activeGroupNumber {
                let key = Self.languageSubgroupDefaultsKey + "." + activeGroupNumber
                if let languageSubgroupTeacherID {
                    defaults.set(languageSubgroupTeacherID, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
            rebuildContinuousTimeline(reset: true)
            if let schedule {
                updateClassScheduleWidgetSnapshot(from: schedule)
                updateSessionScheduleWidgetSnapshot(from: schedule)
            }
        }
    }
    var isRestoringLanguageSubgroup = false
    static let languageSubgroupDefaultsKey = "services.schedule.languageSubgroup.group"

    var isLoading = false
    var isDownloadingReport = false
    var errorMessage: String?
    var noticeMessage: String?
    var isShowingStaleDataWarning = false
    var staleErrorMessage: String?
    var continuousTimelineDays: [ScheduleContinuousDay] = [] {
        didSet {
            updateContinuousDayPartitions()
        }
    }
    var pastContinuousDays: [ScheduleContinuousDay] = []
    var upcomingContinuousDays: [ScheduleContinuousDay] = []
    var pinnedGroupNames: [String] = []
    var pinnedGroupAliases: [String: String] = [:]
    var pinnedTeachers: [PinnedTeacher] = []
    var recentGroupNames: [String] = []
    var recentTeachers: [PinnedTeacher] = []

    let api: ServiceEndpointsAPI
    let authService: AuthenticationService
    let defaults: UserDefaults
    let usesSharedSnapshotCache: Bool
    var hasLoadedInitialData = false
    var activeGroupNumber: String?
    var shouldResetQueryOnModeChange = true
    var isDirectoryLoading = false
    var activeScheduleRequestID: UUID?
    var continuousCursorDate: Date?
    var isContinuousEndReached = false
    var isLoadingContinuousChunk = false
    var searchDebounceTask: Task<Void, Never>?
    var timelineGenerationTask: Task<Void, Never>?
    var timelineRevision = UUID()
    var localScheduleDocument: LocalScheduleDocument?

    static let displayModeDefaultsKey = "services.schedule.displayMode"
    private static let dataSourceDefaultsKey = "services.schedule.dataSource"
    static let subgroupFilterDefaultsKey = "services.schedule.subgroupFilter"
    static let subgroupFilterByGroupDefaultsKey = "services.schedule.subgroupFilter.group"
    static let selectedModeDefaultsKey = "services.schedule.selectedMode"
    static let lastGroupDefaultsKey = "services.schedule.lastGroup"
    static let lastTeacherURLIDDefaultsKey = "services.schedule.lastTeacherURLID"
    static let lastTeacherNameDefaultsKey = "services.schedule.lastTeacherName"
    static let pinnedGroupsDefaultsKey = "services.schedule.pinnedGroups"
    static let pinnedGroupAliasesDefaultsKey = "services.schedule.pinnedGroupAliases"
    static let pinnedTeachersDefaultsKey = "services.schedule.pinnedTeachers"
    static let recentGroupsDefaultsKey = "services.schedule.recentGroups"
    static let recentTeachersDefaultsKey = "services.schedule.recentTeachers"

    static var cachedSnapshot: Snapshot?

    struct Snapshot {
        let dataSource: ScheduleDataSource
        let accountGroupName: String?
        let mode: ScheduleLookupMode
        let query: String
        let schedule: PublicScheduleResponse
        let currentWeekNumber: Int?
        let weekFilter: StudyWeekFilter
        let displayMode: ScheduleDisplayMode
        let subgroupFilter: ScheduleSubgroupFilter
        let languageSubgroupTeacherID: Int?
        let subjectSubgroupTeacherIDs: [String: Int]
        let continuousTimelineDays: [ScheduleContinuousDay]
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

        if mode == .group,
           let lastGroup = self.defaults.string(forKey: Self.lastGroupDefaultsKey)?.nilIfBlank {
            activeGroupNumber = lastGroup
            subgroupFilter = restoredSubgroupFilter(for: lastGroup)
        }

        pinnedGroupNames = self.defaults.stringArray(forKey: Self.pinnedGroupsDefaultsKey) ?? []
        pinnedGroupAliases = self.defaults.dictionary(forKey: Self.pinnedGroupAliasesDefaultsKey) as? [String: String] ?? [:]
        recentGroupNames = self.defaults.stringArray(forKey: Self.recentGroupsDefaultsKey) ?? []
        pinnedTeachers = Self.loadStoredTeachers(forKey: Self.pinnedTeachersDefaultsKey, from: self.defaults)
        recentTeachers = Self.loadStoredTeachers(forKey: Self.recentTeachersDefaultsKey, from: self.defaults)

        if mode == .group, let lastGroup = self.defaults.string(forKey: Self.lastGroupDefaultsKey) {
            query = lastGroup
        } else if mode == .teacher, let lastTeacherName = self.defaults.string(forKey: Self.lastTeacherNameDefaultsKey) {
            query = lastTeacherName
        }

        debouncedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
