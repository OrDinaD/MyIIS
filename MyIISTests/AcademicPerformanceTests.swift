import XCTest
@testable import MyIIS

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

    func testBuildDeadlineItemsFromLessons() {
        let lessons: [PortalGradeBookLesson] = [
            PortalGradeBookLesson(
                id: 1,
                dateString: "10.09.2026",
                gradeBookOmissions: 0,
                isRespectfulOmission: false,
                lessonTypeId: 4,
                lessonTypeAbbrev: "ЛР",
                lessonNameAbbrev: "ОМО",
                lessonName: "Основы машинного обучения",
                subGroup: 0,
                marks: [8],
                markDetails: [PortalLessonMark(mark: 8, taskNumber: 1)],
                controlPoint: "10.09.2026",
                labCount: 4,
                deadline: "10.09.2026",
                deadlineOverdue: false,
                deadlineTaskNumber: 1
            ),
            PortalGradeBookLesson(
                id: 2,
                dateString: "24.09.2026",
                gradeBookOmissions: 0,
                isRespectfulOmission: false,
                lessonTypeId: 4,
                lessonTypeAbbrev: "ЛР",
                lessonNameAbbrev: "ОМО",
                lessonName: "Основы машинного обучения",
                subGroup: 0,
                marks: [],
                markDetails: [],
                controlPoint: "24.09.2026",
                labCount: 4,
                deadline: "24.09.2026",
                deadlineOverdue: true,
                deadlineTaskNumber: 2
            ),
            PortalGradeBookLesson(
                id: 3,
                dateString: "08.10.2026",
                gradeBookOmissions: 0,
                isRespectfulOmission: false,
                lessonTypeId: 4,
                lessonTypeAbbrev: "ЛР",
                lessonNameAbbrev: "ОМО",
                lessonName: "Основы машинного обучения",
                subGroup: 0,
                marks: [],
                markDetails: [],
                controlPoint: "08.10.2026",
                labCount: 4,
                deadline: "08.10.2026",
                deadlineOverdue: false,
                deadlineTaskNumber: 3
            )
        ]

        let items = RatingViewModel.buildDeadlineItems(from: lessons)
        XCTAssertEqual(items.count, 1)

        let omo = items[0]
        XCTAssertEqual(omo.discipline, "ОМО")
        XCTAssertEqual(omo.submitted, 1)
        XCTAssertEqual(omo.total, 4)
        XCTAssertEqual(omo.percent, 25)
        XCTAssertEqual(omo.nearestDeadline, "08.10.2026")
        XCTAssertEqual(omo.nearestDeadlineTaskNumber, 3)
        XCTAssertEqual(omo.overdueDeadlines.count, 1)
        XCTAssertEqual(omo.overdueDeadlines.first?.date, "24.09.2026")
        XCTAssertEqual(omo.overdueDeadlines.first?.taskNumber, 2)
    }

    func testBuildCheckpointSummaries() {
        let lessons: [PortalGradeBookLesson] = [
            PortalGradeBookLesson(
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
                controlPoint: "15.10.2026",
                labCount: nil,
                deadline: nil,
                deadlineOverdue: nil,
                deadlineTaskNumber: nil
            ),
            PortalGradeBookLesson(
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
                controlPoint: "15.11.2026",
                labCount: nil,
                deadline: nil,
                deadlineOverdue: nil,
                deadlineTaskNumber: nil
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

    func testPortalGradeBookLessonMixedMarksDecoding() throws {
        let jsonObjectMarks = """
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
        """.data(using: .utf8)!

        let lesson1 = try JSONDecoder().decode(PortalGradeBookLesson.self, from: jsonObjectMarks)
        XCTAssertEqual(lesson1.marks, [8, 9])
        XCTAssertEqual(lesson1.markDetails.count, 2)
        XCTAssertEqual(lesson1.markDetails[0].mark, 8)
        XCTAssertEqual(lesson1.markDetails[0].taskNumber, 1)
        XCTAssertEqual(lesson1.deadline, "15.09.2026")
        XCTAssertEqual(lesson1.labCount, 8)

        let jsonNumericMarks = """
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
        """.data(using: .utf8)!

        let lesson2 = try JSONDecoder().decode(PortalGradeBookLesson.self, from: jsonNumericMarks)
        XCTAssertEqual(lesson2.marks, [7, 6])
        XCTAssertEqual(lesson2.markDetails.count, 2)
        XCTAssertEqual(lesson2.markDetails[0].mark, 7)
        XCTAssertNil(lesson2.markDetails[0].taskNumber)
        XCTAssertNil(lesson2.deadline)
    }
}
