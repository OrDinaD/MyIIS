//
//  ScheduleServiceView.swift
//  MyIIS
//
import Combine
import QuickLook
import SwiftUI

@MainActor
struct ScheduleServiceView: View {
    @State var viewModel = ScheduleServiceViewModel()
    @State var localScheduleViewModel = LocalScheduleViewModel()
    @AppStorage("enable_beta_sections") private var enableBetaSections = false
    @AppStorage(ScheduleDisplayPreferences.showsMidPairBreaksKey, store: ScheduleDisplayPreferences.defaults)
    var showsMidPairBreaks = false
    @AppStorage(ScheduleDisplayPreferences.hidePastLessonsKey, store: ScheduleDisplayPreferences.defaults)
    var hidePastLessons = true
    @AppStorage(ScheduleDisplayPreferences.cardDensityKey, store: ScheduleDisplayPreferences.defaults)
    private var cardDensityRaw = ScheduleCardDensity.regular.rawValue
    @AppStorage(ScheduleDisplayPreferences.otherSubgroupDisplayKey, store: ScheduleDisplayPreferences.defaults)
    private var otherSubgroupRaw = ScheduleOtherSubgroupDisplay.compact.rawValue

    @State var scheduleReportURL: URL?
    @State var selectedExamLesson: DisciplineSchedule?
    @State var isLocalScheduleEditorPresented = false
    @State var isSearchSheetPresented = false
    @State var isSettingsSheetPresented = false
    @State var isDatePickerPresented = false
    @State private var selectedDateForJump = Date()
    @State private var dateJumpTarget: Date?
    @State var scheduleScrollPosition: String?
    @State var isPinnedPickerPresented = false
    @State var isComparisonPresented = false
    @State var isFreeAuditoriesPresented = false

    var cardDensity: ScheduleCardDensity {
        ScheduleCardDensity(rawValue: cardDensityRaw) ?? .regular
    }

    var otherSubgroupDisplay: ScheduleOtherSubgroupDisplay {
        ScheduleOtherSubgroupDisplay(rawValue: otherSubgroupRaw) ?? .compact
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 32) {
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
                    } else if viewModel.isLoading || !viewModel.hasLoadedInitialData {
                        scheduleSkeletonView
                    } else if viewModel.errorMessage != nil {
                        scheduleInitialErrorView
                    } else {
                        emptySelectionView
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .scrollTargetLayout()
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
            .scrollPosition(id: $scheduleScrollPosition, anchor: .top)
            .onChange(of: viewModel.upcomingContinuousDays.first?.id, initial: true) { _, firstDay in
                guard viewModel.displayMode == .continuous, scheduleScrollPosition == nil else { return }
                scheduleScrollPosition = firstDay
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
                await loadSelectedScheduleSource()
            }
            .onChange(of: viewModel.schedule?.group?.name ?? viewModel.schedule?.employee?.fullName) { previous, _ in
                guard previous != nil else { return }
                scheduleScrollPosition = nil
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
        .sheet(isPresented: $isComparisonPresented) {
            ScheduleComparisonView(source: viewModel)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $isSettingsSheetPresented) {
            ScheduleSettingsView(viewModel: viewModel)
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
            ScheduleDateJumpSheet(
                selectedDate: $selectedDateForJump,
                targetDate: $dateJumpTarget,
                isPresented: $isDatePickerPresented,
                dateRange: scheduleDateRange
            )
        }
        .errorAlert($viewModel.noticeMessage, title: NSLocalizedString("services_schedule_title", comment: ""))
        .sheet(isPresented: $isSearchSheetPresented) {
            ScheduleSearchSheet(viewModel: viewModel, isPresented: $isSearchSheetPresented)
        }
        .sheet(isPresented: $isFreeAuditoriesPresented) {
            FreeAuditoriesView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .scheduleResetToDefaultGroup)) { _ in
            guard !isCurrentScheduleUserAccountGroup || viewModel.mode == .teacher else { return }
            Task {
                await viewModel.resetToDefaultOrPinnedSchedule()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ScheduleServiceView()
    }
}

#Preview("Initial schedule screen") {
    let defaults = UserDefaults(suiteName: "MyIIS.Preview.ScheduleStartup")!
    defaults.set("420603", forKey: ScheduleServiceViewModel.lastGroupDefaultsKey)
    let model = ScheduleServiceViewModel(defaults: defaults)
    model.hasLoadedInitialData = true
    model.isLoading = true
    return NavigationStack {
        ScheduleServiceView(viewModel: model)
    }
}

#Preview("Finished today — initial position") {
    let defaults = UserDefaults(suiteName: "MyIIS.Preview.ScheduleFinishedToday")!
    let model = ScheduleServiceViewModel(defaults: defaults)
    let lesson = DisciplineSchedule(
        id: "preview", auditories: ["101-4"], endLessonTime: "10:35",
        lessonTypeAbbrev: "ЛК", note: nil, subgroup: 0, startLessonTime: "09:00",
        studentGroups: [], subject: "Математика", subjectFullName: nil,
        weekNumbers: [], employees: [], lessonDate: nil,
        startLessonDate: nil, endLessonDate: nil, isAnnouncement: false, isSplit: false
    )
    let group = StudyGroup(
        name: "420603", facultyId: nil, facultyAbbrev: nil, facultyName: nil,
        specialityDepartmentEducationFormId: nil, specialityName: nil,
        specialityAbbrev: nil, course: nil, id: nil, calendarId: nil, educationDegree: nil
    )
    model.schedule = PublicScheduleResponse(
        employee: nil, group: group, exams: [], startDate: nil, endDate: nil,
        startExamsDate: nil, endExamsDate: nil, scheduleByWeekday: [.monday: [lesson]],
        previousScheduleByWeekday: [:], nextScheduleByWeekday: [:]
    )
    model.hasLoadedInitialData = true
    model.isContinuousEndReached = true
    model.pastContinuousDays = [
        ScheduleContinuousDay(date: Date(), weekday: .tuesday, weekNumber: 2, lessons: [lesson])
    ]
    model.upcomingContinuousDays = (1...12).compactMap { offset in
        guard let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) else { return nil }
        return ScheduleContinuousDay(
            date: date, weekday: model.studyWeekday(for: date) ?? .monday,
            weekNumber: 2, lessons: [lesson]
        )
    }
    model.continuousTimelineDays = model.pastContinuousDays + model.upcomingContinuousDays
    return NavigationStack {
        ScheduleServiceView(viewModel: model, scheduleScrollPosition: model.upcomingContinuousDays.first?.id)
    }
}
