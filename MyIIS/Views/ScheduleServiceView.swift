import Combine
import QuickLook
import SwiftUI

// The schedule screen intentionally keeps its closely coupled cards and presentation helpers together.
// swiftlint:disable file_length

// MARK: - Schedule

// swiftlint:disable type_body_length
@MainActor
struct ScheduleServiceView: View {
    @State private var viewModel = ScheduleServiceViewModel()
    @State private var localScheduleViewModel = LocalScheduleViewModel()
    @AppStorage("enable_beta_sections") private var enableBetaSections = false
    @State private var scheduleReportURL: URL?
    @State private var selectedExamLesson: DisciplineSchedule?
    @State private var isLocalScheduleEditorPresented = false

    private var loadingOverlayTitle: String {
        NSLocalizedString("services_schedule_report_downloading", comment: "")
    }

    @State private var isSearchSheetPresented = false
    @State private var showsAllGroups = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if viewModel.isShowingStaleDataWarning {
                    StaleDataBanner(
                        lastUpdateTime: nil,
                        errorMessage: viewModel.staleErrorMessage
                    ) {
                        await viewModel.refreshData()
                    }
                }

                ServiceEndpointSection(
                    title: viewModel.scheduleHeaderTitle,
                    subtitle: viewModel.scheduleHeaderSubtitle,
                    icon: "graduationcap"
                ) {
                    if viewModel.shouldShowWeekFilter {
                        Picker(
                            NSLocalizedString("services_schedule_week_filter", value: "Неделя", comment: ""),
                            selection: $viewModel.weekFilter
                        ) {
                            ForEach(viewModel.weekFilters) { filter in
                                Text(filter.localizedTitle).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if viewModel.schedule != nil {
                    if let employee = viewModel.selectedEmployee {
                        ScheduleTeacherHeader(employee: employee)
                    }

                    switch viewModel.displayMode {
                    case .continuous:
                        if !viewModel.pastContinuousDays.isEmpty {
                            DisclosureGroup {
                                LazyVStack(alignment: .leading, spacing: 14) {
                                    ForEach(viewModel.pastContinuousDays) { day in
                                        VStack(alignment: .leading, spacing: 10) {
                                            Text(viewModel.continuousDayTitle(for: day))
                                                .font(.title3.weight(.bold))
                                                .foregroundStyle(.secondary)

                                            ForEach(day.lessons) { lesson in
                                                ScheduleLessonCard(
                                                    lesson: lesson,
                                                    isCurrent: false,
                                                    progress: nil,
                                                    isPast: true,
                                                    presentation: .sessionCompact,
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
                                .padding(.top, 10)
                            } label: {
                                Label(
                                    NSLocalizedString("services_schedule_past_lessons", comment: "Прошедшие занятия"),
                                    systemImage: "clock.arrow.circlepath"
                                )
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }

                        if viewModel.pastContinuousDays.contains(where: { Calendar.current.isDateInToday($0.date) }) &&
                            !viewModel.upcomingContinuousDays.contains(where: { Calendar.current.isDateInToday($0.date) }) {
                            Text(NSLocalizedString("services_schedule_no_more_today", comment: "На сегодня занятий больше нет 🎉"))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        }

                        ForEach(viewModel.upcomingContinuousDays) { day in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(viewModel.continuousDayTitle(for: day))
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.primary)

                                ForEach(day.lessons) { lesson in
                                    ScheduleLessonCard(
                                        lesson: lesson,
                                        isCurrent: viewModel.isLessonCurrent(lesson, on: day.weekday, for: day.date),
                                        progress: viewModel.currentLessonProgress(lesson, on: day.weekday, for: day.date),
                                        isPast: false,
                                        presentation: .sessionCompact,
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
                                        isCurrent: false,
                                        progress: nil,
                                        isPast: false,
                                        presentation: .sessionCompact,
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
                    case .exams:
                        if !viewModel.pastExamDays.isEmpty {
                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: 14) {
                                    ForEach(viewModel.pastExamDays) { day in
                                        VStack(alignment: .leading, spacing: 10) {
                                            Text(viewModel.examDayTitle(for: day))
                                                .font(.title3.weight(.bold))
                                                .foregroundStyle(examDayTitleColor(for: day))

                                            ForEach(day.lessons) { exam in
                                                ScheduleLessonCard(
                                                    lesson: exam,
                                                    isCurrent: false,
                                                    progress: nil,
                                                    isPast: viewModel.isExamPast(exam, on: day.date),
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
                                .padding(.top, 10)
                            } label: {
                                Label(
                                    NSLocalizedString("services_schedule_past_exams", comment: "Пройденные экзамены"),
                                    systemImage: "clock.arrow.circlepath"
                                )
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }

                        ForEach(viewModel.upcomingExamDays) { day in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(viewModel.examDayTitle(for: day))
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(examDayTitleColor(for: day))

                                ForEach(day.lessons) { exam in
                                    ScheduleLessonCard(
                                        lesson: exam,
                                        isCurrent: false,
                                        progress: nil,
                                        isPast: viewModel.isExamPast(exam, on: day.date),
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
                        scheduleUnavailableView
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
            if viewModel.dataSource == .api || usesLocalJSONSchedule {
                if viewModel.dataSource == .api {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showsAllGroups = false
                            isSearchSheetPresented = true
                        } label: {
                            Label(
                                NSLocalizedString("services_schedule_search_title", value: "Поиск расписания", comment: ""),
                                systemImage: "magnifyingglass"
                            )
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker(
                            NSLocalizedString(
                                "services_schedule_data_source",
                                value: "Источник данных",
                                comment: ""
                            ),
                            selection: $viewModel.dataSource
                        ) {
                            ForEach(ScheduleDataSource.allCases) { source in
                                Label(source.localizedTitle, systemImage: source.icon).tag(source)
                            }
                        }

                        if usesLocalJSONSchedule {
                            Divider()
                            Button {
                                isLocalScheduleEditorPresented = true
                            } label: {
                                Label(NSLocalizedString("local_schedule_edit_event", comment: ""), systemImage: "pencil")
                            }
                        }

                        if viewModel.schedule != nil {
                            Divider()
                            Picker(
                                NSLocalizedString("services_schedule_display_mode", comment: ""),
                                selection: $viewModel.displayMode
                            ) {
                                ForEach(availableDisplayModes) { mode in
                                    Label(mode.localizedTitle, systemImage: mode.icon).tag(mode)
                                }
                            }
                        }

                        if viewModel.dataSource == .api, enableBetaSections, viewModel.showsSubgroupPicker {
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

                        if viewModel.dataSource == .api, enableBetaSections, viewModel.schedule != nil {
                            Divider()
                            Button {
                                Task {
                                    scheduleReportURL = await viewModel.downloadScheduleReport()
                                }
                            } label: {
                                Label(NSLocalizedString("services_schedule_report_download", comment: ""), systemImage: "square.and.arrow.down")
                            }
                            .disabled(viewModel.isDownloadingReport)

                            Button {
                                Task { await viewModel.enableExamRemindersFromUserAction() }
                            } label: {
                                Label(NSLocalizedString("services_schedule_exam_reminders", comment: ""), systemImage: "bell.badge")
                            }
                            .disabled(viewModel.filteredExams.isEmpty)
                        }
                    } label: {
                        Label(NSLocalizedString("services_schedule_actions", comment: ""), systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .overlay {
            if viewModel.isDownloadingReport {
                ProgressView(loadingOverlayTitle)
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            }
        }
        .task {
            enforceBetaScheduleOptions()
            await loadSelectedScheduleSource()
        }
        .onChange(of: viewModel.dataSource) { _, _ in
            Task { await loadSelectedScheduleSource() }
        }
        .onChange(of: enableBetaSections) { _, _ in
            enforceBetaScheduleOptions()
        }
        .refreshable {
            if usesLocalJSONSchedule {
                localScheduleViewModel.reload()
                applyLocalSchedule()
            } else {
                await viewModel.refreshData()
            }
        }
        .quickLookPreview($scheduleReportURL)
        .sheet(isPresented: $isLocalScheduleEditorPresented, onDismiss: applyLocalSchedule) {
            LocalScheduleEditorSheet(viewModel: localScheduleViewModel)
        }
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
            set: { _ in }
        ), actions: {
            Button(NSLocalizedString("common_ok", comment: "")) { viewModel.noticeMessage = nil }
        }, message: {
            Text(viewModel.noticeMessage ?? "")
        })
        .alert(NSLocalizedString("common_error", comment: ""), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in }
        ), actions: {
            Button(NSLocalizedString("common_ok", comment: "")) { viewModel.errorMessage = nil }
        }, message: {
            Text(viewModel.errorMessage ?? "")
        })
        .sheet(isPresented: $isSearchSheetPresented) {
            NavigationStack {
                ScrollView {
                    searchControls
                        .padding(14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding()
                }
                .background(Color(uiColor: .systemGroupedBackground))
                .searchable(
                    text: $viewModel.query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: Text(viewModel.searchPlaceholder)
                )
                .onSubmit(of: .search) {
                    Task { await viewModel.loadByQuery() }
                }
                .task { await viewModel.reloadDirectory() }
                .navigationTitle(NSLocalizedString("services_schedule_search_title", value: "Поиск расписания", comment: ""))
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
            .onChange(of: viewModel.schedule?.group?.name ?? viewModel.schedule?.employee?.fullName) {
                isSearchSheetPresented = false
            }
            .onChange(of: viewModel.selectedEmployee?.id) {
                isSearchSheetPresented = false
            }
        }
    }

    private var usesLocalJSONSchedule: Bool {
        viewModel.dataSource == .localJSON
    }

    private func loadSelectedScheduleSource() async {
        if usesLocalJSONSchedule {
            applyLocalSchedule()
        } else {
            viewModel.prepareForAPISource()
            await viewModel.loadInitialDataIfNeeded()
        }
    }

    private func applyLocalSchedule() {
        guard let document = localScheduleViewModel.document else {
            viewModel.clearLocalSchedule()
            return
        }
        viewModel.applyLocalSchedule(document)
    }

    private var availableDisplayModes: [ScheduleDisplayMode] {
        ScheduleDisplayMode.allCases
    }

    private func enforceBetaScheduleOptions() {
        guard !enableBetaSections else { return }

        if viewModel.dataSource == .api, viewModel.displayMode == .continuous {
            viewModel.displayMode = .byDay
        }
    }

    private var searchControls: some View {
        VStack(spacing: 12) {
            Picker(
                NSLocalizedString("services_schedule_search_title", value: "Поиск расписания", comment: ""),
                selection: $viewModel.mode
            ) {
                Text(NSLocalizedString("services_schedule_mode_group", comment: "")).tag(ScheduleLookupMode.group)
                Text(NSLocalizedString("services_schedule_mode_teacher", comment: "")).tag(ScheduleLookupMode.teacher)
            }
            .pickerStyle(.segmented)

            if viewModel.mode == .group {
                ScheduleSuggestionsView(
                    groups: viewModel.filteredGroups,
                    accountGroupName: viewModel.accountGroupName,
                    showsAllGroups: showsAllGroups,
                    onSelect: { group in
                        Task { await viewModel.loadGroup(group.name) }
                    },
                    onShowAllGroups: {
                        showsAllGroups = true
                    }
                )
            } else {
                ScheduleTeacherSuggestionsView(
                    employees: viewModel.filteredEmployees,
                    isWaitingForQuery: viewModel.isTeacherSearchQueryTooShort,
                    onSelect: { employee in
                        Task { await viewModel.loadEmployee(employee) }
                    }
                )
            }
        }
    }
}
// swiftlint:enable type_body_length

private struct LocalScheduleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: LocalScheduleViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                LocalScheduleView(viewModel: viewModel)
                    .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(NSLocalizedString("local_schedule_edit_event", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("common_close", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

private extension ScheduleServiceView {
    var scheduleUnavailableView: some View {
        ContentUnavailableView {
            Label(
                NSLocalizedString("services_schedule_empty_title", comment: ""),
                systemImage: viewModel.isSchedulePublicationPending
                    ? "calendar.badge.clock"
                    : "calendar"
            )
        } description: {
            Text(viewModel.currentModeEmptyText)
        } actions: {
            Button(NSLocalizedString("common_refresh", comment: "")) {
                Task { await viewModel.refreshData() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    func examDayTitleColor(for day: ExamScheduleDay) -> Color {
        if !day.lessons.isEmpty,
           day.lessons.allSatisfy({ viewModel.isExamPast($0, on: day.date) }) {
            return .secondary
        }
        return Calendar.current.isDateInTomorrow(day.date) ? .red : .primary
    }
}

private struct ScheduleTeacherHeader: View {
    let employee: ScheduleEmployeeDirectoryEntry
    @State private var isPhotoPresented = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                isPhotoPresented = true
            } label: {
                avatar
                    .frame(width: 56, height: 56)
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
            avatar
                .scaledToFit()
                .padding()
                .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let url = photoURL {
            CachedAsyncImage(url: url, maxPixelSize: 360) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                placeholder
            }
        } else {
            placeholder
        }
    }

    private var photoURL: URL? {
        guard let link = employee.photoLink.nilIfBlank else { return nil }
        return URL(string: link
            .replacingOccurrences(of: "http://", with: "https://")
            .replacingOccurrences(of: "null/", with: "https://iis.bsuir.by/"))
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(Color(uiColor: .tertiarySystemGroupedBackground))
            Image(systemName: "person.fill")
                .foregroundStyle(.secondary)
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
    var isPast = false
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
                                .foregroundStyle(cardPrimaryForeground)
                                .lineLimit(2)
                            if isCurrent {
                                currentBadge
                            }
                        }

                        if !lesson.location.isEmpty {
                            Text(lesson.location)
                                .font(.subheadline.weight(.regular))
                                .foregroundStyle(cardSecondaryForeground)
                        }

                        if let note = lesson.note.nilIfBlank {
                            Text(note)
                                .font(.subheadline.weight(.regular))
                                .foregroundStyle(cardSecondaryForeground)
                                .lineLimit(2)
                        }

                        ForEach(displayedTeachers) { teacher in
                            Button {
                                onTeacherTap(teacher)
                            } label: {
                                Label(teacher.fullName, systemImage: "person.fill")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(cardSecondaryForeground)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain)
                        }

                        if let groupName = firstGroupName {
                            Button {
                                onGroupTap(groupName)
                            } label: {
                                Label(groupName, systemImage: "person.2")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(cardSecondaryForeground)
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
                    .foregroundStyle(cardPrimaryForeground)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let compactSubtitle {
                    Text(compactSubtitle)
                        .font(.subheadline.weight(.regular))
                        .foregroundStyle(cardSecondaryForeground)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
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
            Text(lesson.startLessonTime).font(font.weight(.semibold)).foregroundStyle(cardPrimaryForeground)

            if let breakTime = calculateBreakTime() {
                Text(breakTime)
                    .font(font.weight(.regular).width(.compressed))
                    .foregroundStyle(cardSecondaryForeground.opacity(0.7))
                    .scaleEffect(0.85)
            }

            Text(lesson.endLessonTime).font(font.weight(.regular)).foregroundStyle(cardSecondaryForeground)
        }
    }

    private func calculateBreakTime() -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        guard let start = formatter.date(from: lesson.startLessonTime),
              let end = formatter.date(from: lesson.endLessonTime) else { return nil }

        let diff = end.timeIntervalSince(start)
        if diff == 95 * 60 {
            let breakStart = start.addingTimeInterval(45 * 60)
            return formatter.string(from: breakStart)
        }
        return nil
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
            .mask {
                if calculateBreakTime() != nil {
                    VStack(spacing: 2) {
                        Rectangle()
                        Rectangle()
                    }
                } else {
                    Rectangle()
                }
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
            .foregroundStyle(cardPrimaryForeground)
    }

    private func teacherAvatarButton(size: CGFloat) -> some View {
        Button {
            onDetailsTap?()
        } label: {
            teacherAvatarStack(size: size)
        }
        .buttonStyle(.plain)
        .disabled(onDetailsTap == nil)
        .accessibilityLabel(
            Text(
                String(
                    format: NSLocalizedString(
                        "services_schedule_show_details",
                        value: "Подробности занятия: %@",
                        comment: ""
                    ),
                    lesson.title
                )
            )
        )
        .accessibilityValue(displayedTeachers.map(\.fullName).joined(separator: ", "))
    }

    @ViewBuilder
    private func teacherAvatarStack(size: CGFloat) -> some View {
        if displayedTeachers.isEmpty {
            teacherAvatar(nil, size: size)
        } else {
            HStack(spacing: -(size * 0.3)) {
                ForEach(Array(displayedTeachers.prefix(3).enumerated()), id: \.element.id) { index, teacher in
                    teacherAvatar(teacher, size: size)
                        .overlay {
                            Circle()
                                .strokeBorder(cardPrimaryForeground.opacity(0.72), lineWidth: 1.5)
                        }
                        .zIndex(Double(3 - index))
                }

                if displayedTeachers.count > 3 {
                    Text("+\(displayedTeachers.count - 3)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(cardPrimaryForeground)
                        .frame(width: size, height: size)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .fixedSize()
        }
    }

    private func teacherAvatar(_ teacher: DisciplineEmployee?, size: CGFloat) -> some View {
        Group {
            if let url = teacherPhotoURL(for: teacher) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(.white.opacity(0.18))
                }
            } else {
                ZStack {
                    Circle().fill(.white.opacity(0.14))
                    Image(systemName: "person.fill")
                        .foregroundStyle(cardSecondaryForeground)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .saturation(isPast ? 0 : 1)
        .opacity(isPast ? 0.7 : 1)
    }

    private func teacherPhotoURL(for teacher: DisciplineEmployee?) -> URL? {
        guard let link = teacher?.photoLink.nilIfBlank else { return nil }
        let normalized = link
            .replacingOccurrences(of: "http://", with: "https://")
            .replacingOccurrences(of: "null/", with: "https://iis.bsuir.by/")
        return URL(string: normalized)
    }

    private var displayedTeachers: [DisciplineEmployee] {
        lesson.employees.filter { !$0.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    @ViewBuilder
    private func cardBorder(cornerRadius: CGFloat) -> some View {
        if isCurrent {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(accentColor.opacity(0.7), lineWidth: 1.5)
        }
    }

    private var cardBackground: LinearGradient {
        let colors = isPast
            ? [Color(uiColor: .secondarySystemBackground), Color(uiColor: .tertiarySystemBackground)]
            : [Color(red: 0.11, green: 0.12, blue: 0.16), Color(red: 0.13, green: 0.14, blue: 0.18)]
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cardPrimaryForeground: Color { isPast ? .primary : .white }

    private var cardSecondaryForeground: Color { isPast ? .secondary : Color.white.opacity(0.75) }

    private var compactTitle: String {
        if lesson.isAnnouncement {
            return "📣 \(NSLocalizedString("local_schedule_type_announcement", comment: ""))"
        }
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
        if isPast {
            return Color.secondary.opacity(0.65)
        }
        let type = lesson.lessonTypeAbbrev.lowercased()
        if type.contains("экзам") {
            return .red
        }
        if type.contains("конс") {
            return .purple
        }
        if type.contains("лр") {
            return .red
        }
        if type.contains("пз") {
            return .yellow
        }
        if type.contains("лк") {
            return .green
        }
        return .mint
    }

    private var firstGroupName: String? {
        lesson.studentGroups
            .compactMap(\.name)
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }
}

#Preview("Расписание из локального JSON") {
    NavigationStack {
        ScheduleServiceView()
    }
}
