import SwiftUI

struct ScheduleLessonDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var photoTeacher: DisciplineEmployee?

    let lesson: DisciplineSchedule
    var currentGroupName: String? = nil
    let onTeacherScheduleTap: (DisciplineEmployee) -> Void
    var onGroupTap: ((String) -> Void)?

    private var displayedStudentGroups: [DisciplineStudentGroup] {
        guard let current = currentGroupName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !current.isEmpty else {
            return lesson.studentGroups
        }
        return lesson.studentGroups.filter { group in
            guard let name = group.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else {
                return false
            }
            return name.caseInsensitiveCompare(current) != .orderedSame
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                teachersSection
                if !displayedStudentGroups.isEmpty {
                    groupsSection
                }
                detailsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .fullScreenCover(item: $photoTeacher) { teacher in
            TeacherPhotoPreview(teacher: teacher)
        }
    }

    private var header: some View {
        ZStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 48, height: 48)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(shortTitle)
                .font(.title.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private var teachersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Преподаватели")
                .font(.title2.bold())
                .foregroundStyle(.secondary)

            if !lesson.employees.isEmpty {
                ForEach(lesson.employees) { teacher in
                    HStack(spacing: 14) {
                        Button {
                            photoTeacher = teacher
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                TeacherAvatarView(teacher: teacher, size: 72)
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 26, height: 26)
                                    .background(Color.black.opacity(0.55), in: Circle())
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            String(
                                format: String(localized: "Открыть фотографию %@"),
                                teacher.fullName
                            )
                        )

                        Button {
                            onTeacherScheduleTap(teacher)
                        } label: {
                            HStack(spacing: 10) {
                                Text(teacher.fullName)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "chevron.right")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(String(localized: "Открывает расписание преподавателя"))
                    }
                    .padding(14)
                    .background(
                        Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                    )
                }
            } else {
                Text("Не указан")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Группы")
                .font(.title2.bold())
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(displayedStudentGroups, id: \.name) { group in
                    if let name = group.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            onGroupTap?(name)
                        } label: {
                            HStack {
                                Image(systemName: "person.2.fill")
                                    .font(.headline)
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 28)

                                Text(name)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.primary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(onGroupTap == nil)
                    }
                }
            }
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Детали")
                .font(.title2.bold())
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                Text(fullSubjectTitle)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .padding(.bottom, 14)

                detailRow("Время", value: lesson.timeRange.nilIfBlank ?? "--")
                detailRow("День", value: lessonDateText)
                detailRow("Тип", value: lesson.lessonTypeAbbrev.nilIfBlank ?? "--")
                detailRow("Подгруппа", value: lesson.subgroup > 0 ? String(lesson.subgroup) : "--")
                detailRow("Аудитория", value: lesson.location.nilIfBlank ?? "--")
                detailRow("Недели", value: weekText, showsDivider: false)
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private func detailRow(_ title: String, value: String, showsDivider: Bool = true) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(LocalizedStringKey(title))
                    .font(.title3.weight(.regular))
                    .foregroundStyle(.primary)
                Spacer(minLength: 16)
                Text(value)
                    .font(.title3.weight(.regular))
                    .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
            }
            .padding(.vertical, 13)

            if showsDivider {
                Divider()
            }
        }
    }

    private var shortTitle: String {
        if lesson.isAnnouncement { return String(localized: "Объявление") }
        return lesson.subject.nilIfBlank ?? lesson.title
    }

    private var fullSubjectTitle: String {
        if lesson.isAnnouncement {
            return lesson.note.nilIfBlank ?? String(localized: "Объявление")
        }
        return lesson.subjectFullName?.nilIfBlank ?? lesson.subject.nilIfBlank ?? lesson.title
    }

    private var lessonDateText: String {
        guard let date = lesson.lessonDate ?? lesson.startLessonDate else { return "--" }
        return Self.dateFormatter.string(from: date)
    }

    private var weekText: String {
        guard !lesson.weekNumbers.isEmpty else { return "--" }
        return lesson.weekNumbers.map(String.init).joined(separator: ", ")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

// MARK: - Teacher Photo Preview

private struct TeacherPhotoPreview: View {
    @Environment(\.dismiss) private var dismiss
    let teacher: DisciplineEmployee

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                if let url = photoURL {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } placeholder: {
                        ProgressView()
                            .tint(.white)
                    }
                    .padding(.horizontal, 24)
                } else {
                    TeacherAvatarView(teacher: teacher, size: 160)
                }

                Text(teacher.fullName)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer()
            }
        }
    }

    private var photoURL: URL? {
        guard let link = teacher.photoLink.nilIfBlank else { return nil }
        return URL(string: link
            .replacingOccurrences(of: "http://", with: "https://")
            .replacingOccurrences(of: "null/", with: "https://iis.bsuir.by/"))
    }
}

// MARK: - Teacher Avatar View

private struct TeacherAvatarView: View {
    let teacher: DisciplineEmployee
    let size: CGFloat

    var body: some View {
        if let url = photoURL {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                avatarPlaceholder
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            avatarPlaceholder
                .frame(width: size, height: size)
        }
    }

    private var photoURL: URL? {
        guard let link = teacher.photoLink.nilIfBlank else { return nil }
        return URL(string: link
            .replacingOccurrences(of: "http://", with: "https://")
            .replacingOccurrences(of: "null/", with: "https://iis.bsuir.by/"))
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle().fill(Color(uiColor: .tertiarySystemGroupedBackground))
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.45))
                .foregroundStyle(.secondary)
        }
    }
}
