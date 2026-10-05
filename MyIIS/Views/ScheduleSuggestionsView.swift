import SwiftUI

struct ScheduleSuggestionsView: View {
    let groups: [StudyGroup]
    let pinnedGroupNames: [String]
    let pinnedGroupAliases: [String: String]
    let recentGroupNames: [String]
    let accountGroupName: String?
    var isSearching: Bool = false
    let showsAllGroups: Bool
    let onSelect: (StudyGroup) -> Void
    let onTogglePin: (StudyGroup) -> Void
    let onRenamePinnedGroup: (StudyGroup) -> Void
    let onShowAllGroups: () -> Void

    var body: some View {
        if groups.isEmpty {
            ServiceEmptyState(text: NSLocalizedString("services_schedule_groups_empty", comment: ""))
        } else if isSearching {
            rows(groups)
        } else {
            VStack(alignment: .leading, spacing: 24) {
                if !pinnedGroups.isEmpty {
                    section("schedule_pinned_header", groups: pinnedGroups)
                }
                if !recentGroups.isEmpty && !showsAllGroups {
                    section("schedule_recents_header", groups: recentGroups)
                }
                if showsAllGroups || (pinnedGroups.isEmpty && recentGroups.isEmpty) {
                    rows(visibleGroups)
                }
                if !showsAllGroups {
                    Button(action: onShowAllGroups) {
                        Text(ScheduleSearchCopy.text("all_groups"))
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var groupLookup: [String: StudyGroup] {
        Dictionary(groups.map { ($0.name, $0) }, uniquingKeysWith: { current, _ in current })
    }

    private var pinnedGroups: [StudyGroup] {
        let lookup = groupLookup
        return pinnedGroupNames.compactMap { lookup[$0] }
    }

    private var recentGroups: [StudyGroup] {
        let lookup = groupLookup
        let pinned = Set(pinnedGroupNames)
        return recentGroupNames.filter { !pinned.contains($0) }.compactMap { lookup[$0] }
    }

    private var visibleGroups: [StudyGroup] {
        let exclude = Set(pinnedGroupNames + (showsAllGroups ? [] : recentGroupNames))
        return Array(groups.filter { !exclude.contains($0.name) }.prefix(showsAllGroups ? groups.count : 5))
    }

    private func section(_ key: String, groups: [StudyGroup]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString(key, comment: ""))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.leading, 16)
            rows(groups)
        }
    }

    private func rows(_ groups: [StudyGroup]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(groups, id: \.name) { group in
                ScheduleGroupSearchRow(
                    group: group,
                    alias: pinnedGroupAliases[group.name],
                    isAccountGroup: group.name == accountGroupName,
                    isPinned: pinnedGroupNames.contains(group.name),
                    onSelect: { onSelect(group) },
                    onTogglePin: { onTogglePin(group) },
                    onRename: { onRenamePinnedGroup(group) }
                )
                if group.name != groups.last?.name {
                    Divider().padding(.leading, 62)
                }
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }
}
