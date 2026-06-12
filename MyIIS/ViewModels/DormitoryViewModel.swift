import Combine
import Foundation

@MainActor
final class DormitoryViewModel: ObservableObject {
    @Published private(set) var applications: [DormitoryQueueApplication]
    @Published private(set) var privilegeRecords: [DormitoryPrivilegeRecord]
    @Published private(set) var announcement: DormitoryAnnouncement?
    @Published var isLoading: Bool
    @Published var isSubmittingApplication: Bool
    @Published var isDownloadingFile: Bool
    @Published var errorMessage: String?
    @Published var actionErrorMessage: String?

    private let dormitoryService: DormitoryServicing
    private var hasLoadedOnce: Bool
    private static var cachedSnapshot: Snapshot?

    private struct Snapshot {
        let applications: [DormitoryQueueApplication]
        let privilegeRecords: [DormitoryPrivilegeRecord]
    }

    init(
        dormitoryService: DormitoryServicing? = nil,
        initialApplications: [DormitoryQueueApplication] = [],
        initialPrivilegeRecords: [DormitoryPrivilegeRecord] = [],
        announcementDate: Date = .now
    ) {
        self.dormitoryService = dormitoryService ?? DormitoryService()
        let resolvedApplications: [DormitoryQueueApplication]
        let resolvedPrivilegeRecords: [DormitoryPrivilegeRecord]
        if initialApplications.isEmpty,
           initialPrivilegeRecords.isEmpty,
           let cachedSnapshot = Self.cachedSnapshot {
            resolvedApplications = cachedSnapshot.applications
            resolvedPrivilegeRecords = cachedSnapshot.privilegeRecords
        } else {
            resolvedApplications = initialApplications
            resolvedPrivilegeRecords = initialPrivilegeRecords
        }
        self.applications = resolvedApplications
        self.privilegeRecords = resolvedPrivilegeRecords
        self.announcement = DormitoryAnnouncement.current(on: announcementDate)
        self.isLoading = false
        self.isSubmittingApplication = false
        self.isDownloadingFile = false
        self.errorMessage = nil
        self.actionErrorMessage = nil
        self.hasLoadedOnce = !resolvedApplications.isEmpty || !resolvedPrivilegeRecords.isEmpty
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
        guard !hasLoadedOnce else { return }
        await loadData()
    }

    func reload() async {
        announcement = DormitoryAnnouncement.current()
        await loadData(force: true)
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

    private func loadData(force: Bool = false) async {
        if !force && isLoading { return }

        isLoading = true
        errorMessage = nil

        do {
            let applications = try await dormitoryService.fetchApplications()
            let privilegeRecords = try await dormitoryService.fetchPrivilegeRecords()

            self.applications = sorted(applications)
            self.privilegeRecords = privilegeRecords.sorted {
                if $0.year != $1.year { return $0.year > $1.year }
                return $0.dormitoryPrivilegeCategoryName < $1.dormitoryPrivilegeCategoryName
            }

            hasLoadedOnce = true
            Self.cachedSnapshot = Snapshot(
                applications: self.applications,
                privilegeRecords: self.privilegeRecords
            )
        } catch {
            if let error = error as? LocalizedError, let message = error.errorDescription {
                errorMessage = message
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    private func upsert(_ application: DormitoryQueueApplication) {
        var updated = applications
        if let index = updated.firstIndex(where: { $0.id == application.id }) {
            updated[index] = application
        } else {
            updated.append(application)
        }
        applications = sorted(updated)
        Self.cachedSnapshot = Snapshot(
            applications: applications,
            privilegeRecords: privilegeRecords
        )
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
