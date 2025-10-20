import XCTest
@testable import MyIIS

@MainActor
final class StudyViewModelTests: XCTestCase {
    func testFilterSelectionAdjustsDaySchedulesAndSummaries() {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 30, to: start)

        let employee = DisciplineEmployee(
            id: 1,
            firstName: "Иван",
            middleName: "Иванович",
            lastName: "Петров",
            photoLink: nil,
            degree: nil,
            degreeAbbrev: nil,
            rank: nil,
            email: nil,
            urlId: nil,
            calendarId: nil,
            jobPositions: nil,
            isChief: nil
        )

        let mondayLecture = DisciplineSchedule(
            id: "math-lecture",
            auditories: ["101-1"],
            endLessonTime: "09:35",
            lessonTypeAbbrev: "ЛК",
            note: nil,
            subgroup: 0,
            startLessonTime: "08:00",
            studentGroups: [],
            subject: "МА",
            subjectFullName: "Математический анализ",
            weekNumbers: [1, 2],
            employees: [employee],
            lessonDate: start,
            startLessonDate: start,
            endLessonDate: end,
            isAnnouncement: false,
            isSplit: false
        )

        let mondayPractice = DisciplineSchedule(
            id: "math-practice",
            auditories: ["201-1"],
            endLessonTime: "11:10",
            lessonTypeAbbrev: "ПЗ",
            note: nil,
            subgroup: 0,
            startLessonTime: "09:45",
            studentGroups: [],
            subject: "МА",
            subjectFullName: "Математический анализ",
            weekNumbers: [2],
            employees: [employee],
            lessonDate: start,
            startLessonDate: start,
            endLessonDate: end,
            isAnnouncement: false,
            isSplit: false
        )

        let tuesdayLab = DisciplineSchedule(
            id: "prog-lab",
            auditories: ["305-1"],
            endLessonTime: "13:00",
            lessonTypeAbbrev: "ЛР",
            note: nil,
            subgroup: 0,
            startLessonTime: "11:30",
            studentGroups: [],
            subject: "ПРОГ",
            subjectFullName: "Программирование",
            weekNumbers: [2],
            employees: [employee],
            lessonDate: start,
            startLessonDate: start,
            endLessonDate: end,
            isAnnouncement: false,
            isSplit: false
        )

        let group = StudyGroup(
            name: "420603",
            facultyId: nil,
            facultyAbbrev: "ФИТУ",
            facultyName: nil,
            specialityDepartmentEducationFormId: nil,
            specialityName: "Системы управления",
            specialityAbbrev: "СУИ",
            course: 2,
            id: nil,
            calendarId: nil,
            educationDegree: 1
        )

        let plan = StudyPlan(
            startDate: start,
            endDate: end,
            startExamsDate: nil,
            endExamsDate: nil,
            group: group,
            schedule: [
                .monday: [mondayLecture, mondayPractice],
                .tuesday: [tuesdayLab]
            ]
        )

        let viewModel = StudyViewModel(service: StudyServiceMock(), initialPlan: plan)

        XCTAssertEqual(viewModel.availableFilters, [.all, .week(1), .week(2)])
        XCTAssertEqual(viewModel.daySchedules.count, 1)
        XCTAssertEqual(viewModel.daySchedules.first?.lessons.count, 1)

        viewModel.selectedFilter = .week(2)

        XCTAssertEqual(viewModel.daySchedules.count, 2)
        XCTAssertEqual(viewModel.daySchedules.first?.lessons.count, 2)
        XCTAssertEqual(viewModel.disciplineSummaries.count, 2)

        let mathSummary = viewModel.disciplineSummaries.first { $0.title.contains("Математ") }
        XCTAssertNotNil(mathSummary)
        XCTAssertTrue(mathSummary?.lessonTypes.contains("ЛК") ?? false)
        XCTAssertTrue(mathSummary?.lessonTypes.contains("ПЗ") ?? false)
    }
}

private struct StudyServiceMock: StudyServiceProtocol {
    func fetchStudyPlan(for group: String) async throws -> StudyPlan {
        throw APIError.serviceUnavailable(message: "Не использовать сетевой слой в тесте")
    }
}
