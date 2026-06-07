import Combine
import SwiftUI
import QuickLook

// MARK: - Schedule

@MainActor
struct ScheduleServiceView: View {
    @StateObject private var viewModel = ScheduleServiceViewModel()
    @State private var scheduleReportURL: URL?
    @State private var selectedExamLesson: DisciplineSchedule?

    private var loadingOverlayTitle: String {
        viewModel.isDownloadingReport
            ? NSLocalizedString("services_schedule_report_downloading", comment: "")
            : NSLocalizedString("common_loading", comment: "")
    }

    @State private var isSearchSheetPresented = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if viewModel.schedule == nil {
                    searchBlock
                }

                if viewModel.schedule != nil {
                    VStack(alignment: .leading, spacing: 14) {
                        ServiceEndpointSection(
                            title: viewModel.scheduleHeaderTitle,
                            subtitle: viewModel.scheduleHeaderSubtitle,
                            icon: "graduationcap"
                        ) {
                            if viewModel.shouldShowWeekFilter {
                                Picker("", selection: $viewModel.weekFilter) {
                                    ForEach(viewModel.weekFilters) { filter in
                                        Text(filter.localizedTitle).tag(filter)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
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
                                            presentation: .sessionCompact,
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
        .navigationBarTitleDisplayMode(.inline)
        .hiddenNavigationBarBackground()
        .toolbar {
            if viewModel.schedule != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isSearchSheetPresented = true
                    } label: {
                        Label("Поиск расписания", systemImage: "magnifyingglass")
                    }
                }

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

                        if viewModel.showsSubgroupPicker {
                            Divider()
                            Picker(
                                NSLocalizedString("services_schedule_subgroup_filter", comment: ""),
                                selection: $viewModel.subgroupFilter
                            ) {
                                ForEach(viewModel.subgroupFilters) { filter in
                                    Text(filter.localizedTitle).tag(filter)
                                }
                            }
                        }

                        Divider()
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
            }
        }
        .overlay {
            if (viewModel.isLoading && viewModel.schedule == nil) || viewModel.isDownloadingReport {
                ProgressView(loadingOverlayTitle)
            }
        }
        .task { await viewModel.loadInitialDataIfNeeded() }
        .refreshable { await viewModel.refreshData() }
        .quickLookPreview($scheduleReportURL)
        .sheet(item: $selectedExamLesson) { lesson in
            ScheduleLessonDetailSheet(
                lesson: lesson,
                onTeacherScheduleTap: { teacher in
                    selectedExamLesson = nil
                    Task { await viewModel.openTeacherSchedule(teacher) }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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
        .sheet(isPresented: $isSearchSheetPresented) {
            NavigationStack {
                ScrollView {
                    searchBlock
                        .padding()
                }
                .background(Color(uiColor: .systemGroupedBackground))
                .navigationTitle("Поиск расписания")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(NSLocalizedString("common_close", comment: "")) {
                            isSearchSheetPresented = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .onChange(of: viewModel.schedule?.group?.name ?? viewModel.schedule?.employee?.fullName) { _ in
                isSearchSheetPresented = false
            }
        }
    }

    private var searchBlock: some View {
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
    }
}

private enum ScheduleLessonCardPresentation {
    case regular
    case sessionCompact
}

private struct ScheduleLessonCard: View {
    let lesson: DisciplineSchedule
    let isCurrent: Bool
    let progress: Double?
    var presentation: ScheduleLessonCardPresentation = .regular
    let onTeacherTap: (DisciplineEmployee) -> Void
    let onGroupTap: (String) -> Void
    var onDetailsTap: (() -> Void)?

    var body: some View {
        if presentation == .sessionCompact {
            compactBody
        } else {
            regularBody
        }
    }

    private var regularBody: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                timeColumn(font: .system(.body, design: .monospaced))
                    .frame(width: 66)

                HStack(spacing: 12) {
                    accentBar(width: 6)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(lesson.title)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            if isCurrent {
                                currentBadge
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
                    teacherAvatarButton(size: 46)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay { cardBorder(cornerRadius: 16) }
    }

    private var compactBody: some View {
        HStack(spacing: 10) {
            timeColumn(font: .system(size: 16, weight: .medium, design: .monospaced))
                .frame(width: 66)

            accentBar(width: 7)

            VStack(alignment: .leading, spacing: 3) {
                Text(compactTitle)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if let compactSubtitle {
                    Text(compactSubtitle)
                        .font(.subheadline.weight(.regular))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            teacherAvatarButton(size: 44)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { cardBorder(cornerRadius: 14) }
    }

    private func timeColumn(font: Font) -> some View {
        VStack(spacing: 3) {
            Text(lesson.startLessonTime)
                .font(font.weight(.semibold))
                .foregroundStyle(.white)
            Text(lesson.endLessonTime)
                .font(font.weight(.regular))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private func accentBar(width: CGFloat) -> some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                if let progress {
                    Color.clear.frame(height: proxy.size.height * min(max(progress, 0), 1))
                }
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(accentColor)
            }
        }
        .frame(width: width)
    }

    private var currentBadge: some View {
        Text(NSLocalizedString("services_schedule_now_badge", comment: ""))
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(accentColor.opacity(0.3), in: Capsule())
            .foregroundStyle(.white)
    }

    private func teacherAvatarButton(size: CGFloat) -> some View {
        Button {
            onDetailsTap?()
        } label: {
            teacherAvatar(size: size)
        }
        .buttonStyle(.plain)
        .disabled(onDetailsTap == nil)
    }

    private func teacherAvatar(size: CGFloat) -> some View {
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
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    @ViewBuilder
    private func cardBorder(cornerRadius: CGFloat) -> some View {
        if isCurrent {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(accentColor.opacity(0.7), lineWidth: 1.5)
        }
    }

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.11, green: 0.12, blue: 0.16), Color(red: 0.13, green: 0.14, blue: 0.18)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var compactTitle: String {
        if lesson.isAnnouncement { return "📣 Объявление" }
        return lesson.subject.nilIfBlank ?? lesson.lessonTypeAbbrev.nilIfBlank ?? lesson.title
    }

    private var compactSubtitle: String? {
        if lesson.isAnnouncement {
            return [lesson.location.nilIfBlank, lesson.note.nilIfBlank]
                .compactMap { $0 }
                .joined(separator: ", ")
                .nilIfBlank
        }
        return lesson.location.nilIfBlank
    }

    private var accentColor: Color {
        let type = lesson.lessonTypeAbbrev.lowercased()
        if type.contains("экзам") {
            return .red
        }
        if type.contains("конс") {
            return .purple
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
