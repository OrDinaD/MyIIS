import Foundation

struct AnnouncementCategory: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let title: String
    let subtitle: String?
    let iconName: String?

    init(id: String, title: String, subtitle: String? = nil, iconName: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
    }

    static let all = AnnouncementCategory(id: "all", title: "Все")
}

struct Announcement: Codable, Identifiable, Hashable, Equatable {
    struct Attachment: Codable, Identifiable, Hashable, Equatable {
        let id: String
        let title: String
        let url: URL
        let fileSize: Int?

        init(id: String, title: String, url: URL, fileSize: Int? = nil) {
            self.id = id
            self.title = title
            self.url = url
            self.fileSize = fileSize
        }
    }

    let id: String
    let title: String
    let summary: String?
    let body: String?
    let author: String?
    let categoryID: AnnouncementCategory.ID
    let categoryName: String?
    let publishedAt: Date
    let updatedAt: Date?
    var isRead: Bool
    let isPinned: Bool
    let attachments: [Attachment]

    init(
        id: String,
        title: String,
        summary: String? = nil,
        body: String? = nil,
        author: String? = nil,
        categoryID: AnnouncementCategory.ID,
        categoryName: String? = nil,
        publishedAt: Date,
        updatedAt: Date? = nil,
        isRead: Bool,
        isPinned: Bool,
        attachments: [Attachment] = []
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.body = body
        self.author = author
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.publishedAt = publishedAt
        self.updatedAt = updatedAt
        self.isRead = isRead
        self.isPinned = isPinned
        self.attachments = attachments
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case summary
        case body
        case author
        case categoryID = "categoryId"
        case categoryName
        case publishedAt
        case updatedAt
        case isRead
        case isPinned
        case attachments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringID = try? container.decode(String.self, forKey: .id) {
            id = stringID
        } else if let intID = try? container.decode(Int.self, forKey: .id) {
            id = String(intID)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Некорректный идентификатор объявления")
        }
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        body = try container.decodeIfPresent(String.self, forKey: .body)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        if let value = try container.decodeIfPresent(String.self, forKey: .categoryID) {
            categoryID = value
        } else if let intValue = try container.decodeIfPresent(Int.self, forKey: .categoryID) {
            categoryID = String(intValue)
        } else {
            categoryID = AnnouncementCategory.all.id
        }
        categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName)
        publishedAt = try Self.decodeDate(from: container, forKey: .publishedAt)
        if container.contains(.updatedAt) {
            updatedAt = try? Self.decodeDate(from: container, forKey: .updatedAt)
        } else {
            updatedAt = nil
        }
        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        attachments = try container.decodeIfPresent([Attachment].self, forKey: .attachments) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encodeIfPresent(body, forKey: .body)
        try container.encodeIfPresent(author, forKey: .author)
        try container.encode(categoryID, forKey: .categoryID)
        try container.encodeIfPresent(categoryName, forKey: .categoryName)
        try container.encode(publishedAt, forKey: .publishedAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encode(isRead, forKey: .isRead)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(attachments, forKey: .attachments)
    }

    var displayCategory: String {
        categoryName ?? categoryID
    }

    var shortBody: String {
        if let summary, !summary.isEmpty {
            return summary
        }
        guard let body, !body.isEmpty else {
            return ""
        }
        if body.count <= 160 {
            return body
        }
        let truncated = body.prefix(160)
        return String(truncated).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    var relativePublishedAt: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: publishedAt, relativeTo: Date())
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: publishedAt)
    }

    private static func decodeDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Date {
        if let date = try? container.decode(Date.self, forKey: key) {
            return date
        }

        if let timeInterval = try? container.decode(Double.self, forKey: key) {
            return Date(timeIntervalSince1970: timeInterval / (timeInterval > 10_000 ? 1_000 : 1))
        }

        let rawValue = try container.decode(String.self, forKey: key)
        if let parsed = iso8601Formatter.date(from: rawValue) ?? iso8601FractionalFormatter.date(from: rawValue) {
            return parsed
        }

        if let timestamp = Double(rawValue) {
            return Date(timeIntervalSince1970: timestamp / (timestamp > 10_000 ? 1_000 : 1))
        }

        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: container,
            debugDescription: "Не удалось декодировать дату объявления"
        )
    }
}

private let iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
    return formatter
}()

private let iso8601FractionalFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [
        .withInternetDateTime,
        .withFractionalSeconds,
        .withColonSeparatorInTime,
        .withDashSeparatorInDate
    ]
    return formatter
}()
