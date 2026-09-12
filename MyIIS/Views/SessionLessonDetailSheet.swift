import SwiftUI

struct ScheduleLessonDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ScheduleDisplayPreferences.lessonTrackingEnabledKey, store: ScheduleDisplayPreferences.defaults)
    private var lessonTrackingEnabled = true
    @State private var photoTeacher: DisciplineEmployee?
    @State private var isTracked = false

    let lesson: DisciplineSchedule
    var currentGroupName: String? = nil
    var nextOccurrenceDate: Date? = nil
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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if lessonTrackingEnabled, !lesson.isAnnouncement {
                        trackingSection
                    }
                    teachersSection
                    if !displayedStudentGroups.isEmpty {
                        groupsSection
                    }
                    detailsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(shortTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel(NSLocalizedString("common_close", comment: ""))
                }
            }
        }
        .sheet(item: $photoTeacher) { teacher in
            TeacherPhotoSheet(teacher: teacher)
        }
        .onAppear {
            isTracked = LessonTrackingStore.isTracked(lesson)
        }
    }

    private var trackingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: Binding(
                get: { isTracked },
                set: { newValue in
                    isTracked = newValue
                    LessonTrackingStore.setTracked(newValue, for: lesson)
                }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Отслеживать предмет")
                            .font(.headline)
                        Text("Показывать, когда снова будет такая пара")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "clock.arrow.2.circlepath")
                        .foregroundStyle(Color.accentColor)
                }
            }

            if isTracked {
                Divider()

                if let nextOccurrenceDate {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Следующая пара")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(nextOccurrenceDate, style: .relative)
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                            Text(Self.nextOccurrenceFormatter.string(from: nextOccurrenceDate))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 12)

                        Image(systemName: "calendar.badge.clock")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityElement(children: .combine)
                } else {
                    Label("Следующего занятия пока нет в расписании", systemImage: "calendar.badge.exclamationmark")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private var teachersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Преподаватели")
                .font(.title3.bold())
                .foregroundStyle(.secondary)

            if !lesson.employees.isEmpty {
                ForEach(lesson.employees) { teacher in
                    let hasPhoto = hasPhotoAvailable(teacher)
                    HStack(spacing: 14) {
                        if hasPhoto {
                            Button {
                                photoTeacher = teacher
                            } label: {
                                ZStack(alignment: .bottomTrailing) {
                                    TeacherAvatarView(teacher: teacher, size: 56)
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 20, height: 20)
                                        .background(Color.black.opacity(0.6), in: Circle())
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(
                                String(
                                    format: String(localized: "Открыть фотографию %@"),
                                    teacher.fullName
                                )
                            )
                        } else {
                            TeacherAvatarView(teacher: teacher, size: 56)
                        }

                        Button {
                            onTeacherScheduleTap(teacher)
                        } label: {
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(teacher.fullName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)

                                    if let extra = teacher.degree?.nilIfBlank ?? teacher.rank?.nilIfBlank {
                                        Text(extra)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Image(systemName: "chevron.right")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(String(localized: "Открывает расписание преподавателя"))
                    }
                    .padding(14)
                    .background(
                        Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                }
            } else {
                Text("Не указан")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
            }
        }
    }

    private func hasPhotoAvailable(_ teacher: DisciplineEmployee) -> Bool {
        guard let link = teacher.photoLink?.trimmingCharacters(in: .whitespacesAndNewlines),
              !link.isEmpty,
              !link.hasSuffix("null"),
              !link.contains("placeholder") else {
            return false
        }
        return true
    }

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Группы")
                .font(.title3.bold())
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
                            .background(
                                Color(uiColor: .secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
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
                .font(.title3.bold())
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                Text(fullSubjectTitle)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 14)

                if let note = lesson.note.nilIfBlank {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Описание")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(note)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    .padding(.bottom, 14)

                    Divider()
                }

                detailRow("Время", value: lesson.timeRange.nilIfBlank ?? "--")
                detailRow("День", value: lessonDateText)
                detailRow("Тип", value: lesson.lessonTypeAbbrev.nilIfBlank ?? "--")
                detailRow("Подгруппа", value: lesson.subgroup > 0 ? String(lesson.subgroup) : "--")
                detailRow("Аудитория", value: lesson.location.nilIfBlank ?? "--")
                weeksRow
            }
            .padding(16)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
    }

    private var weeksRow: some View {
        HStack(alignment: .center) {
            Text(LocalizedStringKey("Недели"))
                .font(.title3.weight(.regular))
                .foregroundStyle(.primary)

            Spacer(minLength: 16)

            HStack(spacing: 8) {
                ForEach(1...4, id: \.self) { week in
                    let isActive = lesson.weekNumbers.contains(week)
                    Image(systemName: isActive ? "\(week).circle.fill" : "\(week).circle")
                        .font(.title3.weight(isActive ? .semibold : .regular))
                        .foregroundStyle(isActive ? Color.accentColor : Color.secondary.opacity(0.35))
                }
            }
        }
        .padding(.vertical, 13)
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

    private static let nextOccurrenceFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

enum LessonTrackingStore {
    private static let trackedLessonsKey = "schedule.trackedLessons"

    static func identifier(for lesson: DisciplineSchedule) -> String {
        let subject = lesson.subject
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .autoupdatingCurrent)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        let lessonType = lesson.lessonTypeAbbrev
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .autoupdatingCurrent)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(subject)|\(lessonType)|\(lesson.subgroup)"
    }

    static func isTracked(_ lesson: DisciplineSchedule, defaults: UserDefaults = .standard) -> Bool {
        Set(defaults.stringArray(forKey: trackedLessonsKey) ?? []).contains(identifier(for: lesson))
    }

    static func setTracked(
        _ isTracked: Bool,
        for lesson: DisciplineSchedule,
        defaults: UserDefaults = .standard
    ) {
        var identifiers = Set(defaults.stringArray(forKey: trackedLessonsKey) ?? [])
        let identifier = identifier(for: lesson)
        if isTracked {
            identifiers.insert(identifier)
        } else {
            identifiers.remove(identifier)
        }
        defaults.set(identifiers.sorted(), forKey: trackedLessonsKey)
    }
}

// MARK: - Teacher Photo Sheet

private struct TeacherPhotoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let teacher: DisciplineEmployee

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                if let url = photoURL {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(20)
                    } placeholder: {
                        ProgressView()
                            .tint(.secondary)
                    } failure: {
                        fallbackView
                    }
                } else {
                    fallbackView
                }
            }
            .navigationTitle(teacher.fullName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("common_close", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var fallbackView: some View {
        VStack(spacing: 16) {
            TeacherAvatarView(teacher: teacher, size: 88)
            Text(teacher.fullName)
                .font(.headline)
            Text("Фотография отсутствует")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }

    private var photoURL: URL? {
        guard let link = teacher.photoLink?.trimmingCharacters(in: .whitespacesAndNewlines),
              !link.isEmpty,
              !link.hasSuffix("null"),
              !link.contains("placeholder") else {
            return nil
        }
        return ScheduleEmployeePhotoURL.make(photoLink: link, employeeID: teacher.id)
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
        guard let link = teacher.photoLink?.trimmingCharacters(in: .whitespacesAndNewlines),
              !link.isEmpty,
              !link.hasSuffix("null"),
              !link.contains("placeholder") else {
            return nil
        }
        return ScheduleEmployeePhotoURL.make(
            photoLink: link,
            employeeID: teacher.id
        )
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

#Preview("Отслеживание предмета") {
    ScheduleLessonDetailSheet(
        lesson: DisciplineSchedule(
            id: "preview-database-lab",
            auditories: ["510-5"],
            endLessonTime: "12:35",
            lessonTypeAbbrev: "ЛР",
            note: nil,
            subgroup: 1,
            startLessonTime: "11:00",
            studentGroups: [],
            subject: "БД",
            subjectFullName: "Базы данных",
            weekNumbers: [1, 2, 3, 4],
            employees: [],
            lessonDate: Date(),
            startLessonDate: nil,
            endLessonDate: nil,
            isAnnouncement: false,
            isSplit: false
        ),
        currentGroupName: "420602",
        nextOccurrenceDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
        onTeacherScheduleTap: { _ in },
        onGroupTap: { _ in }
    )
}
