import Foundation

/// Shared lesson representation for personal performance and public student rating.
struct RatingLessonMark: Codable, Equatable, Sendable {
    let mark: Int
    let taskNumber: Int?

    init(mark: Int, taskNumber: Int? = nil) {
        self.mark = mark
        self.taskNumber = taskNumber
    }

    init(from decoder: Decoder) throws {
        if let singleVal = try? decoder.singleValueContainer(), let intVal = try? singleVal.decode(Int.self) {
            self.mark = intVal
            self.taskNumber = nil
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mark = (try? container.decode(Int.self, forKey: .mark)) ?? 0
        self.taskNumber = try? container.decodeIfPresent(Int.self, forKey: .taskNumber)
    }
}

struct RatingPercentageMark: Codable, Equatable, Sendable {
    let discipline: String
    let date: String
    let number: Double
}

struct RatingLesson: Decodable, Sendable {
    let id: Int
    let dateString: String
    let gradeBookOmissions: Int
    let isRespectfulOmission: Bool
    let lessonTypeId: Int
    let lessonTypeAbbrev: String
    let lessonNameAbbrev: String
    let lessonName: String?
    let subGroup: Int
    let marks: [Int]
    let markDetails: [RatingLessonMark]
    let controlPoint: String

    private enum CodingKeys: String, CodingKey {
        case id
        case dateString
        case gradebookOmissions
        case gradeBookOmissions
        case isRespectfulOmission
        case lessonTypeId
        case lessonTypeAbbrev
        case lessonNameAbbrev
        case lessonName
        case subGroup
        case marks
        case controlPoint
    }

    init(
        id: Int,
        dateString: String,
        gradeBookOmissions: Int,
        isRespectfulOmission: Bool,
        lessonTypeId: Int,
        lessonTypeAbbrev: String,
        lessonNameAbbrev: String,
        lessonName: String? = nil,
        subGroup: Int,
        marks: [Int],
        markDetails: [RatingLessonMark]? = nil,
        controlPoint: String
    ) {
        self.id = id
        self.dateString = dateString
        self.gradeBookOmissions = gradeBookOmissions
        self.isRespectfulOmission = isRespectfulOmission
        self.lessonTypeId = lessonTypeId
        self.lessonTypeAbbrev = lessonTypeAbbrev
        self.lessonNameAbbrev = lessonNameAbbrev
        self.lessonName = lessonName
        self.subGroup = subGroup
        self.marks = marks
        self.markDetails = markDetails ?? marks.map { RatingLessonMark(mark: $0) }
        self.controlPoint = controlPoint
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(Int.self, forKey: .id)) ?? 0
        self.dateString = (try? container.decode(String.self, forKey: .dateString)) ?? ""
        let omissions = try? container.decodeIfPresent(Int.self, forKey: .gradebookOmissions)
        let legacyOmissions = try? container.decodeIfPresent(Int.self, forKey: .gradeBookOmissions)
        self.gradeBookOmissions = omissions ?? legacyOmissions ?? 0
        self.isRespectfulOmission = (try? container.decode(Bool.self, forKey: .isRespectfulOmission)) ?? false
        self.lessonTypeId = (try? container.decode(Int.self, forKey: .lessonTypeId)) ?? 0
        self.lessonTypeAbbrev = (try? container.decode(String.self, forKey: .lessonTypeAbbrev)) ?? ""
        self.lessonNameAbbrev = (try? container.decode(String.self, forKey: .lessonNameAbbrev)) ?? ""
        self.lessonName = try? container.decodeIfPresent(String.self, forKey: .lessonName)
        self.subGroup = (try? container.decode(Int.self, forKey: .subGroup)) ?? 0

        let decodedDetails = (try? container.decode([RatingLessonMark].self, forKey: .marks)) ?? []
        self.markDetails = decodedDetails
        self.marks = decodedDetails.map(\.mark)

        self.controlPoint = (try? container.decode(String.self, forKey: .controlPoint)) ?? ""
    }
}
