import SwiftUI

@MainActor
struct DiplomaView: View {

    @EnvironmentObject private var authService: AuthenticationService
    @StateObject private var viewModel: DiplomaViewModel

    init(viewModel: DiplomaViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    init() {
        self.init(viewModel: DiplomaViewModel())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(uiColor: .systemBackground),
                        Color(uiColor: .secondarySystemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                content
                    .padding(.horizontal, 20)
            }
            .navigationTitle("Диплом")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            await loadIfNeeded()
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && !viewModel.hasContent {
            ProgressView("Загрузка статуса диплома...")
                .progressViewStyle(.circular)
        } else if let errorMessage = viewModel.errorMessage {
            errorView(message: errorMessage)
        } else if viewModel.hasContent {
            mainContent
                .overlay(alignment: .top) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .padding(.top, 8)
                    }
                }
        } else {
            emptyState
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                summaryCard
                milestonesSection
            }
            .padding(.vertical, 28)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await reload(force: true)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(viewModel.topic)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.leading)

                    statusBadge

                    if let advisor = viewModel.advisorText, !advisor.isEmpty {
                        Label(advisor, systemImage: "person.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                progressRing
            }

            if let updated = viewModel.updatedAtText {
                Label(updated, systemImage: "clock.arrow.circlepath")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: viewModel.completionPercentage, total: 1)
                .progressViewStyle(.linear)
                .tint(.purple)
                .padding(.top, 4)

            if let comment = viewModel.commentText {
                Text(comment)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.purple.opacity(0.08))
                    )
            }

            if let next = viewModel.nextMilestone {
                Divider()
                    .background(Color.white.opacity(0.12))

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(.purple)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Следующий этап")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(next.title)
                            .font(.headline)

                        if let planned = viewModel.plannedDateText(for: next) {
                            Label(planned, systemImage: "calendar")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
            }
        }
        .padding(24)
        .background(cardBackground)
    }

    private var statusBadge: some View {
        let color = statusColor(for: viewModel.progress?.status)
        return Text(viewModel.statusText.uppercased())
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.35), lineWidth: 1)
            )
            .foregroundStyle(color)
            .animation(.easeInOut(duration: 0.25), value: viewModel.statusText)
    }

    private var progressRing: some View {
        let progress = max(0, min(viewModel.completionPercentage, 1))
        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [.purple, .pink, .blue],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 4) {
                Text(viewModel.completionText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("готово")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 94, height: 94)
        .background(
            Circle()
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Этапы диплома")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                if !viewModel.milestones.isEmpty {
                    Text("Всего: \(viewModel.milestones.count)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.milestones.isEmpty {
                Text("Этапы ещё не добавлены. Как только руководитель создаст план, здесь появится таймлайн прогресса.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(cardBackground)
            } else {
                VStack(spacing: 20) {
                    ForEach(viewModel.milestones.indices, id: \.self) { index in
                        timelineRow(
                            for: viewModel.milestones[index],
                            isFirst: index == 0,
                            isLast: index == viewModel.milestones.count - 1
                        )
                    }
                }
            }
        }
    }

    private func timelineRow(for milestone: Milestone, isFirst: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                Circle()
                    .fill(milestoneColor(for: milestone.status))
                    .frame(width: 18, height: 18)
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    }

                if !isLast {
                    Rectangle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 2)
                }
            }
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(milestone.title)
                        .font(.headline)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 8)

                    Text(milestone.status.displayName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(milestoneColor(for: milestone.status).opacity(0.16))
                        )
                        .foregroundStyle(milestoneColor(for: milestone.status))
                }

                if let details = milestone.details, !details.isEmpty {
                    Text(details)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    if let planned = viewModel.plannedDateText(for: milestone) {
                        Label(planned, systemImage: "calendar")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let actual = viewModel.actualDateText(for: milestone) {
                        Label(actual, systemImage: "checkmark.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if milestone.isOverdue {
                        Label("Просрочено", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }

                if let comment = milestone.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.blue.opacity(0.08))
                        )
                }
            }
            .padding(20)
            .background(cardBackground)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)

            Button {
                Task { await reload(force: true) }
            } label: {
                Text("Повторить")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .background(cardBackground)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("Информация о дипломе пока недоступна")
                .font(.headline)

            Text("Здесь появится прогресс дипломного проекта, как только данные будут опубликованы.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await reload(force: true) }
            } label: {
                Text("Обновить")
            }
        }
        .padding(32)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
    }

    private func statusColor(for status: DiplomaProgress.Status?) -> Color {
        guard let status else { return .secondary }
        switch status {
        case .notStarted:
            return .gray
        case .inProgress:
            return .purple
        case .review:
            return .orange
        case .awaitingDefense:
            return .blue
        case .defended:
            return .green
        case .archived:
            return .gray
        case .custom:
            return .purple
        }
    }

    private func milestoneColor(for status: Milestone.Status) -> Color {
        switch status {
        case .planned:
            return .blue
        case .inProgress:
            return .purple
        case .review:
            return .orange
        case .submitted:
            return .teal
        case .completed:
            return .green
        case .blocked:
            return .red
        case .overdue:
            return .pink
        case .custom:
            return .gray
        }
    }

    @MainActor
    private func loadIfNeeded() async {
        guard let userId = authService.currentUser?.id else { return }
        await viewModel.loadProgress(for: String(userId))
    }

    @MainActor
    private func reload(force: Bool = false) async {
        guard let userId = authService.currentUser?.id else { return }
        if force {
            await viewModel.refresh(for: String(userId))
        } else {
            await viewModel.loadProgress(for: String(userId))
        }
    }
}

#if DEBUG
struct DiplomaView_Previews: PreviewProvider {
    static var previews: some View {
        let authService = AuthenticationService.shared
        authService.currentUser = .mock

        return DiplomaView(viewModel: .preview)
            .environmentObject(authService)
    }
}
#endif
