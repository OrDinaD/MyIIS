import Foundation

struct LibraryItem: Identifiable, Codable, Equatable {
    struct Availability: Codable, Equatable {
        let total: Int
        let available: Int

        init(total: Int, available: Int) {
            self.total = total
            self.available = available
        }
    }

    enum ItemType: String, Codable, CaseIterable {
        case book = "BOOK"
        case digital = "DIGITAL"
        case periodical = "PERIODICAL"
        case dissertation = "DISSERTATION"
        case unknown

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let value = (try? container.decode(String.self)) ?? ""
            self = ItemType(rawValue: value.uppercased()) ?? .unknown
        }
    }

    let id: Int
    let title: String
    let authors: [String]
    let description: String?
    let publisher: String?
    let publicationYear: Int?
    let coverURL: URL?
    let itemType: ItemType
    let availability: Availability?
    let language: String?
    let tags: [String]
    let hall: String?
    let inventoryNumber: String?

    init(
        id: Int,
        title: String,
        authors: [String],
        description: String? = nil,
        publisher: String? = nil,
        publicationYear: Int? = nil,
        coverURL: URL? = nil,
        itemType: ItemType = .unknown,
        availability: Availability? = nil,
        language: String? = nil,
        tags: [String] = [],
        hall: String? = nil,
        inventoryNumber: String? = nil
    ) {
        self.id = id
        self.title = title
        self.authors = authors
        self.description = description
        self.publisher = publisher
        self.publicationYear = publicationYear
        self.coverURL = coverURL
        self.itemType = itemType
        self.availability = availability
        self.language = language
        self.tags = tags
        self.hall = hall
        self.inventoryNumber = inventoryNumber
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case authors
        case description
        case publisher
        case publicationYear
        case coverURL = "coverUrl"
        case itemType = "type"
        case availability
        case language
        case tags
        case hall
        case inventoryNumber = "inventoryNumber"
        case author
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        if let authors = try? container.decode([String].self, forKey: .authors) {
            self.authors = authors
        } else if let singleAuthor = try? container.decode(String.self, forKey: .author) {
            self.authors = singleAuthor.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        } else {
            self.authors = []
        }
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.publisher = try container.decodeIfPresent(String.self, forKey: .publisher)
        self.publicationYear = try container.decodeIfPresent(Int.self, forKey: .publicationYear)
        if let coverString = try container.decodeIfPresent(String.self, forKey: .coverURL) {
            self.coverURL = URL(string: coverString)
        } else {
            self.coverURL = nil
        }
        let typeValue = (try? container.decode(String.self, forKey: .itemType)) ?? ItemType.unknown.rawValue
        self.itemType = ItemType(rawValue: typeValue.uppercased()) ?? .unknown
        self.availability = try container.decodeIfPresent(Availability.self, forKey: .availability)
        self.language = try container.decodeIfPresent(String.self, forKey: .language)
        if let tags = try? container.decode([String].self, forKey: .tags) {
            self.tags = tags
        } else if let tag = try? container.decode(String.self, forKey: .tags) {
            self.tags = tag.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        } else {
            self.tags = []
        }
        self.hall = try container.decodeIfPresent(String.self, forKey: .hall)
        self.inventoryNumber = try container.decodeIfPresent(String.self, forKey: .inventoryNumber)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        if !authors.isEmpty {
            try container.encode(authors, forKey: .authors)
        }
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(publisher, forKey: .publisher)
        try container.encodeIfPresent(publicationYear, forKey: .publicationYear)
        try container.encodeIfPresent(coverURL?.absoluteString, forKey: .coverURL)
        try container.encode(itemType.rawValue, forKey: .itemType)
        try container.encodeIfPresent(availability, forKey: .availability)
        try container.encodeIfPresent(language, forKey: .language)
        if !tags.isEmpty {
            try container.encode(tags, forKey: .tags)
        }
        try container.encodeIfPresent(hall, forKey: .hall)
        try container.encodeIfPresent(inventoryNumber, forKey: .inventoryNumber)
    }

    var authorText: String {
        authors.joined(separator: ", ")
    }

    var metadataText: String? {
        var components: [String] = []
        if let publisher, !publisher.isEmpty {
            components.append(publisher)
        }
        if let publicationYear {
            components.append(String(publicationYear))
        }
        if let language, !language.isEmpty {
            components.append(language)
        }
        if components.isEmpty {
            return nil
        }
        return components.joined(separator: " • ")
    }

    func matches(query: String) -> Bool {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return true }
        if title.lowercased().contains(normalized) { return true }
        if authorText.lowercased().contains(normalized) { return true }
        if let description, description.lowercased().contains(normalized) { return true }
        if let tagsMatch = tags.first(where: { $0.lowercased().contains(normalized) }) {
            return !tagsMatch.isEmpty
        }
        return false
    }
}

struct BorrowHistoryEntry: Identifiable, Codable, Equatable {
    enum Status: String, Codable, CaseIterable {
        case active = "ACTIVE"
        case overdue = "OVERDUE"
        case returned = "RETURNED"
        case unknown

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let value = (try? container.decode(String.self)) ?? ""
            self = Status(rawValue: value.uppercased()) ?? .unknown
        }

        var title: String {
            switch self {
            case .active: return "Активна"
            case .overdue: return "Просрочена"
            case .returned: return "Возвращена"
            case .unknown: return "Неизвестно"
            }
        }
    }

    let id: Int
    let itemId: Int
    let title: String
    let authors: [String]
    let borrowedAt: Date
    let dueDate: Date?
    let returnedAt: Date?
    let status: Status
    let location: String?
    let prolongationCount: Int
    let isElectronic: Bool

    init(
        id: Int,
        itemId: Int,
        title: String,
        authors: [String],
        borrowedAt: Date,
        dueDate: Date? = nil,
        returnedAt: Date? = nil,
        status: Status = .unknown,
        location: String? = nil,
        prolongationCount: Int = 0,
        isElectronic: Bool = false
    ) {
        self.id = id
        self.itemId = itemId
        self.title = title
        self.authors = authors
        self.borrowedAt = borrowedAt
        self.dueDate = dueDate
        self.returnedAt = returnedAt
        self.status = status
        self.location = location
        self.prolongationCount = prolongationCount
        self.isElectronic = isElectronic
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case itemId = "itemId"
        case title
        case authors
        case borrowedAt = "borrowDate"
        case dueDate
        case returnedAt = "returnDate"
        case status
        case location
        case prolongationCount = "prolongCount"
        case isElectronic
        case author
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.itemId = try container.decodeIfPresent(Int.self, forKey: .itemId) ?? id
        self.title = try container.decode(String.self, forKey: .title)
        if let authors = try? container.decode([String].self, forKey: .authors) {
            self.authors = authors
        } else if let singleAuthor = try? container.decode(String.self, forKey: .author) {
            self.authors = singleAuthor.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        } else {
            self.authors = []
        }
        self.borrowedAt = try BorrowHistoryEntry.decodeDate(from: container, forKey: .borrowedAt) ?? Date()
        self.dueDate = try BorrowHistoryEntry.decodeDate(from: container, forKey: .dueDate)
        self.returnedAt = try BorrowHistoryEntry.decodeDate(from: container, forKey: .returnedAt)
        let statusValue = (try? container.decode(String.self, forKey: .status)) ?? Status.unknown.rawValue
        self.status = Status(rawValue: statusValue.uppercased()) ?? .unknown
        self.location = try container.decodeIfPresent(String.self, forKey: .location)
        self.prolongationCount = try container.decodeIfPresent(Int.self, forKey: .prolongationCount) ?? 0
        self.isElectronic = try container.decodeIfPresent(Bool.self, forKey: .isElectronic) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(itemId, forKey: .itemId)
        try container.encode(title, forKey: .title)
        if !authors.isEmpty {
            try container.encode(authors, forKey: .authors)
        }
        try container.encode(BorrowHistoryEntry.encoderDateFormatter.string(from: borrowedAt), forKey: .borrowedAt)
        if let dueDate {
            try container.encode(BorrowHistoryEntry.encoderDateFormatter.string(from: dueDate), forKey: .dueDate)
        }
        if let returnedAt {
            try container.encode(BorrowHistoryEntry.encoderDateFormatter.string(from: returnedAt), forKey: .returnedAt)
        }
        try container.encode(status.rawValue, forKey: .status)
        try container.encodeIfPresent(location, forKey: .location)
        if prolongationCount > 0 {
            try container.encode(prolongationCount, forKey: .prolongationCount)
        }
        if isElectronic {
            try container.encode(isElectronic, forKey: .isElectronic)
        }
    }

    var isActive: Bool {
        switch status {
        case .returned: return false
        case .unknown: return returnedAt == nil
        default: return returnedAt == nil
        }
    }

    var isOverdue: Bool {
        if status == .overdue { return true }
        guard let dueDate else { return false }
        return isActive && dueDate < Date()
    }

    var authorText: String {
        authors.joined(separator: ", ")
    }

    var durationDescription: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        var parts: [String] = []
        parts.append("Получено: \(formatter.string(from: borrowedAt))")
        if let dueDate {
            parts.append("До: \(formatter.string(from: dueDate))")
        }
        if let returnedAt {
            parts.append("Возврат: \(formatter.string(from: returnedAt))")
        }
        return parts.joined(separator: " • ")
    }

    func matches(query: String) -> Bool {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return true }
        if title.lowercased().contains(normalized) { return true }
        if authorText.lowercased().contains(normalized) { return true }
        if let location, location.lowercased().contains(normalized) { return true }
        return false
    }

    private static func decodeDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Date? {
        if let timestamp = try? container.decode(Double.self, forKey: key) {
            let timeInterval: TimeInterval
            if timestamp > 9_999_999_999 { // milliseconds
                timeInterval = timestamp / 1000
            } else {
                timeInterval = timestamp
            }
            return Date(timeIntervalSince1970: timeInterval)
        }
        if let stringValue = try? container.decode(String.self, forKey: key) {
            if let date = isoFormatter.date(from: stringValue) {
                return date
            }
            if let date = alternativeFormatter.date(from: stringValue) {
                return date
            }
        }
        return nil
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let alternativeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()

    private static let encoderDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

extension LibraryItem {
    static let previewCatalog: [LibraryItem] = [
        LibraryItem(
            id: 1,
            title: "Алгоритмы. Построение и анализ",
            authors: ["Томас Х. Кормен", "Чарльз Э. Лейзерсон", "Рональд Л. Ривест", "Клиффорд Штайн"],
            description: "Классический труд по алгоритмам с подробными доказательствами.",
            publisher: "МИР",
            publicationYear: 2022,
            itemType: .book,
            availability: .init(total: 5, available: 2),
            language: "ru",
            tags: ["алгоритмы", "компьютерные науки"],
            hall: "Главный фонд",
            inventoryNumber: "A12345"
        ),
        LibraryItem(
            id: 2,
            title: "iOS 17 Human Interface Guidelines",
            authors: ["Apple"],
            description: "Руководство по дизайну приложений в экосистеме Apple.",
            publisher: "Apple",
            publicationYear: 2023,
            itemType: .digital,
            availability: nil,
            language: "en",
            tags: ["design", "ui"],
            hall: "Электронные ресурсы",
            inventoryNumber: nil
        ),
        LibraryItem(
            id: 3,
            title: "Основы машинного обучения",
            authors: ["Е. М. Мастицкий"],
            description: "Пособие по практическому применению методов машинного обучения.",
            publisher: "БГУИР",
            publicationYear: 2021,
            itemType: .book,
            availability: .init(total: 3, available: 1),
            language: "ru",
            tags: ["машинное обучение", "data science"],
            hall: "Читальный зал",
            inventoryNumber: "ML-042"
        )
    ]
}

extension BorrowHistoryEntry {
    static let previewActive: [BorrowHistoryEntry] = [
        BorrowHistoryEntry(
            id: 101,
            itemId: 1,
            title: "Алгоритмы. Построение и анализ",
            authors: ["Т. Кормен", "Ч. Лейзерсон"],
            borrowedAt: Date().addingTimeInterval(-14 * 24 * 60 * 60),
            dueDate: Date().addingTimeInterval(7 * 24 * 60 * 60),
            status: .active,
            location: "Главный фонд",
            prolongationCount: 1,
            isElectronic: false
        ),
        BorrowHistoryEntry(
            id: 102,
            itemId: 2,
            title: "Разработка приложений на SwiftUI",
            authors: ["Apple"],
            borrowedAt: Date().addingTimeInterval(-30 * 24 * 60 * 60),
            dueDate: Date().addingTimeInterval(-2 * 24 * 60 * 60),
            status: .overdue,
            location: "Цифровой абонемент",
            prolongationCount: 0,
            isElectronic: true
        )
    ]

    static let previewArchive: [BorrowHistoryEntry] = [
        BorrowHistoryEntry(
            id: 201,
            itemId: 3,
            title: "Паттерны проектирования",
            authors: ["Э. Гамма", "Р. Хелм", "Р. Джонсон", "Дж. Влиссидес"],
            borrowedAt: Date().addingTimeInterval(-120 * 24 * 60 * 60),
            dueDate: Date().addingTimeInterval(-90 * 24 * 60 * 60),
            returnedAt: Date().addingTimeInterval(-95 * 24 * 60 * 60),
            status: .returned,
            location: "Главный фонд",
            prolongationCount: 2,
            isElectronic: false
        )
    ]
}
