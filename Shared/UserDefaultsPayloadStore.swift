import Foundation

enum UserDefaultsPayloadStore {
    /// iOS emits runtime errors when trying to store values >= 4 MB in CFPreferences.
    /// Because of property list serialization overhead, the limit must be strictly below 4MB. 2MB is a safe limit.
    static let maxPayloadBytes = 2_000_000

    @discardableResult
    static func save(_ data: Data, forKey key: String, in defaults: UserDefaults) -> Bool {
        guard data.count < maxPayloadBytes else {
            defaults.removeObject(forKey: key)
            return false
        }

        defaults.set(data, forKey: key)
        return true
    }

    static func load(forKey key: String, from defaults: UserDefaults) -> Data? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        guard data.count < maxPayloadBytes else {
            defaults.removeObject(forKey: key)
            return nil
        }

        return data
    }
}
