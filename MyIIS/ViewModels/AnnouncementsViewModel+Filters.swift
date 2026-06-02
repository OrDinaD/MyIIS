import Foundation

extension AnnouncementsViewModel {
    func applyFilters() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = allAnnouncements.filter { announcement in
            if let categoryID = selectedCategory?.id,
               categoryID != AnnouncementCategory.all.id,
               announcement.categoryID != categoryID {
                return false
            }

            if showOnlyUnread && announcement.isRead {
                return false
            }

            if !query.isEmpty {
                let haystack = (announcement.title + " " + (announcement.summary ?? announcement.body ?? "")).lowercased()
                if !haystack.contains(query.lowercased()) {
                    return false
                }
            }

            return true
        }

        announcements = sortAnnouncements(filtered)
    }

    func sortAnnouncements(_ items: [Announcement]) -> [Announcement] {
        items.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            if lhs.isRead != rhs.isRead {
                return !lhs.isRead && rhs.isRead
            }
            return lhs.publishedAt > rhs.publishedAt
        }
    }

    func normalizeUnread(_ items: [Announcement]) -> [Announcement] {
        var updated: [Announcement] = []
        var hasChanges = false

        for var item in items {
            if unreadCache.contains(item.id) {
                item.isRead = false
            } else if item.isRead == false {
                unreadCache.insert(item.id)
                hasChanges = true
            }
            updated.append(item)
        }

        if hasChanges {
            persistUnreadCache()
        }

        return updated
    }

    func persistUnreadCache() {
        let ids = Array(unreadCache)
        userDefaults.set(ids, forKey: unreadCacheKey)
    }

    static func restoreUnreadCache(from userDefaults: UserDefaults, key: String) -> Set<String> {
        if let stored = userDefaults.array(forKey: key) as? [String] {
            return Set(stored)
        }
        return []
    }
}
