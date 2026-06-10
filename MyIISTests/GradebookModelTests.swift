@testable import MyIIS
import XCTest

@MainActor
final class GradebookModelTests: XCTestCase {
    func testAverageGradeUsesBestDisciplineGrades() {
        let gradebook = Gradebook(semesters: [
            GradebookSemester(
                number: 1,
                title: nil,
                year: nil,
                disciplines: [
                    GradebookDiscipline(
                        code: "MATH",
                        name: "Math",
                        controlForm: "Exam",
                        teacher: nil,
                        hours: nil,
                        attempts: [
                            GradeAttempt(attempt: 1, type: "EXAM", grade: .numeric(6), date: nil, status: .passed),
                            GradeAttempt(attempt: 2, type: "EXAM", grade: .numeric(8), date: nil, status: .passed)
                        ],
                        lessonOmissions: nil
                    ),
                    GradebookDiscipline(
                        code: "CS",
                        name: "CS",
                        controlForm: "Exam",
                        teacher: nil,
                        hours: nil,
                        attempts: [
                            GradeAttempt(attempt: 1, type: "EXAM", grade: .textual("9,5"), date: nil, status: .passed)
                        ],
                        lessonOmissions: nil
                    )
                ]
            )
        ])

        XCTAssertEqual(gradebook.averageGrade ?? -1, 8.75, accuracy: 0.0001)
    }

    func testNormalizedSortsSemestersAndDisciplines() {
        let semester1 = GradebookSemester(
            number: 1,
            title: nil,
            year: "2023/2024",
            disciplines: [
                GradebookDiscipline(code: "B", name: "B", controlForm: "Exam", teacher: nil, hours: nil, attempts: [
                    GradeAttempt(attempt: 1, type: "EXAM", grade: .numeric(8), date: nil, status: .passed)
                ], lessonOmissions: nil),
                GradebookDiscipline(code: "A", name: "A", controlForm: "Exam", teacher: nil, hours: nil, attempts: [
                    GradeAttempt(attempt: 1, type: "EXAM", grade: .numeric(10), date: nil, status: .passed)
                ], lessonOmissions: nil)
            ]
        )

        let semester2 = GradebookSemester(
            number: 2,
            title: nil,
            year: "2024/2025",
            disciplines: [
                GradebookDiscipline(code: "Z", name: "Z", controlForm: "Exam", teacher: nil, hours: nil, attempts: [
                    GradeAttempt(attempt: 1, type: "EXAM", grade: .numeric(7), date: nil, status: .passed)
                ], lessonOmissions: nil)
            ]
        )

        let normalized = Gradebook(semesters: [semester1, semester2]).normalized()

        XCTAssertEqual(normalized.semesters.map(\GradebookSemester.number), [2, 1])
        XCTAssertEqual(normalized.semesters[1].disciplines.map(\GradebookDiscipline.code), ["A", "B"])
    }

    func testBestAttemptPrefersHigherGradeThenLaterAttempt() {
        let discipline = GradebookDiscipline(
            code: "ALG",
            name: "Algebra",
            controlForm: "Exam",
            teacher: nil,
            hours: nil,
            attempts: [
                GradeAttempt(attempt: 1, type: "EXAM", grade: .numeric(9), date: nil, status: .passed),
                GradeAttempt(attempt: 2, type: "EXAM", grade: .numeric(9), date: nil, status: .passed),
                GradeAttempt(attempt: 3, type: "EXAM", grade: .numeric(8), date: nil, status: .passed)
            ],
            lessonOmissions: nil
        )

        XCTAssertEqual(discipline.bestAttempt?.attempt, 2)
        XCTAssertEqual(discipline.latestAttempt?.attempt, 3)
    }
}
