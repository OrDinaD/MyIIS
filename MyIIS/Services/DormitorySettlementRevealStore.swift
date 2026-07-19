import Foundation

enum DormitorySettlementRevealStore {
    private static let pendingKeyPrefix = "DormitorySettlementReveal.pending."

    static func pendingApplicationID(
        for userID: Int?,
        userDefaults: UserDefaults = .standard
    ) -> Int? {
        if let userID,
           let value = userDefaults.object(forKey: key(for: userID)) as? Int {
            return value
        }

        return userDefaults.object(forKey: anonymousKey) as? Int
    }

    static func markPending(
        applicationID: Int,
        for userID: Int?,
        userDefaults: UserDefaults = .standard
    ) {
        userDefaults.set(applicationID, forKey: key(for: userID))
    }

    static func markRevealed(
        applicationID: Int,
        for userID: Int?,
        userDefaults: UserDefaults = .standard
    ) {
        let keys = [key(for: userID), anonymousKey]
        for key in Set(keys) where userDefaults.object(forKey: key) as? Int == applicationID {
            userDefaults.removeObject(forKey: key)
        }
    }

    static func clearPending(
        for userID: Int?,
        userDefaults: UserDefaults = .standard
    ) {
        userDefaults.removeObject(forKey: key(for: userID))
        if userID != nil {
            userDefaults.removeObject(forKey: anonymousKey)
        }
    }

    private static var anonymousKey: String {
        pendingKeyPrefix + "anonymous"
    }

    private static func key(for userID: Int?) -> String {
        guard let userID else { return anonymousKey }
        return pendingKeyPrefix + "user-\(userID)"
    }
}
