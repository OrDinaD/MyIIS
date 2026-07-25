import SwiftUI

struct UnauthorizedRatingView: View {
    @StateObject private var service = GlobalRatingService.shared

    @State private var selectedFacultyId: Int?
    @State private var selectedSpecialityId: Int?
    @State private var selectedCourse: Int?
    @State private var selectedEntry: GlobalRatingEntry?

    var body: some View {
        NavigationStack {
            Form {
                selectionSection
                statusSection
                ratingSummarySection
                ratingEntriesSection
            }
            .navigationTitle("Рейтинг группы")
            .transparentInlineNavigationBar()
            .task {
                if service.faculties.isEmpty {
                    await service.fetchFaculties()
                }
            }
            .refreshable {
                await refreshCurrentSelection()
            }
            .sheet(item: $selectedEntry) { entry in
                StudentGlobalRatingDetailSheet(
                    entry: entry,
                    detail: service.studentDetails[entry.studentCardNumber],
                    isLoading: service.loadingStudentCardNumbers.contains(entry.studentCardNumber),
                    errorMessage: service.studentDetailErrorMessage,
                    retry: {
                        Task { await service.fetchStudentDetail(studentCardNumber: entry.studentCardNumber) }
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .task(id: entry.studentCardNumber) {
                    await service.fetchStudentDetail(studentCardNumber: entry.studentCardNumber)
                }
            }
        }
    }

    private var selectedFaculty: FacultyDto? {
        service.faculties.first { $0.id == selectedFacultyId }
    }

    private var selectedSpeciality: SpecialityDto? {
        service.specialities.first { $0.id == selectedSpecialityId }
    }

    private var selectedCourseInfo: RatingCourseDto? {
        service.courses.first { $0.course == selectedCourse }
    }

    @ViewBuilder
    private var selectionSection: some View {
        Section("Выбор") {
            if service.isLoadingFaculties && service.faculties.isEmpty {
                LoadingRow(title: "Загрузка факультетов...")
            } else {
                Picker("Факультет", selection: $selectedFacultyId) {
                    Text("Не выбран").tag(nil as Int?)
                    ForEach(service.faculties) { faculty in
                        Text(faculty.text).tag(Optional(faculty.id))
                    }
                }
                .pickerStyle(.navigationLink)
                .onChange(of: selectedFacultyId) { _, newValue in
                    selectedSpecialityId = nil
                    selectedCourse = nil
                    selectedEntry = nil

                    guard let facultyId = newValue else {
                        service.resetAfterFacultyClear()
                        return
                    }

                    Task { await service.fetchSpecialities(facultyId: facultyId) }
                }
            }

            if selectedFacultyId != nil {
                if service.isLoadingSpecialities {
                    LoadingRow(title: "Загрузка специальностей...")
                } else {
                    Picker("Специальность", selection: $selectedSpecialityId) {
                        Text("Не выбрана").tag(nil as Int?)
                        ForEach(service.specialities) { speciality in
                            Text(speciality.text).tag(Optional(speciality.id))
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .disabled(service.specialities.isEmpty)
                    .onChange(of: selectedSpecialityId) { _, newValue in
                        selectedCourse = nil
                        selectedEntry = nil

                        guard let facultyId = selectedFacultyId, let specialityId = newValue else {
                            service.resetAfterSpecialityClear()
                            return
                        }

                        Task { await service.fetchCourses(facultyId: facultyId, specialityId: specialityId) }
                    }
                }
            }

            if selectedSpecialityId != nil {
                if service.isLoadingCourses {
                    LoadingRow(title: "Загрузка курсов...")
                } else {
                    Picker("Курс", selection: $selectedCourse) {
                        Text("Не выбран").tag(nil as Int?)
                        ForEach(service.courses) { course in
                            Text(course.title).tag(Optional(course.course))
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .disabled(service.courses.isEmpty)
                    .onChange(of: selectedCourse) { _, newValue in
                        selectedEntry = nil

                        guard let specialityId = selectedSpecialityId, let course = newValue else {
                            service.resetRating()
                            return
                        }

                        Task { await service.fetchRating(sdefId: specialityId, course: course) }
                    }

                    if let selectedCourseInfo, selectedCourseInfo.hasForeignPlan {
                        Label("Для курса доступен иностранный учебный план", systemImage: "globe.europe.africa.fill")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if let errorMessage = service.errorMessage {
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
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            }
        } else if selectedFacultyId == nil && !service.isLoadingFaculties {
            Section {
                ContentUnavailableView {
                    Label("Выберите факультет", systemImage: "building.columns.fill")
                } description: {
                    Text("После выбора факультета появятся специальности, курсы и общий рейтинг группы.")
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            }
        } else if selectedFacultyId != nil,
                  selectedSpecialityId == nil,
                  !service.isLoadingSpecialities,
                  service.specialities.isEmpty {
            Section {
                ContentUnavailableView(
                    "Нет специальностей",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Для выбранного факультета IIS не вернул список специальностей.")
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            }
        } else if selectedSpecialityId != nil,
                  selectedCourse == nil,
                  !service.isLoadingCourses,
                  service.courses.isEmpty {
            Section {
                ContentUnavailableView(
                    "Нет курсов",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("Для выбранной специальности IIS не вернул доступные курсы.")
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private var ratingSummarySection: some View {
        if selectedCourse != nil, !service.ratingEntries.isEmpty {
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
                LabeledContent("Студентов", value: "\(service.ratingEntries.count)")
                LabeledContent("Средний балл группы", value: formattedGrade(groupAverage))
                LabeledContent("Пропусков всего", value: "\(groupMissedHours) ч")
            }
        }
    }

    @ViewBuilder
    private var ratingEntriesSection: some View {
        if selectedCourse != nil {
            Section("Студенты") {
                if service.isLoadingRating {
                    LoadingRow(title: "Загрузка рейтинга...")
                } else if service.ratingEntries.isEmpty, service.errorMessage == nil {
                    ContentUnavailableView("Нет данных", systemImage: "chart.bar.doc.horizontal", description: Text("IIS не вернул студентов для выбранного курса."))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(service.ratingEntries.enumerated()), id: \.element.id) { index, entry in
                        Button {
                            selectedEntry = entry
                        } label: {
                            GlobalRatingEntryRow(entry: entry, position: index + 1)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Открыть детали рейтинга студента")
                    }
                }
            }
        }
    }

    private var groupAverage: Double? {
        let values = service.ratingEntries.compactMap(\.average)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private var groupMissedHours: Int {
        service.ratingEntries.compactMap(\.hours).reduce(0, +)
    }

    private func refreshCurrentSelection() async {
        if service.faculties.isEmpty {
            await service.fetchFaculties()
        }

        guard let facultyId = selectedFacultyId else { return }

        if selectedSpecialityId == nil {
            await service.fetchSpecialities(facultyId: facultyId)
            return
        }

        guard let specialityId = selectedSpecialityId else { return }

        if selectedCourse == nil {
            await service.fetchCourses(facultyId: facultyId, specialityId: specialityId)
            return
        }

        if let course = selectedCourse {
            await service.fetchRating(sdefId: specialityId, course: course)
        }
    }

    private func retryCurrentStep() async {
        if selectedFacultyId == nil {
            await service.fetchFaculties()
        } else {
            await refreshCurrentSelection()
        }
    }
}

private struct GlobalRatingEntryRow: View {
    let entry: GlobalRatingEntry
    let position: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(position)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 30, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text("Студ. билет \(entry.studentCardNumber)")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                HStack(spacing: 8) {
                    if let hours = entry.hours {
                        RatingPill(title: "\(hours) ч", systemImage: "clock.badge.exclamationmark", tint: missedTint(hours))
                    }

                    if let averageShift = entry.averageShift {
                        RatingPill(title: formattedShift(averageShift), systemImage: shiftIcon(averageShift), tint: shiftTint(averageShift))
                    }
                }

                CheckpointLine(entry: entry)
            }

            Spacer(minLength: 8)

            Text(formattedGrade(entry.average))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(gradeTint(entry.average))
                .monospacedDigit()
                .frame(minWidth: 54, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func missedTint(_ hours: Int) -> Color {
        if hours == 0 { return .green }
        if hours <= 4 { return .orange }
        return .red
    }
}

private struct CheckpointLine: View {
    let entry: GlobalRatingEntry

    private var checkpoints: [CheckpointSnapshot] {
        [
            CheckpointSnapshot(title: "КТ1", average: entry.firstAverage, hours: entry.firstHours),
            CheckpointSnapshot(title: "КТ2", average: entry.secondAverage, hours: entry.secondHours),
            CheckpointSnapshot(title: "КТ3", average: entry.thirdAverage, hours: entry.thirdHours)
        ].filter { $0.average != nil || $0.hours != nil }
    }

    var body: some View {
        if !checkpoints.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) { checkpointContent }
                VStack(alignment: .leading, spacing: 6) { checkpointContent }
            }
            .font(.caption)
        }
    }

    @ViewBuilder
    private var checkpointContent: some View {
        ForEach(checkpoints) { checkpoint in
            Text("\(checkpoint.title): \(formattedGrade(checkpoint.average)) · \(checkpoint.hours ?? 0) ч")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

private struct CheckpointSnapshot: Identifiable {
    let title: String
    let average: Double?
    let hours: Int?
    var id: String { title }
}

private struct RatingPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .labelStyle(.titleAndIcon)
    }
}

private struct LoadingRow: View {
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

private struct StudentGlobalRatingDetailSheet: View {
    let entry: GlobalRatingEntry
    let detail: StudentGlobalRatingDetail?
    let isLoading: Bool
    let errorMessage: String?
    let retry: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Студент") {
                    LabeledContent("Студ. билет", value: entry.studentCardNumber)
                    LabeledContent("Средний балл", value: formattedGrade(entry.average))
                    LabeledContent("Пропуски", value: "\(entry.hours ?? 0) ч")
                    LabeledContent("Динамика", value: formattedShift(entry.averageShift ?? 0))

                    if let detail {
                        if let displayName = detail.displayName {
                            LabeledContent("ФИО", value: displayName)
                        }
                        LabeledContent("Подгруппа", value: formattedSubgroup(detail.subGroupStudent ?? detail.subGroup))
                        LabeledContent("Занятий", value: "\(detail.lessons.count)")
                        LabeledContent("Предметов", value: "\(detail.subjectCount)")
                        LabeledContent("Оценок", value: "\(detail.marks.count)")
                    }
                }

                if isLoading && detail == nil {
                    Section {
                        LoadingRow(title: "Загрузка деталей...")
                    }
                } else if let errorMessage, detail == nil {
                    Section {
                        ContentUnavailableView {
                            Label("Не удалось загрузить", systemImage: "exclamationmark.triangle.fill")
                        } description: {
                            Text(errorMessage)
                        } actions: {
                            Button("Повторить", action: retry)
                                .buttonStyle(.borderedProminent)
                        }
                    }
                } else if let detail {
                    Section("Контрольные точки") {
                        ForEach(makeCheckpointSummaries(from: detail.lessons)) { checkpoint in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(checkpoint.title)
                                        .font(.body.weight(.medium))
                                    Text("\(checkpoint.lessonCount) занятий · \(checkpoint.markCount) оценок")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(formattedGrade(checkpoint.average))
                                    .font(.system(.body, design: .rounded).weight(.semibold))
                                    .foregroundStyle(gradeTint(checkpoint.average))
                                    .monospacedDigit()
                            }
                        }
                    }

                    Section("Предметы") {
                        ForEach(makeSubjectSummaries(from: detail.lessons)) { subject in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(subject.title)
                                        .font(.body.weight(.semibold))
                                        .lineLimit(2)
                                    Spacer()
                                    Text(formattedGrade(subject.average))
                                        .font(.system(.body, design: .rounded).weight(.bold))
                                        .foregroundStyle(gradeTint(subject.average))
                                        .monospacedDigit()
                                }

                                HStack(spacing: 10) {
                                    Text("\(subject.lessonCount) занятий")
                                    Text("\(subject.markCount) оценок")
                                    Text("\(subject.omissionHours) ч")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Детали рейтинга")
            .navigationBarTitleDisplayMode(.inline)
            .hiddenNavigationBarBackground()
        }
    }

    private func formattedSubgroup(_ value: Int) -> String {
        value > 0 ? "\(value)" : "Общая"
    }
}

private struct SubjectRatingSummary: Identifiable {
    let title: String
    let lessonCount: Int
    let markCount: Int
    let average: Double?
    let omissionHours: Int
    var id: String { title }
}

private struct CheckpointRatingSummary: Identifiable {
    let title: String
    let lessonCount: Int
    let markCount: Int
    let average: Double?
    var id: String { title }
}

private func makeSubjectSummaries(from lessons: [PortalGradeBookLesson]) -> [SubjectRatingSummary] {
    Dictionary(grouping: lessons) { $0.lessonNameAbbrev }
        .map { subject, subjectLessons in
            let marks = subjectLessons.flatMap(\.marks)
            let omissions = subjectLessons
                .filter { !$0.isRespectfulOmission }
                .reduce(0) { $0 + max($1.gradeBookOmissions, 0) }

            return SubjectRatingSummary(
                title: subject.isEmpty ? "Без названия" : subject,
                lessonCount: subjectLessons.count,
                markCount: marks.count,
                average: average(of: marks),
                omissionHours: omissions
            )
        }
        .sorted { lhs, rhs in
            if (lhs.average ?? -1) != (rhs.average ?? -1) {
                return (lhs.average ?? -1) > (rhs.average ?? -1)
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
}

private func makeCheckpointSummaries(from lessons: [PortalGradeBookLesson]) -> [CheckpointRatingSummary] {
    Dictionary(grouping: lessons) { $0.controlPoint.isEmpty ? "Вне КТ" : $0.controlPoint }
        .map { title, checkpointLessons in
            let marks = checkpointLessons.flatMap(\.marks)
            return CheckpointRatingSummary(
                title: title,
                lessonCount: checkpointLessons.count,
                markCount: marks.count,
                average: average(of: marks)
            )
        }
        .sorted { lhs, rhs in
            checkpointSortKey(lhs.title) < checkpointSortKey(rhs.title)
        }
}

private func checkpointSortKey(_ title: String) -> String { title == "Вне КТ" ? "9999" : title }

private func average(of marks: [Int]) -> Double? {
    guard !marks.isEmpty else { return nil }
    return Double(marks.reduce(0, +)) / Double(marks.count)
}

private func formattedGrade(_ value: Double?) -> String {
    guard let value else { return "—" }
    return value.formatted(.number.precision(.fractionLength(2)))
}

private func formattedShift(_ value: Double) -> String {
    if abs(value) < 0.005 { return "0.00" }
    let sign = value > 0 ? "+" : ""
    return sign + value.formatted(.number.precision(.fractionLength(2)))
}

private func gradeTint(_ value: Double?) -> Color {
    guard let value else { return .secondary }
    switch value {
    case 9...:
        return .green
    case 7 ..< 9:
        return .mint
    case 5 ..< 7:
        return .orange
    default:
        return .red
    }
}

private func shiftTint(_ value: Double) -> Color {
    if value < -0.005 { return .green }
    if value > 0.005 { return .red }
    return .secondary
}

private func shiftIcon(_ value: Double) -> String {
    if value < -0.005 { return "arrow.down.right" }
    if value > 0.005 { return "arrow.up.right" }
    return "minus"
}
