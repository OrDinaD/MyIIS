import SwiftUI

enum ScheduleComparisonCopy {
    static func text(_ key: String) -> String {
        NSLocalizedString(key, tableName: "ScheduleComparison", comment: "")
    }
}

@MainActor
struct ScheduleComparisonView: View {
    let source: ScheduleServiceViewModel
    @State private var model: ScheduleComparisonViewModel
    @State private var pickerSide: Int?
    @State private var showsCalendar = false
    @State private var selectedLesson: DisciplineSchedule?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var cellHeight = 112

    init(source: ScheduleServiceViewModel) {
        self.source = source
        let isGroup = source.mode == .group && source.dataSource == .api
        let comparison = ScheduleComparisonViewModel(
            group: isGroup ? (source.schedule?.group?.name ?? source.accountGroupName) : source.accountGroupName,
            schedule: isGroup ? source.schedule : nil,
            subgroup: isGroup ? source.subgroupFilter : .all
        )
        comparison.groups = source.groups
        _model = State(initialValue: comparison)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                dateNavigation.padding(.horizontal, 12).padding(.bottom, 12)
                GeometryReader { geometry in
                    let width = dynamicTypeSize.isAccessibilitySize
                        ? max(geometry.size.width, 600) : geometry.size.width
                    let columnWidth = max(0, (width - 33) / 2)
                    ScrollView(dynamicTypeSize.isAccessibilitySize ? [.horizontal, .vertical] : [.vertical]) {
                        VStack(spacing: 8) {
                            HStack(spacing: 0) {
                                groupControl(0).frame(width: columnWidth)
                                Divider()
                                groupControl(1).frame(width: columnWidth)
                            }
                            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                            if model.rows.isEmpty {
                                HStack(alignment: .top, spacing: 12) {
                                    emptyDay(0)
                                    emptyDay(1)
                                }
                                .padding(.vertical, 32)
                            } else {
                                ForEach(model.rows) { row in
                                    ForEach(row.sharedLessons) { lesson in
                                        lessonButton(lesson, shared: true)
                                            .frame(height: cellHeight + 16)
                                            .background(
                                                Color(uiColor: .secondarySystemGroupedBackground),
                                                in: RoundedRectangle(cornerRadius: 14)
                                            )
                                    }
                                    if row.lessons.contains(where: { !$0.isEmpty }) {
                                    ScheduleComparisonGridRow {
                                        rowCell(row, side: 0).frame(width: columnWidth)
                                    } right: {
                                        rowCell(row, side: 1).frame(width: columnWidth)
                                    }
                                    .frame(height: cellHeight * CGFloat(row.capacity) + 8 * CGFloat(row.capacity - 1))
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }
                        }

                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                        .frame(width: width)
                    }
                    .id(model.startDate)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(ScheduleComparisonCopy.text("title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("common_done", value: "Готово", comment: "")) { dismiss() }
                }
            }
            .sheet(item: $selectedLesson) { lesson in
                ScheduleLessonDetailSheet(
                    lesson: lesson,
                    onTeacherScheduleTap: { teacher in
                        selectedLesson = nil
                        dismiss()
                        Task { await source.openTeacherSchedule(teacher) }
                    },
                    onGroupTap: { group in
                        selectedLesson = nil
                        Task { await model.select(group, side: 1) }
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
            }
            .sheet(isPresented: $showsCalendar) { calendarSheet }
            .sheet(isPresented: Binding(
                get: { pickerSide != nil },
                set: { if !$0 { pickerSide = nil } }
            )) {
                if let side = pickerSide {
                    ScheduleComparisonGroupPicker(source: source, model: model) { group in
                        pickerSide = nil
                        Task { await model.select(group.name, side: side) }
                    }
                }
            }
            .task {
                if model.schedules[0] == nil { await model.load(0) }
                await model.rebuild()
            }
            .task(id: "\(model.startDate.timeIntervalSince1970)|\(model.subgroups)") {
                await model.rebuild()
            }
        }
    }

    private var dateNavigation: some View {
        HStack(spacing: 8) {
            Button { shift(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }
            .accessibilityLabel(ScheduleComparisonCopy.text("previous_day"))
            Button { showsCalendar = true } label: {
                Text("\(model.startDate.formatted(.dateTime.day().month(.wide))) (\(model.startDate.formatted(.dateTime.weekday(.abbreviated)).capitalized))")
                    .font(.headline)
                    .accessibilityLabel(model.startDate.formatted(.dateTime.day().month(.wide).weekday(.wide)))
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(ScheduleComparisonCopy.text("choose_date"))
            Button { shift(1) } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
            }
            .accessibilityLabel(ScheduleComparisonCopy.text("next_day"))
        }
    }

    private var calendarSheet: some View {
        NavigationStack {
            DatePicker(
                ScheduleComparisonCopy.text("date"), selection: $model.startDate,
                in: dateRange, displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle(ScheduleComparisonCopy.text("choose_date"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(ScheduleComparisonCopy.text("today")) {
                        model.startDate = Calendar.current.startOfDay(for: Date())
                        showsCalendar = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("common_done", value: "Готово", comment: "")) { showsCalendar = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var dateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        return (calendar.date(byAdding: .year, value: -1, to: now) ?? now)
            ... (calendar.date(byAdding: .year, value: 1, to: now) ?? now)
    }

    private func shift(_ count: Int) {
        guard let date = Calendar.current.date(byAdding: .day, value: count, to: model.startDate),
              dateRange.contains(date) else { return }
        model.startDate = date
    }

    private func groupTitle(_ side: Int) -> String {
        let subgroup = model.subgroups[side]
        let suffix = subgroup == 0 ? ScheduleComparisonCopy.text("all_subgroups") : String(subgroup)
        return "\(model.groupNames[side]) (\(suffix))"
    }

    private func groupControl(_ side: Int) -> some View {
        VStack(spacing: 4) {
            Menu {
                Button(ScheduleComparisonCopy.text("choose_group")) { pickerSide = side }
                if !source.pinnedGroupNames.isEmpty {
                    Divider()
                    ForEach(source.pinnedGroupNames, id: \.self) { group in
                        Button {
                            let subgroup = source.restoredSubgroupFilter(for: group)
                            Task { await model.select(group, side: side, subgroup: subgroup) }
                        } label: {
                            Text(source.pinnedGroupMenuTitle(for: group))
                            Text(source.restoredSubgroupFilter(for: group).localizedTitle)
                            Image(systemName: "pin")
                        }
                    }
                }
                Divider()
                Picker(ScheduleComparisonCopy.text("subgroup"), selection: $model.subgroups[side]) {
                    ForEach(model.subgroupOptions(side), id: \.self) { number in
                        Text(number == 0 ? ScheduleSubgroupFilter.all.localizedTitle
                             : ScheduleSubgroupFilter.subgroup(number).localizedTitle).tag(number)
                    }
                }
                .disabled(model.schedules[side] == nil)
            } label: {
                VStack(spacing: 5) {
                    HStack(spacing: 5) {
                        Text(model.groupNames[side].isEmpty ? ScheduleComparisonCopy.text("choose_group")
                             : groupTitle(side))
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                    if let alias = source.pinnedGroupAlias(for: model.groupNames[side]) {
                        Text(alias).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 52)
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("comparisonGroup\(side)")
            if model.loading[side] {
                ProgressView().accessibilityLabel(NSLocalizedString("common_loading", comment: ""))
            } else if let error = model.errors[side] {
                Text(error).font(.caption).foregroundStyle(.secondary)
                Button(ScheduleComparisonCopy.text("retry")) {
                    Task { await model.load(side, force: true) }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func emptyDay(_ side: Int) -> some View {
        let day = model.days[side].first
        return Text(model.groupNames[side].isEmpty ? ScheduleComparisonCopy.text("choose_group")
                    : day?.unavailable != false ? ScheduleComparisonCopy.text("unavailable")
                    : ScheduleComparisonCopy.text("no_lessons"))
            .font(.subheadline).foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private func lessonButton(_ lesson: DisciplineSchedule, shared: Bool = false) -> some View {
        Button { selectedLesson = lesson } label: {
            ScheduleComparisonLessonCell(lesson: lesson, isShared: shared)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(NSLocalizedString("schedule_card_details_hint", comment: ""))
    }

    private func rowCell(_ row: ScheduleComparisonRow, side: Int) -> some View {
        VStack(spacing: 8) {
            if row.lessons[side].isEmpty {
                ScheduleComparisonGapCell(
                    start: row.startTime, end: row.endTime,
                    title: model.groupNames[side].isEmpty ? ScheduleComparisonCopy.text("choose_group")
                        : model.days[side].first?.unavailable != false ? ScheduleComparisonCopy.text("unavailable")
                        : ScheduleComparisonCopy.text("gap")
                )
            } else {
                ForEach(0..<row.capacity, id: \.self) { index in
                    if row.lessons[side].indices.contains(index) {
                        lessonButton(row.lessons[side][index])
                            .frame(height: cellHeight)
                    } else {
                        Color.clear.frame(height: cellHeight).accessibilityHidden(true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ScheduleComparisonGridRow<Left: View, Right: View>: View {
    @ViewBuilder let left: () -> Left
    @ViewBuilder let right: () -> Right

    var body: some View {
        HStack(spacing: 0) {
            left().frame(maxWidth: .infinity)
            Divider()
            right().frame(maxWidth: .infinity)
        }
    }
}

private struct ScheduleComparisonLessonCell: View {
    let lesson: DisciplineSchedule
    var isShared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 6) {
                Text(lesson.startLessonTime)
                    .font(.caption.monospacedDigit().weight(.semibold))
                Spacer(minLength: 0)
                if !lesson.lessonTypeAbbrev.isEmpty {
                    Text(lesson.lessonTypeAbbrev)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(
                            ScheduleColorPreferences.color(for: lesson.lessonTypeAbbrev).opacity(0.18),
                            in: Capsule()
                        )
                }
            }
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(lesson.subject + (lesson.subgroup > 0 ? " (\(lesson.subgroup))" : ""))
                        .font(isShared ? .title3.weight(.semibold) : .subheadline.weight(.semibold))
                        .lineLimit(2)
                    if !lesson.location.isEmpty {
                        Text(lesson.location)
                            .font(isShared ? .subheadline : .caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let teacher = lesson.employees.first {
                    TeacherAvatarView(teacher: teacher, size: isShared ? 44 : 28)
                }
            }
            .frame(maxWidth: isShared ? 280 : .infinity, maxHeight: .infinity, alignment: .center)
            .frame(maxWidth: .infinity)
            Text(lesson.endLessonTime)
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(isShared ? 16 : 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

        .accessibilityElement(children: .combine)
        .accessibilityValue(lesson.employees.map(\.fullName).joined(separator: ", "))
    }
}

private struct ScheduleComparisonGapCell: View {
    let start: String
    let end: String
    var title = ScheduleComparisonCopy.text("gap")

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(start).font(.caption.monospacedDigit())
            Text(title)
                .font(.subheadline)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .multilineTextAlignment(.center)
            Text(end).font(.caption.monospacedDigit())
        }
        .foregroundStyle(Color(uiColor: .tertiaryLabel))
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.07))
        .accessibilityElement(children: .combine)
    }
}

@MainActor
private struct ScheduleComparisonGroupPicker: View {
    let source: ScheduleServiceViewModel
    let model: ScheduleComparisonViewModel
    let onSelect: (StudyGroup) -> Void
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    private var groups: [StudyGroup] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.groups.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)
            || $0.scheduleSearchDetails.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                if model.groups.isEmpty {
                    if model.isDirectoryLoading {
                        ProgressView()
                    } else {
                        Text(model.directoryError ?? ScheduleComparisonCopy.text("directory_empty"))
                        Button(ScheduleComparisonCopy.text("retry")) {
                            Task { await model.loadDirectory(force: true) }
                        }
                    }
                }
                if !model.groups.isEmpty, groups.isEmpty {
                    Text(ScheduleComparisonCopy.text("no_results"))
                }
                ForEach(groups, id: \.name) { group in
                    ScheduleGroupSearchRow(
                        group: group, alias: source.pinnedGroupAlias(for: group.name),
                        isAccountGroup: group.name == source.accountGroupName,
                        isPinned: source.isGroupPinned(group.name),
                        onSelect: { onSelect(group) }
                    )
                }
            }
            .searchable(text: $query, prompt: ScheduleComparisonCopy.text("search"))
            .navigationTitle(ScheduleComparisonCopy.text("choose_group"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common_cancel", value: "Отмена", comment: "")) { dismiss() }
                }
            }
            .task { await model.loadDirectory() }
        }
    }
}

#Preview("Comparison cards") {
    let lesson = DisciplineSchedule(
        id: "comparison-preview", auditories: ["601б-5 к."], endLessonTime: "18:30",
        lessonTypeAbbrev: "ПЗ", note: nil, subgroup: 2, startLessonTime: "17:05",
        studentGroups: [], subject: "СтатМОД", subjectFullName: nil, weekNumbers: [],
        employees: [
            DisciplineEmployee(
                id: -1, firstName: "Анна", middleName: "Ивановна", lastName: "Пример",
                photoLink: nil, degree: nil, degreeAbbrev: nil, rank: nil, email: nil,
                urlId: nil, calendarId: nil, jobPositions: nil, isChief: nil
            )
        ], lessonDate: nil, startLessonDate: nil, endLessonDate: nil,
        isAnnouncement: false, isSplit: false
    )
    VStack(spacing: 16) {
        HStack {
            Image(systemName: "chevron.left").frame(width: 44, height: 44)
            Text("5 октября (Пн)").font(.headline).frame(maxWidth: .infinity)
            Image(systemName: "chevron.right").frame(width: 44, height: 44)
        }
        VStack(spacing: 0) {
            ScheduleComparisonGridRow {
                Text("420603 (2)").font(.subheadline.weight(.semibold))
            } right: {
                Text("420604 (1)").font(.subheadline.weight(.semibold))
            }.frame(height: 52)
            Divider()
            ScheduleComparisonGridRow {
                ScheduleComparisonLessonCell(lesson: lesson)
            } right: {
                ScheduleComparisonGapCell(start: "17:05", end: "18:30")
            }.frame(height: 112)
            Divider()
            ScheduleComparisonGridRow {
                ScheduleComparisonLessonCell(lesson: lesson)
            } right: {
                ScheduleComparisonLessonCell(lesson: lesson)
            }.frame(height: 112)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).strokeBorder(Color(uiColor: .separator), lineWidth: 0.5)
        }
        ScheduleComparisonLessonCell(lesson: lesson, isShared: true)
            .frame(height: 128)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        Spacer()
    }
    .padding(16)
    .background(Color(uiColor: .systemGroupedBackground))
}
