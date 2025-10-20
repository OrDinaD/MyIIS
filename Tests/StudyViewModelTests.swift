import Foundation
@testable import MyIIS

struct TestFailure: Error {
    let message: String
}

@main
enum StudyViewModelTests {
    static func main() async {
        do {
            try await MainActor.run {
                try runTests()
            }
            print("StudyViewModel tests passed")
        } catch {
            fputs("StudyViewModel tests failed: \(error)\n", stderr)
            exit(1)
        }
    }

    @MainActor
    private static func runTests() throws {
        try testFilterSelection()
    }

    @MainActor
    private static func testFilterSelection() throws {
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

        let viewModel = StudyViewModel(initialPlan: plan)

        try assert(viewModel.availableFilters == [.all, .week(1), .week(2)], "Unexpected filters: \(viewModel.availableFilters)")
        try assert(viewModel.daySchedules.count == 1, "Week 1 should have one day of lessons")
        try assert(viewModel.daySchedules.first?.lessons.count == 1, "Week 1 should contain only lecture")

        viewModel.selectedFilter = .week(2)

        try assert(viewModel.daySchedules.count == 2, "Week 2 should include two days")
        try assert(viewModel.daySchedules.first?.lessons.count == 2, "Week 2 Monday should include two lessons")
        try assert(viewModel.disciplineSummaries.count == 2, "Should aggregate two disciplines")

        guard let mathSummary = viewModel.disciplineSummaries.first(where: { $0.title.contains("Математ") }) else {
            throw TestFailure(message: "Не найден сводный объект по математике")
        }

        try assert(mathSummary.lessonTypes.contains("ЛК"), "Должен содержать лекции")
        try assert(mathSummary.lessonTypes.contains("ПЗ"), "Должен содержать практики")
    }

    private static func assert(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String) throws {
        if !condition() {
            throw TestFailure(message: message())
        }
    }
}
