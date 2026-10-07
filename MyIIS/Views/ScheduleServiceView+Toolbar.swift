import SwiftUI

extension ScheduleServiceView {
    // MARK: - Toolbar

    var isCurrentScheduleUserAccountGroup: Bool {
        guard viewModel.mode == .group,
              let accountGroup = viewModel.accountGroupName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !accountGroup.isEmpty else { return false }
        return viewModel.displayedGroupNumber == accountGroup
    }

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
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
            if viewModel.displayedGroupNumber != nil || viewModel.selectedEmployee != nil,
               !isCurrentScheduleUserAccountGroup {
                pinButton
                    .allowsHitTesting(viewModel.schedule != nil)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
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
                Button {
                    isComparisonPresented = true
                } label: {
                    Label(ScheduleComparisonCopy.text("title"), systemImage: "rectangle.split.2x1")
                }

                Button {
                    isFreeAuditoriesPresented = true
                } label: {
                    Label(
                        NSLocalizedString("free_auditories_menu_title", value: "Свободные аудитории", comment: ""),
                        systemImage: "door.left.hand.open"
                    )
                }

                if let calendarURL = appleCalendarURL {
                    Button {
                        UIApplication.shared.open(calendarURL)
                    } label: {
                        Label(
                            NSLocalizedString("schedule_subscribe_apple_calendar", value: "Добавить в Календарь iOS", comment: ""),
                            systemImage: "calendar.badge.plus"
                        )
                    }
                }
                Divider()
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
        if let group = viewModel.displayedGroupNumber {
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

    private var appleCalendarURL: URL? {
        if viewModel.mode == .group,
           let group = (viewModel.displayedGroupNumber ?? viewModel.schedule?.group?.name)?.trimmingCharacters(in: .whitespacesAndNewlines),
           let encoded = group.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
           !encoded.isEmpty {
            return URL(string: "webcal://bsuir.ordinad.xyz/api/v1/calendar/group/\(encoded).ics")
        } else if viewModel.mode == .teacher,
                  let urlId = (viewModel.selectedEmployee?.urlId ?? viewModel.schedule?.employee?.urlId)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let encoded = urlId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  !encoded.isEmpty {
            return URL(string: "webcal://bsuir.ordinad.xyz/api/v1/calendar/employee/\(encoded).ics")
        }
        return nil
    }
}

extension ScheduleDisplayMode {
    var icon: String {
        switch self {
        case .continuous: return "calendar.day.timeline.left"
        case .byDay: return "calendar"
        case .exams: return "graduationcap.fill"
        }
    }
}
