import Foundation

// MARK: - Study Plan Models

struct StudyPlan: Decodable, Equatable {
    let startDate: Date?
    let endDate: Date?
    let startExamsDate: Date?
    let endExamsDate: Date?
    let group: StudyGroup?
    private let scheduleByWeekday: [StudyWeekday: [DisciplineSchedule]]

    enum CodingKeys: String, CodingKey {
        case startDate
        case endDate
        case startExamsDate
        case endExamsDate
        case group = "studentGroupDto"
        case schedules
    }

    init(
        startDate: Date?,
        endDate: Date?,
        startExamsDate: Date?,
        endExamsDate: Date?,
        group: StudyGroup?,
        schedule: [StudyWeekday: [DisciplineSchedule]]
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.startExamsDate = startExamsDate
        self.endExamsDate = endExamsDate
        self.group = group
        self.scheduleByWeekday = schedule
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dateParser = StudyPlanDateParser.shared

        let startDateString = try container.decodeIfPresent(String.self, forKey: .startDate)
        let endDateString = try container.decodeIfPresent(String.self, forKey: .endDate)
        let startExamsString = try container.decodeIfPresent(String.self, forKey: .startExamsDate)
        let endExamsString = try container.decodeIfPresent(String.self, forKey: .endExamsDate)

        startDate = dateParser.date(from: startDateString)
        endDate = dateParser.date(from: endDateString)
        startExamsDate = dateParser.date(from: startExamsString)
        endExamsDate = dateParser.date(from: endExamsString)
        group = try container.decodeIfPresent(StudyGroup.self, forKey: .group)

        let rawSchedules = try container.decodeIfPresent([String: [DisciplineSchedule]].self, forKey: .schedules) ?? [:]
        var mappedSchedule: [StudyWeekday: [DisciplineSchedule]] = [:]

        for (weekdayRaw, lessons) in rawSchedules {
            guard let weekday = StudyWeekday(rawValue: weekdayRaw) else { continue }
            mappedSchedule[weekday] = lessons.sorted(by: DisciplineSchedule.sortingComparator)
        }

        scheduleByWeekday = mappedSchedule
    }

    var availableWeekNumbers: [Int] {
        var weekSet = Set<Int>()
        for lessons in scheduleByWeekday.values {
            for lesson in lessons {
                weekSet.formUnion(lesson.weekNumbers)
            }
        }
        return Array(weekSet).sorted()
    }

    var isEmpty: Bool { scheduleByWeekday.isEmpty }

    func lessons(for weekday: StudyWeekday, filter: StudyWeekFilter) -> [DisciplineSchedule] {
        guard let lessons = scheduleByWeekday[weekday] else { return [] }
        switch filter {
        case .all:
            return lessons
        case .week(let number):
            return lessons.filter { $0.weekNumbers.isEmpty || $0.weekNumbers.contains(number) }
        }
    }

    func orderedSchedule(filter: StudyWeekFilter) -> [StudyDaySchedule] {
        StudyWeekday.displayOrder.compactMap { weekday in
            let lessons = lessons(for: weekday, filter: filter)
            guard !lessons.isEmpty else { return nil }
            return StudyDaySchedule(weekday: weekday, lessons: lessons)
        }
    }

    func currentWeekNumber(reference date: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard let startDate else { return nil }
        let calendar = calendar
        let startOfReference = calendar.startOfDay(for: date)
        let startOfTerm = calendar.startOfDay(for: startDate)
        guard let weeks = calendar.dateComponents([.weekOfYear], from: startOfTerm, to: startOfReference).weekOfYear else {
            return nil
        }
        let calculated = weeks + 1
        return calculated > 0 ? calculated : nil
    }

    func uniqueDisciplines() -> [DisciplineSummary] {
        var storage: [String: DisciplineSummary.Builder] = [:]

        for lessons in scheduleByWeekday.values {
            for lesson in lessons {
                let key = lesson.subjectFullName.flatMap { $0.isEmpty ? nil : $0 } ?? lesson.subject
                var builder = storage[key, default: DisciplineSummary.Builder(subject: key)]
                builder.add(lesson: lesson)
                storage[key] = builder
            }
        }

        return storage.values
            .map { $0.build() }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}
// MARK: - Supporting Models

struct StudyGroup: Decodable, Equatable, Sendable {
    let name: String
    let facultyId: Int?
    let facultyAbbrev: String?
    let facultyName: String?
    let specialityDepartmentEducationFormId: Int?
    let specialityName: String?
    let specialityAbbrev: String?
    let course: Int?
    let id: Int?
    let calendarId: String?
    let educationDegree: Int?
}

struct StudyDaySchedule: Identifiable, Equatable, Sendable {
    let weekday: StudyWeekday
    let lessons: [DisciplineSchedule]

    var id: StudyWeekday { weekday }
}

enum StudyWeekday: String, CaseIterable, Decodable, Identifiable, Sendable {
    case monday = "Понедельник"
    case tuesday = "Вторник"
    case wednesday = "Среда"
    case thursday = "Четверг"
    case friday = "Пятница"
    case saturday = "Суббота"
    case sunday = "Воскресенье"

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .monday: return NSLocalizedString("weekday_monday", value: "Понедельник", comment: "")
        case .tuesday: return NSLocalizedString("weekday_tuesday", value: "Вторник", comment: "")
        case .wednesday: return NSLocalizedString("weekday_wednesday", value: "Среда", comment: "")
        case .thursday: return NSLocalizedString("weekday_thursday", value: "Четверг", comment: "")
        case .friday: return NSLocalizedString("weekday_friday", value: "Пятница", comment: "")
        case .saturday: return NSLocalizedString("weekday_saturday", value: "Суббота", comment: "")
        case .sunday: return NSLocalizedString("weekday_sunday", value: "Воскресенье", comment: "")
        }
    }

    var shortTitle: String {
        switch self {
        case .monday: return NSLocalizedString("weekday_monday_short", value: "Пн", comment: "")
        case .tuesday: return NSLocalizedString("weekday_tuesday_short", value: "Вт", comment: "")
        case .wednesday: return NSLocalizedString("weekday_wednesday_short", value: "Ср", comment: "")
        case .thursday: return NSLocalizedString("weekday_thursday_short", value: "Чт", comment: "")
        case .friday: return NSLocalizedString("weekday_friday_short", value: "Пт", comment: "")
        case .saturday: return NSLocalizedString("weekday_saturday_short", value: "Сб", comment: "")
        case .sunday: return NSLocalizedString("weekday_sunday_short", value: "Вс", comment: "")
        }
    }

    static var displayOrder: [StudyWeekday] {
        [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }
}

struct DisciplineSchedule: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let auditories: [String]
    let endLessonTime: String
    let lessonTypeAbbrev: String
    let note: String?
    let subgroup: Int
    let startLessonTime: String
    let studentGroups: [DisciplineStudentGroup]
    let subject: String
    let subjectFullName: String?
    var weekNumbers: [Int]
    let employees: [DisciplineEmployee]
    let lessonDate: Date?
    let startLessonDate: Date?
    let endLessonDate: Date?
    let isAnnouncement: Bool
    let isSplit: Bool

    enum CodingKeys: String, CodingKey {
        case auditories
        case endLessonTime
        case lessonTypeAbbrev
        case note
        case subgroup = "numSubgroup"
        case startLessonTime
        case studentGroups
        case subject
        case subjectFullName
        case weekNumbers = "weekNumber"
        case employees
        case lessonDate = "dateLesson"
        case startLessonDate
        case endLessonDate
        case isAnnouncement = "announcement"
        case isSplit = "split"
    }

    init(
        id: String,
        auditories: [String],
        endLessonTime: String,
        lessonTypeAbbrev: String,
        note: String?,
        subgroup: Int,
        startLessonTime: String,
        studentGroups: [DisciplineStudentGroup],
        subject: String,
        subjectFullName: String?,
        weekNumbers: [Int],
        employees: [DisciplineEmployee],
        lessonDate: Date?,
        startLessonDate: Date?,
        endLessonDate: Date?,
        isAnnouncement: Bool,
        isSplit: Bool
    ) {
        self.id = id
        self.auditories = auditories
        self.endLessonTime = endLessonTime
        self.lessonTypeAbbrev = lessonTypeAbbrev
        self.note = note
        self.subgroup = subgroup
        self.startLessonTime = startLessonTime
        self.studentGroups = studentGroups
        self.subject = subject
        self.subjectFullName = subjectFullName
        self.weekNumbers = weekNumbers
        self.employees = employees
        self.lessonDate = lessonDate
        self.startLessonDate = startLessonDate
        self.endLessonDate = endLessonDate
        self.isAnnouncement = isAnnouncement
        self.isSplit = isSplit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dateParser = StudyPlanDateParser.shared

        auditories = try container.decodeIfPresent([String].self, forKey: .auditories) ?? []
        endLessonTime = try container.decodeIfPresent(String.self, forKey: .endLessonTime) ?? ""
        lessonTypeAbbrev = try container.decodeIfPresent(String.self, forKey: .lessonTypeAbbrev) ?? ""
        note = try container.decodeIfPresent(String.self, forKey: .note)
        subgroup = try container.decodeIfPresent(Int.self, forKey: .subgroup) ?? 0
        startLessonTime = try container.decodeIfPresent(String.self, forKey: .startLessonTime) ?? ""
        studentGroups = try container.decodeIfPresent([DisciplineStudentGroup].self, forKey: .studentGroups) ?? []
        subject = try container.decodeIfPresent(String.self, forKey: .subject) ?? ""
        subjectFullName = try container.decodeIfPresent(String.self, forKey: .subjectFullName)
        if let arrayValue = try? container.decodeIfPresent([Int].self, forKey: .weekNumbers) {
            weekNumbers = arrayValue
        } else if let singleValue = try? container.decodeIfPresent(Int.self, forKey: .weekNumbers) {
            if singleValue == 0 {
                weekNumbers = [1, 2, 3, 4]
            } else {
                weekNumbers = [singleValue]
            }
        } else {
            weekNumbers = []
        }
        employees = try container.decodeIfPresent([DisciplineEmployee].self, forKey: .employees) ?? []
        let lessonDateString = try container.decodeIfPresent(String.self, forKey: .lessonDate)
        let startLessonDateString = try container.decodeIfPresent(String.self, forKey: .startLessonDate)
        let endLessonDateString = try container.decodeIfPresent(String.self, forKey: .endLessonDate)
        lessonDate = dateParser.date(from: lessonDateString)
        startLessonDate = dateParser.date(from: startLessonDateString)
        endLessonDate = dateParser.date(from: endLessonDateString)
        isAnnouncement = try container.decodeIfPresent(Bool.self, forKey: .isAnnouncement) ?? false
        isSplit = try container.decodeIfPresent(Bool.self, forKey: .isSplit) ?? false

        let identifierSource = [subjectFullName ?? subject, startLessonTime, endLessonTime, weekNumbers.description].joined(separator: "|")
        id = identifierSource.isEmpty ? UUID().uuidString : identifierSource
    }

    var title: String {
        if isAnnouncement {
            return "📣 \(NSLocalizedString("local_schedule_type_announcement", value: "Объявление", comment: ""))"
        }
        if let subject = subject.nilIfBlank {
            return subject
        }
        if let subjectFullName = subjectFullName?.nilIfBlank {
            return subjectFullName
        }
        return lessonTypeAbbrev.nilIfBlank ?? "Событие"
    }

    var fullTitle: String {
        if isAnnouncement {
            return "📣 \(NSLocalizedString("local_schedule_type_announcement", value: "Объявление", comment: ""))"
        }
        if let subjectFullName = subjectFullName?.nilIfBlank {
            return subjectFullName
        }
        if let subject = subject.nilIfBlank {
            return subject
        }
        return lessonTypeAbbrev.nilIfBlank ?? "Событие"
    }

    var subtitle: String {
        if let employee = employees.first {
            return employee.fullName
        }
        return lessonTypeAbbrev
    }

    var timeRange: String {
        guard !startLessonTime.isEmpty, !endLessonTime.isEmpty else { return "" }
        return "\(startLessonTime) – \(endLessonTime)"
    }

    var location: String {
        auditories.joined(separator: ", ")
    }

    nonisolated func isScheduled(on date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)

        if let lessonDate {
            return calendar.isDate(lessonDate, inSameDayAs: day)
        }

        if let startLessonDate, let endLessonDate {
            let startDay = calendar.startOfDay(for: startLessonDate)
            let endDay = calendar.startOfDay(for: endLessonDate)
            let lowerBound = min(startDay, endDay)
            let upperBound = max(startDay, endDay)
            return lowerBound <= day && day <= upperBound
        }

        if let startLessonDate {
            return day >= calendar.startOfDay(for: startLessonDate)
        }

        if let endLessonDate {
            return day <= calendar.startOfDay(for: endLessonDate)
        }

        return true
    }

    nonisolated static func sortingComparator(lhs: DisciplineSchedule, rhs: DisciplineSchedule) -> Bool {
        if lhs.startLessonTime == rhs.startLessonTime {
            return lhs.endLessonTime < rhs.endLessonTime
        }
        return lhs.startLessonTime < rhs.startLessonTime
    }
}

struct DisciplineStudentGroup: Decodable, Equatable, Sendable {
    let specialityName: String?
    let specialityCode: String?
    let numberOfStudents: Int?
    let name: String?
    let educationDegree: Int?
}

struct DisciplineEmployee: Decodable, Equatable, Identifiable, Sendable {
    let id: Int
    let firstName: String?
    let middleName: String?
    let lastName: String?
    let photoLink: String?
    let degree: String?
    let degreeAbbrev: String?
    let rank: String?
    let email: String?
    let urlId: String?
    let calendarId: String?
    let jobPositions: String?
    let isChief: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName
        case middleName
        case lastName
        case photoLink
        case degree
        case degreeAbbrev
        case rank
        case email
        case urlId
        case calendarId
        case jobPositions
        case isChief = "chief"
    }

    var fullName: String {
        let components = [lastName, firstName, middleName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return components.joined(separator: " ")
    }
}

// MARK: - Discipline Summary

struct DisciplineSummary: Identifiable, Equatable {
    let id: UUID
    let title: String
    let lessonTypes: [String]
    let teachers: [String]
    let weeks: [Int]

    fileprivate init(id: UUID = UUID(), title: String, lessonTypes: [String], teachers: [String], weeks: [Int]) {
        self.id = id
        self.title = title
        self.lessonTypes = lessonTypes
        self.teachers = teachers
        self.weeks = weeks
    }

    fileprivate struct Builder {
        private(set) var title: String
        private var lessonTypes: Set<String> = []
        private var teachers: Set<String> = []
        private var weeks: Set<Int> = []

        init(subject: String) {
            self.title = subject
        }

        mutating func add(lesson: DisciplineSchedule) {
            if !lesson.lessonTypeAbbrev.isEmpty {
                lessonTypes.insert(lesson.lessonTypeAbbrev)
            }
            for employee in lesson.employees {
                let name = employee.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    teachers.insert(name)
                }
            }
            weeks.formUnion(lesson.weekNumbers)
        }

        func build() -> DisciplineSummary {
            DisciplineSummary(
                title: title,
                lessonTypes: lessonTypes.sorted(),
                teachers: teachers.sorted(),
                weeks: weeks.sorted()
            )
        }
    }
}

// MARK: - Filters

enum StudyWeekFilter: Hashable, Identifiable {
    case all
    case week(Int)

    var id: String {
        switch self {
        case .all: return "all"
        case .week(let value): return "week_\(value)"
        }
    }

    var title: String {
        switch self {
        case .all:
            return NSLocalizedString("services_schedule_week_all", value: "Все недели", comment: "")
        case .week(let value):
            return String(format: NSLocalizedString("services_schedule_week_number", value: "Неделя %d", comment: ""), value)
        }
    }
}

// MARK: - Date Parser

final class StudyPlanDateParser {
    static let shared = StudyPlanDateParser()

    private let formatter: DateFormatter

    private init() {
        formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "dd.MM.yyyy"
    }

    func date(from value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        return formatter.date(from: value)
    }
}
