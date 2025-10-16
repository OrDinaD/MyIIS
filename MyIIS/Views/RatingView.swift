import SwiftUI

struct RatingView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @StateObject private var viewModel: RatingViewModel

    init(viewModel: RatingViewModel = RatingViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: Color.gradientBackground,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                content
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
            }
            .navigationTitle("Рейтинг")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let user = authService.currentUser {
            ScrollView {
                VStack(spacing: 20) {
                    header(for: user)

                    if let error = viewModel.errorMessage, !viewModel.students.isEmpty {
                        RatingInfoBanner(
                            title: "Не удалось обновить данные",
                            message: error,
                            icon: "exclamationmark.triangle.fill"
                        )
                    }

                    if let summary = viewModel.summary {
                        RatingSummaryCard(summary: summary, checkpointNumbers: viewModel.checkpointNumbers)
                    }

                    ratingStateView(group: user.education.group)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .task(id: user.education.group) {
                await viewModel.loadRating(forGroup: user.education.group)
            }
            .refreshable {
                await viewModel.refresh(forGroup: user.education.group)
            }
        } else {
            GlassCard {
                VStack(spacing: 12) {
                    Image(systemName: "person.text.rectangle")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text("Чтобы увидеть рейтинг, выполните вход")
                        .font(.headline)
                    Text("Авторизуйтесь в аккаунте, после чего данные группы будут загружены автоматически.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
            }
        }
    }

    private func header(for user: User) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(LinearGradient.glassOverlay)
                            }
                            .frame(width: 56, height: 56)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(LinearGradient.glassBorder, lineWidth: 1.5)
                            }

                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(LinearGradient.iconGradient(.accentPurple))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Рейтинг по контрольным точкам")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text("Группа \(user.education.group) · \(user.education.speciality) · \(user.education.faculty)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                Divider()
                    .opacity(0.5)

                HStack(spacing: 16) {
                    RatingHeaderMetric(
                        title: "Средний балл",
                        value: formattedGrade(viewModel.summary?.averageGrade)
                    )
                    RatingHeaderMetric(
                        title: "Пропущено часов",
                        value: formattedMissed(viewModel.summary?.totalMissedHours)
                    )
                    RatingHeaderMetric(
                        title: "Средний сдвиг",
                        value: formattedShift(viewModel.summary?.averageShift)
                    )
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func ratingStateView(group: String) -> some View {
        if viewModel.isLoading && viewModel.students.isEmpty {
            GlassCard {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Загружаем рейтинг группы \(group)...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(32)
            }
        } else if let error = viewModel.errorMessage, viewModel.students.isEmpty {
            GlassCard {
                VStack(spacing: 16) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.statusWarning)
                    VStack(spacing: 6) {
                        Text("Не удалось загрузить данные")
                            .font(.headline)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task {
                            await viewModel.refresh(forGroup: group)
                        }
                    } label: {
                        Text("Повторить")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background {
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: Color.buttonGradient,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(28)
            }
        } else if viewModel.students.isEmpty {
            GlassCard {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.and.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Данных о рейтинге пока нет")
                        .font(.headline)
                    Text("Попробуйте обновить экран чуть позже или уточните информацию у учебной части.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
            }
        } else {
            RatingTableView(
                students: viewModel.students,
                checkpointNumbers: viewModel.checkpointNumbers,
                summary: viewModel.summary
            )
        }
    }

    private func formattedGrade(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.precision(.fractionLength(2)))
    }

    private func formattedShift(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.precision(.fractionLength(2)))
    }

    private func formattedMissed(_ value: Int?) -> String {
        guard let value else { return "—" }
        return "\(value)"
    }
}

// MARK: - Header Metric View

private struct RatingHeaderMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Summary Card

private struct RatingSummaryCard: View {
    let summary: RatingSummary
    let checkpointNumbers: [Int]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 20) {
                Text("Сводка группы")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    SummaryMetric(icon: "person.3.fill", title: "Студентов", value: "\(summary.studentCount)")
                    SummaryMetric(icon: "star.leadinghalf.filled", title: "Средний балл", value: summary.averageGrade.map { $0.formatted(.number.precision(.fractionLength(2))) } ?? "—")
                    SummaryMetric(icon: "clock.arrow.circlepath", title: "Ср. сдвиг", value: summary.averageShift.map { $0.formatted(.number.precision(.fractionLength(2))) } ?? "—")
                    SummaryMetric(icon: "deskclock", title: "Пропущено часов", value: "\(summary.totalMissedHours)")
                }

                if !checkpointNumbers.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Контрольные точки")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(checkpointNumbers, id: \.self) { number in
                                    let checkpoint = summary.checkpoints.first { $0.number == number }
                                    CheckpointChip(
                                        number: number,
                                        average: checkpoint?.averageGrade,
                                        missed: checkpoint?.totalMissedHours
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

private struct SummaryMetric: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(LinearGradient.iconGradient(.accentPurple))
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.headline)
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CheckpointChip: View {
    let number: Int
    let average: Double?
    let missed: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("КТ \(number)")
                .font(.subheadline)
                .fontWeight(.semibold)
            HStack(spacing: 12) {
                chipMetric(title: "Балл", value: average.map { $0.formatted(.number.precision(.fractionLength(2))) } ?? "—")
                chipMetric(title: "Часы", value: missed.map(String.init) ?? "—")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient.glassOverlay)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(LinearGradient.glassBorder, lineWidth: 1.2)
                }
        }
    }

    private func chipMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Rating Table

private struct RatingTableView: View {
    let students: [StudentRating]
    let checkpointNumbers: [Int]
    let summary: RatingSummary?

    private var columns: [RatingColumn] {
        var base: [RatingColumn] = [
            RatingColumn(content: .position, title: "№", width: 44, alignment: .center),
            RatingColumn(content: .student, title: "Студент", width: 220, alignment: .leading),
            RatingColumn(content: .averageGrade, title: "Средний балл", width: 130, alignment: .center),
            RatingColumn(content: .missedHours, title: "Пропущено часов", width: 150, alignment: .center),
            RatingColumn(content: .averageShift, title: "Ср. сдвиг", width: 120, alignment: .center)
        ]

        for number in checkpointNumbers {
            base.append(contentsOf: [
                RatingColumn(content: .checkpoint(number: number, metric: .grade), title: "КТ \(number)\nБалл", width: 120, alignment: .center),
                RatingColumn(content: .checkpoint(number: number, metric: .missed), title: "КТ \(number)\nЧасы", width: 110, alignment: .center)
            ])
        }

        return base
    }

    var body: some View {
        GlassCard {
            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                VStack(spacing: 0) {
                    headerRow
                    Divider().opacity(0.4)
                    ForEach(Array(zip(students.indices, students)), id: \.1) { index, student in
                        row(for: student, index: index)
                            .background(index.isMultiple(of: 2) ? Color.accentPurple.opacity(0.05) : Color.clear)
                    }
                    if let summary {
                        Divider().opacity(0.4)
                        summaryRow(summary: summary)
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            ForEach(columns) { column in
                Text(column.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .frame(width: column.width, alignment: column.swiftUIAlignment)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
            }
        }
    }

    private func row(for student: StudentRating, index: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(columns) { column in
                Text(text(for: column, student: student, index: index))
                    .font(column.content == .student ? .subheadline : .footnote)
                    .fontWeight(column.content == .student ? .semibold : .regular)
                    .frame(width: column.width, alignment: column.swiftUIAlignment)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
            }
        }
    }

    private func summaryRow(summary: RatingSummary) -> some View {
        HStack(spacing: 0) {
            ForEach(columns) { column in
                Text(summaryText(for: column, summary: summary))
                    .font(.footnote)
                    .fontWeight(column.content == .student ? .semibold : .regular)
                    .frame(width: column.width, alignment: column.swiftUIAlignment)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                    .background(column.content == .student ? Color.accentPurple.opacity(0.1) : Color.clear)
            }
        }
        .background(Color.accentPurple.opacity(0.08))
    }

    private func text(for column: RatingColumn, student: StudentRating, index: Int) -> String {
        switch column.content {
        case .position:
            return "\(index + 1)"
        case .student:
            if let name = student.studentName, !name.isEmpty {
                return name
            }
            return "Зачётная № \(student.recordBookNumber)"
        case .averageGrade:
            return formatGrade(student.averageGrade)
        case .missedHours:
            return formatMissed(student.missedHours)
        case .averageShift:
            return formatShift(student.averageShift)
        case .checkpoint(let number, let metric):
            let checkpoint = student.checkpoints.first { $0.number == number }
            switch metric {
            case .grade:
                return formatGrade(checkpoint?.averageGrade)
            case .missed:
                return formatMissed(checkpoint?.missedHours)
            }
        }
    }

    private func summaryText(for column: RatingColumn, summary: RatingSummary) -> String {
        switch column.content {
        case .position:
            return "Σ"
        case .student:
            return "Средние значения группы"
        case .averageGrade:
            return formatGrade(summary.averageGrade)
        case .missedHours:
            return "\(summary.totalMissedHours)"
        case .averageShift:
            return formatShift(summary.averageShift)
        case .checkpoint(let number, let metric):
            let checkpoint = summary.checkpoints.first { $0.number == number }
            switch metric {
            case .grade:
                return formatGrade(checkpoint?.averageGrade)
            case .missed:
                return checkpoint.map { "\($0.totalMissedHours)" } ?? "—"
            }
        }
    }

    private func formatGrade(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.precision(.fractionLength(2)))
    }

    private func formatShift(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.precision(.fractionLength(2)))
    }

    private func formatMissed(_ value: Int?) -> String {
        guard let value else { return "—" }
        return "\(value)"
    }
}

// MARK: - Rating Column Definition

private struct RatingColumn: Identifiable, Equatable {
    enum Content: Equatable {
        case position
        case student
        case averageGrade
        case missedHours
        case averageShift
        case checkpoint(number: Int, metric: CheckpointMetric)

        enum CheckpointMetric: Equatable {
            case grade
            case missed
        }
    }

    enum ColumnAlignment {
        case leading
        case center
        case trailing

        var swiftUI: Alignment {
            switch self {
            case .leading:
                return .leading
            case .center:
                return .center
            case .trailing:
                return .trailing
            }
        }
    }

    let content: Content
    let title: String
    let width: CGFloat
    let alignment: ColumnAlignment

    var id: String {
        switch content {
        case .position: return "position"
        case .student: return "student"
        case .averageGrade: return "avg"
        case .missedHours: return "missed"
        case .averageShift: return "shift"
        case .checkpoint(let number, let metric):
            switch metric {
            case .grade:
                return "cp_\(number)_grade"
            case .missed:
                return "cp_\(number)_missed"
            }
        }
    }

    var swiftUIAlignment: Alignment {
        alignment.swiftUI
    }
}

// MARK: - Info Banner

private struct RatingInfoBanner: View {
    let title: String
    let message: String
    let icon: String

    var body: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(Color.statusWarning)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(20)
        }
    }
}

#if DEBUG
struct RatingView_Previews: PreviewProvider {
    static var previews: some View {
        RatingView(viewModel: .preview)
            .environmentObject(AuthenticationService.shared)
            .onAppear {
                AuthenticationService.shared.currentUser = .mock
            }
    }
}
#endif
