import SwiftUI

struct HeadmanView: View {
    @StateObject private var viewModel: HeadmanViewModel

    @MainActor
    init() {
        _viewModel = StateObject(wrappedValue: HeadmanViewModel())
    }

    @MainActor
    init(viewModel: HeadmanViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private var availableModes: [HeadmanViewModel.Mode] {
        viewModel.canManageResponsibles ? HeadmanViewModel.Mode.allCases : [.byDate, .summary, .weekly]
    }

    var body: some View {
        List {
            statusSection

            if viewModel.isShowingStaleDataWarning {
                Section {
                    StaleDataBanner(lastUpdateTime: viewModel.lastUpdateTime, errorMessage: viewModel.errorMessage) {
                        Task { await viewModel.refresh() }
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if viewModel.hasAccess {
                modeSection

                switch viewModel.mode {
                case .byDate:
                    byDateSection
                case .summary:
                    summarySection
                case .weekly:
                    weeklySection
                case .responsibles:
                    if viewModel.canManageResponsibles {
                        responsiblesSection
                    }
                }
            } else if !viewModel.isLoadingAccess {
                noAccessSection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Староста")
        .navigationBarTitleDisplayMode(.large)
        .hiddenNavigationBarBackground()
        .task {
            if viewModel.students.isEmpty {
                await viewModel.loadInitialData()
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .onChange(of: viewModel.selectedDate) { _, _ in
            Task { await viewModel.loadLessonsForSelectedDate() }
        }
        .onChange(of: viewModel.canManageResponsibles) { _, canManage in
            if !canManage, viewModel.mode == .responsibles {
                viewModel.mode = .byDate
            }
        }
    }

    private var statusSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                        .frame(width: 38, height: 38)
                        .background(.yellow.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Журнал старосты")
                            .font(.headline)
                        Text(viewModel.hasAccess ? accessSubtitle : "Проверяем доступ по данным ИИС.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if viewModel.isLoadingAccess {
                        ProgressView()
                    } else {
                        Text(viewModel.hasAccess ? "Доступно" : "Нет доступа")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .foregroundColor(viewModel.hasAccess ? .green : .secondary)
                            .background((viewModel.hasAccess ? Color.green : Color.secondary).opacity(0.12), in: Capsule())
                    }
                }

                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if let success = viewModel.successMessage {
                    Label(success, systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.green)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var accessSubtitle: String {
        if viewModel.isGroupHead {
            return "Полный доступ: пропуски, сводная таблица и назначение отмечающих."
        }
        return "Доступ отмечающего: можно выставлять пропуски и смотреть сводную."
    }

    private var noAccessSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("Вкладка доступна только старосте или назначенному отмечающему.", systemImage: "lock.fill")
                    .font(.headline)
                Text(
                    "Проверка выполняется через endpoints `grade-book/is-group-head`, "
                        + "`grade-book/who-can-note` и список студентов группы из HAR."
                )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
    }

    private var modeSection: some View {
        Section {
            Picker("Режим", selection: $viewModel.mode) {
                ForEach(availableModes) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var byDateSection: some View {
        Group {
            Section {
                DatePicker("Дата занятий", selection: $viewModel.selectedDate, displayedComponents: [.date])
                    .datePickerStyle(.compact)

                Label(
                    "Пропуски, выставленные по ошибке, может убрать только преподаватель.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Section("Занятия") {
                if viewModel.isLoadingLessons {
                    ProgressView("Загружаем занятия...")
                } else if viewModel.lessonsByDate.isEmpty {
                    Text("На выбранную дату занятий нет.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.lessonsByDate) { lesson in
                        LessonDisclosureRow(lesson: lesson, viewModel: viewModel)
                    }
                }
            }
        }
    }

    private var summarySection: some View {
        Group {
            Section("Фильтр") {
                if viewModel.subjectOptions.isEmpty {
                    Text("Доступные предметы не найдены.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Предмет", selection: Binding(
                        get: { viewModel.selectedSubjectID ?? viewModel.subjectOptions.first?.id ?? 0 },
                        set: { subjectID in Task { await viewModel.selectSubject(subjectID) } }
                    )) {
                        ForEach(viewModel.subjectOptions) { option in
                            Text(option.title).tag(option.id)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Picker("Подгруппа", selection: Binding(
                        get: { viewModel.selectedSubgroup },
                        set: { subgroup in Task { await viewModel.selectSubgroup(subgroup) } }
                    )) {
                        ForEach(viewModel.availableSubgroups, id: \.self) { subgroup in
                            Text(subgroup == 0 ? "Вся группа" : "\(subgroup) подгруппа").tag(subgroup)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            Section("Сводная таблица") {
                if viewModel.isLoadingSummary {
                    ProgressView("Загружаем сводную...")
                } else if viewModel.summaryStudents.isEmpty {
                    Text("По выбранному предмету пропусков нет.")
                        .foregroundStyle(.secondary)
                } else {
                    SummaryTable(students: viewModel.summaryStudents, responsibleStudentIDs: viewModel.responsibleStudentIDs)
                }
            }
        }
    }

    private var weeklySection: some View {
        Group {
            Section {
                DatePicker("Неделя", selection: Binding(
                    get: { viewModel.selectedWeekAnchorDate },
                    set: { value in Task { await viewModel.selectWeekAnchorDate(value) } }
                ), displayedComponents: [.date])
                    .datePickerStyle(.compact)

                Label(viewModel.selectedWeekTitle, systemImage: "calendar")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Недельная сводка") {
                if viewModel.isLoadingWeekly {
                    ProgressView("Загружаем неделю...")
                } else if viewModel.weeklyStudents.isEmpty {
                    Text("По выбранной неделе данных нет.")
                        .foregroundStyle(.secondary)
                } else {
                    WeeklySummaryTable(students: viewModel.weeklyStudents, responsibleStudentIDs: viewModel.responsibleStudentIDs)
                }
            }
        }
    }

    private var responsiblesSection: some View {
        Section {
            ForEach(viewModel.students.filter { $0.id != viewModel.currentStudentId }) { student in
                ResponsibleStudentRow(student: student, viewModel: viewModel)
            }
        } header: {
            Text("Отмечающие")
        } footer: {
            Text("Изменения отправляются сразу через endpoints назначения и снятия отмечающего.")
        }
    }
}

private struct LessonDisclosureRow: View {
    let lesson: HeadmanLesson
    @ObservedObject var viewModel: HeadmanViewModel

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(lesson.students) { student in
                    OmissionStudentRow(lesson: lesson, student: student, viewModel: viewModel)
                    if student.id != lesson.students.last?.id {
                        Divider()
                    }
                }

                Button {
                    Task { await viewModel.saveOmissions(for: lesson) }
                } label: {
                    Label("Сохранить пропуски", systemImage: "tray.and.arrow.down.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled((viewModel.pendingOmissions[lesson.id] ?? [:]).isEmpty || viewModel.isSaving)
                .padding(.top, 4)
            }
            .padding(.vertical, 8)
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color(for: lesson.lessonTypeAbbrev))
                    .frame(width: 5, height: 46)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(lesson.nameAbbrev)
                            .font(.headline)
                        Text(lesson.lessonTypeAbbrev)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        if let period = lesson.lessonPeriod {
                            Text("\(period.startTime) - \(period.endTime)")
                        }
                        if lesson.subGroup != 0 {
                            Text("\(lesson.subGroup) подгр.")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func color(for lessonType: String) -> Color {
        switch lessonType {
        case "ЛК", "УЛк": return .green
        case "ЛР", "УЛР": return .orange
        case "ПЗ", "УПз": return .purple
        default: return .blue
        }
    }
}

private struct OmissionStudentRow: View {
    let lesson: HeadmanLesson
    let student: HeadmanLessonStudent
    @ObservedObject var viewModel: HeadmanViewModel

    private var lessonHours: Int {
        max(lesson.lessonPeriod?.lessonPeriodHours ?? 2, 1)
    }

    private var pendingHours: Int? {
        viewModel.pendingHours(lessonId: lesson.id, studentId: student.id)
    }

    private var existingHours: Int? {
        student.omission?.missedHours
    }

    private var isChecked: Bool {
        existingHours != nil || pendingHours != nil
    }

    private var isLocked: Bool {
        existingHours != nil || student.isNotStudying == true || student.inOffsettingValue != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(student.fio)
                    .font(.body)
                    .lineLimit(2)
                Spacer(minLength: 12)
                Toggle("", isOn: Binding(
                    get: { isChecked },
                    set: { checked in
                        viewModel.setPendingOmission(
                            lessonId: lesson.id,
                            studentId: student.id,
                            hours: checked ? lessonHours : nil
                        )
                    }
                ))
                .labelsHidden()
                .disabled(isLocked)
            }

            HStack(spacing: 10) {
                if let omission = student.omission {
                    Label(
                        omission.respectfulOmission == true ? "Уважительная причина" : "\(omission.missedHours ?? 0) ч уже выставлено",
                        systemImage: omission.respectfulOmission == true ? "checkmark.seal.fill" : "lock.fill"
                    )
                    .foregroundColor(omission.respectfulOmission == true ? .green : .secondary)
                } else if student.isNotStudying == true {
                    Label("Не изучает", systemImage: "minus.circle.fill")
                        .foregroundStyle(.secondary)
                } else if let value = student.inOffsettingValue {
                    Label("Перезачтено с оценкой \(value)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Часы", selection: Binding(
                        get: { pendingHours ?? lessonHours },
                        set: { hours in
                            viewModel.setPendingOmission(lessonId: lesson.id, studentId: student.id, hours: hours)
                        }
                    )) {
                        ForEach(1...lessonHours, id: \.self) { hours in
                            Text("\(hours) ч").tag(hours)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(!isChecked)
                }

                Spacer()

                if viewModel.responsibleStudentIDs.contains(student.id) {
                    Text("отмечающий")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            .font(.footnote)
        }
        .padding(.vertical, 3)
        .listRowBackground(viewModel.responsibleStudentIDs.contains(student.id) ? Color.yellow.opacity(0.12) : nil)
    }
}
