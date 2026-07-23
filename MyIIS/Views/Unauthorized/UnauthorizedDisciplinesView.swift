import SwiftUI

struct UnauthorizedDisciplinesView: View {
    @StateObject private var service = DisciplinesService.shared
    @StateObject private var formService = GlobalRatingService.shared

    @State private var selectedFacultyId: Int?
    @State private var selectedSpecialityId: Int?
    @State private var selectedCourse: Int?
    @State private var selectedTerm: Int?
    @State private var selectedPlan: DisciplinePlan = .standard

    var body: some View {
        Form {
            selectionSection
            statusSection
            summarySection
            disciplinesSection
        }
        .navigationTitle("Список дисциплин")
        .transparentInlineNavigationBar()
        .task {
            if formService.faculties.isEmpty {
                await formService.fetchFaculties()
            }
        }
        .refreshable {
            await refreshCurrentSelection()
        }
    }

    private var selectedFaculty: FacultyDto? {
        formService.faculties.first { $0.id == selectedFacultyId }
    }

    private var selectedSpeciality: SpecialityDto? {
        formService.specialities.first { $0.id == selectedSpecialityId }
    }

    private var selectedCourseInfo: RatingCourseDto? {
        formService.courses.first { $0.course == selectedCourse }
    }

    private var selectedPlanIsForeign: Bool {
        selectedCourseInfo?.hasForeignPlan == true && selectedPlan == .foreign
    }

    private var selectedTermTitle: String {
        selectedTerm.map { "\($0) семестр" } ?? "Весь курс"
    }

    private var totalHours: Int {
        service.disciplines.reduce(0) { $0 + ($1.hours ?? 0) }
    }

    @ViewBuilder
    private var selectionSection: some View {
        Section("Выбор") {
            if formService.isLoadingFaculties && formService.faculties.isEmpty {
                DisciplineLoadingRow(title: "Загрузка факультетов...")
            } else {
                Picker("Факультет", selection: $selectedFacultyId) {
                    Text("Не выбран").tag(nil as Int?)
                    ForEach(formService.faculties) { faculty in
                        Text(faculty.text).tag(Optional(faculty.id))
                    }
                }
                .pickerStyle(.navigationLink)
                .onChange(of: selectedFacultyId) { _, newValue in
                    selectedSpecialityId = nil
                    selectedCourse = nil
                    selectedTerm = nil
                    selectedPlan = .standard
                    service.reset()

                    guard let facultyId = newValue else {
                        formService.resetAfterFacultyClear()
                        return
                    }

                    Task { await formService.fetchSpecialities(facultyId: facultyId) }
                }
            }

            if selectedFacultyId != nil {
                if formService.isLoadingSpecialities {
                    DisciplineLoadingRow(title: "Загрузка специальностей...")
                } else {
                    Picker("Специальность", selection: $selectedSpecialityId) {
                        Text("Не выбрана").tag(nil as Int?)
                        ForEach(formService.specialities) { speciality in
                            Text(speciality.text).tag(Optional(speciality.id))
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .disabled(formService.specialities.isEmpty)
                    .onChange(of: selectedSpecialityId) { _, newValue in
                        selectedCourse = nil
                        selectedTerm = nil
                        selectedPlan = .standard
                        service.reset()

                        guard let facultyId = selectedFacultyId, let specialityId = newValue else {
                            formService.resetAfterSpecialityClear()
                            return
                        }

                        Task { await formService.fetchCourses(facultyId: facultyId, specialityId: specialityId) }
                    }
                }
            }

            if selectedSpecialityId != nil {
                if formService.isLoadingCourses {
                    DisciplineLoadingRow(title: "Загрузка курсов...")
                } else {
                    Picker("Курс", selection: $selectedCourse) {
                        Text("Не выбран").tag(nil as Int?)
                        ForEach(formService.courses) { course in
                            Text(course.title).tag(Optional(course.course))
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .disabled(formService.courses.isEmpty)
                    .onChange(of: selectedCourse) { _, newValue in
                        selectedTerm = nil
                        selectedPlan = .standard

                        guard newValue != nil else {
                            service.reset()
                            return
                        }

                        fetchDisciplines()
                    }
                }
            }

            if let course = selectedCourse {
                Picker("Семестр", selection: $selectedTerm) {
                    Text("Весь курс").tag(nil as Int?)
                    ForEach(1 ... (2 * course), id: \.self) { term in
                        Text("\(term) семестр").tag(Optional(term))
                    }
                }
                .pickerStyle(.navigationLink)
                .onChange(of: selectedTerm) { _, _ in
                    fetchDisciplines()
                }
            }

            if selectedCourseInfo?.hasForeignPlan == true {
                Picker("Учебный план", selection: $selectedPlan) {
                    ForEach(DisciplinePlan.allCases) { plan in
                        Text(plan.title).tag(plan)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedPlan) { _, _ in
                    fetchDisciplines()
                }
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if let errorMessage = service.errorMessage ?? formService.errorMessage {
            Section {
                ContentUnavailableView {
                    Label("Не удалось загрузить", systemImage: "exclamationmark.triangle.fill")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Повторить") {
                        Task { await retryCurrentStep() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        } else if selectedFacultyId == nil && !formService.isLoadingFaculties {
            Section {
                ContentUnavailableView {
                    Label("Выберите факультет", systemImage: "building.columns.fill")
                } description: {
                    Text("После выбора появятся специальности, курсы, семестры и список дисциплин IIS.")
                }
            }
        } else if selectedFacultyId != nil,
                  selectedSpecialityId == nil,
                  !formService.isLoadingSpecialities,
                  formService.specialities.isEmpty {
            Section {
                ContentUnavailableView(
                    "Нет специальностей",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Для выбранного факультета IIS не вернул список специальностей.")
                )
            }
        } else if selectedSpecialityId != nil,
                  selectedCourse == nil,
                  !formService.isLoadingCourses,
                  formService.courses.isEmpty {
            Section {
                ContentUnavailableView(
                    "Нет курсов",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("Для выбранной специальности IIS не вернул доступные курсы.")
                )
            }
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        if selectedCourse != nil && !service.disciplines.isEmpty {
            Section("Итог") {
                LabeledContent("Факультет", value: selectedFaculty?.text ?? "—")
                if let selectedSpeciality {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Специальность")
                        Text(selectedSpeciality.text)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                LabeledContent("Курс", value: selectedCourseInfo?.title ?? "—")
                LabeledContent("Семестр", value: selectedTermTitle)
                if selectedCourseInfo?.hasForeignPlan == true {
                    LabeledContent("Учебный план", value: selectedPlan.title)
                }
                LabeledContent("Дисциплин", value: "\(service.disciplines.count)")
                LabeledContent("Часов всего", value: "\(totalHours) ч")
            }
        }
    }

    @ViewBuilder
    private var disciplinesSection: some View {
        if selectedCourse != nil {
            Section("Дисциплины") {
                if service.isLoading {
                    DisciplineLoadingRow(title: "Загрузка дисциплин...")
                } else if service.disciplines.isEmpty && service.errorMessage == nil {
                    ContentUnavailableView(
                        "Нет дисциплин",
                        systemImage: "list.bullet.clipboard",
                        description: Text("IIS не вернул дисциплины для выбранных параметров. Попробуйте другой семестр или учебный план.")
                    )
                } else {
                    ForEach(service.disciplines) { discipline in
                        DisciplineRow(discipline: discipline)
                    }
                }
            }
        }
    }

    private func fetchDisciplines() {
        guard let specialityId = selectedSpecialityId, let course = selectedCourse else {
            service.reset()
            return
        }

        Task {
            await service.fetchDisciplines(
                sdefId: specialityId,
                course: course,
                term: selectedTerm,
                isForeign: selectedPlanIsForeign
            )
        }
    }

    private func refreshCurrentSelection() async {
        guard let specialityId = selectedSpecialityId, let course = selectedCourse else {
            if formService.faculties.isEmpty {
                await formService.fetchFaculties()
            }
            return
        }

        await service.fetchDisciplines(
            sdefId: specialityId,
            course: course,
            term: selectedTerm,
            isForeign: selectedPlanIsForeign
        )
    }

    private func retryCurrentStep() async {
        if selectedFacultyId == nil {
            await formService.fetchFaculties()
        } else if let facultyId = selectedFacultyId, selectedSpecialityId == nil {
            await formService.fetchSpecialities(facultyId: facultyId)
        } else if let facultyId = selectedFacultyId,
                  let specialityId = selectedSpecialityId,
                  selectedCourse == nil {
            await formService.fetchCourses(facultyId: facultyId, specialityId: specialityId)
        } else {
            await refreshCurrentSelection()
        }
    }
}

private enum DisciplinePlan: String, CaseIterable, Identifiable {
    case standard
    case foreign

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            return "Обычный"
        case .foreign:
            return "Иностранный"
        }
    }
}

private struct DisciplineRow: View {
    let discipline: DisciplineListEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(discipline.name)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 12)

            if let hours = discipline.hours {
                Text("\(hours) ч")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct DisciplineLoadingRow: View {
    let title: String

    var body: some View {
        HStack {
            Spacer()
            ProgressView(title)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
