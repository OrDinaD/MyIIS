import Foundation
import Combine

@MainActor
final class GroupViewModel: ObservableObject {

    @Published private(set) var groupInfo: GroupInfo?
    @Published private(set) var members: [GroupMember]
    @Published private(set) var filteredMembers: [GroupMember]
    @Published private(set) var filteredCurator: GroupCurator?
    @Published var searchText: String {
        didSet { applyFilters() }
    }
    @Published var isLoading: Bool
    @Published var errorMessage: String?

    private let groupService: GroupServiceProtocol

    init(groupService: GroupServiceProtocol = GroupService(), initialGroupInfo: GroupInfo? = nil) {
        self.groupService = groupService
        let initialMembers = GroupViewModel.sortMembers(from: initialGroupInfo?.members ?? [])
        self.groupInfo = initialGroupInfo
        self.members = initialMembers
        self.filteredMembers = initialMembers
        self.filteredCurator = initialGroupInfo?.curator
        self.searchText = ""
        self.isLoading = false
        self.errorMessage = nil
    }

    var title: String {
        groupInfo?.displayTitle ?? "Группа"
    }

    var subtitle: String? {
        guard let info = groupInfo else { return nil }
        var parts: [String] = []
        if let course = info.course {
            parts.append("\(course) курс")
        }
        if let speciality = info.speciality, !speciality.isEmpty {
            parts.append(speciality)
        }
        if let faculty = info.faculty, !faculty.isEmpty {
            parts.append(faculty)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    var memberCountText: String? {
        guard let info = groupInfo else { return nil }
        return "\(info.members.count) участников"
    }

    var headMember: GroupMember? {
        filteredMembers.first { $0.role == .head }
    }

    var deputyMembers: [GroupMember] {
        filteredMembers.filter { $0.role == .deputy || $0.role == .monitor }
    }

    var studentMembers: [GroupMember] {
        filteredMembers.filter { member in
            switch member.role {
            case .student, .other:
                return true
            case .head, .deputy, .monitor, .curator:
                return false
            }
        }
    }

    var isSearchActive: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasResults: Bool {
        !filteredMembers.isEmpty || filteredCurator != nil
    }

    func loadGroup() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let info = try await groupService.fetchGroupForCurrentUser()
            apply(groupInfo: info)
        } catch {
            if let apiError = error as? APIError {
                errorMessage = apiError.localizedDescription
            } else if let groupError = error as? GroupServiceError {
                errorMessage = groupError.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    func refresh() async {
        await loadGroup()
    }

    func retry() async {
        await loadGroup()
    }

    private func apply(groupInfo: GroupInfo) {
        self.groupInfo = groupInfo
        let sorted = GroupViewModel.sortMembers(from: groupInfo.members)
        self.members = sorted
        applyFilters(using: sorted, curator: groupInfo.curator)
    }

    private func applyFilters() {
        applyFilters(using: members, curator: groupInfo?.curator)
    }

    private func applyFilters(using members: [GroupMember], curator: GroupCurator?) {
        guard !members.isEmpty else {
            filteredMembers = []
            filteredCurator = curator
            return
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            filteredMembers = members
            filteredCurator = curator
            return
        }

        let filtered = members.filter { $0.matches(searchText: query) }
        filteredMembers = filtered
        if let curator, curator.matches(searchText: query) {
            filteredCurator = curator
        } else {
            filteredCurator = nil
        }
    }

    private static func sortMembers(from members: [GroupMember]) -> [GroupMember] {
        let roleOrder: [GroupRole: Int] = [
            .head: 0,
            .deputy: 1,
            .monitor: 2,
            .student: 3,
            .other: 4,
            .curator: 5
        ]

        return members.sorted { lhs, rhs in
            let leftPriority = roleOrder[lhs.role] ?? 10
            let rightPriority = roleOrder[rhs.role] ?? 10
            if leftPriority == rightPriority {
                let lastComparison = lhs.lastName.localizedCaseInsensitiveCompare(rhs.lastName)
                if lastComparison == .orderedSame {
                    return lhs.firstName.localizedCaseInsensitiveCompare(rhs.firstName) == .orderedAscending
                }
                return lastComparison == .orderedAscending
            }
            return leftPriority < rightPriority
        }
    }
}

#if DEBUG
extension GroupViewModel {
    static var preview: GroupViewModel {
        GroupViewModel(groupService: GroupServiceMock(), initialGroupInfo: .preview)
    }
}
#endif
