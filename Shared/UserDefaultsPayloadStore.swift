import Foundation

enum UserDefaultsPayloadStore {
    private static let appGroup = "group.com.OrDinaD.MyIIS"

    nonisolated(unsafe) private static let memoryCache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.countLimit = 64
        cache.totalCostLimit = 16 * 1024 * 1024
        return cache
    }()

    private static let resolvedCacheDirectory: URL? = {
        let baseDir: URL?
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
            baseDir = containerURL.appendingPathComponent("PayloadStore", isDirectory: true)
        } else {
            baseDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("PayloadStore", isDirectory: true)
        }
        if let baseDir, !FileManager.default.fileExists(atPath: baseDir.path) {
            try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        }
        return baseDir
    }()

    private static func cacheDirectory() -> URL? {
        guard let resolved = resolvedCacheDirectory else { return nil }
        if !FileManager.default.fileExists(atPath: resolved.path) {
            try? FileManager.default.createDirectory(at: resolved, withIntermediateDirectories: true)
        }
        return resolved
    }

    private static func fileURL(forKey key: String) -> URL? {
        guard let cacheDir = cacheDirectory() else { return nil }
        let safeKey = key.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
        return cacheDir.appendingPathComponent("\(safeKey).dat")
    }

    @discardableResult
    static func save(_ data: Data, forKey key: String, in defaults: UserDefaults) -> Bool {
        // Update fast memory cache immediately
        memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)

        guard let url = fileURL(forKey: key) else {
            defaults.set(data, forKey: key)
            return false
        }
        do {
            let directory = url.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            // Clean up any old data from UserDefaults only after successful file write
            defaults.removeObject(forKey: key)
            return true
        } catch {
            // Fallback to defaults to prevent data loss if disk write fails
            defaults.set(data, forKey: key)
            return false
        }
    }

    static func load(forKey key: String, from defaults: UserDefaults) -> Data? {
        // 1. Check in-memory cache first
        if let inMemory = memoryCache.object(forKey: key as NSString) {
            return inMemory as Data
        }

        // 2. Try to load from file storage
        if let url = fileURL(forKey: key), let data = try? Data(contentsOf: url) {
            memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
            return data
        }

        // 3. Migration: load from UserDefaults if it's still there
        if let oldData = defaults.data(forKey: key) {
            save(oldData, forKey: key, in: defaults)
            return oldData
        }

        return nil
    }

    static func clear(forKey key: String, from defaults: UserDefaults) {
        memoryCache.removeObject(forKey: key as NSString)
        defaults.removeObject(forKey: key)
        if let url = fileURL(forKey: key), FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func clear(prefix: String, from defaults: UserDefaults = .standard) {
        memoryCache.removeAllObjects()
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
        guard let cacheDir = cacheDirectory() else { return }
        let safePrefix = prefix.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
        if let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) {
            for file in files where file.lastPathComponent.hasPrefix(safePrefix) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    static func clearAll(in defaults: UserDefaults = .standard) {
        memoryCache.removeAllObjects()
        guard let cacheDir = cacheDirectory() else { return }
        if let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
