import Combine
import SwiftUI
import UIKit

@MainActor
final class LMSQuizViewModel: ObservableObject {
    @Published var state: LMSQuizScreenState?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedAnswers: [String: String] = [:]

    private let quizURL: URL
    private let service = LMSQuizService.shared

    init(quizURL: URL) {
        self.quizURL = quizURL
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let overview = try await service.fetchOverview(quizURL: quizURL)
            state = .overview(overview)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startOrResume() async throws {
        guard case let .overview(overview)? = state else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let nextState = try await service.startAttempt(using: overview)
            apply(newState: nextState)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func openNavigationItem(_ item: LMSQuizNavigationItem) async {
        guard let url = item.url else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let nextState = try await service.openAttempt(url: url)
            apply(newState: nextState)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submitNextPage() async {
        await submitAttempt(action: .next)
    }

    func finishCurrentAttempt() async {
        await submitAttempt(action: .finishAttempt)
    }

    func returnToAttemptFromSummary() async {
        guard case let .summary(summary)? = state else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let nextState = try await service.returnToAttempt(from: summary)
            apply(newState: nextState)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submitAllAndFinish() async {
        guard case let .summary(summary)? = state else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let nextState = try await service.finishQuiz(summary: summary)
            apply(newState: nextState)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitAttempt(action: LMSQuizService.AttemptSubmitAction) async {
        guard case let .attempt(page)? = state else { return }
        isLoading = true
        defer { isLoading = false }

        var answers: [String: String] = [:]
        for question in page.questions {
            if let selected = selectedAnswers[question.id] {
                answers[question.id] = selected
            }
        }

        do {
            let nextState = try await service.submitAttempt(page: page, answers: answers, action: action)
            apply(newState: nextState)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(newState: LMSQuizScreenState) {
        state = newState

        if case let .attempt(page) = newState {
            var defaults: [String: String] = [:]
            for question in page.questions {
                if let selected = question.selectedAnswer {
                    defaults[question.id] = selected
                }
            }
            selectedAnswers.merge(defaults) { existing, _ in existing }
        }
    }
}

struct LMSQuizView: View {
    let quizURL: URL

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: LMSQuizViewModel
    @State private var confirmFinishAttempt = false
    @State private var confirmFinishAll = false
    @State private var confirmExit = false
    @State private var selectedImageURL: URL?

    init(quizURL: URL) {
        self.quizURL = quizURL
        self._viewModel = StateObject(wrappedValue: LMSQuizViewModel(quizURL: quizURL))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.state == nil {
                ProgressView("Загрузка теста...")
            } else if let error = viewModel.errorMessage, viewModel.state == nil {
                ErrorStateView(error: error) {
                    Task { await viewModel.load() }
                }
            } else {
                content
            }
        }
        .navigationTitle(navigationTitleText)
        .navigationBarTitleDisplayMode(.large)
        .hiddenNavigationBarBackground()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Выйти") {
                    confirmExit = true
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .overlay {
            if viewModel.isLoading && viewModel.state != nil {
                ProgressView()
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .alert("Ошибка", isPresented: Binding(get: {
            viewModel.errorMessage != nil
        }, set: { newValue in
            if !newValue {
                viewModel.errorMessage = nil
            }
        })) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .confirmationDialog("Закончить попытку?", isPresented: $confirmFinishAttempt, titleVisibility: .visible) {
            Button("Закончить попытку", role: .destructive) {
                Task { await viewModel.finishCurrentAttempt() }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Вы перейдёте к сводке ответов перед финальной отправкой теста.")
        }
        .confirmationDialog("Отправить всё и завершить тест?", isPresented: $confirmFinishAll, titleVisibility: .visible) {
            Button("Отправить и завершить", role: .destructive) {
                Task { await viewModel.submitAllAndFinish() }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("После отправки попытка будет завершена.")
        }
        .confirmationDialog("Выйти из теста?", isPresented: $confirmExit, titleVisibility: .visible) {
            Button("Выйти", role: .destructive) {
                dismiss()
            }
            Button("Остаться", role: .cancel) {}
        } message: {
            Text("Если не нажать кнопки сохранения/перехода, последние изменения могут не сохраниться.")
        }
        .fullScreenCover(item: Binding(
            get: { selectedImageURL.map { ZoomImageToken(url: $0) } },
            set: { token in selectedImageURL = token?.url }
        )) { token in
            ZoomableImageViewer(url: token.url) {
                selectedImageURL = nil
            }
        }
    }

    private var navigationTitleText: String {
        switch viewModel.state {
        case let .overview(overview):
            return overview.courseTitle ?? overview.title
        case let .attempt(page):
            return page.title
        case let .summary(summary):
            return summary.courseTitle ?? summary.title
        case .completion:
            return "Тест"
        case .none:
            return "Тест"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case let .overview(overview):
            overviewView(overview)
        case let .attempt(page):
            attemptView(page)
        case let .summary(summary):
            summaryView(summary)
        case let .completion(message):
            completionView(message)
        case .none:
            ProgressView("Подготовка...")
        }
    }

    private func overviewView(_ overview: LMSQuizOverview) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let warning = overview.warningText {
                    Text(warning)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { try? await viewModel.startOrResume() }
                } label: {
                    Text(overview.resumeAttemptURL == nil ? "Начать попытку" : "Продолжить попытку")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if !overview.previousAttempts.isEmpty {
                    previousAttemptsSection(overview.previousAttempts)
                }
            }
            .padding()
        }
    }

}

private extension LMSQuizView {
    private func attemptView(_ page: LMSQuizAttemptPage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                timerBanner(for: page)
                navigationStrip(for: page)

                ForEach(page.questions) { question in
                    questionCard(question)
                }

                attemptActionButtons
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    @ViewBuilder
    private func timerBanner(for page: LMSQuizAttemptPage) -> some View {
        if let remainingSeconds = page.timerRemainingSeconds {
            QuizTimerBanner(remainingSeconds: remainingSeconds)
                .padding(.horizontal)
        }
    }

    private func navigationStrip(for page: LMSQuizAttemptPage) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(page.navigation) { item in
                    Button {
                        Task { await viewModel.openNavigationItem(item) }
                    } label: {
                        VStack(spacing: 4) {
                            Text(item.label)
                                .font(.subheadline.weight(.semibold))
                            statusPill(text: item.state, color: item.state.statusColor)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(item.isCurrent ? Color.blue.opacity(0.2) : Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private func questionCard(_ question: LMSQuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text("Вопрос \(question.number)")
                    .font(.headline)
                Spacer()
                if let state = question.state {
                    statusPill(text: state, color: state.statusColor)
                }
            }

            HTMLTextBlock(html: question.textHTML)

            ForEach(question.textImages, id: \.absoluteString) { imageURL in
                QuizRemoteImage(url: imageURL) {
                    selectedImageURL = imageURL
                }
            }

            questionChoices(question)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
        .padding(.horizontal)
    }

    private func questionChoices(_ question: LMSQuizQuestion) -> some View {
        VStack(spacing: 8) {
            ForEach(question.choices) { choice in
                Button {
                    viewModel.selectedAnswers[question.id] = choice.value
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        let selectedValue = viewModel.selectedAnswers[question.id] ?? question.selectedAnswer
                        Image(systemName: selectedValue == choice.value ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(.blue)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 6) {
                            HTMLTextBlock(html: choice.labelHTML)
                            ForEach(choice.images, id: \.absoluteString) { imageURL in
                                QuizRemoteImage(url: imageURL) {
                                    selectedImageURL = imageURL
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var attemptActionButtons: some View {
        VStack(spacing: 10) {
            Button {
                Task { await viewModel.submitNextPage() }
            } label: {
                Text("Сохранить и перейти дальше")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button(role: .destructive) {
                confirmFinishAttempt = true
            } label: {
                Text("Закончить попытку")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    private func summaryView(_ summary: LMSQuizSummaryPage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let deadline = summary.deadlineText {
                    Text(deadline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 8) {
                    ForEach(summary.statusItems) { item in
                        HStack {
                            Text("Вопрос \(item.questionNumber)")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            statusPill(text: item.status, color: item.status.statusColor)
                        }
                        .padding(10)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                Button {
                    Task { await viewModel.returnToAttemptFromSummary() }
                } label: {
                    Text("Вернуться к попытке")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    confirmFinishAll = true
                } label: {
                    Text("Отправить всё и завершить тест")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    private func completionView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Тест отправлен")
                .font(.title3.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    private func statusPill(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
            .accessibilityLabel(text)
    }

    private func previousAttemptsSection(_ attempts: [LMSQuizPreviousAttempt]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Предыдущие попытки")
                .font(.headline)

            ForEach(attempts) { attempt in
                VStack(alignment: .leading, spacing: 8) {
                    Text(attempt.title)
                        .font(.subheadline.weight(.semibold))

                    if let state = attempt.state {
                        AttemptMetaRow(label: "Состояние", value: state, color: state.statusColor)
                    }
                    if let startedAt = attempt.startedAt {
                        AttemptMetaRow(label: "Начат", value: startedAt)
                    }
                    if let finishedAt = attempt.finishedAt {
                        AttemptMetaRow(label: "Завершен", value: finishedAt)
                    }
                    if let duration = attempt.duration {
                        AttemptMetaRow(label: "Время", value: duration)
                    }
                    if let score = attempt.score {
                        AttemptMetaRow(label: "Баллы", value: score)
                    }
                    if let grade = attempt.grade {
                        AttemptMetaRow(label: "Оценка", value: grade)
                    }
                    if let reviewMessage = attempt.reviewMessage {
                        Text(reviewMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}
