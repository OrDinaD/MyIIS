//
//  MyIISDataStore.swift
//  MyIIS
//
import Foundation

struct MyIISSharedData: Codable, Sendable {
    var userGroup: String?
    var averageScore: Double?
    var unexcusedAbsences: Int?
    var updatedAt: Date
}

enum MyIISDataStore {
    private enum Key {
        static let sharedData = "myiis_shared_data"
    }

    private static var defaults: UserDefaults? {
        let identifier = "group.com.OrDinaD.MyIIS"
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil else {
            return nil
        }
        return UserDefaults(suiteName: identifier)
    }

    static func update(
        userGroup: String? = nil,
        averageScore: Double? = nil,
        unexcusedAbsences: Int? = nil
    ) {
        var current = loadData() ?? MyIISSharedData(updatedAt: Date())

        if let userGroup = userGroup { current.userGroup = userGroup }
        if let averageScore = averageScore { current.averageScore = averageScore }
        if let unexcusedAbsences = unexcusedAbsences { current.unexcusedAbsences = unexcusedAbsences }

        current.updatedAt = Date()
        save(current)
    }

    static func save(_ data: MyIISSharedData) {
        guard let defaults else { return }
        if let encoded = try? JSONEncoder().encode(data) {
            _ = UserDefaultsPayloadStore.save(encoded, forKey: Key.sharedData, in: defaults)
        }
    }

    static func loadData() -> MyIISSharedData? {
        guard let defaults, let data = UserDefaultsPayloadStore.load(forKey: Key.sharedData, from: defaults) else { return nil }
        return try? JSONDecoder().decode(MyIISSharedData.self, from: data)
    }

    static func clear() {
        defaults?.removeObject(forKey: Key.sharedData)
    }
}
