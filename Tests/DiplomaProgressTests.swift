import XCTest
@testable import MyIIS

final class DiplomaProgressTests: XCTestCase {

    func testCompletionPercentageCalculation() {
        let now = Date()
        let milestones = [
            Milestone(
                id: "1",
                title: "Подготовка",
                details: nil,
                plannedDate: now,
                actualDate: now,
                status: .completed,
                comment: nil,
                order: 1
            ),
            Milestone(
                id: "2",
                title: "Исследование",
                details: nil,
                plannedDate: now,
                actualDate: nil,
                status: .submitted,
                comment: nil,
                order: 2
            ),
            Milestone(
                id: "3",
                title: "Разработка",
                details: nil,
                plannedDate: now,
                actualDate: nil,
                status: .inProgress,
                comment: nil,
                order: 3
            ),
            Milestone(
                id: "4",
                title: "Защита",
                details: nil,
                plannedDate: now,
                actualDate: nil,
                status: .planned,
                comment: nil,
                order: 4
            )
        ]

        let progress = DiplomaProgress(
            topic: "Система рекомендаций",
            advisor: "доц. Иванов И.И.",
            status: .inProgress,
            comment: nil,
            updatedAt: now,
            milestones: milestones
        )

        XCTAssertEqual(progress.completedMilestonesCount, 2)
        XCTAssertEqual(progress.completionPercentage, 0.5, accuracy: 0.0001)
        XCTAssertEqual(progress.completionPercentText, "50%")
    }

    func testNextMilestoneDetection() {
        let now = Date()
        let milestones = [
            Milestone(
                id: "a",
                title: "Старт",
                details: nil,
                plannedDate: now,
                actualDate: now,
                status: .completed,
                comment: nil,
                order: 1
            ),
            Milestone(
                id: "b",
                title: "Промежуточный отчёт",
                details: nil,
                plannedDate: now,
                actualDate: nil,
                status: .review,
                comment: nil,
                order: 2
            ),
            Milestone(
                id: "c",
                title: "Финальная защита",
                details: nil,
                plannedDate: now,
                actualDate: nil,
                status: .planned,
                comment: nil,
                order: 3
            )
        ]

        let progress = DiplomaProgress(
            topic: "Система рекомендации",
            advisor: nil,
            status: .inProgress,
            comment: nil,
            updatedAt: now,
            milestones: milestones
        )

        XCTAssertEqual(progress.nextMilestone?.id, "b")
        XCTAssertEqual(progress.sortedMilestones().map { $0.id }, ["a", "b", "c"])
    }
}
