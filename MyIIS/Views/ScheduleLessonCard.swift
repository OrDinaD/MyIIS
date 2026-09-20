//
//  ScheduleLessonCard.swift
//  MyIIS
//

import SwiftUI

// MARK: - Teacher Header

struct ScheduleTeacherHeader: View {
    let employee: ScheduleEmployeeDirectoryEntry
    @State private var isPhotoPresented = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                isPhotoPresented = true
            } label: {
                avatar
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(employee.displayName)

            VStack(alignment: .leading, spacing: 3) {
                Text(employee.displayName)
                    .font(.headline)
                if let degree = employee.degree.nilIfBlank {
                    Text(degree)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let rank = employee.rank.nilIfBlank {
                    Text(rank)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .sheet(isPresented: $isPhotoPresented) {
            CachedAsyncImage(url: photoURL, maxPixelSize: 2_048, rejectBlankImages: true) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                avatar
            }
            .padding()
            .presentationDetents([.medium, .large])
        }
    }

    private var avatar: some View {
        TeacherAvatarView(
            photoLink: employee.photoLink, employeeID: employee.id,
            firstName: employee.firstName, middleName: employee.middleName,
            lastName: employee.lastName, size: 72
        )
    }

    private var photoURL: URL? {
        ScheduleEmployeePhotoURL.make(
            photoLink: employee.photoLink,
            employeeID: employee.id
        )
    }
}

// MARK: - Lesson Card

struct ScheduleLessonCard: View {
    let lesson: DisciplineSchedule
    let isCurrent: Bool
    let progress: Double?
    var isPast = false
    var isOtherSubgroup = false
    var isTeacherSchedule = false
    var weeksText: String?
    var cardDensity: ScheduleCardDensity = .regular
    var showsMidPairBreaks = false
    let onTeacherTap: (DisciplineEmployee) -> Void
    let onGroupTap: (String) -> Void
    var onDetailsTap: (() -> Void)?

    var body: some View {
        Button {
            onDetailsTap?()
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint(NSLocalizedString("schedule_card_details_hint", value: "Дважды коснитесь для подробностей", comment: ""))
    }

    private var cardCornerRadius: CGFloat {
        cardDensity == .compact || isOtherSubgroup ? 14 : 16
    }

    private var startLessonFont: Font {
        if cardDensity == .compact {
            return .system(size: 15, weight: .bold, design: .monospaced)
        }
        return .system(size: 16, weight: .bold, design: .monospaced)
    }

    private var endLessonFont: Font {
        if cardDensity == .compact {
            return .system(size: 11, weight: .medium, design: .monospaced)
        }
        return .system(size: 12, weight: .medium, design: .monospaced)
    }

    @ViewBuilder
    private var cardContent: some View {
        if isOtherSubgroup {
            otherSubgroupCardContent
        } else {
            regularCardContent
        }
    }

    private var otherSubgroupCardContent: some View {
        HStack(spacing: cardDensity == .compact ? 10 : 12) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(lesson.startLessonTime)
                    .font(.system(size: cardDensity == .compact ? 13 : 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(lesson.endLessonTime)
                    .font(.system(size: cardDensity == .compact ? 10 : 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.75))
            }
            .frame(width: cardDensity == .compact ? 58 : 62, alignment: .trailing)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accentColor.opacity(0.65))
                .frame(width: 4, height: cardDensity == .compact ? 20 : 24)
                .accessibilityHidden(true)

            Text(compactTitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            if lesson.subgroup > 0 {
                Text("[\(lesson.subgroup)]")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.75))
            }
        }
        .padding(.horizontal, cardDensity == .compact ? 12 : 14)
        .padding(.vertical, cardDensity == .compact ? 6 : 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Color.secondary.opacity(0.35))
        }
    }

    private var regularCardContent: some View {
        HStack(spacing: cardDensity == .compact ? 10 : 12) {
            timeColumn
                .frame(width: cardDensity == .compact ? 58 : 62, alignment: .trailing)

            accentBar(width: cardDensity == .compact ? 7 : 9)

            VStack(alignment: .leading, spacing: cardDensity == .compact ? 2 : 4) {
                HStack(spacing: 6) {
                    Text(compactTitle)
                        .font((cardDensity == .compact ? Font.subheadline : Font.headline).weight(.semibold))
                        .foregroundStyle(cardPrimaryForeground)
                        .lineLimit(2)

                    if lesson.subgroup > 0 {
                        subgroupBadge
                    }

                    if let weeksText, !weeksText.isEmpty {
                        weeksBadge(weeksText)
                    }
                }

                HStack(spacing: 6) {
                    if !lesson.location.isEmpty {
                        Text(lesson.location)
                            .lineLimit(1)
                    }

                    if let note = lesson.note.nilIfBlank, !note.isEmpty {
                        Text(note)
                            .lineLimit(cardDensity == .compact ? 1 : 3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .font(.footnote)
                .foregroundStyle(cardSecondaryForeground)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            rightTrailingElement
        }
        .padding(.horizontal, cardDensity == .compact ? 12 : 14)
        .padding(.vertical, cardDensity == .compact ? 8 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundColor, in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .overlay { cardBorder }
    }

    @ViewBuilder
    private var rightTrailingElement: some View {
        if isTeacherSchedule {
            if let groupsText = studentGroupsText {
                Text(groupsText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.12), in: Capsule())
                    .lineLimit(1)
            }
        } else if !displayedTeachers.isEmpty {
            teacherAvatarStack(size: cardDensity == .compact ? 48 : 56)
        }
    }

    private var studentGroupsText: String? {
        let names = lesson.studentGroups.compactMap(\.name).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !names.isEmpty else { return nil }
        if names.count <= 2 {
            return names.joined(separator: " · ")
        }
        return "\(names[0]) +\(names.count - 1)"
    }

    private var subgroupBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "person")
                .font(.system(size: 11, weight: .semibold))
            Text("\(lesson.subgroup)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(cardSecondaryForeground)
    }

    private func weeksBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color(uiColor: .tertiarySystemGroupedBackground), in: Capsule())
            .foregroundStyle(cardSecondaryForeground)
    }

    private var timeColumn: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(lesson.startLessonTime)
                .font(startLessonFont)
                .foregroundStyle(cardPrimaryForeground)

            if let breakTime = calculateBreakTime() {
                Text(breakTime)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(cardSecondaryForeground.opacity(0.75))
            }

            Text(lesson.endLessonTime)
                .font(endLessonFont)
                .foregroundStyle(cardPrimaryForeground)
        }
    }

    private func calculateBreakTime() -> String? {
        guard showsMidPairBreaks else { return nil }
        return ScheduleMidPairBreakCalculator.resolve(
            startTime: lesson.startLessonTime,
            endTime: lesson.endLessonTime
        )?.compactText
    }

    @ViewBuilder
    private func accentBar(width: CGFloat) -> some View {
        if let progress {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(accentColor.opacity(0.2))
                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        Color.clear.frame(height: proxy.size.height * min(max(progress, 0), 1))
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .fill(accentColor)
                    }
                }
            }
            .frame(width: width)
            .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(accentColor)
                .frame(width: width)
                .accessibilityHidden(true)
        }
    }

    private var currentBadge: some View {
        Text(NSLocalizedString("services_schedule_now_badge", value: "СЕЙЧАС", comment: ""))
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(accentColor.opacity(0.25), in: Capsule())
            .foregroundStyle(accentColor)
    }

    @ViewBuilder
    private func teacherAvatarStack(size: CGFloat) -> some View {
        if displayedTeachers.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: -(size * 0.3)) {
                ForEach(Array(displayedTeachers.prefix(2).enumerated()), id: \.element.id) { index, teacher in
                    teacherAvatar(teacher, size: size)
                        .overlay {
                            Circle().strokeBorder(Color(uiColor: .systemBackground), lineWidth: 1.5)
                        }
                        .zIndex(Double(2 - index))
                }

                if displayedTeachers.count > 2 {
                    Text("+\(displayedTeachers.count - 2)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(cardPrimaryForeground)
                        .frame(width: size, height: size)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: Circle())
                }
            }
            .fixedSize()
        }
    }

    private func teacherAvatar(_ teacher: DisciplineEmployee, size: CGFloat) -> some View {
        TeacherAvatarView(teacher: teacher, size: size)
            .saturation(isPast ? 0 : 1)
            .opacity(isPast ? 0.7 : 1)
    }

    private var displayedTeachers: [DisciplineEmployee] {
        lesson.employees.filter { !$0.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    @ViewBuilder
    private var cardBorder: some View {
        if isCurrent {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .strokeBorder(accentColor, lineWidth: 1.5)
        } else if isOtherSubgroup {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                .foregroundStyle(Color.secondary.opacity(0.45))
        }
    }

    private var cardBackgroundColor: Color {
        if isOtherSubgroup {
            return Color(uiColor: .secondarySystemGroupedBackground).opacity(0.55)
        }
        return Color(uiColor: .secondarySystemGroupedBackground)
    }

    private var cardPrimaryForeground: Color {
        isPast ? .secondary : .primary
    }

    private var cardSecondaryForeground: Color {
        .secondary
    }

    private var compactTitle: String {
        if lesson.isAnnouncement {
            return "📣 \(NSLocalizedString("local_schedule_type_announcement", comment: ""))"
        }
        return lesson.subject.nilIfBlank ?? lesson.lessonTypeAbbrev.nilIfBlank ?? lesson.title
    }

    private var accentColor: Color {
        if isPast {
            return Color.secondary.opacity(0.65)
        }
        return ScheduleColorPreferences.color(for: lesson.lessonTypeAbbrev)
    }
}
