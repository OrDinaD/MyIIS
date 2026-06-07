import SwiftUI

struct ScheduleSuggestionsView: View {
    let groups: [StudyGroup]
    let accountGroupName: String?
    let onSelect: (StudyGroup) -> Void

    var body: some View {
        if groups.isEmpty {
            ServiceEmptyState(text: NSLocalizedString("services_schedule_groups_empty", comment: ""))
        } else {
            VStack(spacing: 8) {
                ForEach(groups.prefix(12), id: \.name) { group in
                    Button {
                        onSelect(group)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: group.name == accountGroupName ? "person.crop.circle.badge.checkmark" : "person.3.fill")
                                .foregroundStyle(group.name == accountGroupName ? .green : .blue)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(group.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)

                                    if group.name == accountGroupName {
                                        Text(NSLocalizedString("services_schedule_my_group", comment: ""))
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.green)
                                    }
                                }
                                if let speciality = group.specialityName, !speciality.isEmpty {
                                    Text(speciality)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 8)
                        }
                        .padding(10)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ScheduleTeacherSuggestionsView: View {
    let employees: [ScheduleEmployeeDirectoryEntry]
    let onSelect: (ScheduleEmployeeDirectoryEntry) -> Void

    var body: some View {
        if employees.isEmpty {
            ServiceEmptyState(text: NSLocalizedString("services_schedule_employees_empty", comment: ""))
        } else {
            VStack(spacing: 8) {
                ForEach(employees.prefix(8)) { employee in
                    Button {
                        onSelect(employee)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.blue)
                            Text(employee.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(10)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
