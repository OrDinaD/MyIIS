import Foundation

struct GradebookCacheSnapshot: Codable {
    let markbook: MarkbookResponse
    let currentCourse: Int?
    let updatedAt: Date
}

enum GradebookCacheStore {
    private static let cacheKey = "gradebook_offline_cache_v1"

    static func load(from userDefaults: UserDefaults = .standard) -> GradebookCacheSnapshot? {
        guard let data = UserDefaultsPayloadStore.load(forKey: cacheKey, from: userDefaults) else {
            return nil
        }

        return try? JSONDecoder().decode(GradebookCacheSnapshot.self, from: data)
    }

    static func save(
        markbook: MarkbookResponse,
        currentCourse: Int?,
        updatedAt: Date,
        in userDefaults: UserDefaults = .standard
    ) {
        let snapshot = GradebookCacheSnapshot(
            markbook: markbook,
            currentCourse: currentCourse,
            updatedAt: updatedAt
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        _ = UserDefaultsPayloadStore.save(data, forKey: cacheKey, in: userDefaults)
    }
}
