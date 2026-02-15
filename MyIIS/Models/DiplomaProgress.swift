import Foundation

struct DiplomaProgress: Codable, Equatable {

    enum Status: Equatable {
        case notStarted
        case inProgress
        case review
        case awaitingDefense
        case defended
        case archived
        case custom(String)
    }

    let topic: String
    let advisor: String?
    let status: Status
    let comment: String?
    let updatedAt: Date?
    let milestones: [Milestone]

    var isEmpty: Bool {
        milestones.isEmpty
    }

    var completedMilestonesCount: Int {
        milestones.filter { $0.status.isCompleted }.count
    }

    var completionPercentage: Double {
        guard !milestones.isEmpty else { return 0 }
        return Double(completedMilestonesCount) / Double(milestones.count)
    }

    var completionPercentText: String {
        NumberFormatter.percent.string(from: NSNumber(value: completionPercentage)) ?? "0%"
    }

    var nextMilestone: Milestone? {
        milestones.sortedForTimeline().first { !$0.status.isCompleted }
    }

    func sortedMilestones() -> [Milestone] {
        milestones.sortedForTimeline()
    }
}

extension DiplomaProgress.Status: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Self.make(from: rawValue)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringValue)
    }

    private static func make(from value: String) -> DiplomaProgress.Status {
        switch value.uppercased() {
        case "NOT_STARTED", "PLANNED":
            return .notStarted
        case "IN_PROGRESS":
            return .inProgress
        case "REVIEW", "CHECK":
            return .review
        case "AWAITING_DEFENSE", "SCHEDULED":
            return .awaitingDefense
        case "DEFENDED", "COMPLETED":
            return .defended
        case "ARCHIVED":
            return .archived
        default:
            return .custom(value)
        }
    }

    private var stringValue: String {
        switch self {
        case .notStarted:
            return "NOT_STARTED"
        case .inProgress:
            return "IN_PROGRESS"
        case .review:
            return "REVIEW"
        case .awaitingDefense:
            return "AWAITING_DEFENSE"
        case .defended:
            return "DEFENDED"
        case .archived:
            return "ARCHIVED"
        case .custom(let value):
            return value
        }
    }
}

extension DiplomaProgress.Status {
    var displayName: String {
        switch self {
        case .notStarted:
            return "Не начат"
        case .inProgress:
            return "В работе"
        case .review:
            return "На проверке"
        case .awaitingDefense:
            return "Ожидает защиту"
        case .defended:
            return "Защищён"
        case .archived:
            return "Архив"
        case .custom(let value):
            return value
        }
    }
}

struct Milestone: Codable, Identifiable, Equatable {

    enum Status: Equatable {
        case planned
        case inProgress
        case review
        case submitted
        case completed
        case blocked
        case overdue
        case custom(String)
    }

    let id: String
    let title: String
    let details: String?
    let plannedDate: Date?
    let actualDate: Date?
    let status: Status
    let comment: String?
    let order: Int?

    var displayDate: Date? {
        actualDate ?? plannedDate
    }

    var isOverdue: Bool {
        guard !status.isCompleted, let plannedDate, plannedDate < Date() else {
            return false
        }
        return true
    }
}

extension Milestone.Status: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Self.make(from: rawValue)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringValue)
    }

    private static func make(from value: String) -> Milestone.Status {
        switch value.uppercased() {
        case "PLANNED":
            return .planned
        case "IN_PROGRESS":
            return .inProgress
        case "REVIEW", "CHECK":
            return .review
        case "SUBMITTED":
            return .submitted
        case "COMPLETED", "DONE":
            return .completed
        case "BLOCKED", "PAUSED":
            return .blocked
        case "OVERDUE":
            return .overdue
        default:
            return .custom(value)
        }
    }

    private var stringValue: String {
        switch self {
        case .planned:
            return "PLANNED"
        case .inProgress:
            return "IN_PROGRESS"
        case .review:
            return "REVIEW"
        case .submitted:
            return "SUBMITTED"
        case .completed:
            return "COMPLETED"
        case .blocked:
            return "BLOCKED"
        case .overdue:
            return "OVERDUE"
        case .custom(let value):
            return value
        }
    }
}

extension Milestone.Status {
    var isCompleted: Bool {
        switch self {
        case .completed, .submitted:
            return true
        default:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .planned:
            return "Запланирован"
        case .inProgress:
            return "В процессе"
        case .review:
            return "На проверке"
        case .submitted:
            return "Отправлен"
        case .completed:
            return "Завершён"
        case .blocked:
            return "Заблокирован"
        case .overdue:
            return "Просрочен"
        case .custom(let value):
            return value
        }
    }
}

private extension Array where Element == Milestone {
    func sortedForTimeline() -> [Milestone] {
        sorted { lhs, rhs in
            switch (lhs.order, rhs.order) {
            case let (lhsOrder?, rhsOrder?):
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                break
            }

            switch (lhs.displayDate, rhs.displayDate) {
            case let (lhsDate?, rhsDate?):
                if lhsDate != rhsDate { return lhsDate < rhsDate }
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                break
            }

            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}

private extension NumberFormatter {
    static let percent: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

private enum DiplomaDateParser {
    static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let simpleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()

    static func parse(_ string: String) -> Date? {
        if let date = iso8601Fractional.date(from: string) {
            return date
        }
        if let date = iso8601.date(from: string) {
            return date
        }
        if let date = simpleFormatter.date(from: string) {
            return date
        }
        return nil
    }
}

private extension KeyedDecodingContainer {
    func decodeDiplomaDateIfPresent(forKey key: Key) throws -> Date? {
        if let stringValue = try? decode(String.self, forKey: key) {
            return DiplomaDateParser.parse(stringValue)
        }

        if let doubleValue = try? decode(Double.self, forKey: key) {
            if doubleValue > 10_000_000_000 {
                return Date(timeIntervalSince1970: doubleValue / 1000)
            }
            return Date(timeIntervalSince1970: doubleValue)
        }

        if let intValue = try? decode(Int.self, forKey: key) {
            if intValue > 10_000_000_000 {
                return Date(timeIntervalSince1970: Double(intValue) / 1000)
            }
            return Date(timeIntervalSince1970: Double(intValue))
        }

        return nil
    }
}

extension DiplomaProgress {
    private enum CodingKeys: String, CodingKey {
        case topic
        case advisor
        case status
        case comment
        case updatedAt
        case milestones
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        topic = try container.decode(String.self, forKey: .topic)
        advisor = try container.decodeIfPresent(String.self, forKey: .advisor)
        status = try container.decode(Status.self, forKey: .status)
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
        updatedAt = try container.decodeDiplomaDateIfPresent(forKey: .updatedAt)
        milestones = try container.decodeIfPresent([Milestone].self, forKey: .milestones) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(topic, forKey: .topic)
        try container.encodeIfPresent(advisor, forKey: .advisor)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(comment, forKey: .comment)
        try container.encodeIfPresent(updatedAt?.iso8601String, forKey: .updatedAt)
        try container.encode(milestones, forKey: .milestones)
    }
}

extension Milestone {
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case details
        case plannedDate
        case actualDate
        case status
        case comment
        case order
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let idValue = try? container.decode(String.self, forKey: .id) {
            id = idValue
        } else if let idInt = try? container.decode(Int.self, forKey: .id) {
            id = String(idInt)
        } else {
            id = UUID().uuidString
        }

        title = try container.decode(String.self, forKey: .title)
        details = try container.decodeIfPresent(String.self, forKey: .details)
        plannedDate = try container.decodeDiplomaDateIfPresent(forKey: .plannedDate)
        actualDate = try container.decodeDiplomaDateIfPresent(forKey: .actualDate)
        status = try container.decode(Status.self, forKey: .status)
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
        order = try container.decodeIfPresent(Int.self, forKey: .order)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(details, forKey: .details)
        try container.encodeIfPresent(plannedDate?.iso8601String, forKey: .plannedDate)
        try container.encodeIfPresent(actualDate?.iso8601String, forKey: .actualDate)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(comment, forKey: .comment)
        try container.encodeIfPresent(order, forKey: .order)
    }
}

private extension Date {
    var iso8601String: String {
        DiplomaDateParser.iso8601.string(from: self)
    }
}

// MARK: - Preview Support

extension DiplomaProgress {
    static let preview: DiplomaProgress = {
        let calendar = Calendar.current
        let now = Date()
        let milestone1 = Milestone(
            id: UUID().uuidString,
            title: "Выбор темы и утверждение плана",
            details: "Согласовать тему дипломного проекта с руководителем",
            plannedDate: calendar.date(byAdding: .month, value: -6, to: now),
            actualDate: calendar.date(byAdding: .month, value: -5, to: now),
            status: .completed,
            comment: "Тема утверждена, план согласован",
            order: 1
        )

        let milestone2 = Milestone(
            id: UUID().uuidString,
            title: "Исследовательская часть",
            details: "Сбор данных и анализ предметной области",
            plannedDate: calendar.date(byAdding: .month, value: -3, to: now),
            actualDate: calendar.date(byAdding: .month, value: -2, to: now),
            status: .submitted,
            comment: "Материалы переданы на проверку",
            order: 2
        )

        let milestone3 = Milestone(
            id: UUID().uuidString,
            title: "Разработка приложения",
            details: "Реализация MVP и подготовка презентации",
            plannedDate: calendar.date(byAdding: .month, value: -1, to: now),
            actualDate: nil,
            status: .inProgress,
            comment: "Выполняется интеграция с API",
            order: 3
        )

        let milestone4 = Milestone(
            id: UUID().uuidString,
            title: "Подготовка к защите",
            details: "Написание пояснительной записки и подготовка доклада",
            plannedDate: calendar.date(byAdding: .month, value: 1, to: now),
            actualDate: nil,
            status: .planned,
            comment: nil,
            order: 4
        )

        return DiplomaProgress(
            topic: "Система мониторинга прогресса дипломного проекта",
            advisor: "доц. Петров А.А.",
            status: .inProgress,
            comment: "Сосредоточиться на оптимизации алгоритма планирования",
            updatedAt: now,
            milestones: [milestone1, milestone2, milestone3, milestone4]
        )
    }()
}
