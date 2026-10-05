import Foundation

public struct PinnedTeacher: Codable, Identifiable, Hashable, Sendable {
    public let urlId: String
    public let name: String
    public let photoLink: String?

    public var id: String { urlId }

    public init(urlId: String, name: String, photoLink: String? = nil) {
        self.urlId = urlId
        self.name = name
        self.photoLink = photoLink
    }
}

enum ScheduleLookupMode: String, CaseIterable, Identifiable {
    case group
    case teacher

    var id: String { rawValue }

    var title: String {
        switch self {
        case .group:
            return NSLocalizedString("services_schedule_mode_group", value: "Группа", comment: "")
        case .teacher:
            return NSLocalizedString("services_schedule_mode_teacher", value: "Преподаватель", comment: "")
        }
    }
}

enum ScheduleDisplayMode: String, CaseIterable, Identifiable {
    case continuous
    case byDay
    case exams

    var id: String { rawValue }

    var title: String {
        switch self {
        case .continuous:
            return NSLocalizedString("services_schedule_display_continuous", value: "Поток дней", comment: "")
        case .byDay:
            return NSLocalizedString("services_schedule_display_day", value: "По дням", comment: "")
        case .exams:
            return NSLocalizedString("services_schedule_display_exams", value: "Экзамены", comment: "")
        }
    }
}

enum ScheduleDataSource: String, CaseIterable, Identifiable {
    case api
    case localJSON

    var id: String { rawValue }

    var title: String {
        switch self {
        case .api:
            return NSLocalizedString("services_schedule_source_api", value: "ИИС БГУИР", comment: "")
        case .localJSON:
            return NSLocalizedString("services_schedule_source_local_json", value: "Локальный JSON", comment: "")
        }
    }
}

enum ScheduleSubgroupFilter: Hashable, Identifiable {
    case all
    case subgroup(Int)

    var id: String {
        switch self {
        case .all: return "all"
        case .subgroup(let value): return "subgroup_\(value)"
        }
    }

    var localizedTitle: String {
        switch self {
        case .all:
            return NSLocalizedString("services_schedule_subgroup_all", value: "Все подгруппы", comment: "")
        case .subgroup(let value):
            return String(format: NSLocalizedString("services_schedule_subgroup_format", value: "%d подгруппа", comment: ""), value)
        }
    }

    var shortTitle: String {
        switch self {
        case .all:
            return NSLocalizedString("services_schedule_subgroup_short_all", value: "Все", comment: "")
        case .subgroup(let value):
            return "\(value)"
        }
    }
}

struct ScheduleLanguageSubgroup: Identifiable, Sendable {
    let id: Int
    let number: Int
    let teacherName: String

    var title: String {
        ScheduleSubgroupFilter.subgroup(number).localizedTitle + " · " + teacherName
    }
}

struct ScheduleSubjectSubgroups: Identifiable, Sendable {
    let id: String
    let title: String
    let options: [ScheduleLanguageSubgroup]
    let lessonTypes: Set<String>
}

struct ScheduleContinuousDay: Identifiable, Sendable {
    let date: Date
    let weekday: StudyWeekday
    let weekNumber: Int
    let lessons: [DisciplineSchedule]

    var id: String {
        "\(weekday.rawValue)|\(date.timeIntervalSince1970)|\(weekNumber)"
    }
}

struct ExamScheduleDay: Identifiable, Sendable {
    let date: Date
    let weekday: StudyWeekday?
    let lessons: [DisciplineSchedule]

    var id: String {
        "\(date.timeIntervalSince1970)"
    }
}

extension StudyWeekFilter {
    var localizedTitle: String {
        switch self {
        case .all:
            return NSLocalizedString("services_schedule_subgroup_short_all", value: "Все", comment: "")
        case .week(let value):
            return "\(value)"
        }
    }
}

extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

extension Optional where Wrapped == String {
    var nilIfBlank: String? {
        self?.nilIfBlank
    }
}
