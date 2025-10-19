//
//  GradebookView.swift
//  MyIIS
//
//  Created by GitHub Copilot on 13.10.25.
//

import SwiftUI

struct GradebookView: View {

    @EnvironmentObject private var authService: AuthenticationService
    @StateObject private var viewModel: GradebookViewModel

    @MainActor init(viewModel: GradebookViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    @MainActor init() {
        _viewModel = StateObject(wrappedValue: GradebookViewModel())
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
                    .padding(.horizontal)
            }
            .navigationTitle("Зачетка")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            await loadIfNeeded()
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && !viewModel.hasContent {
            ProgressView("Загрузка зачётки...")
                .progressViewStyle(.circular)
        } else if let errorMessage = viewModel.errorMessage {
            errorView(message: errorMessage)
        } else if viewModel.hasContent {
            gradebookList
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

    private var gradebookList: some View {
        List {
            if let average = viewModel.averageGradeText {
                Section {
                    summaryView(average: average)
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                        .listRowBackground(Color.clear)
                }
            }

            ForEach(viewModel.semesters) { semester in
                Section(header: semesterHeader(title: semester.displayTitle)) {
                    ForEach(semester.sortedDisciplines()) { discipline in
                        disciplineRow(for: discipline)
                            .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                            .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.refresh()
        }
    }

    private func summaryView(average: String) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("Средний балл")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(average)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
        .padding(20)
        .background(cardBackground)
    }

    private func semesterHeader(title: String) -> some View {
        Text(title)
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
    }

    private func disciplineRow(for discipline: GradebookDiscipline) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(discipline.name)
                    .font(.headline)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                Text(discipline.bestGradeText)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(gradeColor(for: discipline.bestGradeValue))
            }

            HStack(spacing: 12) {
                Label(discipline.controlForm, systemImage: "doc.text")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let teacher = discipline.teacher, !teacher.isEmpty {
                    Label(teacher, systemImage: "person.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let latest = discipline.latestAttempt {
                attemptInfo(for: latest)
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private func attemptInfo(for attempt: GradeAttempt) -> some View {
        HStack(spacing: 12) {
            Label(attempt.title, systemImage: "repeat")

            if let date = attempt.date, !date.isEmpty {
                Label(date, systemImage: "calendar")
            }

            Label(attempt.grade.displayValue, systemImage: "checkmark.circle")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
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
                Task {
                    await reload()
                }
            } label: {
                Text("Повторить")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .background(cardBackground)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("Зачётка пока пуста")
                .font(.headline)

            Text("Здесь появятся дисциплины и оценки, как только они будут доступны.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await reload(force: true)
                }
            } label: {
                Text("Обновить")
            }
        }
        .padding(32)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            }
    }

    private func gradeColor(for value: Double?) -> Color {
        guard let value else {
            return .secondary
        }

        switch value {
        case ..<4:
            return .red
        case 4..<7:
            return .orange
        case 7..<9:
            return .yellow
        default:
            return .green
        }
    }

    @MainActor private func loadIfNeeded() async {
        guard let userId = authService.currentUser?.id else {
            return
        }

        if viewModel.hasContent {
            return
        }

        await viewModel.loadGradebook(for: String(userId))
    }

    @MainActor private func reload(force: Bool = false) async {
        guard let userId = authService.currentUser?.id else {
            return
        }

        if force {
            await viewModel.loadGradebook(for: String(userId))
        } else {
            await viewModel.refresh()
        }
    }
}

#if DEBUG
struct GradebookView_Previews: PreviewProvider {
    static var previews: some View {
        let authService = AuthenticationService.shared
        authService.currentUser = .mock

        return GradebookView(viewModel: .preview)
            .environmentObject(authService)
    }
}
#endif
