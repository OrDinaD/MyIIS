import SwiftUI

struct MarkSheetOrderSheet: View {
    @ObservedObject var viewModel: StudyViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSubjectID = -1
    @State private var selectedLessonTypeID = ""
    @State private var selectedEmployeeID = -1
    @State private var reason = false
    @State private var useAbsentDate = false
    @State private var absentDate = Date()
    @State private var hours = 1

    private var selectedSubject: MarkSheetSubject? {
        viewModel.dashboard.markSheetSubjects.first { $0.id == selectedSubjectID }
    }

    private var selectedLessonType: MarkSheetLessonType? {
        selectedSubject?.lessonTypes.first { $0.id == selectedLessonTypeID }
    }

    private var selectedEmployee: MarkSheetEmployee? {
        viewModel.markSheetEmployees.first { $0.id == selectedEmployeeID }
    }

    private var selectedMarkSheetType: MarkSheetType? {
        viewModel.markSheetType(for: selectedLessonType)
    }

    private var canSubmit: Bool {
        selectedSubject != nil &&
        selectedLessonType != nil &&
        selectedEmployee != nil &&
        selectedMarkSheetType != nil &&
        (!reason || useAbsentDate) &&
        (selectedMarkSheetType?.id != 3 || (1 ... 4).contains(hours)) &&
        !viewModel.isSubmitting
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Параметры") {
                    Picker("Дисциплина", selection: $selectedSubjectID) {
                        Text("Выберите").tag(-1)
                        ForEach(viewModel.dashboard.markSheetSubjects) { subject in
                            Text(subject.displayName).tag(subject.id)
                        }
                    }

                    Picker("Тип", selection: $selectedLessonTypeID) {
                        Text("Выберите").tag("")
                        ForEach(selectedSubject?.lessonTypes ?? []) { lessonType in
                            Text(lessonType.displayName).tag(lessonType.id)
                        }
                    }
                    .disabled(selectedSubject == nil)

                    Picker("Преподаватель", selection: $selectedEmployeeID) {
                        Text(viewModel.isLoadingEmployees ? "Загрузка..." : "Выберите").tag(-1)
                        ForEach(viewModel.markSheetEmployees) { employee in
                            Text(employee.displayName).tag(employee.id)
                        }
                    }
                    .disabled(selectedLessonType == nil || viewModel.isLoadingEmployees)

                    Picker("Причина", selection: $reason) {
                        Text("Неуважительная").tag(false)
                        Text("Уважительная").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Пропуск") {
                    Toggle("Указать дату пропуска", isOn: $useAbsentDate)
                        .disabled(reason)
                    if reason || useAbsentDate {
                        DatePicker("Дата", selection: $absentDate, displayedComponents: .date)
                    }
                    if selectedMarkSheetType?.id == 3 {
                        Stepper("Часы ЛР: \(hours)", value: $hours, in: 1 ... 4)
                    }
                }

                Section("Предпросмотр") {
                    PreviewRow(title: "Дисциплина", value: selectedSubject?.displayName ?? "Не выбрана")
                    PreviewRow(title: "Тип", value: selectedMarkSheetType?.shortName ?? selectedLessonType?.displayName ?? "Не выбран")
                    PreviewRow(title: "Преподаватель", value: selectedEmployee?.displayName ?? "Не выбран")
                    PreviewRow(
                        title: "Стоимость",
                        value: viewModel.priceText(
                            type: selectedMarkSheetType,
                            employee: selectedEmployee,
                            hours: hours
                        ) ?? "Будет рассчитана после выбора"
                    )
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Заказать ведомостичку")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
            .navigationTitle("Заказ ведомостички")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .onChange(of: selectedSubjectID) { _, _ in
                selectedLessonTypeID = ""
                selectedEmployeeID = -1
                viewModel.clearEmployees()
            }
            .onChange(of: selectedLessonTypeID) { _, _ in
                selectedEmployeeID = -1
                Task { await viewModel.loadEmployees(for: selectedLessonType) }
            }
            .onChange(of: reason) { _, isRespectful in
                if isRespectful { useAbsentDate = true }
            }
        }
    }

    private func submit() async {
        guard let selectedLessonType, let selectedMarkSheetType, let selectedEmployee else { return }
        let dateString = (reason || useAbsentDate) ? Self.dateFormatter.string(from: absentDate) : nil
        let request = MarkSheetOrderRequest(
            price: viewModel.calculatedPrice(type: selectedMarkSheetType, employee: selectedEmployee, hours: hours),
            markSheetType: selectedMarkSheetType,
            reason: reason,
            hours: selectedMarkSheetType.id == 3 ? String(hours) : "",
            subject: MarkSheetOrderSubject(focsId: selectedLessonType.focsId, thId: selectedLessonType.thId),
            absentDate: dateString,
            employee: selectedEmployee
        )

        if await viewModel.submitMarkSheet(request) {
            dismiss()
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()
}

struct CertificateOrderSheet: View {
    @ObservedObject var viewModel: StudyViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlaceID = -1
    @State private var printType: CertificatePrintType = .ordinary
    @State private var comment = ""
    @State private var count = 1

    private var selectedPlace: CertificatePlace? {
        viewModel.certificatePlaces.first { $0.id == selectedPlaceID }
    }

    private var canSubmit: Bool {
        guard let selectedPlace else { return false }
        if selectedPlace.requiresComment && comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        return (1 ... 10).contains(count) && !viewModel.isSubmitting
    }

    private var provisionPlace: String {
        guard let selectedPlace else { return "" }
        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedComment.isEmpty, !selectedPlace.blocksComment else {
            return selectedPlace.name
        }
        return "\(selectedPlace.name) (\(trimmedComment))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Параметры") {
                    Picker("Тип печати", selection: $printType) {
                        ForEach(CertificatePrintType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .disabled(selectedPlace?.forcesStampedSeal == true)

                    Picker("Место предъявления", selection: $selectedPlaceID) {
                        Text("Выберите").tag(-1)
                        ForEach(viewModel.dashboard.certificatePlaceSections) { section in
                            Section(section.type) {
                                ForEach(section.places) { place in
                                    Text(place.name).tag(place.id)
                                }
                            }
                        }
                    }

                    commentControl

                    Stepper("Количество: \(count)", value: $count, in: 1 ... 10)
                }

                if selectedPlace?.isMilitary == true {
                    Section {
                        Label("Справки в военкомат забирать в кабинете 115а 3 корпуса.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                Section("Правила") {
                    Text(
                        "Если гербовая печать не нужна, выбирайте обычную. "
                        + "Место «иное» используйте только когда подходящего варианта нет, "
                        + "и укажите конкретное место в комментарии."
                    )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Предпросмотр") {
                    PreviewRow(title: "Тип печати", value: printType.rawValue)
                    PreviewRow(title: "Место", value: provisionPlace.isEmpty ? "Не выбрано" : provisionPlace)
                    PreviewRow(title: "Количество", value: "\(count)")
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Заказать справку")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
            .navigationTitle("Заказ справки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .onChange(of: selectedPlaceID) { _, _ in
                if selectedPlace?.forcesStampedSeal == true {
                    printType = .stamped
                } else {
                    printType = .ordinary
                }
                if selectedPlace?.blocksComment == true {
                    comment = ""
                }
            }
        }
    }

    @ViewBuilder
    private var commentControl: some View {
        if let selectedPlace {
            if selectedPlace.blocksComment {
                Label {
                    Text("Комментарий недоступен для выбранного места")
                } icon: {
                    Image(systemName: "lock.fill")
                }
                .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    TextField(commentPlaceholder, text: $comment, axis: .vertical)
                        .lineLimit(2 ... 4)

                    Text(commentHint)
                        .font(.caption)
                        .foregroundStyle(selectedPlace.requiresComment ? .orange : .secondary)
                }
            }
        } else {
            Label {
                Text("Выберите место, чтобы понять нужен ли комментарий")
            } icon: {
                Image(systemName: "text.bubble")
            }
            .foregroundStyle(.secondary)
        }
    }

    private var commentPlaceholder: String {
        selectedPlace?.requiresComment == true ? "Укажите конкретное место" : "Комментарий необязателен"
    }

    private var commentHint: String {
        selectedPlace?.requiresComment == true
            ? "Для места «иное» комментарий обязателен."
            : "Можно уточнить место предъявления, если это поможет деканату."
    }

    private func submit() async {
        let request = CertificateRegisterRequest(
            certificateRequestDto: CertificateRequestPayload(
                certificateType: printType.rawValue,
                provisionPlace: provisionPlace
            ),
            certificateCount: count
        )

        if await viewModel.submitCertificate(request) {
            dismiss()
        }
    }
}

private struct PreviewRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}
