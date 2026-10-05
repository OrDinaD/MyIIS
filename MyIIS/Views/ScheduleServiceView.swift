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
    @State private var hasAutoScrolled = false
    @State var isPinnedPickerPresented = false
    @State var isComparisonPresented = false

    var cardDensity: ScheduleCardDensity {
        ScheduleCardDensity(rawValue: cardDensityRaw) ?? .compact
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
            .overlay(alignment: .top) {
                if viewModel.activeScheduleRequestID != nil, viewModel.schedule != nil {
                    scheduleLoadingBanner
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
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
