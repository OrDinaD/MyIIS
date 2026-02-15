import Foundation

struct DormitoryInfo: Identifiable, Codable, Equatable {

    enum ResidenceStatus: String, Codable, CaseIterable {
        case active
        case expiringSoon
        case debt
        case expelled
        case settling

        var title: String {
            switch self {
            case .active: return "Проживание активно"
            case .expiringSoon: return "Срок заканчивается"
            case .debt: return "Есть задолженность"
            case .expelled: return "Проживание завершено"
            case .settling: return "Заселение в процессе"
            }
        }

        var systemImageName: String {
            switch self {
            case .active: return "checkmark.seal.fill"
            case .expiringSoon: return "hourglass"
            case .debt: return "exclamationmark.triangle.fill"
            case .expelled: return "xmark.octagon.fill"
            case .settling: return "person.crop.circle.badge.plus"
            }
        }
    }

    let id: UUID
    let dormitoryName: String
    let roomNumber: String
    let bedPlace: String
    let floor: Int
    let moveInDate: Date
    let contractEndDate: Date
    let paidUntil: Date
    let monthlyFee: Double
    let currentBalance: Double
    let status: ResidenceStatus
    let lastPaymentDate: Date?
    let notes: String?

    var outstandingDebt: Double {
        max(0, monthlyFee - currentBalance)
    }

    func daysUntilContractEnds(from referenceDate: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard referenceDate <= contractEndDate else { return nil }
        let start = calendar.startOfDay(for: referenceDate)
        let end = calendar.startOfDay(for: contractEndDate)
        return calendar.dateComponents([.day], from: start, to: end).day
    }

    func daysUntilPaymentDue(from referenceDate: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard referenceDate <= paidUntil else { return nil }
        let start = calendar.startOfDay(for: referenceDate)
        let end = calendar.startOfDay(for: paidUntil)
        return calendar.dateComponents([.day], from: start, to: end).day
    }

    func isPaymentOverdue(referenceDate: Date = Date()) -> Bool {
        outstandingDebt > 0 && referenceDate > paidUntil
    }

    var recommendedPaymentAmount: Double {
        outstandingDebt > 0 ? outstandingDebt : monthlyFee
    }
}

struct ResidenceHistory: Identifiable, Codable, Equatable {

    enum EventType: String, Codable, CaseIterable {
        case payment
        case settlement
        case maintenance
        case relocation

        var title: String {
            switch self {
            case .payment: return "Оплата"
            case .settlement: return "Заселение"
            case .maintenance: return "Заявка"
            case .relocation: return "Переселение"
            }
        }

        var systemImageName: String {
            switch self {
            case .payment: return "creditcard.fill"
            case .settlement: return "key.fill"
            case .maintenance: return "wrench.and.screwdriver"
            case .relocation: return "arrow.right.arrow.left"
            }
        }
    }

    let id: UUID
    let eventDate: Date
    let type: EventType
    let title: String
    let amount: Double?
    let description: String?
    let status: String?

    var isPayment: Bool {
        type == .payment
    }
}

struct DormitoryAction: Identifiable, Equatable {
    enum ActionType: CaseIterable {
        case extendContract
        case submitMaintenance
        case requestRelocation
        case makePayment

        var title: String {
            switch self {
            case .extendContract: return "Продлить договор"
            case .submitMaintenance: return "Заявка в техслужбу"
            case .requestRelocation: return "Запрос на переселение"
            case .makePayment: return "Оплатить проживание"
            }
        }

        var subtitle: String {
            switch self {
            case .extendContract: return "До \(DateFormatter.short.format(date: Date().addingTimeInterval(60 * 60 * 24 * 30)))"
            case .submitMaintenance: return "Сообщить о проблеме"
            case .requestRelocation: return "Выбрать другую комнату"
            case .makePayment: return "Через ЕРИП или карту"
            }
        }

        var systemImageName: String {
            switch self {
            case .extendContract: return "calendar.badge.plus"
            case .submitMaintenance: return "wrench.adjustable"
            case .requestRelocation: return "figure.run"
            case .makePayment: return "creditcard"
            }
        }
    }

    let id: UUID
    let type: ActionType
    let title: String
    let subtitle: String
    let systemImageName: String

    init(id: UUID = UUID(), type: ActionType) {
        self.id = id
        self.type = type
        self.title = type.title
        self.subtitle = type.subtitle
        self.systemImageName = type.systemImageName
    }
}

// MARK: - Formatting Helpers

private extension DateFormatter {
    static let short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd MMMM"
        return formatter
    }()

    func format(date: Date) -> String {
        string(from: date)
    }
}

// MARK: - Previews

extension DormitoryInfo {
    static let previewValue: DormitoryInfo = {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let moveIn = calendar.date(byAdding: .month, value: -14, to: now) ?? now
        let contractEnd = calendar.date(byAdding: .month, value: 2, to: now) ?? now
        let paidUntil = calendar.date(byAdding: .day, value: 9, to: now) ?? now

        return DormitoryInfo(
            id: UUID(),
            dormitoryName: "Общежитие №6",
            roomNumber: "512",
            bedPlace: "Место 2",
            floor: 5,
            moveInDate: moveIn,
            contractEndDate: contractEnd,
            paidUntil: paidUntil,
            monthlyFee: 96.40,
            currentBalance: 54.80,
            status: .debt,
            lastPaymentDate: calendar.date(byAdding: .day, value: -21, to: now),
            notes: "Необходимо подтвердить проживание на новый семестр."
        )
    }()
}

extension ResidenceHistory {
    static let preview: [ResidenceHistory] = {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()

        return [
            ResidenceHistory(
                id: UUID(),
                eventDate: calendar.date(byAdding: .day, value: -4, to: now) ?? now,
                type: .payment,
                title: "Оплата через ЕРИП",
                amount: 50.00,
                description: "Погашение задолженности",
                status: "Зачислено"
            ),
            ResidenceHistory(
                id: UUID(),
                eventDate: calendar.date(byAdding: .day, value: -28, to: now) ?? now,
                type: .maintenance,
                title: "Заявка на замену лампы",
                amount: nil,
                description: "Комната 512, перегорела лампа",
                status: "Выполнено"
            ),
            ResidenceHistory(
                id: UUID(),
                eventDate: calendar.date(byAdding: .month, value: -5, to: now) ?? now,
                type: .settlement,
                title: "Пролонгация договора",
                amount: nil,
                description: "Договор продлён до июня",
                status: "Подтверждено"
            )
        ]
    }()
}

extension DormitoryAction {
    static var preview: [DormitoryAction] {
        [DormitoryAction(type: .makePayment),
         DormitoryAction(type: .extendContract),
         DormitoryAction(type: .submitMaintenance)]
    }
}
