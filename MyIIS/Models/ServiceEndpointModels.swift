import Foundation

struct LibraryNewsEntry: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let link: URL
    let date: String
}

struct ScheduleEmployeeDirectoryEntry: Decodable, Identifiable, Hashable {
    let firstName: String?
    let lastName: String?
    let middleName: String?
    let degree: String?
    let rank: String?
    let photoLink: String?
    let calendarId: String?
    let id: Int
    let urlId: String?
    let fio: String?

    var displayName: String {
        if let fio, !fio.isEmpty {
            return fio
        }
        let parts = [lastName, firstName, middleName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        if parts.isEmpty {
            return "ID \(id)"
        }
        return parts.joined(separator: " ")
    }
}

enum ScheduleEmployeePhotoURL {
    static func make(photoLink: String?, employeeID: Int) -> URL? {
        if let link = photoLink?.trimmingCharacters(in: .whitespacesAndNewlines),
           !link.isEmpty {
            return URL(string: link
                .replacingOccurrences(of: "http://", with: "https://")
                .replacingOccurrences(of: "null/", with: "https://iis.bsuir.by/"))
        }

        guard employeeID > 0 else { return nil }
        let server = ScheduleServerConfiguration.selectedServer
        if server == .gateway || server == .auto {
            return URL(string: "https://bsuir.ordinad.xyz/api/v1/employees/photo/\(employeeID)?format=jpeg")
        }
        return URL(string: "https://iis.bsuir.by/api/v1/employees/photo/\(employeeID)")
    }
}

struct PublicScheduleResponse: Decodable, Sendable {
    let employee: DisciplineEmployee?
    let group: StudyGroup?
    let exams: [DisciplineSchedule]
    let startDate: Date?
    let endDate: Date?
    let startExamsDate: Date?
    let endExamsDate: Date?
    private let scheduleByWeekday: [StudyWeekday: [DisciplineSchedule]]
    private let previousScheduleByWeekday: [StudyWeekday: [DisciplineSchedule]]
    private let nextScheduleByWeekday: [StudyWeekday: [DisciplineSchedule]]

    enum CodingKeys: String, CodingKey {
        case employee = "employeeDto"
        case group = "studentGroupDto"
        case schedules
        case previousSchedules
        case nextSchedules
        case exams
        case startDate
        case endDate
        case startExamsDate
        case endExamsDate
    }

    static let publicationPending = PublicScheduleResponse(
        employee: nil,
        group: nil,
        exams: [],
        startDate: nil,
        endDate: nil,
        startExamsDate: nil,
        endExamsDate: nil,
        scheduleByWeekday: [:],
        previousScheduleByWeekday: [:],
        nextScheduleByWeekday: [:]
    )

    init(
        employee: DisciplineEmployee?,
        group: StudyGroup?,
        exams: [DisciplineSchedule],
        startDate: Date?,
        endDate: Date?,
        startExamsDate: Date?,
        endExamsDate: Date?,
        scheduleByWeekday: [StudyWeekday: [DisciplineSchedule]],
        previousScheduleByWeekday: [StudyWeekday: [DisciplineSchedule]],
        nextScheduleByWeekday: [StudyWeekday: [DisciplineSchedule]]
    ) {
        self.employee = employee
        self.group = group
        self.exams = exams
        self.startDate = startDate
        self.endDate = endDate
        self.startExamsDate = startExamsDate
        self.endExamsDate = endExamsDate
        self.scheduleByWeekday = scheduleByWeekday
        self.previousScheduleByWeekday = previousScheduleByWeekday
        self.nextScheduleByWeekday = nextScheduleByWeekday
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dateParser = StudyPlanDateParser.shared

        employee = try container.decodeIfPresent(DisciplineEmployee.self, forKey: .employee)
        group = try container.decodeIfPresent(StudyGroup.self, forKey: .group)

        let startDateRaw = try container.decodeIfPresent(String.self, forKey: .startDate)
        let endDateRaw = try container.decodeIfPresent(String.self, forKey: .endDate)
        let startExamsRaw = try container.decodeIfPresent(String.self, forKey: .startExamsDate)
        let endExamsRaw = try container.decodeIfPresent(String.self, forKey: .endExamsDate)
        startDate = dateParser.date(from: startDateRaw)
        endDate = dateParser.date(from: endDateRaw)
        startExamsDate = dateParser.date(from: startExamsRaw)
        endExamsDate = dateParser.date(from: endExamsRaw)

        exams = (try container.decodeIfPresent([DisciplineSchedule].self, forKey: .exams) ?? [])
            .sorted(by: DisciplineSchedule.sortingComparator)

        let rawSchedules = try container.decodeIfPresent([String: [DisciplineSchedule]].self, forKey: .schedules) ?? [:]
        let rawPreviousSchedules = try container.decodeIfPresent([String: [DisciplineSchedule]].self, forKey: .previousSchedules) ?? [:]
        let rawNextSchedules = try container.decodeIfPresent([String: [DisciplineSchedule]].self, forKey: .nextSchedules) ?? [:]

        scheduleByWeekday = Self.mapSchedule(rawSchedules)
        previousScheduleByWeekday = Self.mapSchedule(rawPreviousSchedules)
        nextScheduleByWeekday = Self.mapSchedule(rawNextSchedules)
    }

    var orderedDays: [StudyDaySchedule] {
        let source = actualScheduleByWeekday
        return StudyWeekday.displayOrder.compactMap { weekday in
            guard let lessons = source[weekday], !lessons.isEmpty else { return nil }
            return StudyDaySchedule(weekday: weekday, lessons: lessons)
        }
    }

    var availableWeekNumbers: [Int] {
        var result = Set<Int>()
        for day in orderedDays {
            for lesson in day.lessons {
                result.formUnion(lesson.weekNumbers)
            }
        }
        for exam in exams {
            result.formUnion(exam.weekNumbers)
        }
        return Array(result).sorted()
    }

    func isSchedulePublicationPending(referenceDate: Date = Date()) -> Bool {
        if scheduleByWeekday.isEmpty, nextScheduleByWeekday.isEmpty, exams.isEmpty {
            return true
        }

        guard !scheduleByWeekday.isEmpty, nextScheduleByWeekday.isEmpty, exams.isEmpty,
              let endDate else {
            return false
        }

        let calendar = Calendar.current
        let endExclusive = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: endDate)
        ) ?? endDate
        return referenceDate >= endExclusive
    }

    private var actualScheduleByWeekday: [StudyWeekday: [DisciplineSchedule]] {
        if !scheduleByWeekday.isEmpty {
            return scheduleByWeekday
        }
        if !nextScheduleByWeekday.isEmpty {
            return nextScheduleByWeekday
        }
        return [:]
    }

    private static func mapSchedule(_ rawValue: [String: [DisciplineSchedule]]) -> [StudyWeekday: [DisciplineSchedule]] {
        var mapped: [StudyWeekday: [DisciplineSchedule]] = [:]
        for (weekdayRaw, lessons) in rawValue {
            guard let weekday = StudyWeekday(rawValue: weekdayRaw) else { continue }
            mapped[weekday] = lessons.sorted(by: DisciplineSchedule.sortingComparator)
        }
        return mapped
    }
}

enum ServiceJSONValue: Codable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: ServiceJSONValue])
    case array([ServiceJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: ServiceJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([ServiceJSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var scalarText: String? {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(format: "%.2f", value)
        case .bool(let value):
            return value ? "true" : "false"
        case .null, .object, .array:
            return nil
        }
    }

    var shortText: String {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(format: "%.2f", value)
        case .bool(let value):
            return value ? "Да" : "Нет"
        case .array(let values):
            return "Массив (\(values.count))"
        case .object(let object):
            return "Объект (\(object.count) полей)"
        case .null:
            return "—"
        }
    }
}

struct ServiceJSONObject: Codable, Hashable {
    let fields: [String: ServiceJSONValue]

    init(fields: [String: ServiceJSONValue]) {
        self.fields = fields
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.fields = try container.decode([String: ServiceJSONValue].self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(fields)
    }
}

struct ServiceJSONObjectPage: Decodable, Equatable {
    let content: [ServiceJSONObject]
    let totalElements: Int
    let totalPages: Int
    let number: Int
    let size: Int
    let isLast: Bool
    let isEmpty: Bool

    enum CodingKeys: String, CodingKey {
        case content
        case totalElements
        case totalPages
        case number
        case size
        case isLast = "last"
        case isEmpty = "empty"
    }
}

extension ServiceJSONObject {
    var stableID: String {
        if let id = fields["id"]?.scalarText {
            return id
        }
        if let title = fields["title"]?.scalarText {
            return title
        }
        let chunks = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.shortText)" }
        return chunks.joined(separator: "|")
    }

    var primaryText: String {
        if let value = fields["title"]?.scalarText, !value.isEmpty {
            return value
        }
        if let value = fields["name"]?.scalarText, !value.isEmpty {
            return value
        }
        if let value = fields["content"]?.scalarText, !value.isEmpty {
            return value
        }
        if let value = fields["description"]?.scalarText, !value.isEmpty {
            return value
        }
        if let value = fields["text"]?.scalarText, !value.isEmpty {
            return value
        }
        return stableID
    }

    var secondaryText: String? {
        if let value = fields["status"]?.scalarText, !value.isEmpty {
            return value
        }
        if let value = fields["date"]?.scalarText, !value.isEmpty {
            return value
        }
        if let value = fields["createdDate"]?.scalarText, !value.isEmpty {
            return value
        }
        return nil
    }

    var detailPairs: [(String, String)] {
        fields
            .filter { !$0.key.hasPrefix("_") }
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value.shortText) }
    }
}
