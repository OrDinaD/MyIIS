import Combine
import Foundation

@MainActor
final class AnnouncementsViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case refreshing
        case loadingMore
        case error(String)

        var isLoading: Bool {
            switch self {
            case .idle, .error:
                return false
            case .loading, .refreshing, .loadingMore:
                return true
            }
        }
    }

    @Published var announcements: [Announcement] = []
    @Published private(set) var categories: [AnnouncementCategory] = [.all]
    @Published private(set) var state: State = .idle
    @Published private(set) var selectedCategory: AnnouncementCategory? = .all
    @Published private(set) var showOnlyUnread: Bool = false
    @Published var searchQuery: String = ""

    private let service: AnnouncementsServicing
    let userDefaults: UserDefaults
    private let pageSize: Int
    let unreadCacheKey = "AnnouncementsViewModel.unreadCache"
    var unreadCache: Set<String>
    var allAnnouncements: [Announcement] = []
    private var currentPage: Int = 0
    private var hasMorePages = true
    private var hasLoadedInitialData = false
    private var searchTask: Task<Void, Never>?

    init(
        service: AnnouncementsServicing? = nil,
        userDefaults: UserDefaults = .standard,
        pageSize: Int = 20
    ) {
        self.service = service ?? AnnouncementsService()
        self.userDefaults = userDefaults
        self.pageSize = pageSize
        self.unreadCache = Self.restoreUnreadCache(from: userDefaults, key: unreadCacheKey)
    }

    deinit {
        searchTask?.cancel()
    }

    func loadInitial() async {
        guard !hasLoadedInitialData else {
            return
        }
        hasLoadedInitialData = true
        await refresh()
    }

    func refresh() async {
        if announcements.isEmpty {
            state = .loading
        } else {
            state = .refreshing
        }
        currentPage = 0
        hasMorePages = true
        await loadCategoriesIfNeeded()
        _ = await fetchPage(page: 0, reset: true)
    }

    func loadMoreIfNeeded(current item: Announcement) async {
        guard hasMorePages else {
            return
        }

        guard announcements.last?.id == item.id else {
            return
        }

        guard state != .loadingMore else {
            return
        }

        state = .loadingMore
        let nextPage = currentPage + 1
        let success = await fetchPage(page: nextPage, reset: false)
        if !success {
            hasMorePages = true
        }
    }

    func selectCategory(_ category: AnnouncementCategory?) async {
        guard selectedCategory?.id != category?.id else {
            return
        }
        selectedCategory = category
        await refresh()
    }

    func setShowOnlyUnread(_ value: Bool) async {
        guard showOnlyUnread != value else {
            return
        }
        showOnlyUnread = value
        await refresh()
    }

    func applySearchQuery() async {
        searchTask?.cancel()
        await refresh()
    }

    func scheduleSearchRefresh(for query: String) {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled, let self else {
                return
            }
            await self.refresh()
        }
    }

    func markAsRead(_ announcement: Announcement) async {
        guard let index = announcements.firstIndex(where: { $0.id == announcement.id }) else {
            return
        }
        guard announcements[index].isRead == false else {
            return
        }

        announcements[index].isRead = true
        allAnnouncements = allAnnouncements.map { item in
            var updated = item
            if updated.id == announcement.id {
                updated.isRead = true
            }
            return updated
        }
        unreadCache.remove(announcement.id)
        persistUnreadCache()

        do {
            try await service.markAnnouncementRead(id: announcement.id)
        } catch {
            announcements[index].isRead = false
            allAnnouncements = allAnnouncements.map { item in
                var updated = item
                if updated.id == announcement.id {
                    updated.isRead = false
                }
                return updated
            }
            unreadCache.insert(announcement.id)
            persistUnreadCache()
            state = .error(error.localizedDescription)
        }
    }

    private func loadCategoriesIfNeeded() async {
        guard categories.count == 1 else {
            return
        }

        do {
            let fetched = try await service.fetchCategories()
            var prepared = fetched
            var seen = Set<String>()
            prepared = prepared.filter { category in
                let inserted = seen.insert(category.id).inserted
                return inserted
            }
            if let index = prepared.firstIndex(where: { $0.id == AnnouncementCategory.all.id }) {
                prepared.remove(at: index)
            }
            prepared.insert(.all, at: 0)
            categories = prepared
        } catch {
            categories = [.all]
            state = .error(error.localizedDescription)
        }
    }

    @discardableResult
    private func fetchPage(page: Int, reset: Bool) async -> Bool {
        let categoryID = selectedCategory?.id == AnnouncementCategory.all.id ? nil : selectedCategory?.id
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let response = try await service.fetchAnnouncements(
                page: page,
                pageSize: pageSize,
                categoryID: categoryID,
                onlyUnread: showOnlyUnread,
                searchQuery: query.isEmpty ? nil : query
            )

            let normalizedItems = normalizeUnread(response.items)
            if reset {
                allAnnouncements = normalizedItems
            } else {
                allAnnouncements.append(contentsOf: normalizedItems)
            }
            hasMorePages = response.hasMore
            currentPage = page
            applyFilters()
            state = .idle
            return true
        } catch {
            if reset {
                announcements = []
                allAnnouncements = []
            }
            state = .error(error.localizedDescription)
            return false
        }
    }

}
