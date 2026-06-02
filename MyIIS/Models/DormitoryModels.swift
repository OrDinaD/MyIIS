import Foundation

struct DormitoryQueueApplication: Decodable, Identifiable, Equatable {
    let id: Int
    let acceptedDate: Date?
    let applicationDate: Date?
    let settledDate: Date?
    let status: String
    let number: Int
    let numberInQueue: Int?
    let docReference: String?
    let docContent: String?
    let rejectionReason: String?
    let roomInfo: String?

    init(
        id: Int,
        acceptedDate: Date?,
        applicationDate: Date?,
        settledDate: Date?,
        status: String,
        number: Int,
        numberInQueue: Int?,
        docReference: String?,
        docContent: String?,
        rejectionReason: String?,
        roomInfo: String?
    ) {
        self.id = id
        self.acceptedDate = acceptedDate
        self.applicationDate = applicationDate
        self.settledDate = settledDate
        self.status = status
        self.number = number
        self.numberInQueue = numberInQueue
        self.docReference = docReference
        self.docContent = docContent
        self.rejectionReason = rejectionReason
        self.roomInfo = roomInfo
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case acceptedDate
        case applicationDate
        case settledDate
        case status
        case number
        case numberInQueue
        case docReference
        case docContent
        case rejectionReason
        case roomInfo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        status = try container.decode(String.self, forKey: .status)
        number = try container.decode(Int.self, forKey: .number)
        numberInQueue = try container.decodeIfPresent(Int.self, forKey: .numberInQueue)
        docReference = try container.decodeIfPresent(String.self, forKey: .docReference)
        docContent = try container.decodeIfPresent(String.self, forKey: .docContent)
        rejectionReason = try container.decodeIfPresent(String.self, forKey: .rejectionReason)
        roomInfo = try container.decodeIfPresent(String.self, forKey: .roomInfo)

        let acceptedDateRaw = try container.decodeIfPresent(String.self, forKey: .acceptedDate)
        let applicationDateRaw = try container.decodeIfPresent(String.self, forKey: .applicationDate)
        let settledDateRaw = try container.decodeIfPresent(String.self, forKey: .settledDate)

        acceptedDate = DormitoryDateParser.parse(acceptedDateRaw)
        applicationDate = DormitoryDateParser.parse(applicationDateRaw)
        settledDate = DormitoryDateParser.parse(settledDateRaw)
    }

    var hasDocument: Bool {
        !(docReference?.isEmpty ?? true) || !(docContent?.isEmpty ?? true)
    }
}

struct DormitoryPrivilegeRecord: Decodable, Identifiable, Equatable {
    let id: Int
    let year: Int
    let dormitoryPrivilegeCategoryId: Int
    let dormitoryPrivilegeCategoryName: String
}

private enum DormitoryDateParser {
    private static let withMilliseconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return formatter
    }()

    private static let withoutMilliseconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    static func parse(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        return withMilliseconds.date(from: raw) ?? withoutMilliseconds.date(from: raw)
    }
}

#if DEBUG
extension DormitoryQueueApplication {
    static let preview: [DormitoryQueueApplication] = [
        DormitoryQueueApplication(
            id: 29990,
            acceptedDate: DormitoryDateParser.parse("2025-06-16T18:54:02.892"),
            applicationDate: DormitoryDateParser.parse("2025-06-07T21:18:41.197"),
            settledDate: DormitoryDateParser.parse("2025-07-25T13:41:57.537"),
            status: "Заселён",
            number: 1210,
            numberInQueue: nil,
            docReference: "29990.jpg",
            docContent: nil,
            rejectionReason: nil,
            roomInfo: "1211-а, Общ.4"
        ),
        DormitoryQueueApplication(
            id: 25434,
            acceptedDate: DormitoryDateParser.parse("2024-08-19T15:25:14.332"),
            applicationDate: DormitoryDateParser.parse("2024-08-19T12:57:00.618"),
            settledDate: DormitoryDateParser.parse("2024-08-26T19:22:04.187"),
            status: "Выселен",
            number: 3013,
            numberInQueue: nil,
            docReference: nil,
            docContent: nil,
            rejectionReason: nil,
            roomInfo: "401-а, Общ.5"
        )
    ]
}

extension DormitoryPrivilegeRecord {
    static let preview: [DormitoryPrivilegeRecord] = [
        DormitoryPrivilegeRecord(id: 11115, year: 2025, dormitoryPrivilegeCategoryId: 2, dormitoryPrivilegeCategoryName: "Первоочередное право"),
        DormitoryPrivilegeRecord(id: 11114, year: 2025, dormitoryPrivilegeCategoryId: 6, dormitoryPrivilegeCategoryName: "Общая очередь"),
        DormitoryPrivilegeRecord(id: 9934, year: 2024, dormitoryPrivilegeCategoryId: 6, dormitoryPrivilegeCategoryName: "Общая очередь")
    ]
}
#endif
