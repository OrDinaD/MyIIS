import Foundation

enum LocalScheduleEventType: String, Codable, CaseIterable, Identifiable, Sendable {
    case lecture
    case practice
    case lab
    case exam
    case consultation
    case announcement
    case other

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .lecture: return NSLocalizedString("local_schedule_type_lecture", comment: "")
        case .practice: return NSLocalizedString("local_schedule_type_practice", comment: "")
        case .lab: return NSLocalizedString("local_schedule_type_lab", comment: "")
        case .exam: return NSLocalizedString("local_schedule_type_exam", comment: "")
        case .consultation: return NSLocalizedString("local_schedule_type_consultation", comment: "")
        case .announcement: return NSLocalizedString("local_schedule_type_announcement", comment: "")
        case .other: return NSLocalizedString("local_schedule_type_other", comment: "")
        }
    }
}

struct LocalScheduleDocument: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var id: String
    var title: String
    var groupName: String?
    var timeZone: String
    var validFrom: String?
    var validThrough: String?
    var updatedAt: String?
    var events: [Event]

    struct Teacher: Codable, Equatable, Sendable {
        var id: Int
        var firstName: String
        var middleName: String?
        var lastName: String
        var degree: String?
        var rank: String?
        var photoLink: String?
        var urlId: String?
        var calendarId: String?

        var fullName: String {
            [lastName, firstName, middleName]
                .compactMap { $0?.nilIfBlank }
                .joined(separator: " ")
        }
    }

    struct Event: Codable, Equatable, Identifiable, Sendable {
        var id: String
        var date: String
        var startTime: String
        var endTime: String
        var title: String
        var shortTitle: String?
        var type: LocalScheduleEventType
        var location: String?
        var teacher: String?
        var teacherDetails: Teacher?
        var note: String?
        var isCancelled: Bool

        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case id
            case date
            case startTime
            case endTime
            case title
            case shortTitle
            case type
            case location
            case teacher
            case teacherDetails
            case note
            case isCancelled
        }

        init(
            id: String,
            date: String,
            startTime: String,
            endTime: String,
            title: String,
            shortTitle: String? = nil,
            type: LocalScheduleEventType,
            location: String? = nil,
            teacher: String? = nil,
            teacherDetails: Teacher? = nil,
            note: String? = nil,
            isCancelled: Bool = false
        ) {
            self.id = id
            self.date = date
            self.startTime = startTime
            self.endTime = endTime
            self.title = title
            self.shortTitle = shortTitle
            self.type = type
            self.location = location
            self.teacher = teacher
            self.teacherDetails = teacherDetails
            self.note = note
            self.isCancelled = isCancelled
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            date = try container.decode(String.self, forKey: .date)
            startTime = try container.decode(String.self, forKey: .startTime)
            endTime = try container.decode(String.self, forKey: .endTime)
            title = try container.decode(String.self, forKey: .title)
            shortTitle = try container.decodeIfPresent(String.self, forKey: .shortTitle)
            type = try container.decode(LocalScheduleEventType.self, forKey: .type)
            location = try container.decodeIfPresent(String.self, forKey: .location)
            teacher = try container.decodeIfPresent(String.self, forKey: .teacher)
            teacherDetails = try container.decodeIfPresent(Teacher.self, forKey: .teacherDetails)
            note = try container.decodeIfPresent(String.self, forKey: .note)
            isCancelled = try container.decodeIfPresent(Bool.self, forKey: .isCancelled) ?? false
        }

        var parsedDate: Date? {
            LocalScheduleFormatting.dayFormatter.date(from: date)
        }

        var displayTitle: String {
            shortTitle?.nilIfBlank ?? title
        }

        var teacherDisplayName: String? {
            teacherDetails?.fullName.nilIfBlank ?? teacher?.nilIfBlank
        }

        func interval(calendar: Calendar = .current, timeZone: TimeZone) -> DateInterval? {
            guard let day = parsedDate,
                  let startComponents = LocalScheduleFormatting.timeComponents(from: startTime),
                  let endComponents = LocalScheduleFormatting.timeComponents(from: endTime) else {
                return nil
            }

            var localCalendar = calendar
            localCalendar.timeZone = timeZone
            var dayComponents = localCalendar.dateComponents([.year, .month, .day], from: day)
            dayComponents.timeZone = timeZone
            dayComponents.hour = startComponents.hour
            dayComponents.minute = startComponents.minute
            guard let start = localCalendar.date(from: dayComponents) else { return nil }

            dayComponents.hour = endComponents.hour
            dayComponents.minute = endComponents.minute
            guard let end = localCalendar.date(from: dayComponents), end > start else { return nil }
            return DateInterval(start: start, end: end)
        }
    }

    var resolvedTimeZone: TimeZone {
        TimeZone(identifier: timeZone) ?? .current
    }

    var sortedEvents: [Event] {
        events.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            if $0.startTime != $1.startTime { return $0.startTime < $1.startTime }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    func validated() throws -> LocalScheduleDocument {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw LocalScheduleValidationError.unsupportedSchema(schemaVersion)
        }
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LocalScheduleValidationError.missingDocumentID
        }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LocalScheduleValidationError.missingTitle
        }
        guard TimeZone(identifier: timeZone) != nil else {
            throw LocalScheduleValidationError.invalidTimeZone(timeZone)
        }

        var identifiers = Set<String>()
        for event in events {
            guard !event.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw LocalScheduleValidationError.missingEventID
            }
            guard identifiers.insert(event.id).inserted else {
                throw LocalScheduleValidationError.duplicateEventID(event.id)
            }
            guard event.parsedDate != nil else {
                throw LocalScheduleValidationError.invalidDate(event.date)
            }
            guard !event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw LocalScheduleValidationError.missingEventTitle(event.id)
            }
            guard event.interval(timeZone: resolvedTimeZone) != nil else {
                throw LocalScheduleValidationError.invalidTimeRange(event.id)
            }
        }

        var result = self
        result.events = sortedEvents
        return result
    }

    func updatingTimestamp(_ date: Date = .now) -> LocalScheduleDocument {
        var result = self
        result.updatedAt = ISO8601DateFormatter().string(from: date)
        result.events = sortedEvents
        return result
    }

    static func empty() -> LocalScheduleDocument {
        LocalScheduleDocument(
            schemaVersion: currentSchemaVersion,
            id: UUID().uuidString.lowercased(),
            title: NSLocalizedString("local_schedule_default_title", comment: ""),
            timeZone: TimeZone.current.identifier,
            validFrom: nil,
            validThrough: nil,
            updatedAt: nil,
            events: []
        )
    }

    static func example(referenceDate: Date = .now, calendar: Calendar = .current) -> LocalScheduleDocument {
        let firstDay = calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate
        let secondDay = calendar.date(byAdding: .day, value: 2, to: referenceDate) ?? referenceDate
        return LocalScheduleDocument(
            schemaVersion: currentSchemaVersion,
            id: "summer-school-example",
            title: NSLocalizedString("local_schedule_example_title", comment: ""),
            timeZone: TimeZone.current.identifier,
            validFrom: LocalScheduleFormatting.dayFormatter.string(from: firstDay),
            validThrough: LocalScheduleFormatting.dayFormatter.string(from: secondDay),
            updatedAt: nil,
            events: [
                Event(
                    id: UUID().uuidString.lowercased(),
                    date: LocalScheduleFormatting.dayFormatter.string(from: firstDay),
                    startTime: "09:00",
                    endTime: "10:30",
                    title: NSLocalizedString("local_schedule_example_event_title", comment: ""),
                    shortTitle: "SwiftUI",
                    type: .lecture,
                    location: NSLocalizedString("local_schedule_example_location", comment: "")
                ),
                Event(
                    id: UUID().uuidString.lowercased(),
                    date: LocalScheduleFormatting.dayFormatter.string(from: secondDay),
                    startTime: "11:00",
                    endTime: "12:30",
                    title: NSLocalizedString("local_schedule_example_project_title", comment: ""),
                    shortTitle: NSLocalizedString("local_schedule_example_project_short", comment: ""),
                    type: .practice,
                    location: NSLocalizedString("local_schedule_example_coworking", comment: "")
                )
            ]
        )
    }
}

enum LocalScheduleFormatting {
    nonisolated static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    nonisolated static func timeComponents(from value: String) -> DateComponents? {
        let parts = value.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2,
              (0 ... 23).contains(parts[0]),
              (0 ... 59).contains(parts[1]) else {
            return nil
        }
        return DateComponents(hour: parts[0], minute: parts[1])
    }
}

enum LocalScheduleValidationError: LocalizedError, Equatable {
    case unsupportedSchema(Int)
    case missingDocumentID
    case missingTitle
    case invalidTimeZone(String)
    case missingEventID
    case duplicateEventID(String)
    case invalidDate(String)
    case missingEventTitle(String)
    case invalidTimeRange(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            return String(format: NSLocalizedString("local_schedule_error_schema", comment: ""), version)
        case .missingDocumentID:
            return NSLocalizedString("local_schedule_error_document_id", comment: "")
        case .missingTitle:
            return NSLocalizedString("local_schedule_error_title", comment: "")
        case .invalidTimeZone(let value):
            return String(format: NSLocalizedString("local_schedule_error_time_zone", comment: ""), value)
        case .missingEventID:
            return NSLocalizedString("local_schedule_error_event_id", comment: "")
        case .duplicateEventID(let value):
            return String(format: NSLocalizedString("local_schedule_error_duplicate_id", comment: ""), value)
        case .invalidDate(let value):
            return String(format: NSLocalizedString("local_schedule_error_date", comment: ""), value)
        case .missingEventTitle(let identifier):
            return String(format: NSLocalizedString("local_schedule_error_event_title", comment: ""), identifier)
        case .invalidTimeRange(let identifier):
            return String(format: NSLocalizedString("local_schedule_error_time", comment: ""), identifier)
        }
    }
}
