import Foundation

struct StudyDashboard: Codable, Equatable {
    var markSheets: [MarkSheetRequest]
    var markSheetTypes: [MarkSheetType]
    var markSheetSubjects: [MarkSheetSubject]
    var certificates: [CertificateRequest]
    var certificatePlaceSections: [CertificatePlaceSection]
    var lmsApplications: [LMSApplication]

    static let empty = StudyDashboard(
        markSheets: [],
        markSheetTypes: [],
        markSheetSubjects: [],
        certificates: [],
        certificatePlaceSections: [],
        lmsApplications: []
    )
}

struct MarkSheetRequest: Codable, Equatable, Identifiable {
    let id: Int
    let number: Int?
    let createdDate: String?
    let absentDate: String?
    let status: String
    let rejectionReason: String?
    let price: Double?
    let retakeCount: Int?
    let subject: MarkSheetRequestSubject?
    let markSheetType: MarkSheetType?
    let employee: MarkSheetEmployee?

    private enum CodingKeys: String, CodingKey {
        case id, number, status, rejectionReason, price, retakeCount, subject, markSheetType, employee
        case createdDate, createDate, dateCreate, dateOrder, absentDate, dateAbsent
    }

    init(
        id: Int,
        number: Int? = nil,
        createdDate: String? = nil,
        absentDate: String? = nil,
        status: String,
        rejectionReason: String? = nil,
        price: Double? = nil,
        retakeCount: Int? = nil,
        subject: MarkSheetRequestSubject? = nil,
        markSheetType: MarkSheetType? = nil,
        employee: MarkSheetEmployee? = nil
    ) {
        self.id = id
        self.number = number
        self.createdDate = createdDate
        self.absentDate = absentDate
        self.status = status
        self.rejectionReason = rejectionReason
        self.price = price
        self.retakeCount = retakeCount
        self.subject = subject
        self.markSheetType = markSheetType
        self.employee = employee
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? UUID().hashValue
        if let intNumber = try? container.decodeIfPresent(Int.self, forKey: .number) {
            number = intNumber
        } else if let stringNumber = try? container.decodeIfPresent(String.self, forKey: .number) {
            number = Int(stringNumber.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            number = nil
        }
        createdDate = try container.decodeFirstString(for: [.createdDate, .createDate, .dateCreate, .dateOrder])
        absentDate = try container.decodeFirstString(for: [.absentDate, .dateAbsent])
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "обрабатывается"
        rejectionReason = try container.decodeIfPresent(String.self, forKey: .rejectionReason)
        price = try container.decodeIfPresent(Double.self, forKey: .price)
        retakeCount = try container.decodeIfPresent(Int.self, forKey: .retakeCount)
        subject = try container.decodeIfPresent(MarkSheetRequestSubject.self, forKey: .subject)
        markSheetType = try container.decodeIfPresent(MarkSheetType.self, forKey: .markSheetType)
        employee = try container.decodeIfPresent(MarkSheetEmployee.self, forKey: .employee)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(number, forKey: .number)
        try container.encodeIfPresent(createdDate, forKey: .createdDate)
        try container.encodeIfPresent(absentDate, forKey: .absentDate)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(rejectionReason, forKey: .rejectionReason)
        try container.encodeIfPresent(price, forKey: .price)
        try container.encodeIfPresent(retakeCount, forKey: .retakeCount)
        try container.encodeIfPresent(subject, forKey: .subject)
        try container.encodeIfPresent(markSheetType, forKey: .markSheetType)
        try container.encodeIfPresent(employee, forKey: .employee)
    }

    var title: String {
        subject?.displayName ?? markSheetType?.shortName ?? "Ведомостичка"
    }

    var isProcessing: Bool {
        status.localizedCaseInsensitiveContains("обрабатывается")
    }
}

struct MarkSheetRequestSubject: Codable, Equatable {
    let abbrev: String?
    let focsId: Int?
    let thId: Int?

    var displayName: String? { abbrev }
}

struct MarkSheetType: Codable, Hashable, Identifiable {
    let id: Int
    let shortName: String
    let fullName: String?
    let price: Double?
    let coefficient: Double?
    let isExam: Bool
    let isOffset: Bool
    let isCourseWork: Bool
    let isLab: Bool
    let isRemote: Bool?
}

struct MarkSheetSubject: Codable, Hashable, Identifiable {
    let etId: Int
    let abbrev: String
    let term: Int
    let lessonTypes: [MarkSheetLessonType]

    var id: Int { etId }
    var displayName: String { "\(abbrev) (\(term) семестр)" }
}

struct MarkSheetLessonType: Codable, Hashable, Identifiable {
    let abbrev: String
    let thId: Int?
    let focsId: Int?
    let isExam: Bool
    let isOffset: Bool
    let isCourseWork: Bool
    let isLab: Bool
    let isRemote: Bool?

    var id: String {
        [abbrev, thId.map(String.init), focsId.map(String.init), isRemote.map(String.init)]
            .compactMap { $0 }
            .joined(separator: "|")
    }

    var displayName: String {
        if isRemote == true {
            return "\(abbrev) (дист.)"
        }
        return abbrev
    }
}

struct MarkSheetEmployee: Codable, Hashable, Identifiable {
    let id: Int
    let firstName: String?
    let lastName: String?
    let middleName: String?
    let fio: String?
    let academicDepartment: String?
    let price: Double?

    var displayName: String {
        if let fio, !fio.isEmpty { return fio }
        let initials = [firstName?.first, middleName?.first]
            .compactMap { $0 }
            .map { "\($0)." }
            .joined(separator: " ")
        if let lastName, !lastName.isEmpty, !initials.isEmpty {
            return "\(lastName) \(initials)"
        }
        return [lastName, firstName, middleName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

struct MarkSheetOrderSubject: Encodable, Equatable {
    let focsId: Int?
    let thId: Int?
}

struct MarkSheetOrderRequest: Encodable, Equatable {
    let price: Double?
    let markSheetType: MarkSheetType
    let reason: Bool
    let hours: String
    let subject: MarkSheetOrderSubject
    let absentDate: String?
    let employee: MarkSheetEmployee
}

struct CertificateRequest: Codable, Equatable, Identifiable {
    let id: Int
    let number: Int
    let provisionPlace: String
    let dateOrder: String
    let issueDate: String?
    let certificateType: String
    let status: Int
    let rejectionReason: String?
    let isByStudent: Bool

    var statusText: String {
        switch status {
        case 1: return "напечатана"
        case 2: return "обрабатывается"
        case 3: return "отклонена"
        default: return "статус \(status)"
        }
    }

    var isProcessing: Bool { status == 2 }
}

struct CertificatePlaceSection: Codable, Equatable, Identifiable {
    let type: String
    let places: [CertificatePlace]

    var id: String { type }
}

struct CertificatePlace: Codable, Hashable, Identifiable {
    let name: String
    let id: Int
    let type: Int

    var requiresComment: Bool { id == 16 }
    var forcesStampedSeal: Bool { type == 1 || type == 2 }
    var blocksComment: Bool { type == 1 || type == 2 }
    var isMilitary: Bool { id == 21 }
}

enum CertificatePrintType: String, CaseIterable, Identifiable, Equatable {
    case ordinary = "обычная"
    case stamped = "гербовая"

    var id: String { rawValue }
}

struct CertificateRegisterRequest: Encodable, Equatable {
    let certificateRequestDto: CertificateRequestPayload
    let certificateCount: Int
}

struct CertificateRequestPayload: Encodable, Equatable {
    let certificateType: String
    let provisionPlace: String
}

struct LMSApplication: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let status: String?
    let detail: String?

    init(id: String, title: String, status: String? = nil, detail: String? = nil) {
        self.id = id
        self.title = title
        self.status = status
        self.detail = detail
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        let idValue = container.decodeLossyString(for: ["lmsApplicationId", "id", "applicationId"]) ?? UUID().uuidString
        let titleValue = container.decodeLossyString(for: ["discipline", "disciplineName", "subject", "name", "title"]) ?? "Заявка ДОТ"
        id = idValue
        title = titleValue
        status = container.decodeLossyString(for: ["status", "applicationStatus"])
        detail = container.decodeLossyString(for: ["educationTerm", "term", "comment"])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        try container.encode(id, forKey: DynamicCodingKey(stringValue: "id")!)
        try container.encode(title, forKey: DynamicCodingKey(stringValue: "title")!)
        try container.encodeIfPresent(status, forKey: DynamicCodingKey(stringValue: "status")!)
        try container.encodeIfPresent(detail, forKey: DynamicCodingKey(stringValue: "detail")!)
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

private extension KeyedDecodingContainer where Key == DynamicCodingKey {
    func decodeLossyString(for keys: [String]) -> String? {
        for key in keys {
            guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
            if let stringValue = try? decodeIfPresent(String.self, forKey: codingKey), !stringValue.isEmpty {
                return stringValue
            }
            if let intValue = try? decodeIfPresent(Int.self, forKey: codingKey) {
                return String(intValue)
            }
        }
        return nil
    }
}

private extension KeyedDecodingContainer {
    func decodeFirstString(for keys: [K]) throws -> String? {
        for key in keys {
            if let value = try decodeIfPresent(String.self, forKey: key), !value.isEmpty {
                return value
            }
        }
        return nil
    }
}
