@testable import MyIIS
import SwiftUI
import XCTest

@MainActor
final class DormitorySupportViewsTests: XCTestCase {

    func testDormitoryStatusTagTints() {
        let tag1 = DormitoryStatusTag(status: "Заселен")
        XCTAssertEqual(tag1.tint, .green)

        let tag2 = DormitoryStatusTag(status: " выселен ")
        XCTAssertEqual(tag2.tint, .orange)

        let tag3 = DormitoryStatusTag(status: "Отказано")
        XCTAssertEqual(tag3.tint, .red)

        let tag4 = DormitoryStatusTag(status: "Отклонено")
        XCTAssertEqual(tag4.tint, .red)

        let tag5 = DormitoryStatusTag(status: "В обработке")
        XCTAssertEqual(tag5.tint, .blue)
    }

    func testDormitoryAnnouncementHasStableIdentity() {
        let date = DateComponents(
            calendar: .current,
            year: 2026,
            month: 6,
            day: 5
        ).date!

        XCTAssertEqual(
            DormitoryAnnouncement.current(on: date),
            DormitoryAnnouncement.current(on: date)
        )
    }

    func testFreshSnapshotAvoidsUnnecessaryAutomaticReload() async {
        let defaults = makeIsolatedDefaults()
        defer { clear(defaults) }

        let writerService = DormitoryServiceMock(
            applications: DormitoryQueueApplication.preview,
            privilegeRecords: DormitoryPrivilegeRecord.preview
        )
        let writer = DormitoryViewModel(
            dormitoryService: writerService,
            userDefaults: defaults,
            automaticRefreshInterval: .infinity
        )
        await writer.reload()

        let readerService = DormitoryServiceMock()
        let reader = DormitoryViewModel(
            dormitoryService: readerService,
            userDefaults: defaults,
            automaticRefreshInterval: .infinity
        )

        XCTAssertEqual(
            reader.applications.map(\.id),
            DormitoryQueueApplication.preview.map(\.id)
        )
        XCTAssertEqual(
            reader.privilegeRecords.map(\.id).sorted(),
            DormitoryPrivilegeRecord.preview.map(\.id).sorted()
        )

        await reader.loadIfNeeded()

        XCTAssertEqual(readerService.fetchApplicationsCallCount, 0)
        XCTAssertEqual(readerService.fetchPrivilegeRecordsCallCount, 0)
    }

    func testStaleSnapshotRefreshesAutomatically() async {
        let defaults = makeIsolatedDefaults()
        defer { clear(defaults) }

        let writerService = DormitoryServiceMock(
            applications: DormitoryQueueApplication.preview,
            privilegeRecords: DormitoryPrivilegeRecord.preview
        )
        let writer = DormitoryViewModel(
            dormitoryService: writerService,
            userDefaults: defaults
        )
        await writer.reload()

        let refreshedApplications = Array(DormitoryQueueApplication.preview.prefix(1))
        let readerService = DormitoryServiceMock(applications: refreshedApplications)
        let reader = DormitoryViewModel(
            dormitoryService: readerService,
            userDefaults: defaults,
            automaticRefreshInterval: -1
        )

        await reader.loadIfNeeded()

        XCTAssertEqual(readerService.fetchApplicationsCallCount, 1)
        XCTAssertEqual(readerService.fetchPrivilegeRecordsCallCount, 1)
        XCTAssertEqual(reader.applications, refreshedApplications)
        XCTAssertFalse(reader.isShowingStaleDataWarning)
    }

    func testConcurrentReloadsShareSingleNetworkOperation() async {
        let service = DormitoryServiceMock(delayNanoseconds: 150_000_000)
        let viewModel = DormitoryViewModel(dormitoryService: service)

        let firstReload = Task { await viewModel.reload() }
        await Task.yield()
        let secondReload = Task { await viewModel.reload() }

        await firstReload.value
        await secondReload.value

        XCTAssertEqual(service.fetchApplicationsCallCount, 1)
        XCTAssertEqual(service.fetchPrivilegeRecordsCallCount, 1)
    }

    func testCancellationDoesNotBecomeStaleDataError() async {
        let service = DormitoryServiceMock(applicationsError: CancellationError())
        let viewModel = DormitoryViewModel(
            dormitoryService: service,
            initialApplications: DormitoryQueueApplication.preview,
            initialPrivilegeRecords: DormitoryPrivilegeRecord.preview
        )

        await viewModel.reload()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isShowingStaleDataWarning)
        XCTAssertEqual(viewModel.applications, DormitoryQueueApplication.preview)
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "DormitorySupportViewsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(suiteName, forKey: "testSuiteName")
        return defaults
    }

    private func clear(_ defaults: UserDefaults) {
        guard let suiteName = defaults.string(forKey: "testSuiteName") else { return }
        defaults.removePersistentDomain(forName: suiteName)
    }
}

private final class DormitoryServiceMock: DormitoryServicing {
    private(set) var fetchApplicationsCallCount = 0
    private(set) var fetchPrivilegeRecordsCallCount = 0

    private let applications: [DormitoryQueueApplication]
    private let privilegeRecords: [DormitoryPrivilegeRecord]
    private let applicationsError: Error?
    private let delayNanoseconds: UInt64

    init(
        applications: [DormitoryQueueApplication] = [],
        privilegeRecords: [DormitoryPrivilegeRecord] = [],
        applicationsError: Error? = nil,
        delayNanoseconds: UInt64 = 0
    ) {
        self.applications = applications
        self.privilegeRecords = privilegeRecords
        self.applicationsError = applicationsError
        self.delayNanoseconds = delayNanoseconds
    }

    func fetchApplications() async throws -> [DormitoryQueueApplication] {
        fetchApplicationsCallCount += 1
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        if let applicationsError {
            throw applicationsError
        }
        return applications
    }

    func fetchPrivilegeRecords() async throws -> [DormitoryPrivilegeRecord] {
        fetchPrivilegeRecordsCallCount += 1
        return privilegeRecords
    }

    func createApplication(documentURL: URL?) async throws -> DormitoryQueueApplication {
        DormitoryQueueApplication.preview[0]
    }

    func updateApplication(
        _ application: DormitoryQueueApplication,
        documentAction: DormitoryDocumentUpdateAction
    ) async throws -> DormitoryQueueApplication {
        application
    }

    func downloadDocument(forRequestID requestID: Int, suggestedFileName: String?) async throws -> URL {
        FileManager.default.temporaryDirectory
    }

    func downloadApplicationForm(forApplicationID applicationID: Int) async throws -> URL {
        FileManager.default.temporaryDirectory
    }
}
