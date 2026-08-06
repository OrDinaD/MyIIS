import Combine
import Foundation

struct DormitorySettlementReveal: Identifiable, Equatable {
    let application: DormitoryQueueApplication
    let isDemo: Bool

    var id: String {
        "\(application.id)-\(application.status)-\(isDemo)"
    }

    static let demo = DormitorySettlementReveal(
        application: DormitoryQueueApplication(
            id: 99_001,
            acceptedDate: Calendar.current.date(byAdding: .day, value: -18, to: .now),
            applicationDate: Calendar.current.date(byAdding: .day, value: -24, to: .now),
            settledDate: .now,
            status: DormitoryApplicationStatus.settled.rawValue,
            number: 703,
            numberInQueue: nil,
            docReference: nil,
            docContent: nil,
            rejectionReason: nil,
            roomInfo: "1302-а, Общ.4"
        ),
        isDemo: true
    )
}

@Observable
@MainActor
final class DormitoryViewModel {
    private(set) var applications: [DormitoryQueueApplication]
    private(set) var privilegeRecords: [DormitoryPrivilegeRecord]
    private(set) var announcement: DormitoryAnnouncement?
    var isLoading: Bool
    var isSubmittingApplication: Bool
    var isDownloadingFile: Bool
    var errorMessage: String?
    var actionErrorMessage: String?
    var lastUpdateTime: Date?
    var isShowingStaleDataWarning = false
    private(set) var settlementReveal: DormitorySettlementReveal?
    private(set) var pendingSettlementApplicationID: Int?

    private let dormitoryService: DormitoryServicing
    private let userDefaults: UserDefaults
    private let settlementRevealUserID: Int?
    private let automaticRefreshInterval: TimeInterval
    private var hasRequestedInitialRefresh = false
    private var activeLoadTask: Task<LoadPayload, Error>?
    private static let cachePrefix = "DormitoryViewModel.snapshot."

    private struct Snapshot: Codable {
        let applications: [DormitoryQueueApplication]
        let privilegeRecords: [DormitoryPrivilegeRecord]
        let lastUpdateTime: Date?
    }

    private struct LoadPayload {
        let applications: [DormitoryQueueApplication]
        let privilegeRecords: [DormitoryPrivilegeRecord]
    }

    init(
        dormitoryService: DormitoryServicing? = nil,
        initialApplications: [DormitoryQueueApplication] = [],
        initialPrivilegeRecords: [DormitoryPrivilegeRecord] = [],
        announcementDate: Date = .now,
        userDefaults: UserDefaults = .standard,
        automaticRefreshInterval: TimeInterval = 60
    ) {
        #if DEBUG
        self.dormitoryService = dormitoryService ?? (APIService.isDemoMode ? DormitoryPreviewService() : DormitoryService())
        #else
        self.dormitoryService = dormitoryService ?? DormitoryService()
        #endif
        self.userDefaults = userDefaults
        self.settlementRevealUserID = AuthenticationService.shared.currentUser?.id
        self.automaticRefreshInterval = automaticRefreshInterval
        let resolvedApplications: [DormitoryQueueApplication]
        let resolvedPrivilegeRecords: [DormitoryPrivilegeRecord]
        let resolvedLastUpdateTime: Date?
        if initialApplications.isEmpty,
           initialPrivilegeRecords.isEmpty,
           let cachedSnapshot = Self.restoreSnapshot(from: userDefaults) {
            resolvedApplications = cachedSnapshot.applications
            resolvedPrivilegeRecords = cachedSnapshot.privilegeRecords
            resolvedLastUpdateTime = cachedSnapshot.lastUpdateTime
        } else {
            resolvedApplications = initialApplications
            resolvedPrivilegeRecords = initialPrivilegeRecords
            resolvedLastUpdateTime = nil
        }
        self.applications = resolvedApplications
        self.privilegeRecords = resolvedPrivilegeRecords
        self.announcement = DormitoryAnnouncement.current(on: announcementDate)
        self.isLoading = false
        self.isSubmittingApplication = false
        self.isDownloadingFile = false
        self.errorMessage = nil
        self.actionErrorMessage = nil
        self.lastUpdateTime = resolvedLastUpdateTime
        self.settlementReveal = nil
        self.pendingSettlementApplicationID = DormitorySettlementRevealStore.pendingApplicationID(
            for: settlementRevealUserID,
            userDefaults: userDefaults
        )
    }

    var canCreateApplication: Bool {
        guard !isLoading, !isSubmittingApplication else { return false }

        let activeStatuses: Set<String> = [
            DormitoryApplicationStatus.waiting.rawValue,
            DormitoryApplicationStatus.documentsAccepted.rawValue,
            DormitoryApplicationStatus.readyToSettle.rawValue
        ]
        if applications.contains(where: { activeStatuses.contains($0.status) }) {
            return false
        }

        guard let settledApplication = applications.first(where: { $0.status == DormitoryApplicationStatus.settled.rawValue }) else {
            return true
        }

        guard let settledDate = settledApplication.settledDate else {
            return true
        }

        let now = Date()
        return isCurrentApplicationSeason(now) && !isCurrentApplicationSeason(settledDate, referenceYear: Calendar.current.component(.year, from: now))
    }

    func loadIfNeeded() async {
        refreshPendingSettlementRevealFromStore()

        guard !hasRequestedInitialRefresh else {
            if let activeLoadTask {
                _ = await activeLoadTask.result
            } else if pendingSettlementApplicationID != nil {
                await loadData()
            }
            return
        }

        hasRequestedInitialRefresh = true
        guard shouldRefreshAutomatically else { return }
        await loadData()
    }

    func reload() async {
        let currentAnnouncement = DormitoryAnnouncement.current()
        if announcement != currentAnnouncement {
            announcement = currentAnnouncement
        }
        await loadData()
    }

    func createApplication(documentURL: URL?) async -> Bool {
        guard !isSubmittingApplication else { return false }
        isSubmittingApplication = true
        actionErrorMessage = nil
        defer { isSubmittingApplication = false }

        do {
            let application = try await dormitoryService.createApplication(documentURL: documentURL)
            upsert(application)
            return true
        } catch {
            actionErrorMessage = displayMessage(for: error)
            return false
        }
    }

    func updateApplication(
        _ application: DormitoryQueueApplication,
        documentAction: DormitoryDocumentUpdateAction
    ) async -> Bool {
        guard !isSubmittingApplication else { return false }
        isSubmittingApplication = true
        actionErrorMessage = nil
        defer { isSubmittingApplication = false }

        do {
            let updatedApplication = try await dormitoryService.updateApplication(
                application,
                documentAction: documentAction
            )
            upsert(updatedApplication)
            return true
        } catch {
            actionErrorMessage = displayMessage(for: error)
            return false
        }
    }

    func downloadDocument(for application: DormitoryQueueApplication) async -> URL? {
        guard !isDownloadingFile else { return nil }
        isDownloadingFile = true
        actionErrorMessage = nil
        defer { isDownloadingFile = false }

        do {
            return try await dormitoryService.downloadDocument(
                forRequestID: application.id,
                suggestedFileName: application.docReference
            )
        } catch {
            actionErrorMessage = displayMessage(for: error)
            return nil
        }
    }

    func downloadApplicationForm(for application: DormitoryQueueApplication) async -> URL? {
        guard !isDownloadingFile else { return nil }
        isDownloadingFile = true
        actionErrorMessage = nil
        defer { isDownloadingFile = false }

        do {
            return try await dormitoryService.downloadApplicationForm(forApplicationID: application.id)
        } catch {
            actionErrorMessage = displayMessage(for: error)
            return nil
        }
    }

    private func loadData() async {
        if let activeLoadTask {
            _ = await activeLoadTask.result
            return
        }

        isLoading = true
        let service = dormitoryService
        let task = Task { @MainActor in
            async let asyncApps = service.fetchApplications()
            async let asyncPrivileges = service.fetchPrivilegeRecords()
            let applications = try await asyncApps
            let privilegeRecords = try await asyncPrivileges
            return LoadPayload(
                applications: applications,
                privilegeRecords: privilegeRecords
            )
        }
        activeLoadTask = task

        let result = await task.result
        activeLoadTask = nil
        isLoading = false

        switch result {
        case .success(let payload):
            let previousApplications = applications
            let loadedApplications = sorted(payload.applications)
            if let detectedReveal = Self.detectSettlementReveal(
                previous: previousApplications,
                current: loadedApplications
            ) {
                DormitorySettlementRevealStore.markPending(
                    applicationID: detectedReveal.application.id,
                    for: settlementRevealUserID,
                    userDefaults: userDefaults
                )
                pendingSettlementApplicationID = detectedReveal.application.id
            }
            applications = loadedApplications
            synchronizePendingSettlementReveal(with: loadedApplications)
            privilegeRecords = payload.privilegeRecords.sorted {
                if $0.year != $1.year { return $0.year > $1.year }
                return $0.dormitoryPrivilegeCategoryName < $1.dormitoryPrivilegeCategoryName
            }
            lastUpdateTime = Date()
            errorMessage = nil
            isShowingStaleDataWarning = false
            saveSnapshot()

        case .failure(let error):
            guard !isCancellation(error) else { return }
            errorMessage = displayMessage(for: error)
            isShowingStaleDataWarning = hasVisibleData
        }
    }

    private func upsert(_ application: DormitoryQueueApplication) {
        var updated = applications
        if let index = updated.firstIndex(where: { $0.id == application.id }) {
            updated[index] = application
        } else {
            updated.append(application)
        }
        applications = sorted(updated)
        lastUpdateTime = Date()
        errorMessage = nil
        isShowingStaleDataWarning = false
        saveSnapshot()
    }

    private var shouldRefreshAutomatically: Bool {
        guard pendingSettlementApplicationID == nil else { return true }
        guard hasVisibleData else { return true }
        guard let lastUpdateTime else { return true }
        return Date().timeIntervalSince(lastUpdateTime) >= automaticRefreshInterval
    }

    private var hasVisibleData: Bool {
        lastUpdateTime != nil || !applications.isEmpty || !privilegeRecords.isEmpty
    }

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return false
    }

    private func sorted(_ applications: [DormitoryQueueApplication]) -> [DormitoryQueueApplication] {
        applications.sorted {
            let lhs = $0.applicationDate ?? .distantPast
            let rhs = $1.applicationDate ?? .distantPast
            return lhs > rhs
        }
    }

    private func displayMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError, let message = localized.errorDescription {
            return message
        }
        return error.localizedDescription
    }

    private func saveSnapshot() {
        let snapshot = Snapshot(
            applications: applications,
            privilegeRecords: privilegeRecords,
            lastUpdateTime: lastUpdateTime ?? Date()
        )
        guard let payload = try? JSONEncoder().encode(snapshot) else { return }
        _ = UserDefaultsPayloadStore.save(payload, forKey: Self.cacheKey, in: userDefaults)
    }

    private static func restoreSnapshot(from userDefaults: UserDefaults) -> Snapshot? {
        guard let payload = UserDefaultsPayloadStore.load(forKey: cacheKey, from: userDefaults) else {
            return nil
        }
        return try? JSONDecoder().decode(Snapshot.self, from: payload)
    }

    private static var cacheKey: String {
        if let user = AuthenticationService.shared.currentUser {
            return cachePrefix + "user-\(user.id)"
        }
        return cachePrefix + "anonymous"
    }

    private func isCurrentApplicationSeason(_ date: Date, referenceYear: Int? = nil) -> Bool {
        let calendar = Calendar.current
        let year = referenceYear ?? calendar.component(.year, from: date)
        guard
            let start = calendar.date(from: DateComponents(year: year, month: 6, day: 1)),
            let end = calendar.date(from: DateComponents(year: year, month: 10, day: 31)),
            let day = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: date))
        else {
            return false
        }
        return day >= start && day <= end
    }
}

extension DormitoryViewModel {
    func isSettlementRevealPending(for application: DormitoryQueueApplication) -> Bool {
        pendingSettlementApplicationID == application.id &&
            application.presentationState == .settled &&
            application.placement != nil
    }

    func presentSettlementReveal(for application: DormitoryQueueApplication) {
        guard isSettlementRevealPending(for: application), settlementReveal == nil else { return }
        settlementReveal = DormitorySettlementReveal(
            application: application,
            isDemo: false
        )
    }

    func completeSettlementReveal() {
        guard let applicationID = settlementReveal?.application.id else { return }
        DormitorySettlementRevealStore.markRevealed(
            applicationID: applicationID,
            for: settlementRevealUserID,
            userDefaults: userDefaults
        )
        pendingSettlementApplicationID = nil
        settlementReveal = nil
    }

    func cancelSettlementReveal() {
        settlementReveal = nil
    }

    private func refreshPendingSettlementRevealFromStore() {
        pendingSettlementApplicationID = DormitorySettlementRevealStore.pendingApplicationID(
            for: settlementRevealUserID,
            userDefaults: userDefaults
        )
    }

    private func synchronizePendingSettlementReveal(
        with applications: [DormitoryQueueApplication]
    ) {
        guard let pendingSettlementApplicationID else { return }
        let isStillAvailable = applications.contains { application in
            application.id == pendingSettlementApplicationID &&
                application.presentationState == .settled &&
                application.placement != nil
        }
        guard !isStillAvailable else { return }

        DormitorySettlementRevealStore.clearPending(
            for: settlementRevealUserID,
            userDefaults: userDefaults
        )
        self.pendingSettlementApplicationID = nil
    }

    var currentPassData: DormitoryPassData {
        let user = AuthenticationService.shared.currentUser
        let roomInfoString = applications.first(where: { $0.roomInfo != nil })?.roomInfo

        let (dorm, room) = parseRoomInfo(roomInfoString)

        return DormitoryPassData(
            dormitoryNumber: dorm,
            roomNumber: room,
            lastName: (user?.lastName.isEmpty == false) ? user!.lastName : "Василевский",
            firstName: (user?.firstName.isEmpty == false) ? user!.firstName : "Владислав",
            middleName: (user?.middleName.isEmpty == false) ? user!.middleName : "Валерьевич",
            faculty: (user?.education.faculty.isEmpty == false) ? user!.education.faculty : "ФИТУ",
            group: (user?.education.group.isEmpty == false) ? user!.education.group : "428503",
            validUntil: "30.06.2025",
            photoURL: user?.photoURL
        )
    }

    private func parseRoomInfo(_ info: String?) -> (dormitory: String, room: String) {
        guard let info = info, !info.isEmpty else {
            return ("5", "401 - а")
        }
        var dorm = "5"
        var room = info

        if let dormMatch = info.range(of: "(?:Общ\\.|Общежитие №?\\s*)(\\d+)", options: .regularExpression) {
            let matchedStr = String(info[dormMatch])
            let extractedDigits = matchedStr.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if !extractedDigits.isEmpty {
                dorm = extractedDigits
            }
        }

        return (dorm, room)
    }
}

private extension DormitoryViewModel {
    static func detectSettlementReveal(
        previous: [DormitoryQueueApplication],
        current: [DormitoryQueueApplication]
    ) -> DormitorySettlementReveal? {
        let previousByID = Dictionary(
            previous.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        guard let settledApplication = current.first(where: { application in
            guard
                application.status == DormitoryApplicationStatus.settled.rawValue,
                !(application.roomInfo?.isEmpty ?? true),
                let previousApplication = previousByID[application.id]
            else {
                return false
            }

            return previousApplication.status == DormitoryApplicationStatus.documentsAccepted.rawValue
        }) else {
            return nil
        }

        return DormitorySettlementReveal(
            application: settledApplication,
            isDemo: false
        )
    }
}

#if DEBUG
extension DormitoryViewModel {
    static var preview: DormitoryViewModel {
        DormitoryViewModel(
            dormitoryService: DormitoryPreviewService(),
            initialApplications: DormitoryQueueApplication.preview,
            initialPrivilegeRecords: DormitoryPrivilegeRecord.preview,
            announcementDate: DateComponents(calendar: .current, year: 2026, month: 6, day: 5).date ?? .now
        )
    }
}
#endif
