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
    private var hidePastLessons = true
    @AppStorage(ScheduleDisplayPreferences.cardDensityKey, store: ScheduleDisplayPreferences.defaults)
    private var cardDensityRaw = ScheduleCardDensity.regular.rawValue
    @AppStorage(ScheduleDisplayPreferences.otherSubgroupDisplayKey, store: ScheduleDisplayPreferences.defaults)
    private var otherSubgroupRaw = ScheduleOtherSubgroupDisplay.compact.rawValue

    @State private var scheduleReportURL: URL?
    @State private var selectedExamLesson: DisciplineSchedule?
    @State private var isLocalScheduleEditorPresented = false
    @State private var isSearchSheetPresented = false
    @State private var isSettingsSheetPresented = false
    @State private var isDatePickerPresented = false
    @State private var selectedDateForJump = Date()
    @State private var dateJumpTarget: Date?
    @State private var showsAllGroups = false
    @State private var renamingPinnedGroupName: String?
    @State private var pinnedGroupAliasDraft = ""
    @State private var hasAutoScrolled = false
    @State private var isPinnedPickerPresented = false

    private var cardDensity: ScheduleCardDensity {
        ScheduleCardDensity(rawValue: cardDensityRaw) ?? .compact
    }

    private var otherSubgroupDisplay: ScheduleOtherSubgroupDisplay {
        ScheduleOtherSubgroupDisplay(rawValue: otherSubgroupRaw) ?? .compact
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 32) {
                    if viewModel.isLoading, viewModel.schedule != nil {
                        scheduleLoadingBanner
                    }

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
            .simultaneousGesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .local)
                    .onEnded { value in
                        if value.startLocation.x < 50 && value.translation.width > 75 && abs(value.translation.height) < 65 {
                            if viewModel.mode == .teacher || (viewModel.mode == .group && !isCurrentScheduleUserAccountGroup) {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                Task {
                                    await viewModel.resetToDefaultOrPinnedSchedule()
                                }
                            }
                        }
                    }
            )
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
                Task { @MainActor in
                    if let dayID = await viewModel.prepareContinuousTimeline(around: target) {
                        await Task.yield()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(dayID, anchor: .top)
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
                currentGroupName: viewModel.mode == .group ? (viewModel.schedule?.group?.name ?? viewModel.query) : nil,
                nextOccurrenceDate: viewModel.nextOccurrenceDate(for: lesson),
                onTeacherScheduleTap: { teacher in
                    selectedExamLesson = nil
                    Task { await viewModel.openTeacherSchedule(teacher) }
                },
                onGroupTap: { groupName in
                    selectedExamLesson = nil
                    Task { await viewModel.openGroupSchedule(groupName) }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
            .presentationBackground(Color(uiColor: .systemGroupedBackground))
            .presentationCornerRadius(28)
        }
        .sheet(isPresented: $isDatePickerPresented) {
            jumpDatePickerSheet
        }
        .errorAlert($viewModel.noticeMessage, title: NSLocalizedString("services_schedule_title", comment: ""))
        .sheet(isPresented: $isSearchSheetPresented) {
            searchSheetContent
        }
        .onReceive(NotificationCenter.default.publisher(for: .scheduleResetToDefaultGroup)) { _ in
            Task {
                await viewModel.resetToDefaultOrPinnedSchedule()
            }
        }
    }

    // MARK: - Header Info Bar

    @ViewBuilder
    private var scheduleHeaderInfoBar: some View {
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

    private var isCurrentScheduleUserAccountGroup: Bool {
        guard viewModel.mode == .group,
              let accountGroup = viewModel.accountGroupName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !accountGroup.isEmpty else { return false }
        return viewModel.schedule?.group?.name.trimmingCharacters(in: .whitespacesAndNewlines) == accountGroup
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Button {
                isPinnedPickerPresented = true
            } label: {
                HStack(spacing: 4) {
                    Text(viewModel.scheduleHeaderTitle).lineLimit(1)
                    Image(systemName: "chevron.down").font(.caption2)
                }
                .font(.headline)
            }
            .accessibilityIdentifier("schedulePinnedPicker")
            .popover(isPresented: $isPinnedPickerPresented) {
                PinnedSchedulePicker(viewModel: viewModel) {
                    isPinnedPickerPresented = false
                }
                .presentationCompactAdaptation(.popover)
            }
        }
        ToolbarItem(placement: .topBarLeading) {
            if viewModel.schedule != nil, !isCurrentScheduleUserAccountGroup {
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

                if viewModel.showsSubgroupPicker {
                    Divider()

                    Picker(
                        NSLocalizedString("schedule_settings_subgroup_header", value: "Подгруппа", comment: ""),
                        selection: $viewModel.subgroupFilter
                    ) {
                        ForEach(viewModel.subgroupFilters) { filter in
                            Text(filter.localizedTitle).tag(filter)
                        }
                    }
                }

                if viewModel.displayMode == .continuous {
                    Divider()

                    Button {
                        isDatePickerPresented = true
                    } label: {
                        Label(
                            NSLocalizedString("schedule_jump_to_date", value: "Перейти к дате", comment: ""),
                            systemImage: "calendar"
                        )
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
                .foregroundStyle(isPinned ? .orange : .secondary)
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
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            if let group = viewModel.schedule?.group?.name {
                viewModel.togglePinnedGroupName(group)
            } else if let employee = viewModel.selectedEmployee {
                viewModel.togglePinnedTeacher(employee)
            }
        }
    }

    // MARK: - Search Sheet

    private var isGroupAliasEditorPresented: Binding<Bool> {
        Binding(
            get: { renamingPinnedGroupName != nil },
            set: { isPresented in
                if !isPresented {
                    renamingPinnedGroupName = nil
                }
            }
        )
    }

    private func beginRenamingPinnedGroup(_ groupName: String) {
        pinnedGroupAliasDraft = viewModel.pinnedGroupAlias(for: groupName) ?? ""
        renamingPinnedGroupName = groupName
    }

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
        .alert(
            NSLocalizedString("schedule_group_alias_title", value: "Название группы", comment: ""),
            isPresented: isGroupAliasEditorPresented
        ) {
            TextField(
                NSLocalizedString("schedule_group_alias_placeholder", value: "Например, Илюха-3", comment: ""),
                text: $pinnedGroupAliasDraft
            )
            Button(NSLocalizedString("common_cancel", comment: ""), role: .cancel) {
                renamingPinnedGroupName = nil
            }
            if let group = renamingPinnedGroupName, viewModel.pinnedGroupAlias(for: group) != nil {
                Button(
                    NSLocalizedString("schedule_group_alias_remove", value: "Удалить название", comment: ""),
                    role: .destructive
                ) {
                    viewModel.setPinnedGroupAlias(nil, for: group)
                    renamingPinnedGroupName = nil
                }
            }
            Button(NSLocalizedString("common_save", comment: "")) {
                guard let group = renamingPinnedGroupName else { return }
                viewModel.setPinnedGroupAlias(pinnedGroupAliasDraft, for: group)
                renamingPinnedGroupName = nil
            }
        } message: {
            if let group = renamingPinnedGroupName {
                Text(
                    String(
                        format: NSLocalizedString("schedule_group_alias_group_format", value: "Группа %@", comment: ""),
                        group
                    )
                )
            }
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
                    pinnedGroupNames: viewModel.pinnedGroupNames,
                    pinnedGroupAliases: viewModel.pinnedGroupAliases,
                    recentGroupNames: viewModel.recentGroupNames,
                    accountGroupName: viewModel.accountGroupName,
                    isSearching: !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    showsAllGroups: showsAllGroups,
                    onSelect: { group in
                        isSearchSheetPresented = false
                        Task { await viewModel.loadGroup(group.name) }
                    },
                    onTogglePin: { group in
                        viewModel.togglePinnedGroup(group)
                    },
                    onRenamePinnedGroup: { group in
                        beginRenamingPinnedGroup(group.name)
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

    private var scheduleLoadingBanner: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)

            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString(
                    "services_schedule_loading_selection",
                    value: "Загружаем выбранное расписание…",
                    comment: ""
                ))
                .font(.subheadline.weight(.semibold))

                Text(NSLocalizedString(
                    "services_schedule_loading_network_hint",
                    value: "При медленной сети это может занять немного времени.",
                    comment: ""
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
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
                viewModel.currentModeEmptyTitle,
                systemImage: viewModel.displayMode == .exams ? "graduationcap" : (viewModel.isSchedulePublicationPending ? "calendar.badge.clock" : "calendar")
            )
        } description: {
            Text(viewModel.currentModeEmptyText)
        } actions: {
            Button(NSLocalizedString("common_refresh", comment: "")) {
                Task { await viewModel.refreshData() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .padding(.vertical, 24)
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
