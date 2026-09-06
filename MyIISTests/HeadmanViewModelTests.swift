@testable import MyIIS
import XCTest

@MainActor
final class HeadmanViewModelTests: XCTestCase {

    var viewModel: HeadmanViewModel!
    var apiService: APIService!
    var authService: AuthenticationService!

    override func setUp() async throws {
        try await super.setUp()

        APIService.isDemoMode = false
        HeadmanViewModel.resetCachedSnapshotForTesting()
        clearResponseCache()

        authService = AuthenticationService(allowSessionRestore: false)
        authService.currentUser = nil
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        config.urlCache = nil
        apiService = APIService(session: URLSession(configuration: config))
        viewModel = HeadmanViewModel(apiService: apiService, authService: authService)
    }

    override func tearDown() async throws {
        viewModel = nil
        apiService = nil
        authService = nil
        MockURLProtocol.mockData = nil
        MockURLProtocol.mockResponse = nil
        MockURLProtocol.mockError = nil
        MockURLProtocol.requestHandler = nil
        APIService.isDemoMode = false
        HeadmanViewModel.resetCachedSnapshotForTesting()
        clearResponseCache()
        try await super.tearDown()
    }

    private func clearResponseCache() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("APIService.responseCache.") {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertEqual(viewModel.mode, .byDate)
        XCTAssertFalse(viewModel.isLoadingAccess)
        XCTAssertFalse(viewModel.hasAccess)
        XCTAssertFalse(viewModel.isGroupHead)
        XCTAssertTrue(viewModel.students.isEmpty)
    }

    // MARK: - Mode Titles

    func testModeTitles() {
        XCTAssertEqual(HeadmanViewModel.Mode.byDate.title, "Пропуски")
        XCTAssertEqual(HeadmanViewModel.Mode.summary.title, "Сводная")
        XCTAssertEqual(HeadmanViewModel.Mode.weekly.title, "Неделя")
        XCTAssertEqual(HeadmanViewModel.Mode.responsibles.title, "Отмечающие")
    }

    // MARK: - Date formatting logic

    func testSelectedWeekTitle() {
        let calendar = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.year = 2024
        comps.month = 4
        comps.day = 10 // Wednesday
        let date = calendar.date(from: comps)!
        viewModel.selectedWeekAnchorDate = date

        // weekStart for 2024-04-10 should be 2024-04-08 (Monday)
        // end should be 2024-04-13 (Saturday)
        // weekDayFormatter format is dd.MM
        XCTAssertEqual(viewModel.selectedWeekTitle, "08.04 - 13.04")
    }

    // MARK: - Data Load Access (Equivalence Partitioning)

    func testLoadInitialData_WhenFailed_DoesNotGrantAccess() async {
        MockURLProtocol.mockError = URLError(.notConnectedToInternet)

        await viewModel.loadInitialData()

        XCTAssertFalse(viewModel.hasAccess)
        XCTAssertFalse(viewModel.isGroupHead)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - Properties Logic

    func testAvailableSubgroups_WhenNoSubjectSelected_ReturnsEmpty() {
        viewModel.subjectOptions = []
        viewModel.selectedSubjectID = nil

        XCTAssertTrue(viewModel.availableSubgroups.isEmpty)
    }

    func testAvailableSubgroups_WhenSubjectSelected_ReturnsSortedSubgroups() {
        let lesson = HeadmanSubjectLesson(id: 1, lessonTypeAbbrev: "ЛК", subgroup: [2, 1, 3])
        let option = HeadmanSubjectOption(subjectName: "Test", lesson: lesson)

        viewModel.subjectOptions = [option]
        viewModel.selectedSubjectID = option.id

        XCTAssertEqual(viewModel.availableSubgroups, [1, 2, 3])
    }

    func testCanManageResponsibles_OnlyWhenGroupHead() {
        viewModel.isGroupHead = false
        XCTAssertFalse(viewModel.canManageResponsibles)

        viewModel.isGroupHead = true
        XCTAssertTrue(viewModel.canManageResponsibles)
    }

    // MARK: - API Logic

    func testLoadInitialData_Success() async {
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }

            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

            if url.path.contains("grade-book/is-group-head") {
                let data = Data("true".utf8)
                return (response, data)
            } else if url.path.contains("grade-book/who-can-note") {
                let data = Data("[1, 2]".utf8)
                return (response, data)
            } else if url.path.contains("grade-book/group-students") {
                let students = [HeadmanStudent(id: 1, fio: "Иванов Иван", username: "ivanov")]
                let data = try JSONEncoder().encode(students)
                return (response, data)
            } else if url.path.contains("grade-book/subjects") {
                let subjects: [String: [HeadmanSubjectLesson]] = [
                    "Math": [HeadmanSubjectLesson(id: 1, lessonTypeAbbrev: "ЛК", subgroup: [1])]
                ]
                let data = try JSONEncoder().encode(subjects)
                return (response, data)
            } else if url.path.contains("grade-book/by-date") {
                let data = Data("[]".utf8)
                return (response, data)
            } else if url.path.contains("grade-book/1/0") || url.path.contains("grade-book/weekly") {
                let data = Data("[]".utf8)
                return (response, data)
            }

            return (response, Data())
        }

        await viewModel.loadInitialData()

        XCTAssertTrue(viewModel.hasAccess)
        XCTAssertTrue(viewModel.isGroupHead)
        XCTAssertEqual(viewModel.students.count, 1)
        XCTAssertEqual(viewModel.subjectOptions.count, 1)
        XCTAssertEqual(viewModel.subjectOptions.first?.subjectName, "Math")
    }

    func testLoadLessonsForSelectedDate_Success() async {
        viewModel.hasAccess = true
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

            if url.path.contains("grade-book/by-date") {
                let json = """
                [
                    {
                        "id": 1,
                        "dateString": "2024-04-10",
                        "nameAbbrev": "Test Lesson",
                        "lessonTypeAbbrev": "ЛК",
                        "subGroup": 1,
                        "students": []
                    }
                ]
                """
                return (response, Data(json.utf8))
            }
            return (response, Data())
        }

        await viewModel.loadLessonsForSelectedDate()

        XCTAssertEqual(viewModel.lessonsByDate.count, 1)
        XCTAssertEqual(viewModel.lessonsByDate.first?.nameAbbrev, "Test Lesson")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoadSummary_Success() async {
        viewModel.hasAccess = true
        viewModel.selectedSubjectID = 1
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path.contains("grade-book/1/0") {
                let json = """
                [
                    {
                        "students": [
                            {
                                "id": 1,
                                "fio": "Петров Петр",
                                "subGroup": 1,
                                "subGroupStudent": 1,
                                "lessons": []
                            }
                        ]
                    }
                ]
                """
                return (response, Data(json.utf8))
            }
            return (response, Data())
        }

        await viewModel.loadSummary()

        XCTAssertEqual(viewModel.summaryStudents.count, 1)
        XCTAssertEqual(viewModel.summaryStudents.first?.fio, "Петров Петр")
        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - Actions

    func testSelectSubject() async {
        viewModel.subjectOptions = [
            HeadmanSubjectOption(subjectName: "Math", lesson: HeadmanSubjectLesson(id: 1, lessonTypeAbbrev: "ЛК", subgroup: [1, 2]))
        ]

        await viewModel.selectSubject(1)

        XCTAssertEqual(viewModel.selectedSubjectID, 1)
        XCTAssertEqual(viewModel.selectedSubgroup, 1) // first available
    }

    func testSelectSubgroup() async {
        await viewModel.selectSubgroup(2)
        XCTAssertEqual(viewModel.selectedSubgroup, 2)
    }

    func testPendingOmissions() {
        XCTAssertNil(viewModel.pendingHours(lessonId: 1, studentId: 1))

        viewModel.setPendingOmission(lessonId: 1, studentId: 1, hours: 2)
        XCTAssertEqual(viewModel.pendingHours(lessonId: 1, studentId: 1), 2)

        viewModel.setPendingOmission(lessonId: 1, studentId: 1, hours: nil)
        XCTAssertNil(viewModel.pendingHours(lessonId: 1, studentId: 1))
    }

    // MARK: - Errors and State

    func testLoadLessonsForSelectedDate_Failure() async {
        viewModel.hasAccess = true
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        await viewModel.loadLessonsForSelectedDate()
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testSaveOmissions_SuccessAndFailure() async {
        let lesson = HeadmanLesson(
            id: 1, dateString: "2024-04-10", nameAbbrev: "Test", lessonTypeAbbrev: "ЛК",
            lessonPeriod: nil, subGroup: 1, students: []
        )

        // Save empty shouldn't do anything
        await viewModel.saveOmissions(for: lesson)
        XCTAssertFalse(viewModel.isSaving)

        viewModel.setPendingOmission(lessonId: 1, studentId: 1, hours: 4)

        // Failure
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        await viewModel.saveOmissions(for: lesson)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertNotNil(viewModel.pendingHours(lessonId: 1, studentId: 1)) // Still pending

        // Success
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        await viewModel.saveOmissions(for: lesson)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.successMessage, "Пропуски сохранены.")
        XCTAssertNil(viewModel.pendingHours(lessonId: 1, studentId: 1)) // Cleared
    }

    func testSetResponsible_SuccessAndFailure() async {
        viewModel.isGroupHead = true
        let student = HeadmanStudent(id: 1, fio: "Иванов Иван", username: "ivanov")
        viewModel.students = [student]

        // Failure
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        await viewModel.setResponsible(true, for: student)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.responsibleStudentIDs.contains(1))

        // Success (Assign)
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        await viewModel.setResponsible(true, for: student)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.responsibleStudentIDs.contains(1))
        XCTAssertEqual(viewModel.students.first?.isResponsible, true)

        // Success (Remove)
        await viewModel.setResponsible(false, for: student)
        XCTAssertFalse(viewModel.responsibleStudentIDs.contains(1))
        XCTAssertEqual(viewModel.students.first?.isResponsible, false)
    }

    func testRefresh_CallsLoadInitialData() async {
        viewModel.hasAccess = false
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url!.path.contains("is-group-head") {
                return (response, Data("true".utf8))
            } else if request.url!.path.contains("who-can-note") {
                return (response, Data("[]".utf8))
            } else if request.url!.path.contains("group-students") {
                return (response, Data("[]".utf8))
            } else if request.url!.path.contains("subjects") {
                return (response, Data("{}".utf8))
            }
            return (response, Data())
        }

        await viewModel.refresh()
        XCTAssertTrue(viewModel.isGroupHead)
    }

    func testLoadWeeklySummary_Success() async {
        viewModel.hasAccess = true
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        await viewModel.selectWeekAnchorDate(Date())

        XCTAssertEqual(viewModel.weeklyStudents.count, 0)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoadInitialData_WhenNotGroupHeadAndNoResponsibles_GracefullyHasNoAccess() async {
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

            if url.path.contains("grade-book/is-group-head") {
                return (response, Data("false".utf8))
            } else if url.path.contains("grade-book/who-can-note") {
                return (response, Data("[]".utf8))
            } else if url.path.contains("grade-book/group-students") || url.path.contains("grade-book/subjects") {
                XCTFail("Should not request students or subjects when user has no headman access")
                let errorResponse = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (errorResponse, Data())
            }
            return (response, Data())
        }

        await viewModel.loadInitialData()

        XCTAssertFalse(viewModel.hasAccess)
        XCTAssertFalse(viewModel.isGroupHead)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.students.isEmpty)
        XCTAssertTrue(viewModel.subjectOptions.isEmpty)
    }
}
