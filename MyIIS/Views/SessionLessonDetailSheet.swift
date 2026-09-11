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
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if lessonTrackingEnabled, !lesson.isAnnouncement {
                    trackingSection
                }
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
        .background(.clear)
        .fullScreenCover(item: $photoTeacher) { teacher in
            TeacherPhotoPreview(teacher: teacher)
        }
        .onAppear {
            isTracked = LessonTrackingStore.isTracked(lesson)
        }
    }

    private var header: some View {
        ZStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay {
                        Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(shortTitle)
                .font(.title2.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
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
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
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
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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

// MARK: - Teacher Photo Preview

private struct TeacherPhotoPreview: View {
    @Environment(\.dismiss) private var dismiss
    let teacher: DisciplineEmployee

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var rotation: Angle = .zero
    @State private var lastRotation: Angle = .zero

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

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
                .padding(.horizontal, 20)
                .scaleEffect(scale)
                .rotationEffect(rotation)
                .offset(offset)
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = max(0.8, lastScale * value)
                            }
                            .onEnded { _ in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    if scale < 1.0 {
                                        scale = 1.0
                                        offset = .zero
                                    } else if scale > 4.0 {
                                        scale = 4.0
                                    }
                                    lastScale = scale
                                }
                            },
                        RotationGesture()
                            .onChanged { angle in
                                rotation = lastRotation + angle
                            }
                            .onEnded { _ in
                                lastRotation = rotation
                            }
                    )
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            if scale > 1.05 {
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            } else {
                                offset = CGSize(
                                    width: value.translation.width * 0.4,
                                    height: max(0, value.translation.height)
                                )
                            }
                        }
                        .onEnded { value in
                            if scale <= 1.05 && value.translation.height > 90 {
                                dismiss()
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    if scale <= 1.05 {
                                        offset = .zero
                                        lastOffset = .zero
                                    } else {
                                        lastOffset = offset
                                    }
                                }
                            }
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if scale > 1.2 {
                            scale = 1.0
                            lastScale = 1.0
                            offset = .zero
                            lastOffset = .zero
                            rotation = .zero
                            lastRotation = .zero
                        } else {
                            scale = 2.5
                            lastScale = 2.5
                        }
                    }
                }
            } else {
                TeacherAvatarView(teacher: teacher, size: 160)
                    .onTapGesture {
                        dismiss()
                    }
            }
        }
    }

    private var photoURL: URL? {
        ScheduleEmployeePhotoURL.make(
            photoLink: teacher.photoLink,
            employeeID: teacher.id
        )
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
        ScheduleEmployeePhotoURL.make(
            photoLink: teacher.photoLink,
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
