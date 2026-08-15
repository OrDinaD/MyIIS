import SwiftUI

struct ScheduleLessonDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var photoTeacher: DisciplineEmployee?

    let lesson: DisciplineSchedule
    let onTeacherScheduleTap: (DisciplineEmployee) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                teachersSection
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
        formatter.locale = .autoupdatingCurrent
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
}

struct TeacherAvatarView: View {
    let teacher: DisciplineEmployee?
    let size: CGFloat

    var body: some View {
        Group {
            if let url = teacher?.securePhotoURL {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color(uiColor: .tertiarySystemFill))
                }
            } else {
                ZStack {
                    Circle().fill(Color(uiColor: .tertiarySystemFill))
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

private struct TeacherPhotoPreview: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    let teacher: DisciplineEmployee?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let url = teacher?.securePhotoURL {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView().tint(.white)
                }
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / lastScale
                            lastScale = value
                            scale = min(max(scale * delta, 1), 4)
                        }
                        .onEnded { _ in
                            lastScale = 1.0
                            if scale <= 1.0 {
                                AccessibilitySupport.update(reduceMotion: reduceMotion) {
                                    scale = 1.0
                                    offset = .zero
                                }
                            }
                        }
                        .simultaneously(with: DragGesture()
                            .onChanged { value in
                                if scale > 1.0 {
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                            }
                            .onEnded { _ in
                                lastOffset = offset
                                if scale <= 1.0 {
                                    lastOffset = .zero
                                }
                            }
                        )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .accessibilityLabel("Изображение")
                .accessibilityValue("Масштаб \(Int(scale * 100)) процентов")
                .accessibilityAction(named: "Сбросить масштаб") {
                    AccessibilitySupport.update(reduceMotion: reduceMotion) {
                        scale = 1.0
                        lastScale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    }
                }
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 160))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.white.opacity(0.18), in: Circle())
            }
            .padding(24)
            .accessibilityLabel("Закрыть")
        }
    }
}

private extension DisciplineEmployee {
    var securePhotoURL: URL? {
        guard let photoLink else { return nil }

        let normalizedLink = photoLink
            .replacingOccurrences(of: "http://", with: "https://")
            .replacingOccurrences(of: "null/", with: "https://iis.bsuir.by/")
        return URL(string: normalizedLink)
    }
}
