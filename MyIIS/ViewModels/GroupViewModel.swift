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
    private var hasLoadedOnce = false

    init(
        apiService: APIService,
        authService: AuthenticationService
    ) {
        self.apiService = apiService
        self.authService = authService
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
        if hasLoadedOnce && !force { return }

        isLoading = true
        errorMessage = nil
        isShowingStaleDataWarning = false

        defer { isLoading = false }

        do {
            let response = try await apiService.getUserGroupInfo()
            groupInfo = response
            hasLoadedOnce = true
            lastUpdateTime = Date()
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

    private func resolveErrorMessage(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.localizedDescription
        }
        return "Не удалось загрузить данные группы"
    }
}
