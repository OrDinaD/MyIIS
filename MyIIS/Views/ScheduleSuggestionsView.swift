import SwiftUI

struct ScheduleSuggestionsView: View {
    let groups: [StudyGroup]
    let accountGroupName: String?
    let showsAllGroups: Bool
    let onSelect: (StudyGroup) -> Void
    let onShowAllGroups: () -> Void

    var body: some View {
        if groups.isEmpty {
            ServiceEmptyState(text: NSLocalizedString("services_schedule_groups_empty", comment: ""))
        } else {
            VStack(spacing: 8) {
                ForEach(visibleGroups, id: \.name) { group in
                    Button {
                        onSelect(group)
                    } label: {
                        groupRow(group)
                    }
                    .buttonStyle(.plain)
                }

                if !showsAllGroups, groups.count > visibleGroups.count {
                    Button {
                        onShowAllGroups()
                    } label: {
                        Label(
                            NSLocalizedString("services_schedule_show_more_groups", value: "Показать другие группы", comment: ""),
                            systemImage: "person.2"
                        )
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var visibleGroups: ArraySlice<StudyGroup> {
        groups.prefix(showsAllGroups ? 30 : 1)
    }

    private func groupRow(_ group: StudyGroup) -> some View {
        HStack(spacing: 10) {
            Image(systemName: group.name == accountGroupName ? "person.crop.circle.badge.checkmark" : "person.2.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(group.name == accountGroupName ? .green : .blue)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
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
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

private extension StudyGroup {
    var detailsText: String {
        let speciality = [specialityAbbrev.nilIfBlank, specialityName.nilIfBlank]
            .compactMap { $0 }
            .joined(separator: " · ")
        let faculty = [facultyAbbrev.nilIfBlank, facultyName.nilIfBlank]
            .compactMap { $0 }
            .joined(separator: " · ")
        let courseText = course.map { String(format: NSLocalizedString("services_schedule_course_number", value: "%d курс", comment: ""), $0) }
        return [faculty.nilIfBlank, speciality.nilIfBlank, courseText].compactMap { $0 }.joined(separator: " • ")
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
