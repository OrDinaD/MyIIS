//
//  ScheduleServiceView.swift
//  MyIIS
//
import Combine
import QuickLook
import SwiftUI

// swiftlint:disable file_length
// swiftlint:disable type_body_length
@MainActor
struct ScheduleServiceView: View {
    @State private var viewModel = ScheduleServiceViewModel()
    @State private var localScheduleViewModel = LocalScheduleViewModel()
    @AppStorage("enable_beta_sections") private var enableBetaSections = false
    @AppStorage(ScheduleDisplayPreferences.showsMidPairBreaksKey, store: ScheduleDisplayPreferences.defaults)
    private var showsMidPairBreaks = false
    @AppStorage(ScheduleDisplayPreferences.hidePastLessonsKey, store: ScheduleDisplayPreferences.defaults)
    private var hidePastLessons = false
    @AppStorage(ScheduleDisplayPreferences.cardDensityKey, store: ScheduleDisplayPreferences.defaults)
    private var cardDensityRaw = ScheduleCardDensity.compact.rawValue
    @AppStorage(ScheduleDisplayPreferences.otherSubgroupDisplayKey, store: ScheduleDisplayPreferences.defaults)
    private var otherSubgroupRaw = ScheduleOtherSubgroupDisplay.compact.rawValue
    @AppStorage("schedule.display.compactDefaultMigrationV1", store: ScheduleDisplayPreferences.defaults)
    private var didMigrateCompactDefault = false

    @State private var scheduleReportURL: URL?
    @State private var selectedExamLesson: DisciplineSchedule?
    @State private var isLocalScheduleEditorPresented = false
    @State private var isSearchSheetPresented = false
    @State private var isSettingsSheetPresented = false
    @State private var isDatePickerPresented = false
    @State private var selectedDateForJump = Date()
    @State private var dateJumpTarget: Date?
    @State private var showsAllGroups = false
    @State private var hasAutoScrolled = false

    private var cardDensity: ScheduleCardDensity {
        ScheduleCardDensity(rawValue: cardDensityRaw) ?? .compact
    }

    private var otherSubgroupDisplay: ScheduleOtherSubgroupDisplay {
        ScheduleOtherSubgroupDisplay(rawValue: otherSubgroupRaw) ?? .compact
    }

    var body: some View {
        ScrollViewReader { proxy in
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

                    if viewModel.schedule != nil {
                        scheduleHeaderInfoBar

                        if let employee = viewModel.selectedEmployee {
                            ScheduleTeacherHeader(employee: employee)
                        }

                        scheduleContent(scrollProxy: proxy)
                    } else if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 220)
                            .accessibilityLabel(NSLocalizedString("common_loading", comment: ""))
                    } else if viewModel.errorMessage != nil {
                        scheduleInitialErrorView
                    } else {
                        emptySelectionView
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(viewModel.scheduleHeaderTitle)
            .navigationBarTitleDisplayMode(.inline)
            .hiddenNavigationBarBackground()
            .toolbar {
                toolbarContent
            }
            .overlay {
                if viewModel.isDownloadingReport {
                    ProgressView(NSLocalizedString("services_schedule_report_downloading", comment: ""))
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                }
            }
            .task {
                if !didMigrateCompactDefault {
                    cardDensityRaw = ScheduleCardDensity.compact.rawValue
                    didMigrateCompactDefault = true
                }
                await loadSelectedScheduleSource()
                if !hasAutoScrolled {
                    try? await Task.sleep(for: .milliseconds(300))
                    scrollToTodayOrCurrent(proxy: proxy)
                    hasAutoScrolled = true
                }
            }
            .onChange(of: viewModel.schedule?.group?.name ?? viewModel.schedule?.employee?.fullName) { _, _ in
                hasAutoScrolled = false
                Task {
                    try? await Task.sleep(for: .milliseconds(200))
                    scrollToTodayOrCurrent(proxy: proxy)
                }
            }
            .onChange(of: otherSubgroupRaw) { _, _ in
                viewModel.refreshSubgroupPresentation()
            }
            .onChange(of: dateJumpTarget) { _, target in
                guard let target else { return }
                if let dayID = viewModel.prepareContinuousTimeline(around: target) {
                    Task { @MainActor in
                        await Task.yield()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(dayID, anchor: .top)
                        }
                    }
                } else {
                    viewModel.noticeMessage = NSLocalizedString(
                        "schedule_date_has_no_lessons",
                        value: "На выбранную дату занятий не найдено.",
                        comment: ""
                    )
                }
                dateJumpTarget = nil
            }
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
        .sheet(isPresented: $isSettingsSheetPresented) {
            ScheduleSettingsView()
        }
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
        .sheet(isPresented: $isDatePickerPresented) {
            jumpDatePickerSheet
        }
        .alert(NSLocalizedString("services_schedule_title", comment: ""), isPresented: Binding(
            get: { viewModel.noticeMessage != nil },
            set: { _ in }
        ), actions: {
            Button(NSLocalizedString("common_ok", comment: "")) { viewModel.noticeMessage = nil }
        }, message: {
            Text(viewModel.noticeMessage ?? "")
        })
        .sheet(isPresented: $isSearchSheetPresented) {
            searchSheetContent
        }
    }

    // MARK: - Header Info Bar

    private var scheduleHeaderInfoBar: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.scheduleHeaderSubtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                if viewModel.displayMode == .continuous {
                    Button {
                        isDatePickerPresented = true
                    } label: {
                        Label(
                            NSLocalizedString("schedule_jump_to_date", value: "Дата", comment: ""),
                            systemImage: "calendar"
                        )
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 10)
                        .frame(minHeight: 44)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                if viewModel.showsSubgroupPicker {
                    Menu {
                        ForEach(viewModel.subgroupFilters) { filter in
                            Button {
                                viewModel.subgroupFilter = filter
                            } label: {
                                HStack {
                                    Text(filter.localizedTitle)
                                    if viewModel.subgroupFilter == filter {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.subgroupFilter.shortTitle)
                                .font(.footnote.weight(.semibold))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 10)
                        .frame(minHeight: 44)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: Capsule())
                    }
                }
            }

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
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Schedule Content

    @ViewBuilder
    private func scheduleContent(scrollProxy: ScrollViewProxy) -> some View {
        switch viewModel.displayMode {
        case .continuous:
            continuousContent(scrollProxy: scrollProxy)
        case .byDay:
            byDayContent
        case .exams:
            examsContent
        }

        if viewModel.isCurrentModeEmpty {
            scheduleUnavailableView
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

            if viewModel.pastContinuousDays.contains(where: { Calendar.current.isDateInToday($0.date) }) &&
                !viewModel.upcomingContinuousDays.contains(where: { Calendar.current.isDateInToday($0.date) }) {
                Text(NSLocalizedString("services_schedule_no_more_today", comment: "На сегодня занятий больше нет 🎉"))
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

    private var emptySelectionView: some View {
        VStack(spacing: 18) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .padding(.top, 40)

            Text(NSLocalizedString("schedule_empty_cta_title", value: "Выберите расписание", comment: ""))
                .font(.title2.weight(.bold))

            Text(NSLocalizedString("schedule_empty_cta_subtitle", value: "Найдите группу или преподавателя, чтобы просматривать занятия и экзамены", comment: ""))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button {
                isSearchSheetPresented = true
            } label: {
                Label(
                    NSLocalizedString("services_schedule_search_title", value: "Поиск расписания", comment: ""),
                    systemImage: "magnifyingglass"
                )
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if viewModel.schedule != nil {
                pinButton
            }
        }

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

        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker(
                    NSLocalizedString("services_schedule_display_mode", comment: ""),
                    selection: $viewModel.displayMode
                ) {
                    ForEach(ScheduleDisplayMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.icon).tag(mode)
                    }
                }

                Divider()

                Button {
                    isSettingsSheetPresented = true
                } label: {
                    Label(
                        NSLocalizedString("schedule_settings_title", value: "Настройки расписания", comment: ""),
                        systemImage: "slider.horizontal.3"
                    )
                }

                if viewModel.dataSource == .api, viewModel.schedule != nil {
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

                if usesLocalJSONSchedule {
                    Divider()
                    Button {
                        isLocalScheduleEditorPresented = true
                    } label: {
                        Label(NSLocalizedString("local_schedule_edit_event", comment: ""), systemImage: "pencil")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private var pinButton: some View {
        let isPinned = isCurrentSchedulePinned
        return Button {
            toggleCurrentSchedulePin()
        } label: {
            Image(systemName: isPinned ? "pin.fill" : "pin")
                .foregroundStyle(isPinned ? .orange : .primary)
        }
        .accessibilityLabel(
            isPinned
                ? NSLocalizedString("schedule_unpin", value: "Открепить", comment: "")
                : NSLocalizedString("schedule_pin", value: "Закрепить", comment: "")
        )
    }

    private var isCurrentSchedulePinned: Bool {
        if let group = viewModel.schedule?.group?.name {
            return viewModel.isGroupPinned(group)
        }
        if let employee = viewModel.selectedEmployee, let urlId = employee.urlId {
            return viewModel.isTeacherPinned(urlId)
        }
        return false
    }

    private func toggleCurrentSchedulePin() {
        if let group = viewModel.schedule?.group?.name {
            viewModel.togglePinnedGroupName(group)
        } else if let employee = viewModel.selectedEmployee {
            viewModel.togglePinnedTeacher(employee)
        }
    }

    // MARK: - Search Sheet

    private var searchSheetContent: some View {
        NavigationStack {
            ScrollView {
                searchControls
                    .padding(14)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .searchable(
                text: $viewModel.query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text(viewModel.searchPlaceholder)
            )
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
                    pinnedGroupNames: viewModel.pinnedGroupNames,
                    recentGroupNames: viewModel.recentGroupNames,
                    accountGroupName: viewModel.accountGroupName,
                    showsAllGroups: showsAllGroups,
                    onSelect: { group in
                        isSearchSheetPresented = false
                        Task { await viewModel.loadGroup(group.name) }
                    },
                    onTogglePin: { group in
                        viewModel.togglePinnedGroup(group)
                    },
                    onShowAllGroups: {
                        showsAllGroups = true
                    }
                )
            } else {
                ScheduleTeacherSuggestionsView(
                    employees: viewModel.filteredEmployees,
                    pinnedTeachers: viewModel.pinnedTeachers,
                    recentTeachers: viewModel.recentTeachers,
                    isWaitingForQuery: viewModel.isTeacherSearchQueryTooShort,
                    onSelect: { employee in
                        isSearchSheetPresented = false
                        Task { await viewModel.loadEmployee(employee) }
                    },
                    onTogglePin: { employee in
                        viewModel.togglePinnedTeacher(employee)
                    }
                )
            }
        }
    }

    // MARK: - Date Jump Sheet

    private var jumpDatePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker(
                    NSLocalizedString("schedule_choose_date", value: "Выберите дату", comment: ""),
                    selection: $selectedDateForJump,
                    in: scheduleDateRange,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()

                Button(NSLocalizedString("schedule_today_action", value: "Сегодня", comment: "")) {
                    dateJumpTarget = Date()
                    isDatePickerPresented = false
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .navigationTitle(NSLocalizedString("schedule_jump_to_date", value: "Перейти к дате", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common_cancel", comment: "")) {
                        isDatePickerPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("schedule_jump_action", value: "Перейти", comment: "")) {
                        dateJumpTarget = selectedDateForJump
                        isDatePickerPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func scrollToTodayOrCurrent(proxy: ScrollViewProxy) {
        if let todayDay = viewModel.upcomingContinuousDays.first(where: { Calendar.current.isDateInToday($0.date) }) {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(todayDay.id, anchor: .top)
            }
        } else if let firstUpcoming = viewModel.upcomingContinuousDays.first {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(firstUpcoming.id, anchor: .top)
            }
        }
    }

    private var scheduleDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = viewModel.schedule?.startDate.map(calendar.startOfDay(for:)) ?? today
        let fallbackEnd = calendar.date(byAdding: .year, value: 1, to: start) ?? start
        let end = viewModel.schedule?.endDate.map(calendar.startOfDay(for:)) ?? fallbackEnd
        let minBound = min(today, min(start, end))
        let maxBound = max(today, max(start, end))
        return minBound ... maxBound
    }

    private var usesLocalJSONSchedule: Bool {
        viewModel.dataSource == .localJSON
    }

    private func loadSelectedScheduleSource() async {
        if usesLocalJSONSchedule {
            applyLocalSchedule()
        } else {
            await viewModel.loadInitialData()
        }
    }

    private func applyLocalSchedule() {
        guard let document = localScheduleViewModel.document else {
            return
        }
        viewModel.applyLocalSchedule(document)
    }

    private var scheduleInitialErrorView: some View {
        ContentUnavailableView {
            Label(
                NSLocalizedString("services_schedule_empty_title", comment: ""),
                systemImage: "wifi.exclamationmark"
            )
        } description: {
            Text(viewModel.errorMessage ?? "")
        } actions: {
            Button(NSLocalizedString("common_retry", comment: "")) {
                viewModel.errorMessage = nil
                Task { await viewModel.refreshData() }
            }
            .buttonStyle(.borderedProminent)

            Button(NSLocalizedString("services_schedule_search_title", comment: "")) {
                viewModel.errorMessage = nil
                isSearchSheetPresented = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var scheduleUnavailableView: some View {
        ContentUnavailableView {
            Label(
                NSLocalizedString("services_schedule_empty_title", comment: ""),
                systemImage: viewModel.isSchedulePublicationPending ? "calendar.badge.clock" : "calendar"
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
// swiftlint:enable type_body_length

// MARK: - Teacher Header

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

// MARK: - Lesson Card

private struct ScheduleLessonCard: View {
    let lesson: DisciplineSchedule
    let isCurrent: Bool
    let progress: Double?
    var isPast = false
    var cardDensity: ScheduleCardDensity = .regular
    var showsMidPairBreaks = false
    let onTeacherTap: (DisciplineEmployee) -> Void
    let onGroupTap: (String) -> Void
    var onDetailsTap: (() -> Void)?

    var body: some View {
        if cardDensity == .compact {
            compactBody
        } else {
            regularBody
        }
    }

    private var regularBody: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                timeColumn(font: .system(.body, design: .monospaced))
                    .frame(width: 66)

                HStack(spacing: 10) {
                    accentBar(width: 5)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(compactTitle)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(cardPrimaryForeground)
                                .lineLimit(2)
                            if isCurrent {
                                currentBadge
                            }
                        }

                        if !lesson.location.isEmpty {
                            Text(lesson.location)
                                .font(.subheadline)
                                .foregroundStyle(cardSecondaryForeground)
                        }

                        if let note = lesson.note.nilIfBlank {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(cardSecondaryForeground)
                                .lineLimit(2)
                        }

                        ForEach(displayedTeachers) { teacher in
                            Button {
                                onTeacherTap(teacher)
                            } label: {
                                Label(teacher.fullName, systemImage: "person.fill")
                                    .font(.caption.weight(.medium))
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
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(cardSecondaryForeground)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer(minLength: 6)
                    teacherAvatarButton(size: 42)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay { cardBorder(cornerRadius: 16) }
    }

    private var compactBody: some View {
        HStack(spacing: 10) {
            timeColumn(font: .system(size: 15, weight: .medium, design: .monospaced))
                .frame(width: 64)

            accentBar(width: 5)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(compactTitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(cardPrimaryForeground)
                        .lineLimit(2)
                    if isCurrent {
                        currentBadge
                    }
                }

                if let compactSubtitle {
                    Text(compactSubtitle)
                        .font(.caption)
                        .foregroundStyle(cardSecondaryForeground)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            teacherAvatarButton(size: 38)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { cardBorder(cornerRadius: 14) }
    }

    private func timeColumn(font: Font) -> some View {
        VStack(spacing: 2) {
            Text(lesson.startLessonTime)
                .font(font.weight(.semibold))
                .foregroundStyle(cardPrimaryForeground)

            if let breakTime = calculateBreakTime() {
                Text(breakTime)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(cardSecondaryForeground.opacity(0.8))
            }

            Text(lesson.endLessonTime)
                .font(font.weight(.regular))
                .foregroundStyle(cardSecondaryForeground)
        }
    }

    private func calculateBreakTime() -> String? {
        guard showsMidPairBreaks else { return nil }
        return ScheduleMidPairBreakCalculator.resolve(
            startTime: lesson.startLessonTime,
            endTime: lesson.endLessonTime
        )?.compactText
    }

    private func accentBar(width: CGFloat) -> some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                if let progress {
                    Color.clear.frame(height: proxy.size.height * min(max(progress, 0), 1))
                }
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(accentColor)
            }
        }
        .frame(width: width)
    }

    private var currentBadge: some View {
        Text(NSLocalizedString("services_schedule_now_badge", value: "СЕЙЧАС", comment: ""))
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(accentColor.opacity(0.25), in: Capsule())
            .foregroundStyle(accentColor)
    }

    private func teacherAvatarButton(size: CGFloat) -> some View {
        Button {
            onDetailsTap?()
        } label: {
            teacherAvatarStack(size: size)
        }
        .buttonStyle(.plain)
        .disabled(onDetailsTap == nil)
        .accessibilityLabel(lesson.title)
    }

    @ViewBuilder
    private func teacherAvatarStack(size: CGFloat) -> some View {
        if displayedTeachers.isEmpty {
            teacherAvatar(nil, size: size)
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

    private func teacherAvatar(_ teacher: DisciplineEmployee?, size: CGFloat) -> some View {
        Group {
            if let url = teacherPhotoURL(for: teacher) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color(uiColor: .tertiarySystemGroupedBackground))
                }
            } else {
                ZStack {
                    Circle().fill(Color(uiColor: .tertiarySystemGroupedBackground))
                    Image(systemName: "person.fill")
                        .font(.caption2)
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
        return URL(string: link
            .replacingOccurrences(of: "http://", with: "https://")
            .replacingOccurrences(of: "null/", with: "https://iis.bsuir.by/"))
    }

    private var displayedTeachers: [DisciplineEmployee] {
        lesson.employees.filter { !$0.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    @ViewBuilder
    private func cardBorder(cornerRadius: CGFloat) -> some View {
        if isCurrent {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(accentColor, lineWidth: 1.5)
        }
    }

    private var cardBackgroundColor: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
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
        return ScheduleColorPreferences.color(for: lesson.lessonTypeAbbrev)
    }

    private var firstGroupName: String? {
        lesson.studentGroups
            .compactMap(\.name)
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }
}

private extension ScheduleDisplayMode {
    var icon: String {
        switch self {
        case .continuous: return "calendar.day.timeline.left"
        case .byDay: return "calendar"
        case .exams: return "graduationcap.fill"
        }
    }
}

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

#Preview {
    NavigationStack {
        ScheduleServiceView()
    }
}
