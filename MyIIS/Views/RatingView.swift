import StoreKit
import SwiftUI

struct RatingView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.requestReview) private var requestReview
    @State var viewModel: RatingViewModel
    @State private var expandedDisciplineIDs: Set<String> = []
    @State private var hasRevealedContent = false
    @AppStorage("rating_view_open_count") private var ratingViewOpenCount = 0

    @MainActor
    init() {
        _viewModel = State(initialValue: RatingViewModel())
    }

    @MainActor
    init(viewModel: RatingViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var ratingAnimation: Animation? {
        accessibilityReduceMotion ? nil : .snappy(duration: 0.28)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(NSLocalizedString("rating_title", comment: ""))
                .navigationBarTitleDisplayMode(.large)
                .hiddenNavigationBarBackground()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let user = authService.currentUser {
            List {
                Section {
                    header(for: user)
                }

                if viewModel.isShowingStaleDataWarning {
                    Section {
                        StaleDataBanner(lastUpdateTime: viewModel.lastUpdateTime, errorMessage: viewModel.errorMessage) {
                            await viewModel.refresh(for: user)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                ratingStateView(user: user)
            }
            .listStyle(.insetGrouped)
            .task(id: user.id) {
                revealContentIfNeeded()
                await viewModel.loadRating(for: user)

                ratingViewOpenCount += 1
                if ratingViewOpenCount == 5 || (ratingViewOpenCount > 5 && ratingViewOpenCount % 20 == 0) {
                    try? await Task.sleep(for: .seconds(2))
                    requestReview()
                }
            }
            .refreshable {
                await viewModel.refresh(for: user)
            }
        } else {
            ContentUnavailableView {
                Label(NSLocalizedString("rating_auth_required", comment: ""), systemImage: "person.crop.circle.badge.exclamationmark")
            } description: {
                Text(NSLocalizedString("rating_auth_description", comment: ""))
            }
        }
    }

    @MainActor
    private func revealContentIfNeeded() {
        guard !hasRevealedContent else { return }

        if accessibilityReduceMotion {
            hasRevealedContent = true
        } else {
            withAnimation(.smooth(duration: 0.35)) {
                hasRevealedContent = true
            }
        }
    }

    private func header(for user: User) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("rating_my_rating", comment: ""))
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(String(format: NSLocalizedString("rating_group", comment: ""), user.education.group))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if viewModel.isLoadingSubjects {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) {
                        ratingHeaderMetrics
                    }
                } else {
                    HStack(spacing: 10) {
                        ratingHeaderMetrics
                    }
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(hasRevealedContent ? 1 : 0)
        .offset(y: hasRevealedContent || accessibilityReduceMotion ? 0 : 8)
    }

    @ViewBuilder
    private var ratingHeaderMetrics: some View {
        RatingHeaderMetric(
            title: NSLocalizedString("rating_average_grade", comment: ""),
            value: formattedGrade(viewModel.gradebookAverage ?? viewModel.students.first?.averageGrade),
            systemImage: "chart.line.uptrend.xyaxis",
            tint: gradeTint(viewModel.gradebookAverage ?? viewModel.students.first?.averageGrade)
        )
        RatingHeaderMetric(
            title: NSLocalizedString("rating_missed_hours", comment: ""),
            value: formattedMissed(viewModel.students.first?.missedHours),
            systemImage: "clock.badge.exclamationmark",
            tint: .orange
        )
    }

    @ViewBuilder
    private func ratingStateView(user: User) -> some View {
        if viewModel.isLoading && viewModel.disciplines.isEmpty {
            loadingRatingView
        } else if let error = viewModel.errorMessage,
                  viewModel.disciplines.isEmpty,
                  viewModel.students.isEmpty {
            errorRatingView(error: error, user: user)
        } else if viewModel.disciplines.isEmpty {
            emptyDisciplinesRatingView
        } else {
            disciplinesRatingList
        }
    }

    @ViewBuilder
    private var loadingRatingView: some View {
        Section {
            HStack {
                Spacer()
                ProgressView(NSLocalizedString("rating_loading_subjects", comment: ""))
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func errorRatingView(error: String, user: User) -> some View {
        Section {
            VStack(spacing: 12) {
                Text(NSLocalizedString("error_data_load_failed", comment: ""))
                    .font(.headline)
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button(NSLocalizedString("common_retry", comment: "")) {
                    Task {
                        await viewModel.refresh(for: user)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var emptyDisciplinesRatingView: some View {
        Section {
            Group {
                if viewModel.isRatingPendingForNewSemester {
                    ContentUnavailableView(
                        NSLocalizedString("rating_semester_completed_title", comment: ""),
                        systemImage: "sun.max.fill",
                        description: Text(NSLocalizedString("rating_semester_completed_desc", comment: ""))
                    )
                } else if viewModel.isGradebookUnavailable {
                    ContentUnavailableView(
                        NSLocalizedString("rating_disciplines_unavailable_title", comment: ""),
                        systemImage: "book.closed",
                        description: Text(NSLocalizedString("rating_disciplines_unavailable_desc", comment: ""))
                    )
                } else {
                    ContentUnavailableView(
                        NSLocalizedString("rating_disciplines_not_found_title", comment: ""),
                        systemImage: "list.bullet.rectangle",
                        description: Text(NSLocalizedString("rating_disciplines_not_found_desc", comment: ""))
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var disciplinesRatingList: some View {
        if !viewModel.deadlineItems.isEmpty {
            deadlinesSection
        }

        Section(NSLocalizedString("rating_section_subjects", comment: "")) {
            if viewModel.isUsingScheduleFallback {
                RatingInfoBanner(
                    title: NSLocalizedString("rating_fallback_banner_title", comment: ""),
                    message: NSLocalizedString("rating_fallback_banner_message", comment: ""),
                    icon: "exclamationmark.triangle.fill"
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            ForEach(viewModel.disciplines) { discipline in
                disciplineRatingRow(discipline: discipline)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }

        checkpointsRatingSection
    }

    @ViewBuilder
    private func disciplineRatingRow(discipline: GradebookDiscipline) -> some View {
        let hasAttempts = !discipline.sortedAttempts.isEmpty
        let hasOmissions = !(discipline.lessonOmissions ?? []).isEmpty

        if !hasAttempts && !hasOmissions {
            disciplineLabelContent(for: discipline)
                .padding(.vertical, 8)
        } else {
            DisclosureGroup(isExpanded: disciplineExpansionBinding(for: discipline)) {
                disciplineAttemptsContent(for: discipline)
            } label: {
                disciplineLabelContent(for: discipline)
            }
            .accessibilityIdentifier("ratingDiscipline_\(discipline.code)")
            .padding(.vertical, 8)
        }
    }

    private func disciplineExpansionBinding(for discipline: GradebookDiscipline) -> Binding<Bool> {
        Binding(
            get: { expandedDisciplineIDs.contains(discipline.id) },
            set: { isExpanded in
                let updateExpansion = {
                    if isExpanded {
                        expandedDisciplineIDs.insert(discipline.id)
                    } else {
                        expandedDisciplineIDs.remove(discipline.id)
                    }
                }

                if accessibilityReduceMotion {
                    updateExpansion()
                } else {
                    withAnimation(.snappy(duration: 0.24)) {
                        updateExpansion()
                    }
                }
            }
        )
    }

    @ViewBuilder
    private func disciplineAttemptsContent(for discipline: GradebookDiscipline) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            let hasOmissions = discipline.lessonOmissions?.isEmpty == false
            let hasAttempts = !discipline.sortedAttempts.isEmpty

            if !hasOmissions && !hasAttempts {
                Text("—")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                if let omissions = discipline.lessonOmissions {
                    ForEach(omissions) { omission in
                        HStack(alignment: .center, spacing: 8) {
                            Text(attemptTypeTitle(omission.type))
                                .font(.subheadline.weight(.medium))
                            Text("\(omission.hours) ч")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.orange)
                            Spacer()
                            Text(formattedAttemptDate(omission.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }

                ForEach(discipline.sortedAttempts) { attempt in
                    HStack(alignment: .center, spacing: 8) {
                        Text(attemptTypeTitle(attempt.type))
                            .font(.subheadline.weight(.medium))
                        Text(attempt.grade.displayValue)
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                        Spacer()
                        Text(formattedAttemptDate(attempt.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func disciplineLabelContent(for discipline: GradebookDiscipline) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(discipline.name)
                .font(.body.weight(.semibold))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let average = discipline.averageGradeValue {
                Text(formattedGrade(average))
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(gradeTint(average))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: average))
                    .frame(minWidth: 64, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
                    .padding(.trailing, 4)
                    .animation(ratingAnimation, value: average)
            } else {
                Text("—")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 64, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
                    .padding(.trailing, 4)
            }
        }
    }

}

private struct RatingHeaderMetric: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    private var numericValue: Double? {
        Double(value.replacingOccurrences(of: ",", with: "."))
    }

    private var metricAnimation: Animation? {
        accessibilityReduceMotion ? nil : .snappy(duration: 0.25)
    }

    private var valueTransition: ContentTransition {
        numericValue.map { .numericText(value: $0) } ?? .opacity
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .monospacedDigit()
                .contentTransition(valueTransition)
                .foregroundStyle(.primary)
                .animation(metricAnimation, value: value)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 102)
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        }
        .accessibilityTextPair(label: title, value: value)
    }
}

private struct RatingInfoBanner: View {
    let title: String
    let message: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct RatingDisciplineDetailsView: View {
    let discipline: GradebookDiscipline
    let checkpoints: [RatingCheckpoint]
    let totalMissedHours: Int?

    private var marksDistribution: [(String, Int)] {
        let grouped = Dictionary(grouping: discipline.attempts) { $0.grade.displayValue }
        return grouped.map { ($0.key, $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0 < rhs.0
            }
    }

    var body: some View {
        List {
            Section("Предмет") {
                LabeledContent("Название", value: discipline.name)
                LabeledContent("Форма контроля", value: discipline.controlForm)
                if let teacher = discipline.teacher, !teacher.isEmpty {
                    LabeledContent("Преподаватель", value: teacher)
                }
                if let hours = discipline.hours {
                    LabeledContent("Часы по дисциплине", value: "\(hours)")
                }
                LabeledContent("Лучшая оценка", value: discipline.bestGradeText)
                LabeledContent("Попыток", value: "\(discipline.attempts.count)")
            }

            Section("Оценки по типам") {
                if marksDistribution.isEmpty {
                    Text("Нет оценок")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(marksDistribution, id: \.0) { item in
                        LabeledContent(item.0, value: "\(item.1)")
                    }
                }
            }

            Section("Попытки") {
                if discipline.sortedAttempts.isEmpty {
                    Text("Попытки не найдены")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(discipline.sortedAttempts) { attempt in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Попытка \(attempt.attempt): \(attempt.grade.displayValue)")
                                .font(.body)
                            Text("Тип: \(attempt.type)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            if let date = attempt.date, !date.isEmpty {
                                Text("Дата: \(RatingDateTextFormatter.format(date))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                if checkpoints.isEmpty {
                    Text("API не вернуло данные КТ")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(checkpoints) { checkpoint in
                        HStack {
                            if let title = checkpoint.title, !title.isEmpty {
                                Text(title)
                            } else {
                                Text("КТ \(checkpoint.number)")
                            }
                            Spacer()
                            Text("\(checkpoint.averageGrade.map { $0.formatted(.number.precision(.fractionLength(2))) } ?? "—")")
                                .foregroundStyle(.secondary)
                            Text("\(checkpoint.missedHours.map(String.init) ?? "—") ч")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                LabeledContent("Всего пропущено часов", value: totalMissedHours.map(String.init) ?? "—")
            } header: {
                Text("КТ и пропуски")
            } footer: {
                Text(
                    "КТ и пропуски в текущем API доступны как агрегированные показатели пользователя, "
                        + "без привязки к конкретной дисциплине."
                )
            }
        }
        .navigationTitle(discipline.name)
        .navigationBarTitleDisplayMode(.large)
        .hiddenNavigationBarBackground()
    }
}

#if DEBUG
struct RatingView_Previews: PreviewProvider {
    static var previews: some View {
        RatingView(viewModel: RatingViewModel.preview)
            .environmentObject(AuthenticationService.shared)
            .onAppear {
                AuthenticationService.shared.currentUser = .mock
            }
    }
}
#endif
