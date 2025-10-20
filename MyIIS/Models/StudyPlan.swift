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
                let key = lesson.subjectFullName?.isEmpty == false ? lesson.subjectFullName! : lesson.subject
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

struct StudyGroup: Decodable, Equatable {
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

struct StudyDaySchedule: Identifiable, Equatable {
    let weekday: StudyWeekday
    let lessons: [DisciplineSchedule]

    var id: StudyWeekday { weekday }
}

enum StudyWeekday: String, CaseIterable, Decodable, Identifiable {
    case monday = "Понедельник"
    case tuesday = "Вторник"
    case wednesday = "Среда"
    case thursday = "Четверг"
    case friday = "Пятница"
    case saturday = "Суббота"
    case sunday = "Воскресенье"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .monday: return "Пн"
        case .tuesday: return "Вт"
        case .wednesday: return "Ср"
        case .thursday: return "Чт"
        case .friday: return "Пт"
        case .saturday: return "Сб"
        case .sunday: return "Вс"
        }
    }

    static var displayOrder: [StudyWeekday] {
        [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }
}

struct DisciplineSchedule: Decodable, Identifiable, Equatable {
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
    let weekNumbers: [Int]
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
        weekNumbers = try container.decodeIfPresent([Int].self, forKey: .weekNumbers) ?? []
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

    var title: String { subjectFullName?.isEmpty == false ? subjectFullName! : subject }

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

    static func sortingComparator(lhs: DisciplineSchedule, rhs: DisciplineSchedule) -> Bool {
        if lhs.startLessonTime == rhs.startLessonTime {
            return lhs.endLessonTime < rhs.endLessonTime
        }
        return lhs.startLessonTime < rhs.startLessonTime
    }
}

struct DisciplineStudentGroup: Decodable, Equatable {
    let specialityName: String?
    let specialityCode: String?
    let numberOfStudents: Int?
    let name: String?
    let educationDegree: Int?
}

struct DisciplineEmployee: Decodable, Equatable, Identifiable {
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
            if let name = lesson.employees.first?.fullName, !name.isEmpty {
                teachers.insert(name)
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
            return "Все недели"
        case .week(let value):
            return "Неделя \(value)"
        }
    }
}

// MARK: - Date Parser

private final class StudyPlanDateParser {
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

#if DEBUG
extension StudyPlan {
    static let mock: StudyPlan = {
        let formatter = StudyPlanDateParser.shared
        let start = formatter.date(from: "01.09.2025")
        let end = formatter.date(from: "28.12.2025")
        let examsStart = formatter.date(from: "29.12.2025")
        let examsEnd = formatter.date(from: "25.01.2026")

        let teacher = DisciplineEmployee(
            id: 1,
            firstName: "Андрей",
            middleName: "Константинович",
            lastName: "Ючков",
            photoLink: nil,
            degree: nil,
            degreeAbbrev: nil,
            rank: nil,
            email: nil,
            urlId: nil,
            calendarId: nil,
            jobPositions: nil,
            isChief: nil
        )

        let oop = DisciplineSchedule(
            id: UUID().uuidString,
            auditories: ["605-5 к."],
            endLessonTime: "11:30",
            lessonTypeAbbrev: "ЛР",
            note: nil,
            subgroup: 0,
            startLessonTime: "10:05",
            studentGroups: [],
            subject: "ООП",
            subjectFullName: "Объектно-ориентированное программирование",
            weekNumbers: [1, 3],
            employees: [teacher],
            lessonDate: nil,
            startLessonDate: formatter.date(from: "06.09.2025"),
            endLessonDate: formatter.date(from: "27.12.2025"),
            isAnnouncement: false,
            isSplit: false
        )

        let graphs = DisciplineSchedule(
            id: UUID().uuidString,
            auditories: ["601б-5 к."],
            endLessonTime: "09:55",
            lessonTypeAbbrev: "ПЗ",
            note: nil,
            subgroup: 0,
            startLessonTime: "08:30",
            studentGroups: [],
            subject: "ТГ",
            subjectFullName: "Теория графов",
            weekNumbers: [1, 3],
            employees: [teacher],
            lessonDate: nil,
            startLessonDate: formatter.date(from: "06.09.2025"),
            endLessonDate: formatter.date(from: "27.12.2025"),
            isAnnouncement: false,
            isSplit: false
        )

        let schedule: [StudyWeekday: [DisciplineSchedule]] = [
            .saturday: [graphs, oop]
        ]

        return StudyPlan(
            startDate: start,
            endDate: end,
            startExamsDate: examsStart,
            endExamsDate: examsEnd,
            group: StudyGroup(
                name: "420603",
                facultyId: 20005,
                facultyAbbrev: "ФИТУ",
                facultyName: "Факультет информационных технологий и управления",
                specialityDepartmentEducationFormId: 20835,
                specialityName: "Системы управления информацией",
                specialityAbbrev: "СУИ (АСОИ)",
                course: 2,
                id: 24930,
                calendarId: nil,
                educationDegree: 1
            ),
            schedule: schedule
        )
    }()
}
#endif
