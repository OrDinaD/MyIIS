import SwiftUI

/// Faculty identity comes from the API abbreviation, never from facultyId or course.
enum ScheduleFacultyPalette {
    static func color(for abbreviation: String?) -> Color {
        switch abbreviation?.uppercased().replacingOccurrences(of: " ", with: "") {
        case "ФКСИС", "КСИС": return .green
        case "ФИТУ": return .blue
        case "ФКП": return .purple
        case "ФИБ", "ФИК": return Color(red: 0.72, green: 0.20, blue: 0.29)
        case "ИЭФ": return .orange
        case "ВФ": return Color(red: 0.39, green: 0.49, blue: 0.29)
        case "ФРЭ": return .teal
        case "ФКТ": return Color(red: 0.78, green: 0.58, blue: 0.20)
        default: return .secondary
        }
    }
}

enum ScheduleSearchCopy {
    static func text(_ key: String) -> String {
        NSLocalizedString(key, tableName: "ScheduleSearch", comment: "")
    }

    static func positionTitle(_ position: Int) -> String {
        text(["year", "faculty", "speciality_first", "speciality_second", "form", "stream"][position])
    }
}

struct ScheduleGroupSearchRow: View {
    let group: StudyGroup
    var alias: String?
    var isAccountGroup = false
    var isPinned = false
    let onSelect: () -> Void
    var onTogglePin: (() -> Void)?
    var onRename: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onSelect) {
                HStack(spacing: 14) {
                    Image(systemName: isAccountGroup ? "person.crop.circle.badge.checkmark" : "person.2.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(ScheduleFacultyPalette.color(for: group.facultyAbbrev))
                        .frame(width: 32)
                        .accessibilityHidden(true)
                    details
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let onTogglePin {
                Button(action: onTogglePin) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 18))
                        .foregroundStyle(isPinned ? Color.orange : .secondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(NSLocalizedString(isPinned ? "schedule_unpin" : "schedule_pin", comment: ""))
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, onTogglePin == nil ? 16 : 4)
        .contextMenu {
            if isPinned, onRename != nil { RenameButton() }
            if let onTogglePin {
                Button(action: onTogglePin) {
                    Label(
                        NSLocalizedString(isPinned ? "schedule_unpin" : "schedule_pin", comment: ""),
                        systemImage: isPinned ? "pin.slash" : "pin"
                    )
                }
            }
        }
        .renameAction { onRename?() }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(alias?.nilIfBlank.map { "\($0) · \(group.name)" } ?? group.name)
                .font(.body)
                .foregroundStyle(.primary)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            Text(group.scheduleSearchDetails)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if isAccountGroup {
                Text(NSLocalizedString("services_schedule_my_group", comment: ""))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

extension StudyGroup {
    var scheduleSearchDetails: String {
        let courseText = course.map {
            String(format: NSLocalizedString("services_schedule_course_number", value: "%d курс", comment: ""), $0)
        }
        return [facultyAbbrev.nilIfBlank, specialityAbbrev.nilIfBlank, courseText]
            .compactMap { $0 }.joined(separator: " · ")
    }
}
