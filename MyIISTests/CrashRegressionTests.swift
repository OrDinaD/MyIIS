@testable import MyIIS
import XCTest

@MainActor
final class CrashRegressionTests: XCTestCase {

    // MARK: - 1. AcademicChangeModels Duplicate Keys Regression Tests

    func testDuplicateOmissionItems_doesNotCrash_deduplicatesSafely() throws {
        // Construct JSON snapshots containing duplicate subject keys to test Dictionary deduplication
        let oldJson = """
        {
          "markbookItems": [],
          "ratingItems": [],
          "omissionItems": [
            { "subject": "Физика", "hours": 4 },
            { "subject": "Физика", "hours": 2 }
          ],
          "dormitoryItems": [],
          "penaltyItems": [],
          "certificateItems": [],
          "scheduleItems": [],
          "hasDormitoryBaseline": false,
          "hasPenaltiesBaseline": false,
          "hasCertificatesBaseline": false,
          "hasScheduleBaseline": false,
          "capturedAt": 0
        }
        """

        let newJson = """
        {
          "markbookItems": [],
          "ratingItems": [],
          "omissionItems": [
            { "subject": "Физика", "hours": 6 }
          ],
          "dormitoryItems": [],
          "penaltyItems": [],
          "certificateItems": [],
          "scheduleItems": [],
          "hasDormitoryBaseline": false,
          "hasPenaltiesBaseline": false,
          "hasCertificatesBaseline": false,
          "hasScheduleBaseline": false,
          "capturedAt": 100
        }
        """

        let decoder = JSONDecoder()
        let oldSnapshot = try decoder.decode(AcademicChangeSnapshot.self, from: Data(oldJson.utf8))
        let newSnapshot = try decoder.decode(AcademicChangeSnapshot.self, from: Data(newJson.utf8))

        // This must not trap/fatalError even with duplicate subjects in oldSnapshot
        let changes = newSnapshot.changes(since: oldSnapshot)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes.first?.subject, "Физика")
        XCTAssertEqual(changes.first?.value, "+4 ч")
    }

    func testDuplicateDormitoryItems_doesNotCrash_deduplicatesSafely() throws {
        let oldSnapshot = try makeDormitorySnapshot(status: "Документы приняты", roomInfo: "-", duplicateCount: 2)
        let newSnapshot = try makeDormitorySnapshot(status: "Заселён", roomInfo: "Комната 405", duplicateCount: 1)

        let settledIDs = newSnapshot.newlySettledDormitoryApplicationIDs(since: oldSnapshot)
        XCTAssertEqual(settledIDs, [101])
    }

    private func makeDormitorySnapshot(status: String, roomInfo: String, duplicateCount: Int) throws -> AcademicChangeSnapshot {
        var items: [[String: Any]] = []
        for _ in 0 ..< duplicateCount {
            items.append([
                "id": 101,
                "number": 1,
                "status": status,
                "queueText": "№12",
                "documentText": "Прикреплен",
                "acceptedDate": "12.08.2026",
                "settledDate": status == "Заселён" ? "20.08.2026" : "-",
                "rejectionReason": "-",
                "roomInfo": roomInfo
            ])
        }

        let dict: [String: Any] = [
            "markbookItems": [],
            "ratingItems": [],
            "omissionItems": [],
            "dormitoryItems": items,
            "penaltyItems": [],
            "certificateItems": [],
            "scheduleItems": [],
            "hasDormitoryBaseline": true,
            "hasPenaltiesBaseline": false,
            "hasCertificatesBaseline": false,
            "hasScheduleBaseline": false,
            "capturedAt": 0
        ]

        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(AcademicChangeSnapshot.self, from: data)
    }

    // MARK: - 2. HeadmanViewModel Duplicate Students Regression Test

    func testHeadmanWeeklySummary_withDuplicateStudentIDs_doesNotCrash() {
        let student1 = HeadmanStudent(id: 42, fio: "Иванов И.И.", username: "42", isResponsible: false)
        let studentDuplicate = HeadmanStudent(id: 42, fio: "Иванов И.И.", username: "42", isResponsible: false)

        let students = [student1, studentDuplicate]
        let summaries = HeadmanViewModel.buildWeeklySummary(students: students, lessons: [])

        XCTAssertEqual(summaries.count, 2)
        XCTAssertEqual(summaries.first?.id, 42)
    }

    // MARK: - 3. AttendanceWidgetDataStore Clear Regression Test

    func testAttendanceWidgetDataStore_clear_removesPayloadFileAndDefaults() {
        let snapshot = AttendanceWidgetSnapshot(
            monthTitle: "август",
            unexcusedHours: 12,
            updatedAt: Date()
        )

        AttendanceWidgetDataStore.save(snapshot)
        XCTAssertNotNil(AttendanceWidgetDataStore.loadSnapshot())

        AttendanceWidgetDataStore.clear()
        XCTAssertNil(AttendanceWidgetDataStore.loadSnapshot())
    }

    // MARK: - 4. Subgroup Filter Reset Test

    func testScheduleServiceViewModel_sanitizeSubgroupFilter_resetsWhenNoSubgroupsAvailable() {
        let suiteName = "CrashRegressionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let viewModel = ScheduleServiceViewModel(defaults: defaults)
        viewModel.schedule = PublicScheduleResponse(
            employee: nil,
            group: StudyGroup(
                name: "Test",
                facultyId: 1,
                facultyAbbrev: "ФИТУ",
                facultyName: "Факультет",
                specialityDepartmentEducationFormId: 1,
                specialityName: "Специальность",
                specialityAbbrev: "СП",
                course: 1,
                id: 1,
                calendarId: nil,
                educationDegree: 1
            ),
            exams: [],
            startDate: nil,
            endDate: nil,
            startExamsDate: nil,
            endExamsDate: nil,
            scheduleByWeekday: [:],
            previousScheduleByWeekday: [:],
            nextScheduleByWeekday: [:]
        )
        viewModel.subgroupFilter = .subgroup(2)

        // When schedule has no subgroup splits, subgroupFilters is [.all]
        XCTAssertEqual(viewModel.subgroupFilters, [.all])
    }

    // MARK: - 5. Keychain Credential Store Roundtrip Test

    func testCredentialStore_accessibleAfterFirstUnlock() throws {
        let store = CredentialStore.shared
        let testCreds = StoredCredentials(username: "test_user_\(UUID().uuidString)", password: "secure_password")

        do {
            try store.save(testCreds)
            let retrieved = try store.retrieve()
            XCTAssertEqual(retrieved?.username, testCreds.username)
            XCTAssertEqual(retrieved?.password, testCreds.password)

            try store.clear()
            let cleared = try store.retrieve()
            XCTAssertNil(cleared)
        } catch CredentialStoreError.unexpectedStatus(let status) where status == errSecMissingEntitlement {
            throw XCTSkip("Keychain entitlement not available in this test environment.")
        }
    }

    // MARK: - 6. DormitoryCardMotion Concurrency and Clamping Regression Tests

    func testDormitoryCardMotion_applyMotion_updatesValuesSafelyOnMainActor() {
        let motion = DormitoryCardMotion()
        XCTAssertEqual(motion.horizontal, 0.0)
        XCTAssertEqual(motion.vertical, 0.0)

        // Simulate roll and pitch updates
        motion.applyMotion(roll: 0.325, pitch: -0.325)
        XCTAssertEqual(motion.horizontal, 0.5, accuracy: 0.001)
        XCTAssertEqual(motion.vertical, -0.5, accuracy: 0.001)

        // Threshold check: small changes under 0.02 must not trigger mutation
        motion.applyMotion(roll: 0.326, pitch: -0.326)
        XCTAssertEqual(motion.horizontal, 0.5, accuracy: 0.001)
        XCTAssertEqual(motion.vertical, -0.5, accuracy: 0.001)

        // Stop resets values
        motion.stop()
        XCTAssertEqual(motion.horizontal, 0.0)
        XCTAssertEqual(motion.vertical, 0.0)
    }

    func testDormitoryCardMotion_clamped_boundsValues() {
        XCTAssertEqual(DormitoryCardMotion.clamped(-10.0), -1.0)
        XCTAssertEqual(DormitoryCardMotion.clamped(10.0), 1.0)
        XCTAssertEqual(DormitoryCardMotion.clamped(0.42), 0.42, accuracy: 0.0001)
    }

    func testDormitoryCardMotion_lifecycle_startStopDoesNotCrash() {
        let motion = DormitoryCardMotion()
        motion.start()
        motion.stop()
        XCTAssertEqual(motion.horizontal, 0.0)
        XCTAssertEqual(motion.vertical, 0.0)
    }
}
