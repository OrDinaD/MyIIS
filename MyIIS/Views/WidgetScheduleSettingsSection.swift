import SwiftUI

struct WidgetScheduleSettingsSection: View {
    @AppStorage(WidgetScheduleSelection.groupKey, store: WidgetScheduleSelection.defaults)
    private var customGroup = ""
    @AppStorage(WidgetScheduleSelection.teacherIDKey, store: WidgetScheduleSelection.defaults)
    private var teacherID = ""
    @AppStorage(WidgetScheduleSelection.teacherNameKey, store: WidgetScheduleSelection.defaults)
    private var teacherName = ""
    @AppStorage(WidgetScheduleSelection.accountGroupKey, store: WidgetScheduleSelection.defaults)
    private var accountGroup = ""
    @State private var isSelecting = false
    @State private var pickerModel = ScheduleServiceViewModel(persistsLookupMode: false)

    var body: some View {
        Section {
            Button {
                pickerModel.query = ""
                pickerModel.mode = teacherID.isEmpty ? .group : .teacher
                isSelecting = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(teacherID.isEmpty ? (customGroup.nilIfBlank ?? accountGroup.nilIfBlank ?? "Не выбрано") : teacherName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(NSLocalizedString(
                            teacherID.isEmpty ? "services_schedule_mode_group" : "services_schedule_mode_teacher", comment: ""
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .accessibilityHint("Изменить расписание виджета")

            if !teacherID.isEmpty || (!customGroup.isEmpty && customGroup != accountGroup) {
                Button("Использовать группу аккаунта") {
                    WidgetScheduleSelection.useAccountGroup(in: WidgetScheduleSelection.defaults)
                    refresh()
                }
                .disabled(accountGroup.isEmpty)
            }
        } header: {
            Text("Расписание в виджетах")
        } footer: {
            Text("По умолчанию — группа вашего аккаунта. Выбранная группа или преподаватель закреплены для виджетов и не меняются при просмотре других расписаний.")
        }
        .sheet(isPresented: $isSelecting) {
            NavigationStack {
                ScheduleSearchSheet(
                    viewModel: pickerModel,
                    isPresented: $isSelecting,
                    onSelectGroup: selectGroup,
                    onSelectTeacher: selectTeacher
                )
                .navigationTitle("Расписание в виджетах")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(NSLocalizedString("common_cancel", comment: "")) { isSelecting = false }
                    }
                }
            }
        }
        .task {
            if let group = AuthenticationService.shared.currentUser?.education.group {
                await WidgetScheduleRefreshService.shared.updateAccountGroup(group)
            }
        }
    }

    private func selectGroup(_ group: StudyGroup) {
        customGroup = group.name
        teacherID = ""
        teacherName = ""
        refresh()
    }

    private func selectTeacher(_ teacher: ScheduleEmployeeDirectoryEntry) {
        guard let urlID = teacher.urlId?.nilIfBlank else { return }
        teacherName = teacher.displayName
        teacherID = urlID
        customGroup = ""
        refresh()
    }

    private func refresh() {
        ClassScheduleWidgetDataStore.clear()
        SessionScheduleWidgetDataStore.clear()
        WatchScheduleConnectivityService.shared.clear()
        Task { await WidgetScheduleRefreshService.shared.refresh(force: true) }
    }
}

#Preview {
    Form { WidgetScheduleSettingsSection() }
}
