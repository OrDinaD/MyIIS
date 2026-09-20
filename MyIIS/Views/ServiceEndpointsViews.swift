import Combine
import Observation
import SwiftUI

struct ServiceEndpointSnapshot<Value: Codable>: Codable {
    let value: Value
    let updatedAt: Date
}

enum ServiceEndpointCache {
    static func restore<Value: Codable>(for key: String, as type: Value.Type, from defaults: UserDefaults = .standard) -> (value: Value, updatedAt: Date)? {
        guard let payload = UserDefaultsPayloadStore.load(forKey: key, from: defaults),
              let snapshot = try? JSONDecoder().decode(ServiceEndpointSnapshot<Value>.self, from: payload) else {
            return nil
        }
        return (snapshot.value, snapshot.updatedAt)
    }

    @discardableResult
    static func save<Value: Codable>(_ value: Value, for key: String, in defaults: UserDefaults = .standard) -> Date {
        let updatedAt = Date()
        let snapshot = ServiceEndpointSnapshot(value: value, updatedAt: updatedAt)
        if let payload = try? JSONEncoder().encode(snapshot) {
            _ = UserDefaultsPayloadStore.save(payload, forKey: key, in: defaults)
        }
        return updatedAt
    }
}

@MainActor
@Observable
final class CachedEndpointViewModel<Value: Codable> {
    var value: Value
    var isLoading = false
    var errorMessage: String?
    private(set) var isShowingStaleDataWarning = false
    private(set) var lastUpdateTime: Date?
    private(set) var staleErrorMessage: String?

    private let cacheKey: String
    private let fetcher: @MainActor () async throws -> Value
    private var hasLoadedOnce = false

    init(
        initialValue: Value,
        cacheKey: String,
        fetcher: @escaping @MainActor () async throws -> Value
    ) {
        self.value = initialValue
        self.cacheKey = cacheKey
        self.fetcher = fetcher
        _ = restoreSnapshot(markStale: false, message: nil)
    }

    var hasContent: Bool {
        lastUpdateTime != nil
    }

    func loadIfNeeded() async {
        guard !hasLoadedOnce else { return }
        await reload()
    }

    func reload() async {
        if isLoading { return }
        if lastUpdateTime == nil {
            _ = restoreSnapshot(markStale: false, message: nil)
        }
        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await fetcher()
            apply(value: fetched, updatedAt: ServiceEndpointCache.save(fetched, for: cacheKey))
            hasLoadedOnce = true
            isShowingStaleDataWarning = false
            staleErrorMessage = nil
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            if restoreSnapshot(markStale: true, message: message) {
                errorMessage = nil
            } else {
                errorMessage = message
            }
        }
    }

    private func restoreSnapshot(markStale: Bool, message: String?) -> Bool {
        guard let cached = ServiceEndpointCache.restore(for: cacheKey, as: Value.self) else {
            return false
        }
        apply(value: cached.value, updatedAt: cached.updatedAt)
        if markStale {
            hasLoadedOnce = true
        }
        isShowingStaleDataWarning = markStale
        staleErrorMessage = markStale ? message : nil
        return true
    }

    private func apply(value: Value, updatedAt: Date) {
        self.value = value
        self.lastUpdateTime = updatedAt
    }
}

// MARK: - Library

@MainActor
struct LibraryServiceView: View {
    @State private var viewModel = LibraryServiceViewModel()
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if viewModel.isShowingStaleDataWarning {
                    StaleDataBanner(lastUpdateTime: viewModel.lastUpdateTime, errorMessage: viewModel.staleErrorMessage) {
                        await viewModel.reload()
                    }
                }

                ServiceEndpointSection(
                    title: NSLocalizedString("services_library_books_title", comment: ""),
                    subtitle: nil,
                    icon: "books.vertical.fill"
                ) {
                    if viewModel.books.isEmpty {
                        ServiceEmptyState(text: NSLocalizedString("services_library_books_empty", comment: ""))
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.books, id: \.stableID) { item in
                                ServiceJSONItemCard(item: item)
                            }
                        }
                    }
                }

                if !viewModel.news.isEmpty {
                    ServiceEndpointSection(
                        title: NSLocalizedString("services_library_news_title", comment: ""),
                        subtitle: nil,
                        icon: "newspaper.fill"
                    ) {
                        VStack(spacing: 10) {
                            ForEach(viewModel.news) { news in
                                Button {
                                    openURL(news.link)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(news.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .multilineTextAlignment(.leading)
                                        HStack(spacing: 6) {
                                            Image(systemName: "calendar")
                                            Text(news.displayDate)
                                                .font(.caption)
                                            Spacer(minLength: 8)
                                            Image(systemName: "arrow.up.right.square")
                                        }
                                        .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(NSLocalizedString("services_library_navigation_title", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        .hiddenNavigationBarBackground()
        .overlay {
            if viewModel.isLoading && !viewModel.hasContent {
                ProgressView(NSLocalizedString("common_loading", comment: ""))
            }
        }
        .task { await viewModel.loadIfNeeded() }
        .refreshable { await viewModel.reload() }
        .errorAlert($viewModel.errorMessage)
    }
}
@MainActor
@Observable
private final class LibraryServiceViewModel {
    var books: [ServiceJSONObject] = []
    var news: [LibraryNewsEntry] = []
    var isLoading = false
    var errorMessage: String?
    private(set) var isShowingStaleDataWarning = false
    private(set) var lastUpdateTime: Date?
    private(set) var staleErrorMessage: String?

    private let api = ServiceEndpointsAPI()
    private var hasLoadedOnce = false
    private static let cacheKey = "LibraryServiceViewModel.snapshot"
    private static let booksCacheKey = "LibraryServiceViewModel.books"
    private static let newsCacheKey = "LibraryServiceViewModel.news"

    private struct Snapshot: Codable {
        let books: [ServiceJSONObject]
        let news: [LibraryNewsEntry]
    }

    init() {
        _ = restoreSnapshot(markStale: false, message: nil)
    }

    var hasContent: Bool {
        lastUpdateTime != nil || !books.isEmpty || !news.isEmpty
    }

    func loadIfNeeded() async {
        guard !hasLoadedOnce else { return }
        await reload()
    }

    func reload() async {
        if isLoading { return }
        if !hasContent {
            _ = restoreSnapshot(markStale: false, message: nil)
        }
        isLoading = true
        defer { isLoading = false }

        var loadedAnySection = false
        var firstErrorMessage: String?

        do {
            let booksResult = try await api.fetchLibraryBooks()
            books = booksResult
            updateLastUpdateTime(ServiceEndpointCache.save(booksResult, for: Self.booksCacheKey))
            loadedAnySection = true
        } catch is CancellationError {
            return
        } catch {
            firstErrorMessage = firstErrorMessage ?? displayMessage(for: error)
        }

        do {
            let newsResult = try await api.fetchLibraryNews()
            news = newsResult
            updateLastUpdateTime(ServiceEndpointCache.save(newsResult, for: Self.newsCacheKey))
            loadedAnySection = true
        } catch is CancellationError {
            return
        } catch {
            firstErrorMessage = firstErrorMessage ?? displayMessage(for: error)
        }

        if loadedAnySection {
            _ = ServiceEndpointCache.save(Snapshot(books: books, news: news), for: Self.cacheKey)
            hasLoadedOnce = true
            isShowingStaleDataWarning = firstErrorMessage != nil
            staleErrorMessage = firstErrorMessage
            errorMessage = nil
            return
        }

        if restoreSnapshot(markStale: true, message: firstErrorMessage) {
            errorMessage = nil
        } else {
            errorMessage = firstErrorMessage
        }
    }

    private func restoreSnapshot(markStale: Bool, message: String?) -> Bool {
        var restoredAnySection = false

        if let cachedBooks = ServiceEndpointCache.restore(for: Self.booksCacheKey, as: [ServiceJSONObject].self) {
            books = cachedBooks.value
            updateLastUpdateTime(cachedBooks.updatedAt)
            restoredAnySection = true
        }

        if let cachedNews = ServiceEndpointCache.restore(for: Self.newsCacheKey, as: [LibraryNewsEntry].self) {
            news = cachedNews.value
            updateLastUpdateTime(cachedNews.updatedAt)
            restoredAnySection = true
        }

        if !restoredAnySection,
           let cached = ServiceEndpointCache.restore(for: Self.cacheKey, as: Snapshot.self) {
            apply(snapshot: cached.value, updatedAt: cached.updatedAt)
            restoredAnySection = true
        }

        guard restoredAnySection else { return false }
        if markStale {
            hasLoadedOnce = true
        }
        isShowingStaleDataWarning = markStale
        staleErrorMessage = markStale ? message : nil
        return true
    }

    private func apply(snapshot: Snapshot, updatedAt: Date) {
        books = snapshot.books
        news = snapshot.news
        updateLastUpdateTime(updatedAt)
    }

    private func updateLastUpdateTime(_ updatedAt: Date) {
        if let current = lastUpdateTime {
            lastUpdateTime = max(current, updatedAt)
        } else {
            lastUpdateTime = updatedAt
        }
    }

    private func displayMessage(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

// MARK: - Announcements

@MainActor
struct AnnouncementsServiceView: View {
    @State private var viewModel: CachedEndpointViewModel<[ServiceJSONObject]>

    init() {
        _viewModel = State(initialValue: CachedEndpointViewModel(
            initialValue: [],
            cacheKey: "AnnouncementsServiceViewModel.snapshot"
        ) {
            let groupNumber = AuthenticationService.shared.currentUser?.education.group.nilIfBlank
                ?? MyIISDataStore.loadData()?.userGroup?.nilIfBlank
            return try await ServiceEndpointsAPI().fetchAnnouncements(groupNumber: groupNumber)
        })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if viewModel.isShowingStaleDataWarning {
                    StaleDataBanner(lastUpdateTime: viewModel.lastUpdateTime, errorMessage: viewModel.staleErrorMessage) {
                        await viewModel.reload()
                    }
                }

                ServiceEndpointSection(
                    title: NSLocalizedString("services_announcements_title", comment: ""),
                    subtitle: nil,
                    icon: "megaphone.fill"
                ) {
                    if viewModel.value.isEmpty {
                        ServiceEmptyState(text: NSLocalizedString("services_announcements_empty", comment: ""))
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.value, id: \.stableID) { item in
                                ServiceJSONItemCard(item: item)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(NSLocalizedString("services_announcements_title", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        .hiddenNavigationBarBackground()
        .overlay {
            if viewModel.isLoading && viewModel.value.isEmpty {
                ProgressView(NSLocalizedString("common_loading", comment: ""))
            }
        }
        .task { await viewModel.loadIfNeeded() }
        .refreshable { await viewModel.reload() }
        .errorAlert($viewModel.errorMessage)
    }
}

// MARK: - Penalties

@MainActor
struct PenaltiesServiceView: View {
    @State private var viewModel: CachedEndpointViewModel<[ServiceJSONObject]>

    init() {
        _viewModel = State(initialValue: CachedEndpointViewModel(
            initialValue: [],
            cacheKey: "PenaltiesServiceViewModel.snapshot"
        ) {
            try await ServiceEndpointsAPI().fetchPenalties()
        })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if viewModel.isShowingStaleDataWarning {
                    StaleDataBanner(lastUpdateTime: viewModel.lastUpdateTime, errorMessage: viewModel.staleErrorMessage) {
                        await viewModel.reload()
                    }
                }

                ServiceEndpointSection(
                    title: NSLocalizedString("services_penalties_title", comment: ""),
                    subtitle: nil,
                    icon: "exclamationmark.bubble.fill"
                ) {
                    if viewModel.value.isEmpty {
                        ServiceEmptyState(text: NSLocalizedString("services_penalties_empty", comment: ""))
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.value, id: \.stableID) { item in
                                PenaltyItemCard(item: item)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(NSLocalizedString("services_penalties_title", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        .hiddenNavigationBarBackground()
        .overlay {
            if viewModel.isLoading && viewModel.value.isEmpty {
                ProgressView(NSLocalizedString("common_loading", comment: ""))
            }
        }
        .task { await viewModel.loadIfNeeded() }
        .refreshable { await viewModel.reload() }
        .errorAlert($viewModel.errorMessage)
    }
}
