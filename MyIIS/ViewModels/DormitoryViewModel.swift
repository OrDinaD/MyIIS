import Combine
import Foundation

@MainActor
final class DormitoryViewModel: ObservableObject {
    @Published private(set) var applications: [DormitoryQueueApplication]
    @Published private(set) var privilegeRecords: [DormitoryPrivilegeRecord]
    @Published var isLoading: Bool
    @Published var errorMessage: String?

    private let dormitoryService: DormitoryServicing
    private var hasLoadedOnce: Bool

    init(
        dormitoryService: DormitoryServicing? = nil,
        initialApplications: [DormitoryQueueApplication] = [],
        initialPrivilegeRecords: [DormitoryPrivilegeRecord] = []
    ) {
        self.dormitoryService = dormitoryService ?? DormitoryService()
        self.applications = initialApplications
        self.privilegeRecords = initialPrivilegeRecords
        self.isLoading = false
        self.errorMessage = nil
        self.hasLoadedOnce = !initialApplications.isEmpty || !initialPrivilegeRecords.isEmpty
    }

    func loadIfNeeded() async {
        guard !hasLoadedOnce else { return }
        await loadData()
    }

    func reload() async {
        await loadData(force: true)
    }

    private func loadData(force: Bool = false) async {
        if !force && isLoading { return }

        isLoading = true
        errorMessage = nil

        do {
            async let fetchedApplications = dormitoryService.fetchApplications()
            async let fetchedPrivileges = dormitoryService.fetchPrivilegeRecords()

            let applications = try await fetchedApplications
            let privilegeRecords = try await fetchedPrivileges

            self.applications = applications.sorted {
                let lhs = $0.applicationDate ?? .distantPast
                let rhs = $1.applicationDate ?? .distantPast
                return lhs > rhs
            }

            self.privilegeRecords = privilegeRecords.sorted {
                if $0.year != $1.year { return $0.year > $1.year }
                return $0.dormitoryPrivilegeCategoryName < $1.dormitoryPrivilegeCategoryName
            }

            hasLoadedOnce = true
        } catch {
            if let error = error as? LocalizedError, let message = error.errorDescription {
                errorMessage = message
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }
}

#if DEBUG
extension DormitoryViewModel {
    static var preview: DormitoryViewModel {
        DormitoryViewModel(
            dormitoryService: DormitoryPreviewService(),
            initialApplications: DormitoryQueueApplication.preview,
            initialPrivilegeRecords: DormitoryPrivilegeRecord.preview
        )
    }
}
#endif
