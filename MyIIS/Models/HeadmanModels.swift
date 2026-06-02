import Foundation

struct HeadmanStudent: Codable, Identifiable, Hashable {
    let id: Int
    let fio: String
    let username: String
    var isResponsible: Bool?
}

struct HeadmanSubjectLesson: Codable, Identifiable, Hashable {
    let id: Int
    let lessonTypeAbbrev: String
    let subgroup: [Int]
}

struct HeadmanSubjectOption: Identifiable, Hashable {
    let subjectName: String
    let lesson: HeadmanSubjectLesson

    var id: Int { lesson.id }

    var title: String {
        "\(subjectName) \(lesson.lessonTypeAbbrev)"
    }
}

struct HeadmanLessonsByDateResponse: Decodable {
    let lessons: [HeadmanLesson]

    enum CodingKeys: String, CodingKey {
        case lessons
    }

    init(from decoder: Decoder) throws {
        if let keyed = try? decoder.container(keyedBy: CodingKeys.self),
           let lessons = try keyed.decodeIfPresent([HeadmanLesson].self, forKey: .lessons) {
            self.lessons = lessons
            return
        }

        var arrayContainer = try decoder.unkeyedContainer()
        var decodedLessons: [HeadmanLesson] = []
        while !arrayContainer.isAtEnd {
            decodedLessons.append(try arrayContainer.decode(HeadmanLesson.self))
        }
        self.lessons = decodedLessons
    }
}

struct HeadmanLesson: Decodable, Identifiable, Hashable {
    let id: Int
    let dateString: String
    let nameAbbrev: String
    let lessonTypeAbbrev: String
    let lessonPeriod: HeadmanLessonPeriod?
    let subGroup: Int
    var students: [HeadmanLessonStudent]
}

struct HeadmanLessonPeriod: Decodable, Hashable {
    let lessonPeriodHours: Int
    let startTime: String
    let endTime: String
}

struct HeadmanLessonStudent: Decodable, Identifiable, Hashable {
    let id: Int
    let fio: String
    var omission: HeadmanOmission?
    let inOffsettingValue: Int?
    let isNotStudying: Bool?
}

struct HeadmanOmission: Decodable, Hashable {
    let missedHours: Int?
    let respectfulOmission: Bool?

    enum CodingKeys: String, CodingKey {
        case missedHours
        case hours
        case respectfulOmission
        case isRespectfulOmission
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        missedHours = try container.decodeIfPresent(Int.self, forKey: .missedHours)
            ?? container.decodeIfPresent(Int.self, forKey: .hours)
        respectfulOmission = try container.decodeIfPresent(Bool.self, forKey: .respectfulOmission)
            ?? container.decodeIfPresent(Bool.self, forKey: .isRespectfulOmission)
    }
}

struct HeadmanSummaryResponse: Decodable, Hashable {
    let students: [HeadmanSummaryStudent]
}

struct HeadmanSummaryStudent: Decodable, Identifiable, Hashable {
    let id: Int
    let fio: String
    let subGroup: Int?
    let subGroupStudent: Int?
    let lessons: [HeadmanSummaryLesson]

    var totalMissedHours: Int {
        lessons.reduce(0) { $0 + $1.gradeBookOmissions }
    }
}

struct HeadmanSummaryLesson: Decodable, Identifiable, Hashable {
    let id: Int
    let dateString: String
    let gradeBookOmissions: Int
    let isRespectfulOmission: Bool
    let lessonTypeId: Int
    let lessonTypeAbbrev: String
    let lessonNameAbbrev: String
    let subGroup: Int
    let marks: [Int]
    let controlPoint: String?
}

struct HeadmanCreateOmissionRequest: Encodable {
    let studentOmissionsHoursDtoList: [HeadmanStudentOmissionHours]
    let idLesson: Int
}

struct HeadmanStudentOmissionHours: Encodable, Hashable {
    let student: Int
    let hours: Int
}

struct HeadmanAssignResponsibleRequest: Encodable {
    let studentIds: [Int]
    let studentFlags: [Bool]
}

enum HeadmanLessonCategory: String, CaseIterable {
    case lecture = "ЛК"
    case lab = "ЛР"
    case practice = "ПЗ"

    init?(lessonTypeAbbrev: String) {
        let normalized = lessonTypeAbbrev.uppercased()
        if normalized.contains("ЛК") {
            self = .lecture
        } else if normalized.contains("ЛР") {
            self = .lab
        } else if normalized.contains("ПЗ") {
            self = .practice
        } else {
            return nil
        }
    }
}

struct HeadmanWeeklyTotals: Hashable {
    var respectfulByCategory: [HeadmanLessonCategory: Int] = [:]
    var unrespectfulByCategory: [HeadmanLessonCategory: Int] = [:]

    mutating func add(hours: Int, isRespectful: Bool, category: HeadmanLessonCategory) {
        guard hours > 0 else { return }
        if isRespectful {
            respectfulByCategory[category, default: 0] += hours
        } else {
            unrespectfulByCategory[category, default: 0] += hours
        }
    }

    func respectfulHours(for category: HeadmanLessonCategory) -> Int {
        respectfulByCategory[category, default: 0]
    }

    func unrespectfulHours(for category: HeadmanLessonCategory) -> Int {
        unrespectfulByCategory[category, default: 0]
    }

    var respectfulTotal: Int {
        respectfulByCategory.values.reduce(0, +)
    }

    var unrespectfulTotal: Int {
        unrespectfulByCategory.values.reduce(0, +)
    }
}

struct HeadmanWeeklyStudentSummary: Identifiable, Hashable {
    let id: Int
    let fio: String
    let totals: HeadmanWeeklyTotals
}
