import Foundation

struct DormitoryTestFailure: Error {
    let message: String
}

func assert(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String) throws {
    if !condition() {
        throw DormitoryTestFailure(message: message())
    }
}

@main
enum DormitoryCalculationsTest {
    static func main() {
        do {
            let calendar = Calendar(identifier: .gregorian)
            let referenceComponents = DateComponents(calendar: calendar, year: 2025, month: 3, day: 10)
            guard let referenceDate = referenceComponents.date else {
                throw DormitoryTestFailure(message: "Не удалось создать тестовую дату")
            }

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

            let days = info.daysUntilPaymentDue(from: referenceDate, calendar: calendar)
            try assert(days == 5, "Ожидалось 5 дней до оплаты, получено: \(String(describing: days))")

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

            try assert(overdue.isPaymentOverdue(referenceDate: referenceDate), "Задолженность должна быть просрочена")

            let recommended = info.recommendedPaymentAmount
            try assert(
                abs(recommended - 80) < 0.001,
                "Рекомендованная сумма платежа должна составлять 80 BYN, получено: \(recommended)"
            )

            print("Dormitory calculations test passed")
        } catch {
            fputs("Dormitory calculations test failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
