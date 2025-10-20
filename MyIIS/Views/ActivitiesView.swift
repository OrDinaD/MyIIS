import SwiftUI

@MainActor
struct ActivitiesView: View {
    @StateObject private var viewModel: ActivitiesViewModel

    init(viewModel: ActivitiesViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    init() {
        self.init(viewModel: ActivitiesViewModel())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background
                content
            }
            .navigationTitle("Активности")
            .toolbar { toolbarContent }
            .searchable(text: $viewModel.searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Поиск по мероприятиям")
            .task { await viewModel.loadInitialDataIfNeeded() }
            .refreshable { await viewModel.reload() }
            .alert("Ошибка", isPresented: errorBinding) {
                Button("Понятно", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "Произошла неизвестная ошибка")
            }
        }
    }

    private var content: some View {
        Group {
            if viewModel.isLoading && viewModel.activities.isEmpty {
                ProgressView("Загружаем мероприятия…")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else if viewModel.filteredActivities.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        filtersSection
                        LazyVStack(spacing: 20) {
                            ForEach(viewModel.filteredActivities) { activity in
                                ActivityCard(
                                    activity: activity,
                                    status: activity.status(at: viewModel.currentDate),
                                    isRegistrationOpen: activity.isRegistrationOpen(at: viewModel.currentDate),
                                    isLoading: viewModel.registrationsInProgress.contains(activity.id)
                                ) {
                                    Task { await viewModel.toggleRegistration(for: activity) }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                    .padding(.top, 16)
                }
            }
        }
        .animation(.easeInOut, value: viewModel.filteredActivities)
        .animation(.easeInOut, value: viewModel.isLoading)
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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: viewModel.activeFiltersCount > 0 ? "line.3.horizontal.decrease.circle" : "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(.purple.gradient)
                .symbolEffect(.pulse, options: .repeat(1))
            Text(viewModel.activeFiltersCount > 0 ? "Ничего не найдено" : "Скоро появятся мероприятия")
                .font(.title2)
                .fontWeight(.semibold)
            Text(viewModel.activeFiltersCount > 0 ? "Попробуйте изменить фильтры поиска." : "Загляните позже, мы подготовим новые активности.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if viewModel.activeFiltersCount > 0 {
                Button("Сбросить фильтры", role: .cancel) {
                    withAnimation(.easeInOut) { viewModel.resetFilters() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(32)
    }

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Фильтры")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                if viewModel.activeFiltersCount > 0 {
                    Button("Сбросить") {
                        withAnimation(.easeInOut) { viewModel.resetFilters() }
                    }
                    .font(.callout)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    FilterChip(
                        title: "Все",
                        isSelected: viewModel.selectedCategory == nil
                    ) {
                        withAnimation(.easeInOut) { viewModel.selectedCategory = nil }
                    }

                    ForEach(viewModel.categories) { category in
                        FilterChip(
                            title: category.name,
                            subtitle: category.shortDescription,
                            systemImage: category.iconSystemName,
                            isSelected: viewModel.selectedCategory == category
                        ) {
                            withAnimation(.easeInOut) {
                                viewModel.selectedCategory = viewModel.selectedCategory == category ? nil : category
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    FilterChip(
                        title: "Статусы",
                        isSelected: viewModel.selectedStatus == nil
                    ) {
                        withAnimation(.easeInOut) { viewModel.selectedStatus = nil }
                    }

                    ForEach(ActivityStatus.allCases) { status in
                        FilterChip(
                            title: status.title,
                            isSelected: viewModel.selectedStatus == status
                        ) {
                            withAnimation(.easeInOut) {
                                viewModel.selectedStatus = viewModel.selectedStatus == status ? nil : status
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Только с открытой регистрацией", isOn: $viewModel.showOnlyAvailable)
                    .toggleStyle(.switch)
                Toggle("Только мои регистрации", isOn: $viewModel.showOnlyRegistered)
                    .toggleStyle(.switch)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal)
        }
    }

    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if let lastUpdated = viewModel.lastUpdated {
                Text(lastUpdated, style: .time)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule(style: .continuous))
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.errorMessage = nil
                }
            }
        )
    }
}

private struct FilterChip: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .imageScale(.medium)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout)
                        .fontWeight(.semibold)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 40)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .foregroundStyle(foregroundColor)
        }
        .buttonStyle(.plain)
    }

    private var background: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(.linearGradient(
                Gradient(colors: [Color.purple.opacity(0.7), Color.blue.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        } else {
            return AnyShapeStyle(.ultraThinMaterial)
        }
    }

    private var borderColor: Color {
        isSelected ? Color.purple.opacity(0.8) : Color.purple.opacity(0.2)
    }

    private var foregroundColor: Color {
        isSelected ? .white : .primary
    }
}

private struct ActivityCard: View {
    let activity: Activity
    let status: ActivityStatus
    let isRegistrationOpen: Bool
    let isLoading: Bool
    let onToggleRegistration: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(activity.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if let subtitle = activity.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(status.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusBackground)
                    .foregroundStyle(statusForeground)
                    .clipShape(Capsule(style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Label(activity.category.name, systemImage: activity.category.iconSystemName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Label(activity.location, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Label(activity.timeIntervalDescription, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(activity.description)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(4)

            HStack {
                if let capacity = activity.capacity {
                    HStack(spacing: 6) {
                        Image(systemName: "person.3")
                            .imageScale(.small)
                        Text("\(activity.registeredCount)/\(capacity)")
                            .font(.caption)
                    }
                    .padding(8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    Button(action: onToggleRegistration) {
                        Text(activity.userRegistration.isRegistered ? "Отменить" : "Записаться")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(buttonBackground)
                            .foregroundStyle(buttonForeground)
                            .clipShape(Capsule(style: .continuous))
                    }
                    .disabled(!isRegistrationOpen && !activity.userRegistration.isRegistered)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
        )
    }

    private var cardBackground: some ShapeStyle {
        LinearGradient(
            colors: [Color.white.opacity(0.92), Color(.secondarySystemBackground).opacity(0.85)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var statusBackground: some ShapeStyle {
        switch status {
        case .scheduled:
            return AnyShapeStyle(Color.blue.opacity(0.15))
        case .inProgress:
            return AnyShapeStyle(Color.green.opacity(0.2))
        case .finished:
            return AnyShapeStyle(Color.gray.opacity(0.2))
        case .cancelled:
            return AnyShapeStyle(Color.red.opacity(0.2))
        }
    }

    private var statusForeground: Color {
        switch status {
        case .scheduled: return .blue
        case .inProgress: return .green
        case .finished: return .gray
        case .cancelled: return .red
        }
    }

    private var buttonBackground: some ShapeStyle {
        if activity.userRegistration.isRegistered {
            return AnyShapeStyle(Color.red.opacity(0.2))
        }

        if isRegistrationOpen {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.purple.opacity(0.9), Color.blue.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            return AnyShapeStyle(Color.gray.opacity(0.2))
        }
    }

    private var buttonForeground: Color {
        if activity.userRegistration.isRegistered {
            return .red
        }
        return isRegistrationOpen ? .white : .gray
    }
}

#Preview {
    ActivitiesView(viewModel: ActivitiesViewModel(service: ActivitiesService.preview))
}
