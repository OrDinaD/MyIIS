import XCTest
@testable import MyIIS

final class DormitoryCalculationsTests: XCTestCase {
    func testPaymentDeadlinesAndRecommendations() {
        let calendar = Calendar(identifier: .gregorian)
        let referenceComponents = DateComponents(calendar: calendar, year: 2025, month: 3, day: 10)
        let referenceDate = referenceComponents.date!

        let info = DormitoryInfo(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE") ?? UUID(),
            dormitoryName: "Общежитие №1",
            roomNumber: "101",
            bedPlace: "Место 1",
            floor: 3,
            moveInDate: calendar.date(byAdding: .month, value: -6, to: referenceDate) ?? referenceDate,
            contractEndDate: calendar.date(byAdding: .month, value: 4, to: referenceDate) ?? referenceDate,
            paidUntil: calendar.date(byAdding: .day, value: 5, to: referenceDate) ?? referenceDate,
            monthlyFee: 100,
            currentBalance: 20,
            status: .debt,
            lastPaymentDate: calendar.date(byAdding: .day, value: -12, to: referenceDate),
            notes: nil
        )

        XCTAssertEqual(info.daysUntilPaymentDue(from: referenceDate, calendar: calendar), 5)

        let overdue = DormitoryInfo(
            id: UUID(),
            dormitoryName: "Общежитие №2",
            roomNumber: "305",
            bedPlace: "Место 2",
            floor: 5,
            moveInDate: calendar.date(byAdding: .year, value: -1, to: referenceDate) ?? referenceDate,
            contractEndDate: calendar.date(byAdding: .month, value: 6, to: referenceDate) ?? referenceDate,
            paidUntil: calendar.date(byAdding: .day, value: -3, to: referenceDate) ?? referenceDate,
            monthlyFee: 120,
            currentBalance: 40,
            status: .debt,
            lastPaymentDate: calendar.date(byAdding: .day, value: -32, to: referenceDate),
            notes: "Необходимо срочно погасить задолженность"
        )

        XCTAssertTrue(overdue.isPaymentOverdue(referenceDate: referenceDate))
        XCTAssertEqual(info.recommendedPaymentAmount, 80, accuracy: 0.001)
    }
}
