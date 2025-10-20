//
//  StudyView.swift
//  MyIIS
//
//  Created by GitHub Copilot on 13.10.25.
//

import SwiftUI

@MainActor
struct StudyView: View {

    @EnvironmentObject private var authService: AuthenticationService
    @StateObject private var viewModel: StudyViewModel

    init(viewModel: StudyViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    init() {
        self.init(viewModel: StudyViewModel())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background
                content
                    .padding(.horizontal)
            }
            .navigationTitle("Учеба")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            await loadIfNeeded()
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && !viewModel.hasContent {
            ProgressView("Загрузка учебного плана...")
                .progressViewStyle(.circular)
        } else if let message = viewModel.errorMessage {
            errorView(message: message)
        } else if viewModel.hasContent {
            ScrollView {
                LazyVStack(spacing: 20) {
                    headerCard

                    if viewModel.shouldShowFilters {
                        filtersCard
                    }

                    if !viewModel.disciplineSummaries.isEmpty {
                        disciplinesCard
                    }

                    ForEach(viewModel.daySchedules) { schedule in
                        dayScheduleCard(schedule)
                    }
                }
                .padding(.vertical, 24)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await viewModel.refresh()
            }
            .overlay(alignment: .top) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .padding(.top, 12)
                }
            }
        } else {
            emptyState
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.groupTitle)
                    .font(.title)
                    .fontWeight(.bold)

                if let subtitle = viewModel.groupSubtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                if let range = viewModel.studyRangeText {
                    Label(range, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let exams = viewModel.examsRangeText {
                    Label("Сессия: \(exams)", systemImage: "graduationcap")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let total = viewModel.lessonsCountText {
                    Label(total, systemImage: "list.bullet.rectangle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Label(viewModel.currentWeekTitle, systemImage: "calendar.badge.clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .background(cardBackground)
    }

    private var filtersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Недели")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.availableFilters) { filter in
                        filterChip(for: filter)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private func filterChip(for filter: StudyWeekFilter) -> some View {
        let isSelected = filter == viewModel.selectedFilter

        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                viewModel.selectedFilter = filter
            }
        } label: {
            Text(filter.title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(filterBackgroundStyle(isSelected: isSelected))
                )
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private var disciplinesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Дисциплины")
                .font(.headline)

            ForEach(Array(viewModel.disciplineSummaries.enumerated()), id: \.offset) { index, summary in
                if index > 0 {
                    Divider()
                        .background(Color.white.opacity(0.15))
                }
                disciplineRow(summary)
            }
        }
        .padding(24)
        .background(cardBackground)
    }

    private func disciplineRow(_ summary: DisciplineSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(summary.title)
                .font(.headline)

            if !summary.lessonTypes.isEmpty {
                HStack(spacing: 8) {
                    ForEach(summary.lessonTypes, id: \.self) { type in
                        Text(type)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(chipBackground)
                    }
                }
            }

            if !summary.teachers.isEmpty {
                Label(summary.teachers.joined(separator: ", "), systemImage: "person.2.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !summary.weeks.isEmpty {
                Label("Недели: \(summary.weeks.map(String.init).joined(separator: ", "))", systemImage: "calendar")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dayScheduleCard(_ schedule: StudyDaySchedule) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(schedule.weekday.rawValue)
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                ForEach(Array(schedule.lessons.enumerated()), id: \.offset) { index, lesson in
                    if index > 0 {
                        Divider()
                            .background(Color.white.opacity(0.15))
                    }
                    lessonRow(lesson)
                }
            }
        }
        .padding(24)
        .background(cardBackground)
    }

    private func lessonRow(_ lesson: DisciplineSchedule) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(lesson.title)
                        .font(.headline)

                    if !lesson.subtitle.isEmpty {
                        Text(lesson.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                if !lesson.lessonTypeAbbrev.isEmpty {
                    Text(lesson.lessonTypeAbbrev)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(chipBackground)
                }
            }

            HStack(spacing: 12) {
                if !lesson.timeRange.isEmpty {
                    Label(lesson.timeRange, systemImage: "clock")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !lesson.location.isEmpty {
                    Label(lesson.location, systemImage: "mappin.and.ellipse")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !lesson.weekNumbers.isEmpty {
                    Label("Недели: \(lesson.weekNumbers.map(String.init).joined(separator: ", "))", systemImage: "calendar")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.85)

            if let note = lesson.note, !note.isEmpty {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    await reload(force: true)
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
            Image(systemName: "calendar")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("Расписание пока недоступно")
                .font(.headline)

            Text("Попробуйте обновить страницу немного позже.")
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

    private var background: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemBackground),
                Color(uiColor: .secondarySystemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            }
    }

    private var chipBackground: some View {
        Capsule(style: .continuous)
            .fill(Color.white.opacity(0.12))
    }

    private var selectedFilterBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.35),
                Color.accentColor.opacity(0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func filterBackgroundStyle(isSelected: Bool) -> AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(selectedFilterBackground)
        } else {
            return AnyShapeStyle(Color.white.opacity(0.12))
        }
    }

    private func loadIfNeeded() async {
        guard let group = authService.currentUser?.education.group, !group.isEmpty else { return }
        await viewModel.load(for: group)
    }

    private func reload(force: Bool = false) async {
        guard let group = authService.currentUser?.education.group, !group.isEmpty else { return }
        await viewModel.load(for: group, force: force)
    }
}

#if DEBUG
#Preview {
    let authService = AuthenticationService.shared
    authService.currentUser = .mock
    return StudyView(viewModel: .preview)
        .environmentObject(authService)
}
#endif
