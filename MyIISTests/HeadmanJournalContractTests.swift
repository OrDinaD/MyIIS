@testable import MyIIS
import XCTest

@MainActor
final class HeadmanJournalContractTests: XCTestCase {
    func testCapturedJournalShapePreservesNullAndSubgroupEligibility() throws {
        let json = """
        {
          "attendance": [
            {"studentId": 1, "subGroup": 1,
             "lessonRecords": {"10": null, "11": {"missedHours": 2, "respectfulOmission": true}}},
            {"studentId": 2, "subGroup": 2, "lessonRecords": {"10": null}}
          ],
          "lessons": [
            {"id": 10, "date": "2026-09-03", "subgroup": 1, "topic": null, "numberOfHours": 2},
            {"id": 11, "date": "2026-09-10", "subgroup": 0, "topic": "Тема", "numberOfHours": 2}
          ],
          "subgroupsCount": 2
        }
        """
        let data = try JSONDecoder().decode(HeadmanJournalData.self, from: Data(json.utf8))
        XCTAssertNil(data.record(studentID: 1, lessonID: 10))
        XCTAssertTrue(data.contains(studentID: 1, lesson: data.lessons[0]))
        XCTAssertFalse(data.contains(studentID: 2, lesson: data.lessons[0]))
        XCTAssertFalse(data.contains(studentID: 3, lesson: data.lessons[0]))
        XCTAssertEqual(data.record(studentID: 1, lessonID: 11)?.missedHours, 2)
        XCTAssertEqual(data.record(studentID: 1, lessonID: 11)?.respectfulOmission, true)
    }

    func testTopicFilterIncludesCommonLessonsAndKeepsSubgroupTopicsSeparate() {
        let data = HeadmanJournalData(attendance: [], lessons: [
            .init(id: 3, date: "2026-09-05", subgroup: 2, topic: "Вторая", numberOfHours: 2),
            .init(id: 1, date: "2026-09-03", subgroup: 0, topic: "Общая", numberOfHours: 2),
            .init(id: 2, date: "2026-09-04", subgroup: 1, topic: "Первая", numberOfHours: 2)
        ], subgroupsCount: 2)
        XCTAssertEqual(data.topicSubgroups, [1, 2])
        XCTAssertEqual(data.topicLessons(subgroup: 2).map(\.id), [1, 3])
        XCTAssertEqual(data.topicLessons(subgroup: 1).map(\.id), [1, 2])
        XCTAssertEqual(data.topicLessons(subgroup: 0).map(\.id), [1, 2, 3])
        XCTAssertEqual(data.topicLessons(subgroup: 2).last?.topic, "Вторая")
    }

    func testCapturedSubjectsDoNotRequireLegacySubgroupArray() throws {
        let json = """
        {"Предмет":[{"id":1,"hasSubGroups":true,"lessonTypeAbbrev":"ЛР",
        "teacherInfo":{"fullName":"Преподаватель","email":null}}]}
        """
        let subjects = try JSONDecoder().decode(
            [String: [HeadmanJournalSubject]].self, from: Data(json.utf8)
        )
        XCTAssertEqual(subjects["Предмет"]?.first?.hasSubGroups, true)
        XCTAssertNil(subjects["Предмет"]?.first?.teacherInfo?.email)
    }

    func testCreateResponseUsesStudentIDDictionaryRatherThanStudentArray() throws {
        let json = #"{"1":{"missedHours":2,"respectfulOmission":false}}"#
        let response = try JSONDecoder().decode([String: HeadmanOmission].self, from: Data(json.utf8))
        XCTAssertEqual(response["1"]?.missedHours, 2)
        XCTAssertEqual(response["1"]?.respectfulOmission, false)
        let request = HeadmanCreateOmissionRequest(
            studentOmissionsHoursDtoList: [HeadmanStudentOmissionHours(student: 1, hours: 2)], idLesson: 10
        )
        let body = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
        )
        XCTAssertEqual(body["idLesson"] as? Int, 10)
        XCTAssertNotNil(body["studentOmissionsHoursDtoList"])
    }
}
