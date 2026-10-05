import SwiftUI

struct HeadmanJournalEditor: View {
    @Bindable var model: HeadmanJournalViewModel
    let lesson: HeadmanJournalData.Lesson
    let topicMode: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var hours: [Int: Int] = [:]
    @State private var topic = ""
    @State private var confirming = false

    private var eligibleStudents: [HeadmanJournalStudent] {
        model.students.filter { model.data?.contains(studentID: $0.id, lesson: lesson) == true }
    }

    private var confirmationDetails: String {
        let header = "\(model.selectedOption?.title ?? "") · \(lesson.date)\n"
        if topicMode { return header + topic }
        let rows = eligibleStudents.compactMap { student -> String? in
            guard let value = hours[student.id] else { return nil }
            return "\(student.fullName): \(value) ч"
        }
        return header + rows.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(model.selectedOption?.title ?? "").font(.headline)
                    Text("\(lesson.date) · \(lesson.numberOfHours) ч").monospacedDigit()
                }
                if let error = model.error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                        Button("Обновить журнал") {
                            Task {
                                await model.reload()
                                hours = [:]
                            }
                        }.disabled(model.isSaving || model.isLoading)
                    }
                }
                if topicMode {
                    Section("Тема занятия") {
                        TextField("Введите тему из журнала", text: $topic, axis: .vertical)
                            .lineLimit(4...12)
                    }
                } else {
                    Section {
                        ForEach(eligibleStudents) { student in
                            studentRow(student)
                        }
                    } header: {
                        Text("Студенты")
                    } footer: {
                        Text("Выберите отсутствующих и число часов. Уже выставленные пропуски изменить здесь нельзя.")
                    }
                }
            }
            .navigationTitle(topicMode ? "Тема занятия" : "Выставить пропуски")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }.disabled(model.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { confirming = true }
                        .disabled(!model.canWrite || (topicMode ? topic == (lesson.topic ?? "") : hours.isEmpty))
                }
            }
            .interactiveDismissDisabled(model.isSaving)
            .onAppear { topic = lesson.topic ?? "" }
            .alert(topicMode ? "Сохранить тему занятия?" : "Выставить пропуски?",
                   isPresented: $confirming) {
                Button("Отмена", role: .cancel) {}
                Button("Да, сохранить") {
                    Task {
                        let saved = topicMode
                            ? await model.saveTopic(lesson: lesson, topic: topic)
                            : await model.save(lesson: lesson, hours: hours)
                        if saved { dismiss() }
                    }
                }
            } message: {
                Text("Вы уверены, что хотите сохранить эти изменения в ИИС?\n\n\(confirmationDetails)")
            }
            .disabled(model.isSaving)
        }
    }

    @ViewBuilder
    private func studentRow(_ student: HeadmanJournalStudent) -> some View {
        if let record = model.data?.record(studentID: student.id, lessonID: lesson.id) {
            LabeledContent(student.fullName) {
                Text("\(record.respectfulOmission == true ? "У" : "Н") · \(record.missedHours ?? 0) ч")
                    .foregroundStyle(.secondary)
            }
        } else if lesson.numberOfHours > 0 {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(student.fullName, isOn: Binding(
                    get: { hours[student.id] != nil },
                    set: { hours[student.id] = $0 ? lesson.numberOfHours : nil }
                ))
                if hours[student.id] != nil {
                    Picker("Пропущено часов", selection: Binding(
                        get: { hours[student.id] ?? lesson.numberOfHours },
                        set: { hours[student.id] = $0 }
                    )) {
                        ForEach(1...lesson.numberOfHours, id: \.self) { value in
                            Text("\(value) ч").tag(value)
                        }
                    }
                }
            }
        }
    }
}
