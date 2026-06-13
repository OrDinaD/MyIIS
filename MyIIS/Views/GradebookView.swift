import SwiftUI

struct GradebookView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel: GradebookViewModel
    @State private var expandedSubjectId: MarkbookMark.ID?
    @State private var sharePayload: GradebookShareImagePayload?
    @State private var shareErrorMessage: String?
    @State private var isPreparingShareImage = false

    @MainActor
    init() {
        _viewModel = StateObject(wrappedValue: GradebookViewModel())
    }

    @MainActor
    init(viewModel: GradebookViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private var isCurrentSemesterSelected: Bool {
        guard let currentCourse = viewModel.currentCourse,
              let selected = viewModel.selectedSemesterKey else {
            return false
        }
        return selected == String(currentCourse)
    }

    var body: some View {
        List {
            headerSection
            if viewModel.isShowingStaleDataWarning {
                Section {
                    StaleDataBanner(lastUpdateTime: viewModel.lastUpdateTime, errorMessage: viewModel.errorMessage) {
                        Task { await viewModel.refresh() }
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            semesterSection
            marksSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(NSLocalizedString("gradebook_title", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: prepareShareImage) {
                    if isPreparingShareImage {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(NSLocalizedString("gradebook_share", comment: ""), systemImage: "square.and.arrow.up")
                    }
                }
                .disabled(viewModel.marksForSelectedSemester.isEmpty || isPreparingShareImage)
                .accessibilityLabel(NSLocalizedString("gradebook_share", comment: ""))
            }
        }
        .hiddenNavigationBarBackground()
        .sheet(item: $sharePayload) { payload in
            GradebookSharePreviewView(payload: payload)
        }
        .alert(NSLocalizedString("common_error", comment: ""), isPresented: shareErrorBinding) {
            Button(NSLocalizedString("common_ok", comment: "")) {
                shareErrorMessage = nil
            }
        } message: {
            Text(shareErrorMessage ?? "")
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .onChange(of: viewModel.selectedSemesterKey) { _, _ in
            expandedSubjectId = nil
        }
    }

    private var shareErrorBinding: Binding<Bool> {
        Binding(
            get: { shareErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    shareErrorMessage = nil
                }
            }
        )
    }

    private func prepareShareImage() {
        guard let snapshot = makeShareSnapshot() else {
            shareErrorMessage = NSLocalizedString("gradebook_share_no_data", comment: "")
            return
        }

        isPreparingShareImage = true
        defer { isPreparingShareImage = false }

        do {
            sharePayload = try GradebookShareImageExporter.renderPNG(snapshot: snapshot)
        } catch {
            shareErrorMessage = error.localizedDescription
        }
    }

    private func makeShareSnapshot() -> GradebookShareSnapshot? {
        guard let selectedSemesterKey = viewModel.selectedSemesterKey,
              !viewModel.marksForSelectedSemester.isEmpty
        else {
            return nil
        }

        return GradebookShareSnapshot(
            number: viewModel.numberText,
            semesterKey: selectedSemesterKey,
            semesterAverageText: viewModel.semesterAverageText,
            overallAverageText: viewModel.overallAverageText,
            generatedAt: Date(),
            subjects: viewModel.marksForSelectedSemester.map(makeShareSubject)
        )
    }

    private func makeShareSubject(from mark: MarkbookMark) -> GradebookShareSubject {
        let averageText = mark.averageForLastFourYearsText ?? "—"
        return GradebookShareSubject(
            id: mark.id,
            abbreviation: mark.subject.nonEmptyOrDash,
            fullName: mark.fullSubject.nonEmptyOrDash,
            controlForm: mark.formOfControl.nonEmptyOrDash,
            grade: mark.displayGrade.nonEmptyOrDash,
            averageText: averageText,
            retakesText: mark.displayRetakes.nonEmptyOrDash
        )
    }

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: NSLocalizedString("gradebook_number", comment: ""), viewModel.numberText))
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Text(String(format: NSLocalizedString("gradebook_overall_average", comment: ""), viewModel.overallAverageText))
                        .font(.headline)
                        .multilineTextAlignment(.trailing)
                }

                if viewModel.isLoading {
                    ProgressView(NSLocalizedString("gradebook_loading", comment: ""))
                        .font(.footnote)
                }

                if let error = viewModel.errorMessage, viewModel.markbook == nil {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var semesterSection: some View {
        Section(NSLocalizedString("gradebook_section_semester", comment: "")) {
            if viewModel.semesterKeys.isEmpty {
                Text(NSLocalizedString("gradebook_semesters_not_found", comment: ""))
                    .foregroundStyle(.secondary)
            } else {
                semesterPicker
                LabeledContent(NSLocalizedString("gradebook_semester_average", comment: ""), value: viewModel.semesterAverageText)
                if let yearlyAverage = viewModel.yearlyAverage {
                    LabeledContent {
                        Text(viewModel.yearlyAverageText)
                            .foregroundStyle(yearlyAverage > 8.75 ? .green : .yellow)
                            .fontWeight(.medium)
                    } label: {
                        Text("Средний балл за год")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var semesterPicker: some View {
        Picker(NSLocalizedString("gradebook_section_semester", comment: ""), selection: Binding(
            get: { viewModel.selectedSemesterKey ?? viewModel.semesterKeys.last ?? "" },
            set: { viewModel.selectSemester($0) }
        )) {
            ForEach(viewModel.semesterKeys, id: \.self) { key in
                Text(key).tag(key)
            }
        }
        .pickerStyle(.segmented)
    }

    private var marksSection: some View {
        Section(NSLocalizedString("gradebook_section_subjects", comment: "")) {
            if viewModel.marksForSelectedSemester.isEmpty {
                Text(NSLocalizedString("gradebook_no_subjects", comment: ""))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.marksForSelectedSemester) { mark in
                    MarkRow(mark: mark, isExpanded: expandedSubjectId == mark.id, isCurrentSemester: isCurrentSemesterSelected) {
                        AccessibilitySupport.update(
                            reduceMotion: reduceMotion,
                            animation: .spring(response: 0.3, dampingFraction: 0.7)
                        ) {
                            expandedSubjectId = (expandedSubjectId == mark.id) ? nil : mark.id
                        }
                    }
                }
            }
        }
    }
}

private extension String {
    var nonEmptyOrDash: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
}

private struct MarkRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let mark: MarkbookMark
    let isExpanded: Bool
    let isCurrentSemester: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    subjectTitle
                    gradeText
                }
            } else {
                HStack(alignment: .top, spacing: 8) {
                    subjectTitle
                    Spacer(minLength: 8)
                    gradeText
                        .frame(width: 90, alignment: .trailing)
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if mark.hasExpandedFullName {
                        Text(mark.fullSubject)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, -2)
                    }

                    markGrid
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(mark.subject)
        .accessibilityValue("Оценка \(mark.displayGrade)")
        .accessibilityHint(isExpanded ? "Скрывает подробности" : "Показывает подробности")
        .accessibilityIdentifier("gradebookMark_\(mark.subject)")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: isExpanded ? "Скрыть подробности" : "Показать подробности") {
            onToggle()
        }
    }

    private var subjectTitle: some View {
        HStack(spacing: 6) {
            Text(mark.subject)
                .font(.body.weight(.semibold))
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
            Image(systemName: "chevron.down")
                .font(.caption)
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isExpanded && !reduceMotion ? 180 : 0))
                .accessibilityHidden(true)
        }
    }

    private var gradeText: some View {
        Text(mark.displayGrade)
            .font(.headline)
            .monospacedDigit()
    }

    private var markGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
            GridRow {
                Text(NSLocalizedString("gradebook_hours", comment: ""))
                    .foregroundStyle(.secondary)
                Text(mark.displayHours)
            }
            GridRow {
                Text(NSLocalizedString("gradebook_control_form", comment: ""))
                    .foregroundStyle(.secondary)
                Text(mark.formOfControl)
            }
            if !isCurrentSemester {
                GridRow {
                    Text(NSLocalizedString("gradebook_date", comment: ""))
                        .foregroundStyle(.secondary)
                    Text(mark.date ?? "—")
                }
                GridRow {
                    Text(NSLocalizedString("gradebook_teacher", comment: ""))
                        .foregroundStyle(.secondary)
                    Text((mark.teacher?.isEmpty == false) ? (mark.teacher ?? "") : "—")
                }
            }
            GridRow {
                Text(NSLocalizedString("gradebook_retakes", comment: ""))
                    .foregroundStyle(.secondary)
                Text(mark.displayRetakes)
            }
            if let average4Years = mark.averageForLastFourYearsText {
                GridRow {
                    Text(NSLocalizedString("gradebook_average_4years", comment: ""))
                        .foregroundStyle(.secondary)
                    Text(average4Years)
                }
            }
        }
        .font(.footnote)
    }
}

#if DEBUG
extension GradebookViewModel {
    static var previewVM: GradebookViewModel {
        let viewModel = GradebookViewModel()
        viewModel.markbook = MarkbookResponse(number: "42850012", averageMark: 9.59, markPages: [
            "3": MarkbookSemester(averageMark: 10.0, marks: [
                MarkbookMark(
                    subject: "АПЭЦ", formOfControl: "Зачет",
                    fullSubject: "Автоматизированное проектирование электрических цепей",
                    hours: "108.0", credits: 3.0, mark: "зач", date: "30.12.2025",
                    teacher: "Шилин Л. Ю.", commonMark: nil, commonRetakes: nil, retakesCount: 0
                ),
                MarkbookMark(
                    subject: "ООП", formOfControl: "Курс. работа",
                    fullSubject: "Объектно-ориентированное программирование",
                    hours: "30.0", credits: 1.0, mark: "10", date: "29.12.2025",
                    teacher: "Ючков А. К.", commonMark: 7.49, commonRetakes: 0.025, retakesCount: 0
                )
            ])
        ])
        viewModel.semesterKeys = ["3"]
        viewModel.selectedSemesterKey = "3"
        viewModel.currentCourse = 3
        return viewModel
    }
}

#Preview {
    NavigationStack {
        GradebookView(viewModel: .previewVM)
    }
}
#endif
