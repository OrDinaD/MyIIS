import SwiftUI

struct HeadmanView: View {
    @State private var model = HeadmanJournalViewModel()
    @State private var editingLesson: HeadmanJournalData.Lesson?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        List {
            Section {
                Label("Журнал старосты", systemImage: "book.closed")
                    .font(.title2.weight(.semibold))
                    .fontDesign(.serif)
                Text("Посещаемость и темы занятий из ИИС")
                    .foregroundStyle(.secondary)
                if let error = model.error {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                    Button("Повторить") { Task { await model.reload() } }
                        .disabled(model.isSaving)
                }
                if let success = model.success {
                    Label(success, systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
            }
            if model.accessDenied {
                ContentUnavailableView(
                    "Нет доступа", systemImage: "lock",
                    description: Text("Журнал доступен старосте или назначенному отмечающему. Права определяются аккаунтом ИИС.")
                )
            } else {
                filters
                if model.isLoading {
                    ProgressView("Загружаем журнал…")
                } else if let data = model.data {
                    switch model.page {
                    case .attendance:
                        Section {
                            HeadmanJournalGrid(students: model.students, data: data) { editingLesson = $0 }
                        } header: {
                            Text("Лист учёта посещаемости")
                        } footer: {
                            Text("Нажмите на дату, чтобы выставить пропуски. У — уважительная причина, Н — неуважительная.")
                            Text("Пустая клетка означает отсутствие записи, а не подтверждённое присутствие.")
                        }
                    case .topics:
                        topics(data)
                    case .summary:
                        HeadmanJournalSummary(students: model.students, data: data)
                    }
                } else if !model.isLoading && model.error == nil {
                    ContentUnavailableView("Нет занятий", systemImage: "book",
                                           description: Text("Для этого предмета журнал пока пуст."))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Староста")
        .task { await model.loadIfNeeded() }
        .onChange(of: AuthenticationService.shared.currentUser?.id) { _, _ in
            editingLesson = nil
            Task { await model.reload() }
        }
        .onChange(of: model.data?.topicSubgroups) { _, subgroups in
            if let subgroups, !subgroups.contains(model.topicSubgroup) {
                model.topicSubgroup = 0
            }
        }
        .refreshable { if !model.isSaving { await model.reload() } }
        .sheet(item: $editingLesson) { lesson in
            HeadmanJournalEditor(model: model, lesson: lesson, topicMode: model.page == .topics)
        }
    }

    private var filters: some View {
        Section {
            if !model.options.isEmpty {
                Picker("Дисциплина", selection: Binding(
                    get: { model.selectedID ?? model.options[0].id },
                    set: { id in Task { await model.select(id) } }
                )) {
                    ForEach(model.options) { option in Text(option.title).tag(option.id) }
                }
                .disabled(model.isSaving)
                if let teacher = model.selectedOption?.subject.teacherInfo?.fullName {
                    Label(teacher, systemImage: "person")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            if dynamicTypeSize.isAccessibilitySize {
                pagePicker.pickerStyle(.menu)
            } else {
                pagePicker.pickerStyle(.segmented)
            }
        }
    }

    private var pagePicker: some View {
        Picker("Лист журнала", selection: $model.page) {
            ForEach(HeadmanJournalViewModel.Page.allCases, id: \.self) { page in
                Text(LocalizedStringKey(page.rawValue)).tag(page)
            }
        }
    }

    private func topics(_ data: HeadmanJournalData) -> some View {
        Section("План проведения занятий") {
            if !data.topicSubgroups.isEmpty {
                Picker("Подгруппа для тем", selection: $model.topicSubgroup) {
                    Text("Все подгруппы").tag(0)
                    ForEach(data.topicSubgroups, id: \.self) { subgroup in
                        Text("Подгруппа \(subgroup)").tag(subgroup)
                    }
                }
                .disabled(model.isSaving)
                Text("Общие занятия видны при любом выборе. Тема сохраняется только для выбранного занятия.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if data.topicLessons(subgroup: model.topicSubgroup).isEmpty {
                Text("Для выбранной подгруппы нет занятий.")
                    .foregroundStyle(.secondary)
            }
            ForEach(data.topicLessons(subgroup: model.topicSubgroup)) { lesson in
                Button { editingLesson = lesson } label: {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading) {
                            Text(lesson.date).monospacedDigit()
                            Text("\(lesson.numberOfHours) ч")
                            Text(lesson.subgroup == 0
                                 ? String(localized: "Общее занятие")
                                 : String(localized: "Подгруппа \(lesson.subgroup)"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Text(lesson.topic ?? String(localized: "Тема не заполнена"))
                            .foregroundStyle(lesson.topic == nil ? .secondary : .primary)
                        Spacer(minLength: 0)
                        Image(systemName: "pencil").accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!model.canWrite)
            }
        }
    }
}

private struct HeadmanJournalGrid: View {
    let students: [HeadmanJournalStudent]
    let data: HeadmanJournalData
    let edit: (HeadmanJournalData.Lesson) -> Void
    private let records: [Int: [String: HeadmanOmission?]]
    private let lessons: [HeadmanJournalData.Lesson]
    @ScaledMetric(relativeTo: .footnote) private var rowHeight: CGFloat = 70
    @ScaledMetric(relativeTo: .caption) private var headerHeight: CGFloat = 80
    @ScaledMetric(relativeTo: .footnote) private var nameWidth: CGFloat = 210
    @ScaledMetric(relativeTo: .caption) private var lessonWidth: CGFloat = 100

    init(students: [HeadmanJournalStudent], data: HeadmanJournalData,
         edit: @escaping (HeadmanJournalData.Lesson) -> Void) {
        self.students = students
        self.data = data
        self.edit = edit
        records = Dictionary(data.attendance.map { ($0.studentId, $0.lessonRecords) },
                             uniquingKeysWith: { _, last in last })
        lessons = data.lessons.sorted { ($0.date, $0.id) < ($1.date, $1.id) }
    }

    var body: some View {
        ScrollView(.horizontal) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    cell("№ · ФИО студента", width: nameWidth)
                    ForEach(lessons) { lesson in
                        Button { edit(lesson) } label: {
                            VStack(spacing: 3) {
                                Text(lesson.date).monospacedDigit()
                                Text("\(lesson.numberOfHours) ч")
                                if lesson.subgroup > 0 { Text("П/г \(lesson.subgroup)") }
                            }
                            .font(.caption.weight(.semibold))
                            .frame(width: lessonWidth, height: headerHeight)
                            .background(Color.accentColor.opacity(0.12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Занятие \(lesson.date), \(lesson.numberOfHours) часов, подгруппа \(lesson.subgroup)")
                        .border(Color.secondary.opacity(0.3), width: 0.5)
                    }
                }
                ForEach(Array(students.enumerated()), id: \.element.id) { index, student in
                    HStack(spacing: 0) {
                        cell("\(index + 1). \(student.fullName)", width: nameWidth)
                        ForEach(lessons) { lesson in
                            let record = records[student.id]?[String(lesson.id)].flatMap { $0 }
                            Text(record.map { "\($0.respectfulOmission == true ? "У" : "Н") \($0.missedHours ?? 0)" } ?? "")
                                .foregroundStyle(record?.respectfulOmission == true ? Color.green : Color.primary)
                                .font(.footnote.weight(.medium))
                                .frame(width: lessonWidth, height: rowHeight)
                                .border(Color.secondary.opacity(0.3), width: 0.5)
                                .accessibilityLabel("\(student.fullName), \(lesson.date): \(record?.missedHours.map(String.init) ?? String(localized: "нет записи"))")
                        }
                    }
                    .background(index.isMultiple(of: 2) ? Color.clear : Color.secondary.opacity(0.05))
                }
            }
        }
    }

    private func cell(_ text: String, width: CGFloat) -> some View {
        Text(text).font(.footnote).frame(width: width, height: rowHeight, alignment: .leading)
            .padding(.horizontal, 6).border(Color.secondary.opacity(0.3), width: 0.5)
    }
}
