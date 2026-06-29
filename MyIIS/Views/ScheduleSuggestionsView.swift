import SwiftUI

struct ScheduleSuggestionsView: View {
    let groups: [StudyGroup]
    let accountGroupName: String?
    let pinnedGroupNames: [String]
    let onSelect: (StudyGroup) -> Void
    let onTogglePin: (StudyGroup) -> Void

    var body: some View {
        if groups.isEmpty {
            ServiceEmptyState(text: NSLocalizedString("services_schedule_groups_empty", comment: ""))
        } else {
            VStack(spacing: 8) {
                ForEach(groups.prefix(12), id: \.name) { group in
                    groupRow(group)
                }
            }
        }
    }

    private func groupRow(_ group: StudyGroup) -> some View {
        HStack(spacing: 10) {
            Button {
                onSelect(group)
            } label: {
                groupLabel(group)
            }
            .buttonStyle(.plain)

            pinButton(for: group)
        }
        .padding(10)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        }
    }

    private func groupLabel(_ group: StudyGroup) -> some View {
        HStack(spacing: 10) {
            Image(systemName: groupIcon(for: group))
                .font(.title3.weight(.semibold))
                .foregroundStyle(group.name == accountGroupName ? .green : .blue)
                .frame(width: 28, height: 28)

            groupText(group)
        }
        .contentShape(Rectangle())
    }

    private func groupText(_ group: StudyGroup) -> some View {
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

            if let speciality = group.specialityName.nilIfBlank {
                Text(speciality)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pinButton(for group: StudyGroup) -> some View {
        Button {
            onTogglePin(group)
        } label: {
            Image(systemName: isPinned(group) ? "pin.fill" : "pin")
                .font(.callout.weight(.semibold))
                .foregroundStyle(isPinned(group) ? .orange : .secondary)
                .frame(width: 34, height: 34)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(isPinned(group) ? "Открепить группу" : "Закрепить группу")
    }

    private func isPinned(_ group: StudyGroup) -> Bool {
        pinnedGroupNames.contains(group.name)
    }

    private func groupIcon(for group: StudyGroup) -> String {
        if group.name == accountGroupName { return "person.crop.circle.badge.checkmark" }
        if isPinned(group) { return "pin.circle.fill" }
        return "person.2.fill"
    }
}

struct ScheduleTeacherSuggestionsView: View {
    let employees: [ScheduleEmployeeDirectoryEntry]
    let isWaitingForQuery: Bool
    let onSelect: (ScheduleEmployeeDirectoryEntry) -> Void

    var body: some View {
        if isWaitingForQuery {
            ServiceEmptyState(text: NSLocalizedString("services_schedule_teacher_search_hint", comment: ""))
        } else if employees.isEmpty {
            ServiceEmptyState(text: NSLocalizedString("services_schedule_employees_empty", comment: ""))
        } else {
            VStack(spacing: 8) {
                ForEach(employees.prefix(10)) { employee in
                    Button {
                        onSelect(employee)
                    } label: {
                        HStack(spacing: 12) {
                            teacherPhoto(for: employee)

                            Text(employee.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(10)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(.white.opacity(0.08))
                        }
                    }
                    .buttonStyle(.plain)
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

private extension ScheduleEmployeeDirectoryEntry {
    var photoURL: URL? {
        guard let link = photoLink.nilIfBlank else { return nil }
        let normalized = link
            .replacingOccurrences(of: "http://", with: "https://")
            .replacingOccurrences(of: "null/", with: "https://iis.bsuir.by/")
        return URL(string: normalized)
    }
}
