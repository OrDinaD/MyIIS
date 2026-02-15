import Foundation
import SwiftUI

@MainActor
struct AnnouncementsView: View {
    @StateObject private var viewModel: AnnouncementsViewModel

    init(viewModel: AnnouncementsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    init() {
        self.init(viewModel: AnnouncementsViewModel())
    }

    private var backgroundGradient: some View {
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

    private func categoryBackgroundStyle(isSelected: Bool) -> AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color.purple.opacity(0.85))
        } else {
            return AnyShapeStyle(Material.ultraThin)
        }
    }

    private var errorMessage: String? {
        if case let .error(message) = viewModel.state {
            return message
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                backgroundGradient

                ScrollView {
                    VStack(spacing: 24) {
                        filtersSection
                        contentSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 32)
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    await viewModel.refresh()
                }

                if viewModel.state == .loading && viewModel.announcements.isEmpty {
                    ProgressView()
                        .controlSize(.large)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                }

                if let message = errorMessage, !viewModel.announcements.isEmpty {
                    errorBanner(message)
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationTitle("Объявления")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.loadInitial()
            }
            .searchable(text: $viewModel.searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Поиск объявлений")
            .onSubmit(of: .search) {
                Task {
                    await viewModel.applySearchQuery()
                }
            }
            .onChange(of: viewModel.searchQuery) { _, newValue in
                viewModel.scheduleSearchRefresh(for: newValue)
            }
        }
    }

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        Label {
            Text(message)
                .font(.callout)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.multicolor)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 8)
        .padding(.top, 24)
    }

    @ViewBuilder
    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.categories) { category in
                        categoryChip(for: category)
                    }
                }
                .padding(.horizontal, 4)
            }

            Toggle(isOn: Binding(
                get: { viewModel.showOnlyUnread },
                set: { newValue in
                    Task {
                        await viewModel.setShowOnlyUnread(newValue)
                    }
                }
            )) {
                Label("Только непрочитанные", systemImage: "envelope.badge")
            }
            .toggleStyle(SwitchToggleStyle(tint: .purple))
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 12)
    }

    @ViewBuilder
    private var contentSection: some View {
        if viewModel.announcements.isEmpty {
            switch viewModel.state {
            case .error:
                errorPlaceholder
            case .loading, .refreshing:
                loadingPlaceholder
            default:
                emptyPlaceholder
            }
        } else {
            LazyVStack(spacing: 20, pinnedViews: []) {
                ForEach(viewModel.announcements) { announcement in
                    AnnouncementCardView(
                        announcement: announcement,
                        markAsReadAction: {
                            Task {
                                await viewModel.markAsRead(announcement)
                            }
                        }
                    )
                    .onAppear {
                        Task {
                            await viewModel.loadMoreIfNeeded(current: announcement)
                        }
                    }
                }

                if viewModel.state == .loadingMore {
                    ProgressView()
                        .controlSize(.large)
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: 16) {
            ForEach(0..<3) { _ in
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(height: 140)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                    )
                    .shimmering()
            }
        }
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.badge.checkmark")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.purple.gradient)
            Text("Вы в курсе всех новостей")
                .font(.title3.bold())
            Text("Новых объявлений пока нет. Попробуйте обновить ленту чуть позже.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private var errorPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(.orange)
            Text("Не удалось загрузить объявления")
                .font(.title3.bold())
            if let message = errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                Task {
                    await viewModel.refresh()
                }
            } label: {
                Label("Повторить", systemImage: "arrow.clockwise")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private func categoryChip(for category: AnnouncementCategory) -> some View {
        let isSelected = viewModel.selectedCategory?.id == category.id || (category.id == AnnouncementCategory.all.id && viewModel.selectedCategory == nil)

        return Button {
            Task {
                await viewModel.selectCategory(category)
            }
        } label: {
            HStack(spacing: 8) {
                if let icon = category.iconName {
                    Image(systemName: icon)
                }
                Text(category.title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(categoryBackgroundStyle(isSelected: isSelected))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? Color.purple.opacity(0.95) : Color.white.opacity(0.3), lineWidth: 1)
            )
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .shadow(color: isSelected ? Color.purple.opacity(0.25) : Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

private struct AnnouncementCardView: View {
    let announcement: Announcement
    let markAsReadAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(announcement.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if announcement.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.subheadline)
                        .rotationEffect(.degrees(-30))
                        .foregroundStyle(.orange)
                }

                Spacer()

                if !announcement.isRead {
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 10, height: 10)
                        .transition(.scale)
                }
            }

            if let author = announcement.author, !author.isEmpty {
                Text(author)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !announcement.shortBody.isEmpty {
                Text(announcement.shortBody)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }

            HStack {
                Label(announcement.displayCategory, systemImage: "folder")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(announcement.relativePublishedAt)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(announcement.formattedDate)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                if !announcement.isRead {
                    Button(action: markAsReadAction) {
                        Text("Прочитано")
                            .font(.footnote.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
    }
}

private struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.05),
                        Color.white.opacity(0.25),
                        Color.white.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .mask(content)
                .offset(x: phase * 200)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

private extension View {
    func shimmering() -> some View {
        modifier(ShimmerEffect())
    }
}

#Preview {
    let previewService = MockAnnouncementsService()
    let suiteName = "AnnouncementsPreview"
    let defaults = UserDefaults(suiteName: suiteName) ?? .standard
    if let suiteDefaults = UserDefaults(suiteName: suiteName) {
        suiteDefaults.removePersistentDomain(forName: suiteName)
    }
    let previewViewModel = AnnouncementsViewModel(service: previewService, userDefaults: defaults)
    return AnnouncementsView(viewModel: previewViewModel)
}

private final class MockAnnouncementsService: AnnouncementsServicing {
    private let categories: [AnnouncementCategory]
    private let announcements: [Announcement]

    init() {
        categories = [
            .all,
            AnnouncementCategory(id: "important", title: "Важно", iconName: "exclamationmark.circle.fill"),
            AnnouncementCategory(id: "events", title: "События", iconName: "calendar")
        ]

        let now = Date()
        announcements = [
            Announcement(
                id: "1",
                title: "Обновление расписания",
                summary: "Добавлены занятия по курсу машинного обучения.",
                body: "Полный текст объявления о том, что в расписании появились новые пары.",
                author: "Учебный отдел",
                categoryID: "important",
                categoryName: "Важно",
                publishedAt: now.addingTimeInterval(-3600),
                isRead: false,
                isPinned: true
            ),
            Announcement(
                id: "2",
                title: "Встреча клуба разработчиков",
                summary: "Каждую среду в 18:00 в аудитории 402.",
                body: nil,
                author: "IT Клуб",
                categoryID: "events",
                categoryName: "События",
                publishedAt: now.addingTimeInterval(-18_000),
                isRead: false,
                isPinned: false
            ),
            Announcement(
                id: "3",
                title: "Плановое обновление ИИС",
                summary: "Сервис будет недоступен 2 часа ночью.",
                body: nil,
                author: "ИТ отдел",
                categoryID: "important",
                categoryName: "Важно",
                publishedAt: now.addingTimeInterval(-72_000),
                isRead: true,
                isPinned: false
            )
        ]
    }

    func fetchCategories() async throws -> [AnnouncementCategory] {
        categories
    }

    func fetchAnnouncements(
        page: Int,
        pageSize: Int,
        categoryID: String?,
        onlyUnread: Bool,
        searchQuery: String?
    ) async throws -> AnnouncementPage {
        AnnouncementPage(items: announcements, page: page, pageSize: pageSize, totalItems: announcements.count, totalPages: 1)
    }

    func markAnnouncementsRead(ids: [String]) async throws {}

    func markAnnouncementRead(id: String) async throws {}
}
