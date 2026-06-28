import Combine
import Foundation

@MainActor
final class GroupViewModel: ObservableObject {
    @Published var groupInfo: UserGroupInfoResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdateTime: Date?
    @Published var isShowingStaleDataWarning = false
    @Published var isDownloadingReport = false
    @Published var downloadedReportURL: URL?

    private let apiService: APIService
    private let authService: AuthenticationService
    private let userDefaults: UserDefaults
    private var hasLoadedOnce = false
    private static let cachePrefix = "GroupViewModel.snapshot."
    private static let refreshInterval: TimeInterval = 7 * 24 * 60 * 60

    private struct Snapshot: Codable {
        let groupInfo: UserGroupInfoResponse
        let lastUpdateTime: Date?
    }

    init(
        apiService: APIService,
        authService: AuthenticationService,
        userDefaults: UserDefaults = .standard
    ) {
        self.apiService = apiService
        self.authService = authService
        self.userDefaults = userDefaults
        if let cachedSnapshot = restoreSnapshot() {
            groupInfo = cachedSnapshot.groupInfo
            lastUpdateTime = cachedSnapshot.lastUpdateTime
            hasLoadedOnce = true
        }
    }

    convenience init() {
        self.init(apiService: APIService(), authService: .shared)
    }

    var groupTitle: String {
        groupInfo?.numberOfGroup ?? authService.currentUser?.education.group ?? "—"
    }

    var studentsCount: Int {
        groupInfo?.groupInfoStudentDto.count ?? 0
    }

    var students: [GroupStudent] {
        groupInfo?.groupInfoStudentDto ?? []
    }

    var currentUserName: String? {
        authService.currentUser?.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func isCurrentUser(_ student: GroupStudent) -> Bool {
        guard let currentUserName, !currentUserName.isEmpty else { return false }
        return student.fio.compare(currentUserName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    func loadIfNeeded() async {
        await load(force: false)
    }

    func reload() async {
        await load(force: true)
    }

    func downloadGroupReport() async {
        if isDownloadingReport { return }
        isDownloadingReport = true
        defer { isDownloadingReport = false }

        do {
            downloadedReportURL = try await apiService.downloadGroupListReport()
        } catch {
            errorMessage = resolveErrorMessage(error)
        }
    }

    func logout() {
        authService.logout()
    }

    private func load(force: Bool) async {
        if isLoading { return }
        if hasLoadedOnce && !force && !shouldRefreshCachedGroup { return }

        isLoading = true
        errorMessage = nil
        isShowingStaleDataWarning = false

        defer { isLoading = false }

        do {
            let response = try await apiService.getUserGroupInfo()
            groupInfo = response
            hasLoadedOnce = true
            lastUpdateTime = Date()
            saveSnapshot(groupInfo: response)
        } catch {
            let resolved = resolveErrorMessage(error)
            if hasLoadedOnce {
                isShowingStaleDataWarning = true
                errorMessage = resolved
            } else {
                errorMessage = resolved
            }
        }
    }

    private var shouldRefreshCachedGroup: Bool {
        guard let lastUpdateTime else { return true }
        return Date().timeIntervalSince(lastUpdateTime) > Self.refreshInterval
    }

    private func saveSnapshot(groupInfo: UserGroupInfoResponse) {
        let snapshot = Snapshot(groupInfo: groupInfo, lastUpdateTime: lastUpdateTime ?? Date())
        guard let payload = try? JSONEncoder().encode(snapshot) else { return }
        _ = UserDefaultsPayloadStore.save(payload, forKey: cacheKey, in: userDefaults)
    }

    private func restoreSnapshot() -> Snapshot? {
        guard let payload = UserDefaultsPayloadStore.load(forKey: cacheKey, from: userDefaults) else {
            return nil
        }
        return try? JSONDecoder().decode(Snapshot.self, from: payload)
    }

    private var cacheKey: String {
        if let user = authService.currentUser {
            return Self.cachePrefix + "user-\(user.id)-\(user.education.group)"
        }
        return Self.cachePrefix + "anonymous"
    }

    private func resolveErrorMessage(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.localizedDescription
        }
        return "Не удалось загрузить данные группы"
    }
}
