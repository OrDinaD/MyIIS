import SwiftUI

extension ScheduleServiceView {
    // MARK: - Header Info Bar

    @ViewBuilder
    var scheduleHeaderInfoBar: some View {
        if let subtitle = viewModel.scheduleHeaderSubtitle {
            HStack(alignment: .center, spacing: 10) {
                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Schedule Content

    @ViewBuilder
    func scheduleContent(scrollProxy: ScrollViewProxy) -> some View {
        switch viewModel.displayMode {
        case .continuous:
            continuousContent(scrollProxy: scrollProxy)
        case .byDay:
            byDayContent
        case .exams:
            examsContent
        }

        if viewModel.isCurrentModeEmpty {
            if viewModel.displayMode == .continuous && viewModel.isLoadingContinuousChunk {
                scheduleSkeletonView
            } else {
                scheduleUnavailableView
            }
        }
    }

    private func continuousContent(scrollProxy: ScrollViewProxy) -> some View {
        Group {
            if !viewModel.pastContinuousDays.isEmpty && !hidePastLessons {
                DisclosureGroup {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(viewModel.pastContinuousDays) { day in
                            continuousDayBlock(day, isPast: true)
                        }
                    }
                    .padding(.top, 10)
                } label: {
                    Label(
                        NSLocalizedString("services_schedule_past_lessons", comment: "Прошедшие занятия"),
                        systemImage: "clock.arrow.circlepath"
                    )
                    .font(.headline)
                    .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            if viewModel.hasFinishedLessonsToday {
                Text(NSLocalizedString("services_schedule_no_more_today", comment: ""))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }

            ForEach(viewModel.upcomingContinuousDays) { day in
                continuousDayBlock(day, isPast: false)
                    .id(day.id)
                    .onAppear {
                        viewModel.loadMoreContinuousDaysIfNeeded(lastVisibleDayID: day.id)
                    }
            }
        }
    }

    private func continuousDayBlock(_ day: ScheduleContinuousDay, isPast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.continuousDayTitle(for: day))
                .font(.title3.weight(.bold))
                .foregroundStyle(Calendar.current.isDateInToday(day.date) ? Color.accentColor : (isPast ? .secondary : .primary))

            ForEach(day.lessons) { lesson in
                ScheduleLessonCard(
                    lesson: lesson,
                    isCurrent: viewModel.isLessonCurrent(lesson, on: day.weekday, for: day.date),
                    progress: viewModel.currentLessonProgress(lesson, on: day.weekday, for: day.date),
                    isPast: isPast,
                    isOtherSubgroup: viewModel.isOtherSubgroupLesson(lesson),
                    isTeacherSchedule: viewModel.mode == .teacher,
                    cardDensity: lessonCardDensity(for: lesson),
                    showsMidPairBreaks: showsMidPairBreaks,
                    onTeacherTap: { teacher in
                        Task { await viewModel.openTeacherSchedule(teacher) }
                    },
                    onGroupTap: { groupName in
                        Task { await viewModel.openGroupSchedule(groupName) }
                    },
                    onDetailsTap: {
                        selectedExamLesson = lesson
                    }
                )
            }
        }
    }

    private var byDayContent: some View {
        VStack(alignment: .leading, spacing: 32) {
            if viewModel.shouldShowWeekFilter {
                Menu {
                    ForEach(viewModel.weekFilters) { filter in
                        Button {
                            viewModel.weekFilter = filter
                        } label: {
                            HStack {
                                Text(filter.localizedTitle)
                                if viewModel.weekFilter == filter {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label(
                        "\(NSLocalizedString("services_schedule_week_filter", value: "Неделя", comment: "")): \(viewModel.weekFilter.localizedTitle)",
                        systemImage: "calendar.badge.clock"
                    )
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 36)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            ForEach(viewModel.displayedDays, id: \.weekday) { day in
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.dayTitle(for: day))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)

                    ForEach(day.lessons) { lesson in
                        ScheduleLessonCard(
                            lesson: lesson,
                            isCurrent: false,
                            progress: nil,
                            isPast: false,
                            isOtherSubgroup: viewModel.isOtherSubgroupLesson(lesson),
                            isTeacherSchedule: viewModel.mode == .teacher,
                            weeksText: ScheduleServiceViewModel.weeksBadgeText(for: lesson),
                            cardDensity: lessonCardDensity(for: lesson),
                            showsMidPairBreaks: showsMidPairBreaks,
                            onTeacherTap: { teacher in
                                Task { await viewModel.openTeacherSchedule(teacher) }
                            },
                            onGroupTap: { groupName in
                                Task { await viewModel.openGroupSchedule(groupName) }
                            },
                            onDetailsTap: {
                                selectedExamLesson = lesson
                            }
                        )
                    }
                }
            }
        }
    }

    private var examsContent: some View {
        Group {
            if !viewModel.pastExamDays.isEmpty {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(viewModel.pastExamDays) { day in
                            examDayBlock(day, isPast: true)
                        }
                    }
                    .padding(.top, 10)
                } label: {
                    Label(
                        NSLocalizedString("services_schedule_past_exams", comment: "Пройденные экзамены"),
                        systemImage: "clock.arrow.circlepath"
                    )
                    .font(.headline)
                    .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            ForEach(viewModel.upcomingExamDays) { day in
                examDayBlock(day, isPast: false)
            }
        }
    }

    private func examDayBlock(_ day: ExamScheduleDay, isPast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.examDayTitle(for: day))
                .font(.title3.weight(.bold))
                .foregroundStyle(examDayTitleColor(for: day))

            ForEach(day.lessons) { exam in
                ScheduleLessonCard(
                    lesson: exam,
                    isCurrent: false,
                    progress: nil,
                    isPast: isPast || viewModel.isExamPast(exam, on: day.date),
                    isOtherSubgroup: viewModel.isOtherSubgroupLesson(exam),
                    isTeacherSchedule: viewModel.mode == .teacher,
                    cardDensity: cardDensity,
                    showsMidPairBreaks: showsMidPairBreaks,
                    onTeacherTap: { teacher in
                        Task { await viewModel.openTeacherSchedule(teacher) }
                    },
                    onGroupTap: { groupName in
                        Task { await viewModel.openGroupSchedule(groupName) }
                    },
                    onDetailsTap: {
                        selectedExamLesson = exam
                    }
                )
            }
        }
    }

    // MARK: - Empty States

    private func lessonCardDensity(for lesson: DisciplineSchedule) -> ScheduleCardDensity {
        if viewModel.isOtherSubgroupLesson(lesson), otherSubgroupDisplay == .compact {
            return .compact
        }
        return cardDensity
    }

    private func examDayTitleColor(for day: ExamScheduleDay) -> Color {
        if !day.lessons.isEmpty,
           day.lessons.allSatisfy({ viewModel.isExamPast($0, on: day.date) }) {
            return .secondary
        }
        return Calendar.current.isDateInTomorrow(day.date) ? .red : .primary
    }
}
