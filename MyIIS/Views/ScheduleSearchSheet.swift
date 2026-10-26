import SwiftUI

/// Search controls own their presentation state and share the schedule model.
struct ScheduleSearchSheet: View {
    @Bindable var viewModel: ScheduleServiceViewModel
    @Binding var isPresented: Bool
    var onSelectGroup: ((StudyGroup) -> Void)?
    var onSelectTeacher: ((ScheduleEmployeeDirectoryEntry) -> Void)?
    @State private var showsAllGroups = false
    @State private var showsNumberFinder = false
    @State private var pullProgress: CGFloat = 0
    @FocusState private var searchFocused: Bool
    @State private var renamingPinnedGroupName: String?
    @State private var pinnedGroupAliasDraft = ""

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

    var body: some View {
        ScheduleObservedScrollView(threshold: .pulledDown(100), onCrossThreshold: {
            if viewModel.mode == .group, !showsNumberFinder {
                searchFocused = false
                showsNumberFinder = true
            }
        }, onProgress: { progress in
            if viewModel.mode == .group { pullProgress = progress }
        }, content: {
            VStack(spacing: 20) {
                if viewModel.mode == .group {
                    ZStack {
                        Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 3)
                        Circle().trim(from: 0, to: pullProgress)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: "number").font(.caption)
                    }
                    .frame(width: 28, height: 28)
                    .opacity(pullProgress)
                    .frame(height: 28 * pullProgress)
                    .accessibilityHidden(true)
                }
                searchField
                searchControls
                if viewModel.mode == .group {
                    numberFinderEntry
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 22)
            .padding(.bottom, 24)
        })
        .sensoryFeedback(.selection, trigger: Int(pullProgress * 4))
        .sensoryFeedback(.success, trigger: showsNumberFinder)
        .background(Color(uiColor: .systemGroupedBackground))
        .accessibilityAction(.escape) { isPresented = false }
        .scrollDismissesKeyboard(.interactively)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .fullScreenCover(isPresented: $showsNumberFinder) {
            ScheduleGroupNumberFinder(viewModel: viewModel) { group in
                isPresented = false
                selectGroup(group)
            }
        }
        .task { await viewModel.loadDirectoryIfNeeded(force: false) }
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

    private func selectGroup(_ group: StudyGroup) {
        if let onSelectGroup {
            onSelectGroup(group)
        } else {
            Task { await viewModel.loadGroup(group.name) }
        }
    }

    private func selectTeacher(_ teacher: ScheduleEmployeeDirectoryEntry) {
        if let onSelectTeacher {
            onSelectTeacher(teacher)
        } else {
            Task { await viewModel.loadEmployee(teacher) }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(
                ScheduleSearchCopy.text(viewModel.mode == .group ? "find_group" : "find_teacher"),
                text: $viewModel.query
            )
            .focused($searchFocused)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .accessibilityIdentifier("schedule.search.field")
            if !viewModel.query.isEmpty {
                Button { viewModel.query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(ScheduleSearchCopy.text("clear_search"))
            }
        }
        .font(.body)
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .frame(minHeight: 50)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
    }

    private var numberFinderEntry: some View {
        Button {
            searchFocused = false
            showsNumberFinder = true
        } label: {
            VStack(spacing: 8) {
                Text("0 0 0 0 0 0")
                    .font(.title2.monospacedDigit())
                    .accessibilityHidden(true)
                Text(ScheduleSearchCopy.text("number_finder"))
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(ScheduleSearchCopy.text("pull_hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("schedule.numberFinder.open")
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

            if viewModel.mode == .group ? viewModel.groups.isEmpty : viewModel.employees.isEmpty {
                ScheduleDirectoryStatus(viewModel: viewModel)
            } else if viewModel.mode == .group {
                ScheduleSuggestionsView(
                    groups: viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? viewModel.groups : viewModel.filteredGroups,
                    pinnedGroupNames: viewModel.pinnedGroupNames,
                    pinnedGroupAliases: viewModel.pinnedGroupAliases,
                    recentGroupNames: viewModel.recentGroupNames,
                    accountGroupName: viewModel.accountGroupName,
                    isSearching: !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    showsAllGroups: showsAllGroups,
                    onSelect: { group in
                        isPresented = false
                        selectGroup(group)
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
                        isPresented = false
                        selectTeacher(employee)
                    },
                    onTogglePin: { employee in
                        viewModel.togglePinnedTeacher(employee)
                    }
                )
            }
        }
    }
}
