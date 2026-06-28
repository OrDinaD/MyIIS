import Foundation

struct DormitoryQueueApplication: Codable, Identifiable, Equatable {
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

    private let acceptedDateSource: String?
    private let applicationDateSource: String?
    private let settledDateSource: String?

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
        roomInfo: String?,
        acceptedDateSource: String? = nil,
        applicationDateSource: String? = nil,
        settledDateSource: String? = nil
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
        self.acceptedDateSource = acceptedDateSource
        self.applicationDateSource = applicationDateSource
        self.settledDateSource = settledDateSource
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

        acceptedDateSource = try container.decodeIfPresent(String.self, forKey: .acceptedDate)
        applicationDateSource = try container.decodeIfPresent(String.self, forKey: .applicationDate)
        settledDateSource = try container.decodeIfPresent(String.self, forKey: .settledDate)

        acceptedDate = DormitoryDateParser.parse(acceptedDateSource)
        applicationDate = DormitoryDateParser.parse(applicationDateSource)
        settledDate = DormitoryDateParser.parse(settledDateSource)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(status, forKey: .status)
        try container.encode(number, forKey: .number)
        try container.encodeIfPresent(numberInQueue, forKey: .numberInQueue)
        try container.encodeIfPresent(docReference, forKey: .docReference)
        try container.encodeIfPresent(docContent, forKey: .docContent)
        try container.encodeIfPresent(rejectionReason, forKey: .rejectionReason)
        try container.encodeIfPresent(roomInfo, forKey: .roomInfo)
        try container.encodeIfPresent(acceptedDateSource ?? DormitoryDateParser.apiString(from: acceptedDate), forKey: .acceptedDate)
        try container.encodeIfPresent(applicationDateSource ?? DormitoryDateParser.apiString(from: applicationDate), forKey: .applicationDate)
        try container.encodeIfPresent(settledDateSource ?? DormitoryDateParser.apiString(from: settledDate), forKey: .settledDate)
    }

    var hasDocument: Bool {
        !(docReference?.isEmpty ?? true) || !(docContent?.isEmpty ?? true)
    }

    var canEdit: Bool {
        status == DormitoryApplicationStatus.waiting.rawValue
    }

    var canDownloadApplicationForm: Bool {
        status == DormitoryApplicationStatus.waiting.rawValue || status == DormitoryApplicationStatus.documentsAccepted.rawValue
    }

    func updatePayload(docContent: String?) -> DormitoryQueueApplicationUpdatePayload {
        DormitoryQueueApplicationUpdatePayload(
            id: id,
            acceptedDate: acceptedDateSource ?? DormitoryDateParser.apiString(from: acceptedDate),
            applicationDate: applicationDateSource ?? DormitoryDateParser.apiString(from: applicationDate),
            settledDate: settledDateSource ?? DormitoryDateParser.apiString(from: settledDate),
            status: status,
            number: number,
            numberInQueue: numberInQueue,
            docReference: docReference,
            docContent: docContent,
            rejectionReason: rejectionReason,
            roomInfo: roomInfo
        )
    }
}

struct DormitoryQueueApplicationUpdatePayload: Encodable {
    let id: Int
    let acceptedDate: String?
    let applicationDate: String?
    let settledDate: String?
    let status: String
    let number: Int
    let numberInQueue: Int?
    let docReference: String?
    let docContent: String?
    let rejectionReason: String?
    let roomInfo: String?
}

struct DormitoryPrivilegeRecord: Codable, Identifiable, Equatable {
    let id: Int
    let year: Int
    let dormitoryPrivilegeCategoryId: Int
    let dormitoryPrivilegeCategoryName: String
}

enum DormitoryApplicationStatus: String {
    case waiting = "Ожидание"
    case documentsAccepted = "Документы приняты"
    case readyToSettle = "К заселению"
    case settled = "Заселён"
    case rejected = "Отклонена"
    case evicted = "Выселен"
}

enum DormitoryDocumentUpdateAction: Equatable {
    case unchanged
    case remove
    case replace(URL)
}

struct DormitoryAnnouncement: Equatable {
    let title: String
    let leadingMessage: String
    let requiredDocumentsIntro: String
    let requiredDocuments: [DormitoryAnnouncementDocument]

    static func current(on date: Date = .now, calendar: Calendar = .current) -> DormitoryAnnouncement? {
        guard isSiteAnnouncementWindowActive(on: date, calendar: calendar) else { return nil }
        return DormitoryAnnouncement(
            title: "Объявление о приёме документов для общежития",
            leadingMessage: "С 1 июня по 30 июня осуществляется приём документов для постановки на учёт нуждающихся в предоставлении места в общежитии.",
            requiredDocumentsIntro: "Для постановки на учёт необходимо предоставить заместителям деканов по ИВР своих факультетов следующие документы:",
            requiredDocuments: [
                DormitoryAnnouncementDocument(
                    title: "Заявление установленного образца",
                    details: "форма есть в личном кабинете студента на iis.bsuir.by."
                ),
                DormitoryAnnouncementDocument(
                    title: "Справку о занимаемом в данном населенном пункте жилом помещении, месте жительства и составе семьи",
                    details: "по форме Приложения 2 к постановлению Министерства ЖКХ РБ от 21.12.2005 №58; выдаётся по месту регистрации на всех членов семьи."
                ),
                DormitoryAnnouncementDocument(
                    title: "Копии удостоверений, свидетельств, иных документов",
                    details: "дипломы, грамоты, благодарности, подтверждающие право на льготы, установленные законодательством."
                ),
                DormitoryAnnouncementDocument(
                    title: "Оригиналы ходатайств от кафедр, УИВР, спортклуба, профкома, БРСМ и др.",
                    details: nil
                )
            ]
        )
    }

    private static func isSiteAnnouncementWindowActive(on date: Date, calendar: Calendar) -> Bool {
        let year = calendar.component(.year, from: date)
        guard
            let start = calendar.date(from: DateComponents(year: year, month: 5, day: 15)),
            let end = calendar.date(from: DateComponents(year: year, month: 7, day: 10)),
            let currentDay = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: date))
        else {
            return false
        }

        return currentDay >= start && currentDay <= end
    }
}

struct DormitoryAnnouncementDocument: Equatable, Identifiable {
    let id = UUID()
    let title: String
    let details: String?
}

enum DormitoryDateParser {
    private static let fractionalISO8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let apiDateFormatter: DateFormatter = {
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
        return fractionalISO8601.date(from: raw)
            ?? apiDateFormatter.date(from: raw)
            ?? withoutMilliseconds.date(from: raw)
            ?? parseVariableFractionalDate(raw)
    }

    static func apiString(from date: Date?) -> String? {
        guard let date else { return nil }
        return apiDateFormatter.string(from: date)
    }

    private static func parseVariableFractionalDate(_ raw: String) -> Date? {
        let parts = raw.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }

        let fraction = String(parts[1].prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0)
        return apiDateFormatter.date(from: parts[0] + "." + fraction)
    }
}

#if DEBUG
extension DormitoryQueueApplication {
    static let preview: [DormitoryQueueApplication] = [
        DormitoryQueueApplication(
            id: 36859,
            acceptedDate: nil,
            applicationDate: DormitoryDateParser.parse("2026-06-04T00:27:47.190211"),
            settledDate: nil,
            status: "Ожидание",
            number: 703,
            numberInQueue: nil,
            docReference: "36859.jpg",
            docContent: nil,
            rejectionReason: nil,
            roomInfo: nil,
            applicationDateSource: "2026-06-04T00:27:47.190211"
        ),
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
