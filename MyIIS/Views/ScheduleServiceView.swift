import Combine
import QuickLook
import SwiftUI

// MARK: - Schedule

@MainActor
struct ScheduleServiceView: View {
    @StateObject private var viewModel = ScheduleServiceViewModel()
    @StateObject private var localScheduleViewModel = LocalScheduleViewModel()
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
            LazyVStack(spacing: 14) {
                if viewModel.dataSource == .localJSON {
                    LocalScheduleView(viewModel: localScheduleViewModel)
                } else if viewModel.dataSource == .localExcel {
                    localExcelBlock()
                } else {
                    if viewModel.schedule == nil, !viewModel.isLoading {
                        searchBlock()
                    }

                    if viewModel.dataSource == .api, viewModel.schedule != nil {
                        LazyVStack(alignment: .leading, spacing: 14) {
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
                            if !viewModel.pastContinuousDays.isEmpty {
                                DisclosureGroup {
                                    VStack(alignment: .leading, spacing: 14) {
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
                                    Label(NSLocalizedString("services_schedule_past_lessons", comment: "Прошедшие занятия"), systemImage: "clock.arrow.circlepath")
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
                                    Label(NSLocalizedString("services_schedule_past_exams", comment: "Пройденные экзамены"), systemImage: "clock.arrow.circlepath")
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
                            ServiceEmptyState(text: viewModel.currentModeEmptyText)
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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(NSLocalizedString("services_item_schedule", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .hiddenNavigationBarBackground()
        .toolbar {
            if viewModel.schedule != nil || viewModel.dataSource != .api {
                if viewModel.dataSource == .api, viewModel.schedule != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isSearchSheetPresented = true
                        } label: {
                            Label("Поиск расписания", systemImage: "magnifyingglass")
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker(
                            "Источник данных",
                            selection: $viewModel.dataSource
                        ) {
                            ForEach(ScheduleDataSource.allCases) { source in
                                Label(source.localizedTitle, systemImage: source.icon).tag(source)
                            }
                        }

                        if viewModel.dataSource == .api, viewModel.schedule != nil {
                            Divider()

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
            if (viewModel.isLoading && viewModel.schedule == nil) || viewModel.isDownloadingReport {
                ProgressView(loadingOverlayTitle)
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
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
                    searchBlock(inSheet: true)
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
            .onChange(of: viewModel.schedule?.group?.name ?? viewModel.schedule?.employee?.fullName) {
                isSearchSheetPresented = false
            }
        }
    }

    @ViewBuilder
    private func searchBlock(inSheet: Bool = false) -> some View {
        if inSheet {
            searchControls(showTextField: false)
                .padding(14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            ServiceEndpointSection(
                title: NSLocalizedString("services_schedule_title", comment: ""),
                subtitle: NSLocalizedString("services_schedule_subtitle", comment: ""),
                icon: "calendar"
            ) {
                searchControls(showTextField: true)
            }
        }
    }

    private func searchControls(showTextField: Bool) -> some View {
        VStack(spacing: 12) {
            Picker("", selection: $viewModel.mode) {
                Text(NSLocalizedString("services_schedule_mode_group", comment: "")).tag(ScheduleLookupMode.group)
                Text(NSLocalizedString("services_schedule_mode_teacher", comment: "")).tag(ScheduleLookupMode.teacher)
            }
            .pickerStyle(.segmented)

            if viewModel.mode == .group {
                MilitaryScheduleImportButton(
                    viewModel: viewModel,
                    localScheduleViewModel: localScheduleViewModel
                )
            }

            if showTextField {
                TextField(viewModel.searchPlaceholder, text: $viewModel.query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    )
                    .onSubmit {
                        Task { await viewModel.loadByQuery() }
                    }
            }

            Button {
                Task { await viewModel.loadByQuery() }
            } label: {
                Label(NSLocalizedString("services_schedule_load_button", comment: ""), systemImage: "arrow.down.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if viewModel.mode == .group {
                ScheduleSuggestionsView(
                    groups: viewModel.filteredGroups,
                    accountGroupName: viewModel.accountGroupName,
                    pinnedGroupNames: viewModel.pinnedGroupNames,
                    onSelect: { group in
                        Task { await viewModel.loadGroup(group.name) }
                    },
                    onTogglePin: { group in
                        viewModel.togglePinnedGroup(group)
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
    @ViewBuilder
    private func localExcelBlock() -> some View {
        ServiceEndpointSection(
            title: "Локальное расписание",
            subtitle: "Загрузка из файла Excel",
            icon: "doc.text.image"
        ) {
            VStack(spacing: 16) {
                Text("Функция импорта расписания из локального Excel-файла. Здесь вы сможете загрузить свой файл с расписанием, и приложение отобразит его вместо расписания с сервера БГУИР.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button {
                    // TODO: Реализовать выбор Excel-файла
                } label: {
                    Label("Выбрать Excel-файл", systemImage: "folder")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 12))
                .controlSize(.large)
            }
            .padding(.vertical, 8)
        }
    }
}

private extension ScheduleServiceView {
    func examDayTitleColor(for day: ExamScheduleDay) -> Color {
        if !day.lessons.isEmpty,
           day.lessons.allSatisfy({ viewModel.isExamPast($0, on: day.date) }) {
            return .secondary
        }
        return Calendar.current.isDateInTomorrow(day.date) ? .red : .primary
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

                        if let teacher = lesson.employees.first, !teacher.fullName.isEmpty {
                            Button {
                                onTeacherTap(teacher)
                            } label: {
                                Label(teacher.fullName, systemImage: "person.fill")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(cardSecondaryForeground)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if let compactSubtitle {
                    Text(compactSubtitle)
                        .font(.subheadline.weight(.regular))
                        .foregroundStyle(cardSecondaryForeground)
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
            teacherAvatar(size: size)
        }
        .buttonStyle(.plain)
        .disabled(onDetailsTap == nil)
    }

    private func teacherAvatar(size: CGFloat) -> some View {
        Group {
            if let url = teacherPhotoURL {
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

    private var teacherPhotoURL: URL? {
        guard let link = lesson.employees.first?.photoLink.nilIfBlank else { return nil }
        let normalized = link
            .replacingOccurrences(of: "http://", with: "https://")
            .replacingOccurrences(of: "null/", with: "https://iis.bsuir.by/")
        return URL(string: normalized)
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
            ? [Color(uiColor: .systemGray3), Color(uiColor: .systemGray4)]
            : [Color(red: 0.11, green: 0.12, blue: 0.16), Color(red: 0.13, green: 0.14, blue: 0.18)]
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cardPrimaryForeground: Color { isPast ? Color.white.opacity(0.78) : .white }

    private var cardSecondaryForeground: Color { isPast ? Color.white.opacity(0.58) : Color.white.opacity(0.75) }

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
        if isPast {
            return Color.white.opacity(0.45)
        }
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
