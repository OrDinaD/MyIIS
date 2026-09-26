@testable import MyIIS
import XCTest

@MainActor
final class AcademicPerformanceTests: XCTestCase {

    func testDisciplineDeadlineItemPercentAndCompletion() {
        let item = DisciplineDeadlineItem(
            id: "САиИО",
            discipline: "САиИО",
            fullDisciplineName: "Системный анализ и исследование операций",
            submitted: 2,
            total: 8,
            nearestDeadline: "15.10.2026",
            nearestDeadlineTaskNumber: 3,
            nearestDeadlineOverdue: false,
            overdueDeadlines: [],
            deadlinesMissing: false
        )

        XCTAssertEqual(item.percent, 25)
        XCTAssertFalse(item.isCompleted)
        XCTAssertFalse(item.allSubmitted)

        let completedItem = DisciplineDeadlineItem(
            id: "ОМО",
            discipline: "ОМО",
            fullDisciplineName: "Основы машинного обучения",
            submitted: 4,
            total: 4,
            nearestDeadline: nil,
            nearestDeadlineTaskNumber: nil,
            nearestDeadlineOverdue: false,
            overdueDeadlines: [],
            deadlinesMissing: false
        )

        XCTAssertEqual(completedItem.percent, 100)
        XCTAssertTrue(completedItem.isCompleted)
        XCTAssertTrue(completedItem.allSubmitted)
        XCTAssertEqual(completedItem.urgencyStatus, .completed)
    }

    func testOverdueDeadlineItemDisplayTitle() {
        let overdueWithTask = OverdueDeadlineItem(date: "12.09.2026", taskNumber: 2)
        XCTAssertEqual(overdueWithTask.displayTitle, "12.09 (№ 2)")

        let overdueWithoutTask = OverdueDeadlineItem(date: "12.09.2026", taskNumber: nil)
        XCTAssertEqual(overdueWithoutTask.displayTitle, "12.09")
    }

    func testBuildCheckpointSummaries() {
        let lessons: [RatingLesson] = [
            RatingLesson(
                id: 1,
                dateString: "15.10.2026",
                gradeBookOmissions: 2,
                isRespectfulOmission: false,
                lessonTypeId: 2,
                lessonTypeAbbrev: "ПЗ",
                lessonNameAbbrev: "Фил",
                lessonName: "Философия",
                subGroup: 0,
                marks: [7, 8],
                markDetails: [],
                controlPoint: "15.10.2026"
            ),
            RatingLesson(
                id: 2,
                dateString: "15.11.2026",
                gradeBookOmissions: 0,
                isRespectfulOmission: false,
                lessonTypeId: 2,
                lessonTypeAbbrev: "ПЗ",
                lessonNameAbbrev: "Фил",
                lessonName: "Философия",
                subGroup: 0,
                marks: [9],
                markDetails: [],
                controlPoint: "15.11.2026"
            )
        ]

        let summaries = RatingViewModel.buildCheckpointSummaries(from: lessons)
        XCTAssertEqual(summaries.count, 3)

        let cp1 = summaries[0]
        XCTAssertEqual(cp1.number, 1)
        XCTAssertEqual(cp1.date, "15.10.2026")
        XCTAssertEqual(cp1.averageGrade, 7.5)
        XCTAssertNil(cp1.delta)
        XCTAssertEqual(cp1.absences, 2)

        let cp2 = summaries[1]
        XCTAssertEqual(cp2.number, 2)
        XCTAssertEqual(cp2.date, "15.11.2026")
        XCTAssertEqual(cp2.averageGrade, 9.0)
        XCTAssertEqual(cp2.delta, 1.5)
        XCTAssertEqual(cp2.absences, 0)

        let total = summaries[2]
        XCTAssertTrue(total.isTotal)
        XCTAssertEqual(total.date, "Итого")
        XCTAssertEqual(total.absences, 2)
        XCTAssertEqual(total.averageGrade, 8.0)
    }

    func testRatingLessonMixedMarksDecoding() throws {
        let jsonObjectMarks = Data("""
        {
            "id": 100,
            "date": "10.09.2026",
            "controlPoint": "10.09.2026",
            "gradeBookOmissions": 0,
            "isRespectfulOmission": false,
            "lessonName": "САиИО",
            "lessonNameAbbrev": "САиИО",
            "lessonType": "Лабораторная работа",
            "lessonTypeAbbrev": "ЛР",
            "lessonTypeId": 4,
            "marks": [
                {"mark": 8, "taskNumber": 1},
                {"mark": 9, "taskNumber": 2}
            ],
            "deadline": "15.09.2026",
            "deadlineOverdue": false,
            "deadlineTaskNumber": 3,
            "labCount": 8
        }
        """.utf8)

        let lesson1 = try JSONDecoder().decode(RatingLesson.self, from: jsonObjectMarks)
        XCTAssertEqual(lesson1.marks, [8, 9])
        XCTAssertEqual(lesson1.markDetails.count, 2)
        XCTAssertEqual(lesson1.markDetails[0].mark, 8)
        XCTAssertEqual(lesson1.markDetails[0].taskNumber, 1)

        let jsonNumericMarks = Data("""
        {
            "id": 101,
            "date": "12.09.2026",
            "controlPoint": "12.09.2026",
            "gradeBookOmissions": 2,
            "isRespectfulOmission": false,
            "lessonName": "Физика",
            "lessonNameAbbrev": "Физ",
            "lessonType": "Лабораторная работа",
            "lessonTypeAbbrev": "ЛР",
            "lessonTypeId": 4,
            "marks": [7, 6],
            "deadline": null,
            "labCount": null
        }
        """.utf8)

        let lesson2 = try JSONDecoder().decode(RatingLesson.self, from: jsonNumericMarks)
        XCTAssertEqual(lesson2.marks, [7, 6])
        XCTAssertEqual(lesson2.markDetails.count, 2)
        XCTAssertEqual(lesson2.markDetails[0].mark, 7)
        XCTAssertNil(lesson2.markDetails[0].taskNumber)
    }
}

@MainActor
final class RatingLoadingTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName = ""
    private var group = ""
    private var session: URLSession!
    private var api: RatingAPIStub!
    private var user: User!
    private var cacheKey: String { "RatingViewModel.snapshot.personal-rating.v1.\(group)|\(user.id)" }

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "RatingLoadingTests.\(UUID().uuidString)"
        group = suiteName
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        var payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(User.mock)) as? [String: Any]
        )
        var education = try XCTUnwrap(payload["education"] as? [String: Any])
        education["group"] = group
        payload["education"] = education
        user = try JSONDecoder().decode(User.self, from: JSONSerialization.data(withJSONObject: payload))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
        api = RatingAPIStub(session: session)
        MockURLProtocol.requestHandler = { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil
            ))
            return (response, Data("""
            {"schedules":{"Понедельник":[{"subject":"Расписание","lessonTypeAbbrev":"ЛК"}]}}
            """.utf8))
        }
    }

    override func tearDown() async throws {
        UserDefaultsPayloadStore.clear(forKey: cacheKey, from: defaults)
        ServiceEndpointsAPI.clearResponseCache(in: defaults)
        defaults.removePersistentDomain(forName: suiteName)
        session.invalidateAndCancel()
        MockURLProtocol.requestHandler = nil
        api = nil
        session = nil
        defaults = nil
        user = nil
        try await super.tearDown()
    }

    func testEmptyGradebookDoesNotInventSubjectsOrServerFailure() async {
        api.student = PersonalRatingResponse(lessons: [])
        let viewModel = makeViewModel()

        await viewModel.loadRating(for: user)

        XCTAssertTrue(viewModel.disciplines.isEmpty)
        XCTAssertTrue(viewModel.students.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isGradebookUnavailable)
        XCTAssertFalse(viewModel.isRatingPendingForNewSemester)
        XCTAssertNil(UserDefaultsPayloadStore.load(forKey: cacheKey, from: defaults))
    }

    func testNotFoundRemainsAnErrorAndNextLoadRecovers() async {
        api.failure = .serverError(statusCode: 404, message: "Not found")
        let viewModel = makeViewModel()
        await viewModel.loadRating(for: user)

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.isGradebookUnavailable)
        XCTAssertTrue(viewModel.disciplines.isEmpty)
        XCTAssertNil(UserDefaultsPayloadStore.load(forKey: cacheKey, from: defaults))

        api.failure = nil
        api.student = makeStudent(mark: 8)
        await viewModel.loadRating(for: user)

        XCTAssertEqual(api.requests, 2)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.gradebookAverage, 8)
        XCTAssertEqual(viewModel.disciplines.first?.name, "Математика")
    }

    func testCachedGradebookStillFetchesFreshMarks() async {
        api.student = makeStudent(mark: 7)
        await makeViewModel().loadRating(for: user)

        api.student = makeStudent(mark: 9)
        let relaunchedViewModel = makeViewModel()
        await relaunchedViewModel.loadRating(for: user)

        XCTAssertEqual(api.requests, 2)
        XCTAssertEqual(relaunchedViewModel.gradebookAverage, 9)
    }

    func testFailedRefreshPreservesLastSuccessfulSnapshotAndTimestamp() async throws {
        api.student = makeStudent(mark: 7)
        let viewModel = makeViewModel()
        await viewModel.loadRating(for: user)
        let saved = try XCTUnwrap(UserDefaultsPayloadStore.load(forKey: cacheKey, from: defaults))
        let updatedAt = viewModel.lastUpdateTime

        api.failure = .serverError(statusCode: 404, message: "Not found")
        await viewModel.loadRating(for: user)

        XCTAssertEqual(viewModel.gradebookAverage, 7)
        XCTAssertTrue(viewModel.isShowingStaleDataWarning)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.lastUpdateTime, updatedAt)
        XCTAssertEqual(UserDefaultsPayloadStore.load(forKey: cacheKey, from: defaults), saved)
    }

    func testEmptySuccessClearsPreviousMarksAndCache() async {
        api.student = makeStudent(mark: 8)
        let viewModel = makeViewModel()
        await viewModel.loadRating(for: user)

        api.student = PersonalRatingResponse(lessons: [])
        await viewModel.refresh(for: user)

        XCTAssertTrue(viewModel.disciplines.isEmpty)
        XCTAssertNil(viewModel.gradebookAverage)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(UserDefaultsPayloadStore.load(forKey: cacheKey, from: defaults))
    }

    func testUnauthorizedDoesNotRestoreCachedMarks() async {
        api.student = makeStudent(mark: 8)
        let viewModel = makeViewModel()
        await viewModel.loadRating(for: user)

        api.failure = .unauthorized(message: "Expired")
        await viewModel.refresh(for: user)

        XCTAssertTrue(viewModel.isUnauthorized)
        XCTAssertTrue(viewModel.disciplines.isEmpty)
        XCTAssertNil(viewModel.gradebookAverage)
        XCTAssertFalse(viewModel.isShowingStaleDataWarning)
    }

    func testLegacyScheduleSnapshotCannotMaskNetworkError() async throws {
        api.student = makeStudent(mark: 8)
        await makeViewModel().loadRating(for: user)
        let saved = try XCTUnwrap(UserDefaultsPayloadStore.load(forKey: cacheKey, from: defaults))
        var snapshot = try XCTUnwrap(JSONSerialization.jsonObject(with: saved) as? [String: Any])
        var disciplines = try XCTUnwrap(snapshot["disciplines"] as? [[String: Any]])
        disciplines[0]["code"] = "schedule_Математика"
        snapshot["disciplines"] = disciplines
        snapshot["students"] = []
        snapshot.removeValue(forKey: "gradebookAverage")
        UserDefaultsPayloadStore.save(
            try JSONSerialization.data(withJSONObject: snapshot), forKey: cacheKey, in: defaults
        )

        api.failure = .serverError(statusCode: 404, message: "Not found")
        let viewModel = makeViewModel()
        await viewModel.loadRating(for: user)

        XCTAssertEqual(api.requests, 2)
        XCTAssertTrue(viewModel.disciplines.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isShowingStaleDataWarning)
    }

    func testMalformedResponseIsNotDecodedAsEmptySuccess() throws {
        for json in [
            #"{"subjects":{},"deadlines":[],"percentageMarks":[]}"#,
            #"{"subjects":[null],"deadlines":[],"percentageMarks":[]}"#,
            #"{"subjects":null,"deadlines":[],"percentageMarks":[]}"#,
            #"{}"#
        ] {
            XCTAssertThrowsError(try JSONDecoder().decode(PersonalRatingResponse.self, from: Data(json.utf8)))
        }
        let empty = try JSONDecoder().decode(
            PersonalRatingResponse.self,
            from: Data(#"{"subjects":[],"deadlines":[],"percentageMarks":[]}"#.utf8)
        )
        XCTAssertTrue(empty.lessons.isEmpty)
    }

    private func makeViewModel() -> RatingViewModel {
        RatingViewModel(
            apiService: api,
            userDefaults: defaults,
            scheduleAPI: ServiceEndpointsAPI(session: session, userDefaults: defaults)
        )
    }

    private func makeStudent(mark: Int) -> PersonalRatingResponse {
        PersonalRatingResponse(lessons: [
            RatingLesson(
                id: 1, dateString: "25.09.2026", gradeBookOmissions: 2,
                isRespectfulOmission: false, lessonTypeId: 2, lessonTypeAbbrev: "ПЗ",
                lessonNameAbbrev: "Математика", subGroup: 0, marks: [mark],
                controlPoint: "25.09.2026"
            )
        ])
    }
}

@MainActor
private final class RatingAPIStub: APIService {
    var student = PersonalRatingResponse(lessons: [])
    var failure: APIError?
    private(set) var requests = 0

    override func getPersonalRating() async throws -> PersonalRatingResponse {
        requests += 1
        if let failure { throw failure }
        return student
    }
}
