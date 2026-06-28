import Foundation

enum UserDefaultsPayloadStore {
    private static let appGroup = "group.com.OrDinaD.MyIIS"

    private static func cacheDirectory() -> URL? {
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
            return containerURL.appendingPathComponent("PayloadStore", isDirectory: true)
        }
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("PayloadStore")
    }

    private static func fileURL(forKey key: String) -> URL? {
        guard let cacheDir = cacheDirectory() else { return nil }
        if !FileManager.default.fileExists(atPath: cacheDir.path) {
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        let safeKey = key.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
        return cacheDir.appendingPathComponent("\(safeKey).dat")
    }

    @discardableResult
    static func save(_ data: Data, forKey key: String, in defaults: UserDefaults) -> Bool {
        // Clean up any old data from UserDefaults to free up space (fixes the 4MB limit bug)
        defaults.removeObject(forKey: key)

        guard let url = fileURL(forKey: key) else { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func load(forKey key: String, from defaults: UserDefaults) -> Data? {
        // 1. Try to load from the new file storage
        if let url = fileURL(forKey: key), let data = try? Data(contentsOf: url) {
            return data
        }

        // 2. Migration: load from UserDefaults if it's still there
        if let oldData = defaults.data(forKey: key) {
            // Save it to disk for next time and remove from UserDefaults
            save(oldData, forKey: key, in: defaults)
            return oldData
        }

        return nil
    }
}
