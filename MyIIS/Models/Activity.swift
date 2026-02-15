import Foundation

enum ActivityStatus: String, Codable, CaseIterable, Identifiable {
    case scheduled
    case inProgress
    case finished
    case cancelled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scheduled: return "Запланировано"
        case .inProgress: return "Идёт"
        case .finished: return "Завершено"
        case .cancelled: return "Отменено"
        }
    }
}

enum ActivityRegistrationState: String, Codable, CaseIterable, Identifiable {
    case notRegistered
    case registered
    case waitlisted

    var id: String { rawValue }

    var isRegistered: Bool {
        self == .registered
    }
}

struct Activity: Codable, Identifiable, Equatable {
    let id: Int
    let title: String
    let subtitle: String?
    let description: String
    let category: ActivityCategory
    let location: String
    let startDate: Date
    let endDate: Date
    let registrationDeadline: Date?
    let imageURL: URL?
    let capacity: Int?
    var registeredCount: Int
    let cancellationDate: Date?
    var userRegistration: ActivityRegistrationState

    init(
        id: Int,
        title: String,
        subtitle: String? = nil,
        description: String,
        category: ActivityCategory,
        location: String,
        startDate: Date,
        endDate: Date,
        registrationDeadline: Date? = nil,
        imageURL: URL? = nil,
        capacity: Int? = nil,
        registeredCount: Int = 0,
        cancellationDate: Date? = nil,
        userRegistration: ActivityRegistrationState = .notRegistered
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.category = category
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.registrationDeadline = registrationDeadline
        self.imageURL = imageURL
        self.capacity = capacity
        self.registeredCount = registeredCount
        self.cancellationDate = cancellationDate
        self.userRegistration = userRegistration
    }

    func status(at date: Date) -> ActivityStatus {
        if let cancellationDate, cancellationDate <= date {
            return .cancelled
        }

        if date < startDate {
            return .scheduled
        }

        if date > endDate {
            return .finished
        }

        return .inProgress
    }

    var status: ActivityStatus { status(at: Date()) }

    func isRegistrationOpen(at date: Date) -> Bool {
        guard cancellationDate == nil else { return false }
        if let capacity, registeredCount >= capacity { return false }
        if let registrationDeadline, date > registrationDeadline { return false }
        return date <= startDate
    }

    var isRegistrationOpen: Bool { isRegistrationOpen(at: Date()) }

    var isFull: Bool {
        if let capacity { return registeredCount >= capacity }
        return false
    }

    var timeIntervalDescription: String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startDate, to: endDate)
    }
}

#if DEBUG
extension Activity {
    static func preview(
        id: Int,
        title: String,
        subtitle: String? = nil,
        description: String = "",
        category: ActivityCategory,
        location: String,
        startOffset: TimeInterval,
        duration: TimeInterval,
        registrationDeadlineOffset: TimeInterval? = nil,
        capacity: Int? = 40,
        registered: Int = 0,
        cancellationOffset: TimeInterval? = nil,
        registrationState: ActivityRegistrationState = .notRegistered
    ) -> Activity {
        let now = Date()
        let start = now.addingTimeInterval(startOffset)
        let end = start.addingTimeInterval(duration)
        let deadline = registrationDeadlineOffset.map { start.addingTimeInterval($0) }
        let cancellationDate = cancellationOffset.map { start.addingTimeInterval($0) }

        return Activity(
            id: id,
            title: title,
            subtitle: subtitle,
            description: description,
            category: category,
            location: location,
            startDate: start,
            endDate: end,
            registrationDeadline: deadline,
            capacity: capacity,
            registeredCount: registered,
            cancellationDate: cancellationDate,
            userRegistration: registrationState
        )
    }

    nonisolated(unsafe) static let previewActivities: [Activity] = [
        .preview(
            id: 100,
            title: "IT Волонтёры",
            subtitle: "Поддержка городского хакатона",
            description: "Помогаем участникам настроить оборудование и консультируем по техническим вопросам.",
            category: .volunteering,
            location: "Main Hall",
            startOffset: 60 * 60 * 24 * 2,
            duration: 60 * 60 * 3,
            registrationDeadlineOffset: -60 * 60 * 12,
            capacity: 25,
            registered: 12
        ),
        .preview(
            id: 101,
            title: "Ночной забег",
            subtitle: "5 км по городу",
            description: "Присоединяйтесь к вечернему забегу по улицам Минска.",
            category: .sport,
            location: "Стадион БГУИР",
            startOffset: -60 * 60,
            duration: 60 * 60,
            registrationDeadlineOffset: -60 * 60 * 4,
            capacity: 60,
            registered: 55,
            registrationState: .registered
        ),
        .preview(
            id: 102,
            title: "Театральная лаборатория",
            subtitle: "Иммерсивные практики",
            description: "Погрузитесь в мир современного театра и попробуйте себя на сцене.",
            category: .culture,
            location: "Дом культуры",
            startOffset: -60 * 60 * 24 * 4,
            duration: 60 * 60 * 2,
            registrationDeadlineOffset: -60 * 60 * 24 * 5,
            capacity: 40,
            registered: 40
        ),
        .preview(
            id: 103,
            title: "Хакатон AI & ML",
            subtitle: "48 часов инноваций",
            description: "Командные соревнования по разработке решений на базе искусственного интеллекта.",
            category: .science,
            location: "IOT Lab",
            startOffset: 60 * 60 * 24 * 6,
            duration: 60 * 60 * 24,
            registrationDeadlineOffset: -60 * 60 * 24 * 2,
            capacity: 80,
            registered: 78
        )
    ]
}
#endif
