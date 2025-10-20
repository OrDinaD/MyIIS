import Foundation

protocol GroupServiceProtocol {
    func fetchGroupForCurrentUser() async throws -> GroupInfo
    func fetchGroup(for groupNumber: String) async throws -> GroupInfo
}

enum GroupServiceError: LocalizedError {
    case notAuthenticated
    case groupNotSpecified
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Необходимо войти в систему."
        case .groupNotSpecified:
            return "Не указан номер группы."
        case .invalidResponse:
            return "Не удалось получить данные группы."
        }
    }
}

final class GroupService: GroupServiceProtocol {

    private let apiService: APIService
    private let authenticationService: AuthenticationService
    private let logService: LogService

    init(
        apiService: APIService = APIService(),
        authenticationService: AuthenticationService = .shared,
        logService: LogService = .shared
    ) {
        self.apiService = apiService
        self.authenticationService = authenticationService
        self.logService = logService
    }

    func fetchGroupForCurrentUser() async throws -> GroupInfo {
        guard let user = authenticationService.currentUser else {
            logService.log("❌ GroupService: user is not authenticated")
            throw GroupServiceError.notAuthenticated
        }

        return try await fetchGroup(for: user.education.group)
    }

    func fetchGroup(for groupNumber: String) async throws -> GroupInfo {
        let trimmedGroup = groupNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGroup.isEmpty else {
            logService.log("❌ GroupService: group number is empty")
            throw GroupServiceError.groupNotSpecified
        }

        logService.log("📘 Loading group info for \(trimmedGroup)")

        do {
            let response = try await apiService.getGroupMembers(group: trimmedGroup)
            guard !response.members.isEmpty else {
                logService.log("❌ GroupService: empty members list for group \(trimmedGroup)")
                throw GroupServiceError.invalidResponse
            }

            let members = response.members.compactMap(makeMember(from:))
            let curator = makeCurator(from: response.curator)

            let course = response.course ?? authenticationService.currentUser?.education.course
            let faculty = response.faculty ?? authenticationService.currentUser?.education.faculty
            let speciality = response.speciality ?? authenticationService.currentUser?.education.speciality
            let number = response.groupNumber ?? trimmedGroup

            let groupInfo = GroupInfo(
                groupNumber: number,
                course: course,
                faculty: faculty,
                speciality: speciality,
                curator: curator,
                members: members
            )

            logService.log("✅ GroupService: loaded \(groupInfo.members.count) members")
            return groupInfo
        } catch {
            if let apiError = error as? APIError {
                logService.log("❌ GroupService API error: \(apiError.localizedDescription)")
                throw apiError
            }
            logService.log("❌ GroupService unexpected error: \(error.localizedDescription)")
            throw error
        }
    }

    private func makeMember(from response: GroupMemberResponse) -> GroupMember? {
        let identifierSource = response.id ?? {
            let base = [response.fio, response.lastName, response.firstName, response.middleName]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .joined(separator: "_")
            return base.isEmpty ? nil : abs(base.hashValue)
        }()

        guard let id = identifierSource else {
            return nil
        }

        let nameComponents = parseName(
            firstName: response.firstName,
            lastName: response.lastName,
            middleName: response.middleName,
            fio: response.fio
        )

        let contacts = buildContacts(phone: response.mobilePhone ?? response.phone, email: response.email)

        let roleString = response.role ?? response.roles?.first ?? "student"
        let resolvedRole: GroupRole
        if response.isHead == true {
            resolvedRole = .head
        } else if response.isDeputy == true {
            resolvedRole = .deputy
        } else if response.isMonitor == true {
            resolvedRole = .monitor
        } else {
            resolvedRole = GroupRole(string: roleString)
        }

        let avatarURL: URL?
        if let photoUrl = response.photoUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
           !photoUrl.isEmpty {
            avatarURL = URL(string: photoUrl)
        } else {
            avatarURL = nil
        }

        return GroupMember(
            id: id,
            firstName: nameComponents.first,
            lastName: nameComponents.last,
            middleName: nameComponents.middle,
            role: resolvedRole,
            contacts: contacts,
            avatarURL: avatarURL
        )
    }

    private func makeCurator(from response: GroupCuratorResponse?) -> GroupCurator? {
        guard let response else { return nil }
        let fullName = response.fio ?? ""
        let contacts = buildContacts(phone: response.mobilePhone ?? response.phone, email: response.email)
        guard !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !contacts.isEmpty else {
            return nil
        }
        return GroupCurator(fullName: fullName.isEmpty ? "Куратор" : fullName, contacts: contacts)
    }

    private func buildContacts(phone: String?, email: String?) -> [ContactItem] {
        var contacts: [ContactItem] = []
        if let phone, !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            contacts.append(ContactItem(type: .phone, value: phone))
        }
        if let email, !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            contacts.append(ContactItem(type: .email, value: email))
        }
        return contacts
    }

    private func parseName(
        firstName: String?,
        lastName: String?,
        middleName: String?,
        fio: String?
    ) -> (first: String, last: String, middle: String) {
        if let fio, !fio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let components = fio
                .split(separator: " ")
                .map { String($0) }
            let last = components.first ?? ""
            let first = components.count > 1 ? components[1] : ""
            let middle = components.count > 2 ? components[2] : ""
            return (first, last, middle)
        }

        return (
            firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            lastName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            middleName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )
    }
}

#if DEBUG
struct GroupServiceMock: GroupServiceProtocol {
    var result: Result<GroupInfo, Error>

    init(result: Result<GroupInfo, Error> = .success(.preview)) {
        self.result = result
    }

    func fetchGroupForCurrentUser() async throws -> GroupInfo {
        switch result {
        case .success(let info):
            return info
        case .failure(let error):
            throw error
        }
    }

    func fetchGroup(for groupNumber: String) async throws -> GroupInfo {
        try await fetchGroupForCurrentUser()
    }
}
#endif
