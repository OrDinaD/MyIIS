import Foundation

// MARK: - Group Contacts

struct ContactItem: Identifiable, Codable, Equatable {
    enum ContactType: String, Codable {
        case phone
        case email
        case messenger
        case other
    }

    let id: UUID
    let type: ContactType
    let value: String
    let label: String?

    init(id: UUID = UUID(), type: ContactType, value: String, label: String? = nil) {
        self.id = id
        self.type = type
        self.value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        self.label = label?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var formattedValue: String {
        switch type {
        case .phone:
            return Self.format(phone: value)
        default:
            return value
        }
    }

    var displayLabel: String {
        if let label, !label.isEmpty {
            return label
        }
        switch type {
        case .phone:
            return "Телефон"
        case .email:
            return "Email"
        case .messenger:
            return "Мессенджер"
        case .other:
            return "Контакт"
        }
    }

    var iconName: String {
        switch type {
        case .phone:
            return "phone.fill"
        case .email:
            return "envelope.fill"
        case .messenger:
            return "bubble.left.and.bubble.right.fill"
        case .other:
            return "person.crop.circle.fill"
        }
    }

    var url: URL? {
        switch type {
        case .phone:
            let digits = value.filter { $0.isNumber || $0 == "+" }
            return URL(string: "tel://\(digits)")
        case .email:
            return URL(string: "mailto:\(value)")
        case .messenger, .other:
            return URL(string: value)
        }
    }

    private static func format(phone: String) -> String {
        let allowedCharacters = CharacterSet(charactersIn: "+0123456789")
        let sanitized = phone.unicodeScalars.filter { allowedCharacters.contains($0) }
        guard sanitized.contains(where: { CharacterSet.decimalDigits.contains($0) }) else {
            return phone
        }

        let hasPlus = sanitized.first == "+"
        let digitsOnly = sanitized.filter { CharacterSet.decimalDigits.contains($0) }
        guard !digitsOnly.isEmpty else { return phone }

        var index = digitsOnly.startIndex
        var formatted = ""

        if digitsOnly.count > 10 {
            var countryLength = min(3, digitsOnly.count - 7)
            if digitsOnly.count == 11 { countryLength = 1 }
            if countryLength < 0 { countryLength = 0 }
            let countryEnd = digitsOnly.index(index, offsetBy: countryLength)
            let countryCode = String(digitsOnly[index..<countryEnd])
            formatted += (hasPlus ? "+" : "") + countryCode + " "
            index = countryEnd
        } else if hasPlus {
            formatted += "+"
        }

        var remaining = String(digitsOnly[index...])
        if !remaining.isEmpty {
            let areaLength: Int
            if remaining.count >= 9 {
                areaLength = 2
            } else if remaining.count >= 7 {
                areaLength = 3
            } else if remaining.count >= 5 {
                areaLength = 2
            } else {
                areaLength = remaining.count
            }
            guard areaLength > 0 else { return formatted.trimmingCharacters(in: .whitespaces) }
            let areaEnd = remaining.index(remaining.startIndex, offsetBy: areaLength)
            let areaCode = String(remaining[..<areaEnd])
            remaining = String(remaining[areaEnd...])
            if !areaCode.isEmpty {
                formatted += "(\(areaCode)) "
            }
        }

        if !remaining.isEmpty {
            let pattern = [3, 2, 2]
            var segments: [String] = []
            var restIndex = remaining.startIndex
            for size in pattern where restIndex < remaining.endIndex {
                let distance = remaining.distance(from: restIndex, to: remaining.endIndex)
                let end = remaining.index(restIndex, offsetBy: min(size, distance))
                let chunk = String(remaining[restIndex..<end])
                segments.append(chunk)
                restIndex = end
            }
            if restIndex < remaining.endIndex {
                segments.append(String(remaining[restIndex...]))
            }
            formatted += segments.joined(separator: "-")
        }

        return formatted.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Group Roles

enum GroupRole: Codable, CaseIterable {
    case head
    case deputy
    case monitor
    case curator
    case student
    case other

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = (try? container.decode(String.self)) ?? ""
        self = GroupRole.resolve(from: value)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawString)
    }

    init(string: String) {
        self = GroupRole.resolve(from: string)
    }

    private static func resolve(from value: String) -> GroupRole {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch normalized {
        case "head", "headman", "староста", "leader":
            return .head
        case "deputy", "subhead", "assistant", "заместитель", "deputyhead":
            return .deputy
        case "monitor":
            return .monitor
        case "curator", "куратор":
            return .curator
        case "student", "member":
            return .student
        default:
            return .other
        }
    }

    private var rawString: String {
        switch self {
        case .head:
            return "head"
        case .deputy:
            return "deputy"
        case .monitor:
            return "monitor"
        case .curator:
            return "curator"
        case .student:
            return "student"
        case .other:
            return "other"
        }
    }

    var displayName: String {
        switch self {
        case .head:
            return "Староста"
        case .deputy:
            return "Заместитель"
        case .monitor:
            return "Монитор"
        case .curator:
            return "Куратор"
        case .student:
            return "Студент"
        case .other:
            return "Участник"
        }
    }
}

// MARK: - Group Member

struct GroupMember: Identifiable, Codable, Equatable {
    let id: Int
    let firstName: String
    let lastName: String
    let middleName: String
    let role: GroupRole
    let contacts: [ContactItem]
    let avatarURL: URL?
    let notes: String?

    init(
        id: Int,
        firstName: String,
        lastName: String,
        middleName: String,
        role: GroupRole,
        contacts: [ContactItem] = [],
        avatarURL: URL? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.firstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.lastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.middleName = middleName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.role = role
        self.contacts = contacts
        self.avatarURL = avatarURL
        self.notes = notes
    }

    var fullName: String {
        let components = [lastName, firstName, middleName].filter { !$0.isEmpty }
        return components.joined(separator: " ")
    }

    var shortName: String {
        let firstInitial = firstName.first.map { String($0) + "." } ?? ""
        let middleInitial = middleName.first.map { String($0) + "." } ?? ""
        return "\(lastName) \(firstInitial)\(middleInitial)".trimmingCharacters(in: .whitespaces)
    }

    var initials: String {
        let firstInitial = firstName.first.map(String.init) ?? ""
        let lastInitial = lastName.first.map(String.init) ?? ""
        return "\(firstInitial)\(lastInitial)"
    }

    var primaryPhone: ContactItem? {
        contacts.first { $0.type == .phone }
    }

    var primaryEmail: ContactItem? {
        contacts.first { $0.type == .email }
    }

    func matches(searchText: String) -> Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let lowercased = trimmed.lowercased()

        if fullName.lowercased().contains(lowercased) ||
            shortName.lowercased().contains(lowercased) ||
            role.displayName.lowercased().contains(lowercased) {
            return true
        }

        for contact in contacts {
            if contact.formattedValue.lowercased().contains(lowercased) ||
                contact.value.lowercased().contains(lowercased) ||
                (contact.label?.lowercased().contains(lowercased) ?? false) {
                return true
            }
        }

        return false
    }
}

// MARK: - Group Curator

struct GroupCurator: Codable, Equatable {
    let fullName: String
    let contacts: [ContactItem]

    init(fullName: String, contacts: [ContactItem]) {
        self.fullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.contacts = contacts
    }

    var initials: String {
        let components = fullName.split(separator: " ")
        let first = components.first?.first.map(String.init) ?? ""
        let last = components.dropFirst().first?.first.map(String.init) ?? ""
        return "\(first)\(last)"
    }

    func matches(searchText: String) -> Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let lowercased = trimmed.lowercased()

        if fullName.lowercased().contains(lowercased) {
            return true
        }

        for contact in contacts {
            if contact.formattedValue.lowercased().contains(lowercased) ||
                contact.value.lowercased().contains(lowercased) ||
                (contact.label?.lowercased().contains(lowercased) ?? false) {
                return true
            }
        }

        return false
    }
}

// MARK: - Group Info

struct GroupInfo: Codable, Equatable {
    let groupNumber: String
    let course: Int?
    let faculty: String?
    let speciality: String?
    let curator: GroupCurator?
    let members: [GroupMember]

    init(
        groupNumber: String,
        course: Int?,
        faculty: String?,
        speciality: String?,
        curator: GroupCurator?,
        members: [GroupMember]
    ) {
        self.groupNumber = groupNumber
        self.course = course
        self.faculty = faculty
        self.speciality = speciality
        self.curator = curator
        self.members = members
    }

    var displayTitle: String {
        "Группа \(groupNumber)"
    }

    var head: GroupMember? {
        members.first { $0.role == .head }
    }

    var deputies: [GroupMember] {
        members.filter { $0.role == .deputy || $0.role == .monitor }
            .sorted { $0.lastName.localizedCaseInsensitiveCompare($1.lastName) == .orderedAscending }
    }

    var students: [GroupMember] {
        members.filter { member in
            switch member.role {
            case .student, .other:
                return true
            case .head, .deputy, .monitor, .curator:
                return false
            }
        }
        .sorted { lhs, rhs in
            let comparison = lhs.lastName.localizedCaseInsensitiveCompare(rhs.lastName)
            if comparison == .orderedSame {
                return lhs.firstName.localizedCaseInsensitiveCompare(rhs.firstName) == .orderedAscending
            }
            return comparison == .orderedAscending
        }
    }

    var contacts: [ContactItem] {
        var items: [ContactItem] = []
        if let curator {
            items.append(contentsOf: curator.contacts)
        }
        if let headContact = head?.primaryPhone {
            items.append(headContact)
        }
        if let deputyContact = deputies.first?.primaryPhone {
            items.append(deputyContact)
        }
        return items
    }
}

#if DEBUG
extension GroupInfo {
    static let preview = GroupInfo(
        groupNumber: "851001",
        course: 1,
        faculty: "КСиС",
        speciality: "ПОИТ",
        curator: GroupCurator(
            fullName: "Мария Сергеевна Кураторова",
            contacts: [
                ContactItem(type: .phone, value: "+375291112233"),
                ContactItem(type: .email, value: "curator@example.com")
            ]
        ),
        members: [
            GroupMember(
                id: 1,
                firstName: "Антон",
                lastName: "Парамонов",
                middleName: "Иванович",
                role: .head,
                contacts: [
                    ContactItem(type: .phone, value: "+375291234567"),
                    ContactItem(type: .email, value: "anton.paramonov@example.com")
                ]
            ),
            GroupMember(
                id: 2,
                firstName: "Екатерина",
                lastName: "Сидорова",
                middleName: "Петровна",
                role: .deputy,
                contacts: [
                    ContactItem(type: .phone, value: "+375291112244")
                ]
            ),
            GroupMember(
                id: 3,
                firstName: "Илья",
                lastName: "Козлов",
                middleName: "Алексеевич",
                role: .student,
                contacts: [
                    ContactItem(type: .messenger, value: "https://t.me/ilya", label: "Telegram")
                ]
            )
        ]
    )
}
#endif
