import SwiftUI

struct GradebookView: View {
    @StateObject private var viewModel: GradebookViewModel
    @State private var expandedSubjectId: MarkbookMark.ID?

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
        .hiddenNavigationBarBackground()
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .onChange(of: viewModel.selectedSemesterKey) { _, _ in
            expandedSubjectId = nil
        }
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

                if let error = viewModel.errorMessage {
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
                        expandedSubjectId = (expandedSubjectId == mark.id) ? nil : mark.id
                    }
                }

                footerNotes
            }
        }
    }

    private var footerNotes: some View {
        Group {
            Text(NSLocalizedString("gradebook_retakes_note", comment: ""))
            Text(NSLocalizedString("gradebook_average_4years_note", comment: ""))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

private struct MarkRow: View {
    let mark: MarkbookMark
    let isExpanded: Bool
    let isCurrentSemester: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Button(action: onToggle) {
                    HStack(spacing: 6) {
                        Text(mark.subject)
                            .font(.body.weight(.semibold))
                            .lineLimit(2)
                        if mark.hasExpandedFullName {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)
                Text(mark.displayGrade)
                    .font(.headline)
                    .monospacedDigit()
                    .frame(width: 90, alignment: .trailing)
            }

            if isExpanded, mark.hasExpandedFullName {
                Text(mark.fullSubject)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, -2)
            }

            markGrid
        }
        .padding(.vertical, 6)
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
        viewModel.currentCourse = 3
        return viewModel
    }
}
#endif
