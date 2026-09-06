import Foundation

struct OmissionApplication: Codable, Identifiable {
    let id: Int
    let status: String
    let number: Int
    let createdDate: Date
    let rejectionReason: String?
    let omissionCertificateType: String
    let dateFrom: Date
    let dateTo: Date
    let placeOfStay: String?
    let signature: String?

    private enum CodingKeys: String, CodingKey {
        case id, status, number, rejectionReason, omissionCertificateType, placeOfStay, signature
        case createdDate, dateFrom, dateTo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        status = try container.decode(String.self, forKey: .status)
        number = try container.decode(Int.self, forKey: .number)
        rejectionReason = try container.decodeIfPresent(String.self, forKey: .rejectionReason)
        omissionCertificateType = try container.decode(String.self, forKey: .omissionCertificateType)
        placeOfStay = try container.decodeIfPresent(String.self, forKey: .placeOfStay)
        signature = try container.decodeIfPresent(String.self, forKey: .signature)
        createdDate = try container.decodeMillisecondsDate(forKey: .createdDate)
        dateFrom = try container.decodeMillisecondsDate(forKey: .dateFrom)
        dateTo = try container.decodeMillisecondsDate(forKey: .dateTo)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(status, forKey: .status)
        try container.encode(number, forKey: .number)
        try container.encodeIfPresent(rejectionReason, forKey: .rejectionReason)
        try container.encode(omissionCertificateType, forKey: .omissionCertificateType)
        try container.encodeIfPresent(placeOfStay, forKey: .placeOfStay)
        try container.encodeIfPresent(signature, forKey: .signature)
        // Store dates as time intervals (assuming decoding from Int or Double)
        try container.encode(Int(createdDate.timeIntervalSince1970 * 1000), forKey: .createdDate)
        try container.encode(Int(dateFrom.timeIntervalSince1970 * 1000), forKey: .dateFrom)
        try container.encode(Int(dateTo.timeIntervalSince1970 * 1000), forKey: .dateTo)
    }
}

struct OmissionCertificate: Codable, Identifiable {
    let id: Int
    let dateFrom: Date
    let dateTo: Date
    let note: String?
    let name: String
    let term: String

    private enum CodingKeys: String, CodingKey {
        case id, note, name, term
        case dateFrom, dateTo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        name = try container.decode(String.self, forKey: .name)

        if let termString = try? container.decode(String.self, forKey: .term) {
            term = termString
        } else if let termInt = try? container.decode(Int.self, forKey: .term) {
            term = String(termInt)
        } else {
            term = "0"
        }

        dateFrom = try container.decodeMillisecondsDate(forKey: .dateFrom)
        dateTo = try container.decodeMillisecondsDate(forKey: .dateTo)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encode(name, forKey: .name)
        try container.encode(term, forKey: .term)
        try container.encode(Int(dateFrom.timeIntervalSince1970 * 1000), forKey: .dateFrom)
        try container.encode(Int(dateTo.timeIntervalSince1970 * 1000), forKey: .dateTo)
    }
}

struct OmissionsByStudentResponse: Codable {
    let omissionDtoList: [OmissionCertificate]
    let faculty: String?

    private enum CodingKeys: String, CodingKey {
        case omissionDtoList
        case omissionList
        case omissions
        case faculty
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode([OmissionCertificate].self) {
            omissionDtoList = value
            faculty = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let value = try container.decodeIfPresent([OmissionCertificate].self, forKey: .omissionDtoList) {
            omissionDtoList = value
        } else if let value = try container.decodeIfPresent([OmissionCertificate].self, forKey: .omissionList) {
            omissionDtoList = value
        } else if let value = try container.decodeIfPresent([OmissionCertificate].self, forKey: .omissions) {
            omissionDtoList = value
        } else {
            omissionDtoList = []
        }

        faculty = try container.decodeIfPresent(String.self, forKey: .faculty)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(omissionDtoList, forKey: .omissionDtoList)
        try container.encodeIfPresent(faculty, forKey: .faculty)
    }

    init(omissionDtoList: [OmissionCertificate], faculty: String?) {
        self.omissionDtoList = omissionDtoList
        self.faculty = faculty
    }
}

struct MonthlyOmissionCount: Codable, Identifiable {
    let month: String
    let omissionCount: Int

    var id: String { month }
}

struct ErrorResponse: Codable {
    let msg: String
}

struct PortalGradeBookEntry: Decodable {
    let student: PortalGradeBookStudent?
}

struct PortalLessonMark: Codable, Equatable, Sendable {
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

struct PortalPercentageMark: Codable, Equatable, Sendable {
    let discipline: String
    let date: String
    let number: Double
}

struct PortalGradeBookStudent: Decodable, Sendable {
    let lessons: [PortalGradeBookLesson]
    let percentageMarks: [PortalPercentageMark]

    private enum CodingKeys: String, CodingKey {
        case lessons
        case percentageMarks
    }

    init(lessons: [PortalGradeBookLesson], percentageMarks: [PortalPercentageMark] = []) {
        self.lessons = lessons
        self.percentageMarks = percentageMarks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.lessons = (try? container.decode([PortalGradeBookLesson].self, forKey: .lessons)) ?? []
        self.percentageMarks = (try? container.decodeIfPresent([PortalPercentageMark].self, forKey: .percentageMarks)) ?? []
    }
}

struct PortalGradeBookLesson: Decodable, Sendable {
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
    let markDetails: [PortalLessonMark]
    let controlPoint: String
    let labCount: Int?
    let deadline: String?
    let deadlineOverdue: Bool?
    let deadlineTaskNumber: Int?

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
        case labCount
        case deadline
        case deadlineOverdue
        case deadlineTaskNumber
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
        markDetails: [PortalLessonMark]? = nil,
        controlPoint: String,
        labCount: Int? = nil,
        deadline: String? = nil,
        deadlineOverdue: Bool? = nil,
        deadlineTaskNumber: Int? = nil
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
        self.markDetails = markDetails ?? marks.map { PortalLessonMark(mark: $0) }
        self.controlPoint = controlPoint
        self.labCount = labCount
        self.deadline = deadline
        self.deadlineOverdue = deadlineOverdue
        self.deadlineTaskNumber = deadlineTaskNumber
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

        let decodedDetails = (try? container.decode([PortalLessonMark].self, forKey: .marks)) ?? []
        self.markDetails = decodedDetails
        self.marks = decodedDetails.map(\.mark)

        self.controlPoint = (try? container.decode(String.self, forKey: .controlPoint)) ?? ""
        self.labCount = try? container.decodeIfPresent(Int.self, forKey: .labCount)
        self.deadline = try? container.decodeIfPresent(String.self, forKey: .deadline)
        self.deadlineOverdue = try? container.decodeIfPresent(Bool.self, forKey: .deadlineOverdue)
        self.deadlineTaskNumber = try? container.decodeIfPresent(Int.self, forKey: .deadlineTaskNumber)
    }
}

struct UserGroupInfoResponse: Codable {
    let numberOfGroup: String
    let studentGroupCuratorDto: GroupCurator?
    let groupInfoStudentDto: [GroupStudent]

    private enum CodingKeys: String, CodingKey {
        case numberOfGroup
        case studentGroupCuratorDto
        case groupInfoStudentDto
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        numberOfGroup = try container.decode(String.self, forKey: .numberOfGroup)
        studentGroupCuratorDto = try container.decodeIfPresent(GroupCurator.self, forKey: .studentGroupCuratorDto)
        groupInfoStudentDto = try container.decodeIfPresent([GroupStudent].self, forKey: .groupInfoStudentDto) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(numberOfGroup, forKey: .numberOfGroup)
        try container.encodeIfPresent(studentGroupCuratorDto, forKey: .studentGroupCuratorDto)
        try container.encode(groupInfoStudentDto, forKey: .groupInfoStudentDto)
    }
}

struct GroupCurator: Codable {
    let position: String
    let fio: String
    let phone: String?
    let email: String?
    let urlId: String?
}

struct GroupStudent: Codable, Identifiable {
    let position: String
    let fio: String
    let urlId: String?

    var id: String { "\(fio)|\(position)" }

    var isHeadman: Bool {
        position.localizedCaseInsensitiveContains("староста")
    }
}
