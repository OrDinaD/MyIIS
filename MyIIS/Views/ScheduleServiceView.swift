import Combine
import SwiftUI

// MARK: - Schedule

@MainActor
struct ScheduleServiceView: View {
    @StateObject private var viewModel = ScheduleServiceViewModel()
    @State private var scheduleReportURL: URL?

    private var loadingOverlayTitle: String {
        viewModel.isDownloadingReport
            ? NSLocalizedString("services_schedule_report_downloading", comment: "")
            : NSLocalizedString("common_loading", comment: "")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ServiceEndpointSection(
                    title: NSLocalizedString("services_schedule_title", comment: ""),
                    subtitle: NSLocalizedString("services_schedule_subtitle", comment: ""),
                    icon: "calendar"
                ) {
                    VStack(spacing: 12) {
                        Picker("", selection: $viewModel.mode) {
                            Text(NSLocalizedString("services_schedule_mode_group", comment: "")).tag(ScheduleLookupMode.group)
                            Text(NSLocalizedString("services_schedule_mode_teacher", comment: "")).tag(ScheduleLookupMode.teacher)
                        }
                        .pickerStyle(.segmented)

                        TextField(viewModel.searchPlaceholder, text: $viewModel.query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                            )
                            .onSubmit {
                                Task { await viewModel.loadByQuery() }
                            }

                        Button {
                            Task { await viewModel.loadByQuery() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.circle.fill")
                                Text(NSLocalizedString("services_schedule_load_button", comment: ""))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        if viewModel.mode == .group {
                            ScheduleSuggestionsView(
                                groups: viewModel.filteredGroups,
                                accountGroupName: viewModel.accountGroupName,
                                onSelect: { group in
                                    Task { await viewModel.loadGroup(group.name) }
                                }
                            )
                        } else {
                            ScheduleTeacherSuggestionsView(
                                employees: viewModel.filteredEmployees,
                                onSelect: { employee in
                                    Task { await viewModel.loadEmployee(employee) }
                                }
                            )
                        }
                    }
                }

                if viewModel.schedule != nil {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(viewModel.scheduleHeaderTitle)
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.5)
                            .lineLimit(2)

                        Text(viewModel.scheduleHeaderSubtitle)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(3)

                        if viewModel.shouldShowWeekFilter {
                            Picker("", selection: $viewModel.weekFilter) {
                                ForEach(viewModel.weekFilters) { filter in
                                    Text(filter.localizedTitle).tag(filter)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        switch viewModel.displayMode {
                        case .continuous:
                            ForEach(viewModel.continuousTimelineDays) { day in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(viewModel.continuousDayTitle(for: day))
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(.primary)

                                    ForEach(day.lessons) { lesson in
                                        ScheduleLessonCard(
                                            lesson: lesson,
                                            isCurrent: viewModel.isLessonCurrent(lesson, on: day.weekday, for: day.date),
                                            progress: viewModel.currentLessonProgress(lesson, on: day.weekday, for: day.date),
                                            onTeacherTap: { teacher in
                                                Task { await viewModel.openTeacherSchedule(teacher) }
                                            },
                                            onGroupTap: { groupName in
                                                Task { await viewModel.openGroupSchedule(groupName) }
                                            }
                                        )
                                    }
                                }
                                .onAppear {
                                    viewModel.loadMoreContinuousDaysIfNeeded(lastVisibleDayID: day.id)
                                }
                            }
                        case .byDay:
                            ForEach(viewModel.displayedDays, id: \.weekday) { day in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(viewModel.dayTitle(for: day))
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(.primary)

                                    ForEach(day.lessons) { lesson in
                                        ScheduleLessonCard(
                                            lesson: lesson,
                                            isCurrent: viewModel.isLessonCurrent(lesson, on: day.weekday),
                                            progress: viewModel.currentLessonProgress(lesson, on: day.weekday),
                                            onTeacherTap: { teacher in
                                                Task { await viewModel.openTeacherSchedule(teacher) }
                                            },
                                            onGroupTap: { groupName in
                                                Task { await viewModel.openGroupSchedule(groupName) }
                                            }
                                        )
                                    }
                                }
                            }
                        case .exams:
                            ForEach(viewModel.examDays) { day in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(viewModel.examDayTitle(for: day))
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(Calendar.current.isDateInTomorrow(day.date) ? Color.red : Color.primary)

                                    ForEach(day.lessons) { exam in
                                        ScheduleLessonCard(
                                            lesson: exam,
                                            isCurrent: false,
                                            progress: nil,
                                            onTeacherTap: { teacher in
                                                Task { await viewModel.openTeacherSchedule(teacher) }
                                            },
                                            onGroupTap: { groupName in
                                                Task { await viewModel.openGroupSchedule(groupName) }
                                            }
                                        )
                                    }
                                }
                            }
                        }

                        if viewModel.isCurrentModeEmpty {
                            ServiceEmptyState(text: NSLocalizedString("services_schedule_empty_week", comment: ""))
                        }
                    }
                } else {
                    ServiceEndpointSection(
                        title: NSLocalizedString("services_schedule_empty_title", comment: ""),
                        subtitle: NSLocalizedString("services_schedule_empty_subtitle", comment: ""),
                        icon: "calendar.badge.exclamationmark"
                    ) {
                        ServiceEmptyState(text: NSLocalizedString("services_schedule_empty_hint", comment: ""))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(NSLocalizedString("services_item_schedule", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        .hiddenNavigationBarBackground()
        .toolbar {
            if viewModel.schedule != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker(
                            NSLocalizedString("services_schedule_display_mode", comment: ""),
                            selection: $viewModel.displayMode
                        ) {
                            ForEach(ScheduleDisplayMode.allCases) { mode in
                                Label(mode.localizedTitle, systemImage: mode.icon).tag(mode)
                            }
                        }
                    } label: {
                        Label(
                            viewModel.displayMode.localizedTitle,
                            systemImage: viewModel.displayMode.icon
                        )
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task {
                                scheduleReportURL = await viewModel.downloadScheduleReport()
                            }
                        } label: {
                            Label(NSLocalizedString("services_schedule_report_download", comment: ""), systemImage: "square.and.arrow.down")
                        }
                        .disabled(viewModel.isDownloadingReport)

                        if let googleCalendarURL = viewModel.googleCalendarURL {
                            Link(destination: googleCalendarURL) {
                                Label(NSLocalizedString("services_schedule_google_calendar", comment: ""), systemImage: "calendar.badge.plus")
                            }
                        }

                        Button {
                            Task { await viewModel.enableExamRemindersFromUserAction() }
                        } label: {
                            Label(NSLocalizedString("services_schedule_exam_reminders", comment: ""), systemImage: "bell.badge")
                        }
                        .disabled(viewModel.filteredExams.isEmpty)
                    } label: {
                        Label(NSLocalizedString("services_schedule_actions", comment: ""), systemImage: "ellipsis.circle")
                    }
                }

                if viewModel.showsSubgroupPicker {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker(
                                NSLocalizedString("services_schedule_subgroup_filter", comment: ""),
                                selection: $viewModel.subgroupFilter
                            ) {
                                ForEach(viewModel.subgroupFilters) { filter in
                                    Text(filter.localizedTitle).tag(filter)
                                }
                            }
                        } label: {
                            Label(
                                viewModel.subgroupFilter.localizedCompactTitle,
                                systemImage: "person.2"
                            )
                        }
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading || viewModel.isDownloadingReport {
                ProgressView(loadingOverlayTitle)
            }
        }
        .task { await viewModel.loadInitialDataIfNeeded() }
        .refreshable { await viewModel.refreshData() }
        .sheet(isPresented: Binding(
            get: { scheduleReportURL != nil },
            set: { isPresented in
                if !isPresented {
                    scheduleReportURL = nil
                }
            }
        )) {
            if let scheduleReportURL {
                ShareSheet(activityItems: [scheduleReportURL])
            }
        }
        .alert(NSLocalizedString("services_schedule_reminders_title", comment: ""), isPresented: Binding(
            get: { viewModel.noticeMessage != nil },
            set: { shouldShow in
                if !shouldShow {
                    viewModel.noticeMessage = nil
                }
            }
        ), actions: {
            Button(NSLocalizedString("common_ok", comment: "")) { viewModel.noticeMessage = nil }
        }, message: {
            Text(viewModel.noticeMessage ?? "")
        })
        .alert(NSLocalizedString("common_error", comment: ""), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { shouldShow in
                if !shouldShow {
                    viewModel.errorMessage = nil
                }
            }
        ), actions: {
            Button(NSLocalizedString("common_ok", comment: "")) { viewModel.errorMessage = nil }
        }, message: {
            Text(viewModel.errorMessage ?? "")
        })
    }
}

private struct ScheduleLessonCard: View {
    let lesson: DisciplineSchedule
    let isCurrent: Bool
    let progress: Double?
    let onTeacherTap: (DisciplineEmployee) -> Void
    let onGroupTap: (String) -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text(lesson.startLessonTime)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.white)
                    Text(lesson.endLessonTime)
                        .font(.system(.body, design: .monospaced).weight(.regular))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .frame(width: 66)

                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(accentColor)
                        .frame(width: 6)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(lesson.title)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            if isCurrent {
                                Text(NSLocalizedString("services_schedule_now_badge", comment: ""))
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(accentColor.opacity(0.3), in: Capsule())
                                    .foregroundStyle(.white)
                            }
                        }

                        if !lesson.location.isEmpty {
                            Text(lesson.location)
                                .font(.subheadline.weight(.regular))
                                .foregroundStyle(.white.opacity(0.75))
                        }

                        if let note = lesson.note.nilIfBlank {
                            Text(note)
                                .font(.subheadline.weight(.regular))
                                .foregroundStyle(.white.opacity(0.75))
                                .lineLimit(2)
                        }

                        if let teacher = lesson.employees.first, !teacher.fullName.isEmpty {
                            Button {
                                onTeacherTap(teacher)
                            } label: {
                                Label(teacher.fullName, systemImage: "person.fill")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .buttonStyle(.plain)
                        }

                        if let groupName = firstGroupName {
                            Button {
                                onGroupTap(groupName)
                            } label: {
                                Label(groupName, systemImage: "person.3.fill")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer(minLength: 6)

                    teacherAvatar
                }
            }

            if let progress {
                ProgressView(value: min(max(progress, 0), 1))
                    .progressViewStyle(.linear)
                    .tint(accentColor)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            if lesson.isAnnouncement || lesson.isSplit {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [8, 6]))
            } else if isCurrent {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(accentColor.opacity(0.7), lineWidth: 1.5)
            }
        }
    }

    private var teacherAvatar: some View {
        Group {
            if let link = lesson.employees.first?.photoLink, let url = URL(string: link) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(.white.opacity(0.18))
                }
            } else {
                ZStack {
                    Circle().fill(.white.opacity(0.14))
                    Image(systemName: "person.fill")
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(Circle())
    }

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.11, green: 0.12, blue: 0.16), Color(red: 0.13, green: 0.14, blue: 0.18)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var accentColor: Color {
        let type = lesson.lessonTypeAbbrev.lowercased()
        if type.contains("экзам") {
            return .red
        }
        if type.contains("конс") {
            return .yellow
        }
        if type.contains("лр") {
            return .green
        }
        if type.contains("пз") {
            return .yellow
        }
        if type.contains("лк") {
            return .blue
        }
        return .mint
    }

    private var firstGroupName: String? {
        lesson.studentGroups
            .compactMap(\.name)
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }
}

private struct ScheduleSuggestionsView: View {
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

private struct ScheduleTeacherSuggestionsView: View {
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
