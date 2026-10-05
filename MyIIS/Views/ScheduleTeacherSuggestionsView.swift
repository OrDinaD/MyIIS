import SwiftUI

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
            LazyVStack(spacing: 0) {
                ForEach(employees) { employee in
                    let isPinned = pinnedTeachers.contains(where: { $0.urlId == employee.urlId })
                    HStack(spacing: 2) {
                        Button {
                            onSelect(employee)
                        } label: {
                            HStack(spacing: 12) {
                                teacherPhoto(for: employee)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(employee.displayName)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)

                                    if let degree = employee.degree?.nilIfBlank {
                                        Text(degree)
                                            .font(.caption)
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

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
                    if employee.id != employees.last?.id {
                        Divider().padding(.leading, 70)
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
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
