@testable import MyIIS
import XCTest

@MainActor
final class PersonalRatingContractTests: XCTestCase {
    // Reduced, anonymized shape from Успеваемость.har (2026-09-26).
    private static let payload = """
    {
      "subjects": [{
        "id": 1, "abbrev": "Предмет", "name": "Учебный предмет",
        "lessonTypes": [{
          "id": 4, "abbrev": "ЛР", "termHoursId": 10,
          "lessons": [
            {"id": 100, "dateString": "10.09.2026", "gradebookOmissions": 2,
             "subGroup": 2, "marks": [{"mark": 8, "taskNumber": 1},
                                    {"mark": 9, "taskNumber": 2},
                                    {"mark": null, "taskNumber": 3}], "controlPoint": "01.10.2026"},
            {"id": 101, "dateString": "10.10.2026", "gradebookOmissions": 0,
             "subGroup": 2, "marks": [], "controlPoint": "01.11.2026"}
          ]
        }]
      }],
      "deadlines": [{"termHoursId": 10, "taskCount": 6,
                     "deadlines": [{"lessonId": 100, "taskNumber": 1},
                                   {"lessonId": 101, "taskNumber": 3}]}],
      "percentageMarks": []
    }
    """

    func testNestedSubjectsPreserveLessonMetadataMarksAndOmissions() throws {
        let response = try decode()
        let lessons = response.lessons
        XCTAssertEqual(response.subjects.count, 1)
        XCTAssertEqual(lessons.count, 2)
        XCTAssertEqual(lessons[0].lessonNameAbbrev, "Предмет")
        XCTAssertEqual(lessons[0].lessonName, "Учебный предмет")
        XCTAssertEqual(lessons[0].lessonTypeId, 4)
        XCTAssertEqual(lessons[0].lessonTypeAbbrev, "ЛР")
        XCTAssertEqual(lessons[0].marks, [8, 9])
        XCTAssertEqual(lessons[0].markDetails.compactMap(\.taskNumber), [1, 2])
        XCTAssertEqual(lessons[0].gradeBookOmissions, 2)
        XCTAssertEqual(lessons[0].dateString, "10.09.2026")
    }

    func testDeadlinesJoinByTermHoursAndLessonIDs() throws {
        let response = try decode()
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-26T12:00:00Z"))
        let items = RatingViewModel.buildDeadlineItems(from: response, now: now)
        let item = try XCTUnwrap(items.first)
        XCTAssertEqual(item.total, 6)
        XCTAssertEqual(item.submitted, 2, "Two submitted tasks in one lesson must both count")
        XCTAssertEqual(item.nearestDeadline, "10.10.2026")
        XCTAssertEqual(item.nearestDeadlineTaskNumber, 3)
        XCTAssertEqual(item.overdueDeadlines.map(\.date), ["10.09.2026"])
        XCTAssertFalse(item.deadlinesMissing)
    }

    func testEmptyDeadlinesKeepTaskCountAndMalformedDatesAreIgnored() throws {
        for date in ["31.02.2026", "00.09.2026", "10.13.2026", "10.09.999999"] {
            let payload = Self.payload
                .replacingOccurrences(of: "10.09.2026", with: date)
                .replacingOccurrences(of: "10.10.2026", with: date)
            let response = try JSONDecoder().decode(PersonalRatingResponse.self, from: Data(payload.utf8))
            let item = try XCTUnwrap(RatingViewModel.buildDeadlineItems(from: response).first)
            XCTAssertEqual(item.total, 6)
            XCTAssertTrue(item.deadlinesMissing)
            XCTAssertNil(item.nearestDeadline)
            XCTAssertTrue(item.overdueDeadlines.isEmpty)
        }
    }

    func testBrokenNestedLessonsThrowInsteadOfReturningEmptyRating() {
        let invalid = Self.payload.replacingOccurrences(of: #""marks": []"#, with: #""marks": {}"#)
        XCTAssertThrowsError(try JSONDecoder().decode(PersonalRatingResponse.self, from: Data(invalid.utf8)))
    }

    func testAPIRequestsOnlyPersonalRatingAndDecodesNewRoot() async throws {
        #if DEBUG
        let previousDemoMode = APIService.isDemoMode
        APIService.isDemoMode = false
        defer { APIService.isDemoMode = previousDemoMode }
        #endif
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        let payload = Data(Self.payload.utf8)
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/personal-rating")
            XCTAssertNil(request.url?.query)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil
            ))
            return (response, payload)
        }
        defer {
            session.invalidateAndCancel()
            MockURLProtocol.requestHandler = nil
        }

        let response = try await APIService(session: session).getPersonalRating()
        XCTAssertEqual(response.subjects.first?.lessonTypes.first?.termHoursId, 10)
        XCTAssertEqual(response.lessons.flatMap(\.marks), [8, 9])
        XCTAssertEqual(response.deadlines.first?.taskCount, 6)
    }

    private func decode() throws -> PersonalRatingResponse {
        try JSONDecoder().decode(PersonalRatingResponse.self, from: Data(Self.payload.utf8))
    }
}
