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

struct PortalGradeBookStudent: Decodable {
    let lessons: [PortalGradeBookLesson]
}

struct PortalGradeBookLesson: Decodable {
    let id: Int
    let dateString: String
    let gradeBookOmissions: Int
    let isRespectfulOmission: Bool
    let lessonTypeId: Int
    let lessonTypeAbbrev: String
    let lessonNameAbbrev: String
    let subGroup: Int
    let marks: [Int]
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
        subGroup: Int,
        marks: [Int],
        controlPoint: String
    ) {
        self.id = id
        self.dateString = dateString
        self.gradeBookOmissions = gradeBookOmissions
        self.isRespectfulOmission = isRespectfulOmission
        self.lessonTypeId = lessonTypeId
        self.lessonTypeAbbrev = lessonTypeAbbrev
        self.lessonNameAbbrev = lessonNameAbbrev
        self.subGroup = subGroup
        self.marks = marks
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
        self.subGroup = (try? container.decode(Int.self, forKey: .subGroup)) ?? 0
        self.marks = (try? container.decode([Int].self, forKey: .marks)) ?? []
        self.controlPoint = (try? container.decode(String.self, forKey: .controlPoint)) ?? ""
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
