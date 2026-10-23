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
    @State private var isEditing = false
    @State private var draft = ""
    @State private var teacherMode = false
    @State private var teachers: [ScheduleEmployeeDirectoryEntry] = []
    @State private var errorMessage: String?
    @State private var isLoadingTeachers = false

    var body: some View {
        Section {
            if isEditing {
                Picker("Источник", selection: $teacherMode) {
                    Text("Группа").tag(false)
                    Text("Преподаватель").tag(true)
                }
                .pickerStyle(.segmented)
                TextField(teacherMode ? "Фамилия преподавателя" : "Номер группы", text: $draft)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if teacherMode {
                    teacherResults
                } else {
                    Button("Сохранить группу") { saveGroup() }
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Button("Отмена", role: .cancel) { isEditing = false; errorMessage = nil }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(WidgetScheduleSelection.target(in: WidgetScheduleSelection.defaults).title ?? "Не выбрано")
                            .font(.headline)
                        Text(teacherID.isEmpty ? "Группа" : "Преподаватель")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        draft = customGroup.isEmpty ? accountGroup : customGroup
                        teacherMode = !teacherID.isEmpty
                        if teacherMode { draft = teacherName }
                        isEditing = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel("Изменить расписание виджета")
                }
                if !customGroup.isEmpty || !teacherID.isEmpty {
                    Button("Использовать группу аккаунта") {
                        customGroup = ""
                        teacherID = ""
                        teacherName = ""
                        refresh()
                    }
                    .disabled(accountGroup.isEmpty)
                }
            }
        } header: {
            Text("Расписание в виджетах")
        } footer: {
            Text("По умолчанию — группа вашего аккаунта. Выбранная группа или преподаватель закреплены для виджетов и не меняются при просмотре других расписаний.")
        }
        .task(id: teacherMode) {
            guard teacherMode, teachers.isEmpty else { return }
            isLoadingTeachers = true
            defer { isLoadingTeachers = false }
            do {
                teachers = try await ServiceEndpointsAPI().fetchAllEmployees()
            } catch {
                errorMessage = "Не удалось загрузить преподавателей. Проверьте подключение и попробуйте снова."
            }
        }
    }

    @ViewBuilder private var teacherResults: some View {
        if isLoadingTeachers {
            ProgressView("Загружаем преподавателей…")
        } else {
            ForEach(filteredTeachers, id: \.id) { teacher in
                Button(teacher.displayName) {
                    guard let urlID = teacher.urlId, !urlID.isEmpty else { return }
                    teacherID = urlID
                    teacherName = teacher.displayName
                    customGroup = ""
                    isEditing = false
                    refresh()
                }
            }
            if !draft.isEmpty, filteredTeachers.isEmpty, errorMessage == nil {
                Text("Преподаватель не найден").foregroundStyle(.secondary)
            }
        }
    }

    private var filteredTeachers: [ScheduleEmployeeDirectoryEntry] {
        let query = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return Array(teachers.filter {
            $0.urlId != nil && $0.displayName.localizedCaseInsensitiveContains(query)
        }.prefix(12))
    }

    private func saveGroup() {
        let group = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (4...12).contains(group.count), group.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            errorMessage = "Введите номер группы цифрами."
            return
        }
        customGroup = group
        teacherID = ""
        teacherName = ""
        errorMessage = nil
        isEditing = false
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
