import Foundation

// MARK: - Penalty Type

enum PenaltyType: String, Codable, CaseIterable, Identifiable {
    case remark = "REMARK"
    case warning = "WARNING"
    case reprimand = "REPRIMAND"
    case severeReprimand = "SEVERE_REPRIMAND"
    case dismissal = "DISMISSAL"
    case other = "OTHER"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .remark:
            return "Замечание"
        case .warning:
            return "Предупреждение"
        case .reprimand:
            return "Выговор"
        case .severeReprimand:
            return "Строгий выговор"
        case .dismissal:
            return "Отчисление"
        case .other:
            return "Другое"
        }
    }

    /// Уровень строгости взыскания. Используется при сортировке.
    var severityRank: Int {
        switch self {
        case .dismissal:
            return 5
        case .severeReprimand:
            return 4
        case .reprimand:
            return 3
        case .warning:
            return 2
        case .remark:
            return 1
        case .other:
            return 0
        }
    }

    /// Системная иконка для визуализации типа взыскания.
    var systemImageName: String {
        switch self {
        case .remark:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .reprimand:
            return "hand.raised.fingers.spread.fill"
        case .severeReprimand:
            return "hand.raised.slash.fill"
        case .dismissal:
            return "person.crop.circle.badge.xmark"
        case .other:
            return "questionmark.diamond.fill"
        }
    }
}

// MARK: - Penalty Record

struct PenaltyRecord: Identifiable, Codable, Equatable {
    let recordID: String
    let type: PenaltyType
    let title: String
    let description: String?
    let issuedAt: Date
    let updatedAt: Date?
    let authority: String?
    let status: Status
    let note: String?

    var id: String { recordID }

    /// Возвращает `true`, если взыскание всё ещё активно.
    var isActive: Bool { status == .active }

    /// Отображаемое описание, гарантированно не пустое.
    var displayDescription: String {
        if let description, !description.isEmpty {
            return description
        }
        if let note, !note.isEmpty {
            return note
        }
        return title
    }

    static func defaultSort(lhs: PenaltyRecord, rhs: PenaltyRecord) -> Bool {
        if lhs.issuedAt != rhs.issuedAt {
            return lhs.issuedAt > rhs.issuedAt
        }

        if lhs.type.severityRank != rhs.type.severityRank {
            return lhs.type.severityRank > rhs.type.severityRank
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }
}

extension PenaltyRecord {
    enum Status: String, Codable, Equatable {
        case active = "ACTIVE"
        case resolved = "RESOLVED"
        case cancelled = "CANCELLED"
        case expired = "EXPIRED"
        case unknown = "UNKNOWN"

        var displayName: String {
            switch self {
            case .active:
                return "Активно"
            case .resolved:
                return "Закрыто"
            case .cancelled:
                return "Аннулировано"
            case .expired:
                return "Истёк срок"
            case .unknown:
                return "Статус неизвестен"
            }
        }

        var symbolName: String {
            switch self {
            case .active:
                return "clock.badge.exclamationmark"
            case .resolved:
                return "checkmark.seal.fill"
            case .cancelled:
                return "xmark.octagon.fill"
            case .expired:
                return "hourglass.badge.exclamationmark"
            case .unknown:
                return "questionmark.circle.fill"
            }
        }

        var isCritical: Bool {
            switch self {
            case .active, .expired:
                return true
            case .resolved, .cancelled, .unknown:
                return false
            }
        }
    }
}

// MARK: - Codable Support

extension PenaltyRecord {
    enum CodingKeys: String, CodingKey {
        case recordID = "id"
        case type
        case title
        case description
        case issuedAt
        case updatedAt
        case authority
        case status
        case note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recordID = try container.decode(String.self, forKey: .recordID)
        type = try container.decodeIfPresent(PenaltyType.self, forKey: .type) ?? .other
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        issuedAt = try container.decodeFlexibleDate(forKey: .issuedAt)
        updatedAt = container.decodeFlexibleDateIfPresent(forKey: .updatedAt)
        authority = try container.decodeIfPresent(String.self, forKey: .authority)
        status = try container.decodeIfPresent(Status.self, forKey: .status) ?? .unknown
        note = try container.decodeIfPresent(String.self, forKey: .note)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(recordID, forKey: .recordID)
        try container.encode(type, forKey: .type)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(issuedAt.iso8601String(), forKey: .issuedAt)
        if let updatedAt {
            try container.encode(updatedAt.iso8601String(), forKey: .updatedAt)
        }
        try container.encodeIfPresent(authority, forKey: .authority)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(note, forKey: .note)
    }
}

private extension KeyedDecodingContainer where K == PenaltyRecord.CodingKeys {
    func decodeFlexibleDate(forKey key: KeyedDecodingContainer<K>.Key) throws -> Date {
        if let milliseconds = try? decode(Double.self, forKey: key) {
            return Date(timeIntervalSince1970: milliseconds / 1000)
        }

        if let stringValue = try? decode(String.self, forKey: key) {
            if let date = ISO8601DateFormatter.penaltiesFormatter.date(from: stringValue) {
                return date
            }

            let formatter = DateFormatter.penaltiesFormatter
            if let date = formatter.date(from: stringValue) {
                return date
            }
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "Не удалось распарсить дату взыскания"
            )
        )
    }

    func decodeFlexibleDateIfPresent(forKey key: KeyedDecodingContainer<K>.Key) -> Date? {
        guard contains(key) else { return nil }
        return try? decodeFlexibleDate(forKey: key)
    }
}

private extension Date {
    func iso8601String() -> String {
        ISO8601DateFormatter.penaltiesFormatter.string(from: self)
    }
}

private extension ISO8601DateFormatter {
    static let penaltiesFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

private extension DateFormatter {
    static let penaltiesFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()
}
