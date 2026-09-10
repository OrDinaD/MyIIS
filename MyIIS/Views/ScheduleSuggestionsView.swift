import SwiftUI

struct ScheduleSuggestionsView: View {
    let groups: [StudyGroup]
    let pinnedGroupNames: [String]
    let recentGroupNames: [String]
    let accountGroupName: String?
    var isSearching: Bool = false
    let showsAllGroups: Bool
    let onSelect: (StudyGroup) -> Void
    let onTogglePin: (StudyGroup) -> Void
    let onShowAllGroups: () -> Void

    var body: some View {
        if groups.isEmpty {
            ServiceEmptyState(text: NSLocalizedString("services_schedule_groups_empty", comment: ""))
        } else if isSearching {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(groups, id: \.name) { group in
                    groupRowButton(group, isPinned: pinnedGroupNames.contains(group.name))
                }
            }
        } else {
            VStack(spacing: 12) {
                if !pinnedGroups.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        sectionLabel(NSLocalizedString("schedule_pinned_header", value: "Закреплённые", comment: ""), icon: "pin.fill")
                        ForEach(pinnedGroups, id: \.name) { group in
                            groupRowButton(group, isPinned: true)
                        }
                    }
                }

                if !recentGroups.isEmpty && !showsAllGroups {
                    VStack(alignment: .leading, spacing: 6) {
                        sectionLabel(NSLocalizedString("schedule_recents_header", value: "Недавние", comment: ""), icon: "clock.arrow.circlepath")
                        ForEach(recentGroups, id: \.name) { group in
                            groupRowButton(group, isPinned: pinnedGroupNames.contains(group.name))
                        }
                    }
                }

                if pinnedGroups.isEmpty && recentGroups.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(visibleGroups, id: \.name) { group in
                            groupRowButton(group, isPinned: pinnedGroupNames.contains(group.name))
                        }
                    }
                } else if showsAllGroups {
                    VStack(alignment: .leading, spacing: 6) {
                        sectionLabel(NSLocalizedString("schedule_all_groups_header", value: "Группы", comment: ""), icon: "person.2.fill")
                        ForEach(visibleGroups, id: \.name) { group in
                            groupRowButton(group, isPinned: pinnedGroupNames.contains(group.name))
                        }
                    }
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
        let pinnedSet = Set(pinnedGroupNames)
        return recentGroupNames
            .filter { !pinnedSet.contains($0) }
            .compactMap { lookup[$0] }
    }

    private var visibleGroups: [StudyGroup] {
        let exclude = Set(pinnedGroupNames + recentGroupNames)
        let remaining = groups.filter { !exclude.contains($0.name) }
        return Array(remaining.prefix(showsAllGroups ? 35 : 5))
    }

    private func sectionLabel(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }

    // Selection, pinning, context-menu, and accessibility belong to one atomic row.
    // swiftlint:disable:next function_body_length
    private func groupRowButton(_ group: StudyGroup, isPinned: Bool) -> some View {
        HStack(spacing: 2) {
            Button {
                onSelect(group)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: group.name == accountGroupName ? "person.crop.circle.badge.checkmark" : "person.2.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(group.name == accountGroupName ? .green : .blue)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(group.name)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .monospacedDigit()

                            if group.name == accountGroupName {
                                Text(NSLocalizedString("services_schedule_my_group", comment: ""))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.green)
                            }
                        }

                        Text(group.detailsText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                onTogglePin(group)
            } label: {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.subheadline)
                    .foregroundStyle(isPinned ? Color.orange : Color(uiColor: .tertiaryLabel))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                isPinned
                    ? NSLocalizedString("schedule_unpin", value: "Открепить", comment: "")
                    : NSLocalizedString("schedule_pin", value: "Закрепить", comment: "")
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contextMenu {
            Button {
                onTogglePin(group)
            } label: {
                Label(
                    isPinned
                        ? NSLocalizedString("schedule_unpin", value: "Открепить", comment: "")
                        : NSLocalizedString("schedule_pin", value: "Закрепить", comment: ""),
                    systemImage: isPinned ? "pin.slash" : "pin"
                )
            }
        }
    }
}

struct ScheduleTeacherSuggestionsView: View {
    let employees: [ScheduleEmployeeDirectoryEntry]
    let pinnedTeachers: [PinnedTeacher]
    let recentTeachers: [PinnedTeacher]
    let isWaitingForQuery: Bool
    let onSelect: (ScheduleEmployeeDirectoryEntry) -> Void
    let onTogglePin: (ScheduleEmployeeDirectoryEntry) -> Void

    var body: some View {
        if isWaitingForQuery {
            ServiceEmptyState(text: NSLocalizedString("services_schedule_teacher_search_hint", comment: ""))
        } else if employees.isEmpty {
            ServiceEmptyState(text: NSLocalizedString("services_schedule_employees_empty", comment: ""))
        } else {
            VStack(spacing: 8) {
                ForEach(employees.prefix(15)) { employee in
                    let isPinned = pinnedTeachers.contains(where: { $0.urlId == employee.urlId })
                    HStack(spacing: 2) {
                        Button {
                            onSelect(employee)
                        } label: {
                            HStack(spacing: 12) {
                                teacherPhoto(for: employee)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(employee.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)

                                    if let degree = employee.degree?.nilIfBlank {
                                        Text(degree)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            onTogglePin(employee)
                        } label: {
                            Image(systemName: isPinned ? "pin.fill" : "pin")
                                .font(.subheadline)
                                .foregroundStyle(isPinned ? Color.orange : Color(uiColor: .tertiaryLabel))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            isPinned
                                ? NSLocalizedString("schedule_unpin", value: "Открепить", comment: "")
                                : NSLocalizedString("schedule_pin", value: "Закрепить", comment: "")
                        )
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .contextMenu {
                        Button {
                            onTogglePin(employee)
                        } label: {
                            Label(
                                isPinned
                                    ? NSLocalizedString("schedule_unpin", value: "Открепить", comment: "")
                                    : NSLocalizedString("schedule_pin", value: "Закрепить", comment: ""),
                                systemImage: isPinned ? "pin.slash" : "pin"
                            )
                        }
                    }
                }
            }
        }
    }

    private func teacherPhoto(for employee: ScheduleEmployeeDirectoryEntry) -> some View {
        Group {
            if let url = employee.photoURL {
                CachedAsyncImage(url: url, maxPixelSize: 96) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    teacherPlaceholder
                }
            } else {
                teacherPlaceholder
            }
        }
        .frame(width: 42, height: 42)
        .clipShape(Circle())
    }

    private var teacherPlaceholder: some View {
        ZStack {
            Circle().fill(Color(uiColor: .tertiarySystemGroupedBackground))
            Image(systemName: "person.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private extension StudyGroup {
    var detailsText: String {
        let courseText = course.map {
            String(format: NSLocalizedString("services_schedule_course_number", value: "%d курс", comment: ""), $0)
        }
        return [facultyAbbrev.nilIfBlank, specialityAbbrev.nilIfBlank, courseText]
            .compactMap { $0 }
            .joined(separator: " • ")
    }
}

private extension ScheduleEmployeeDirectoryEntry {
    var photoURL: URL? {
        guard let link = photoLink.nilIfBlank else { return nil }
        let normalized = link
            .replacingOccurrences(of: "http://", with: "https://")
            .replacingOccurrences(of: "null/", with: "https://iis.bsuir.by/")
        return URL(string: normalized)
    }
}
