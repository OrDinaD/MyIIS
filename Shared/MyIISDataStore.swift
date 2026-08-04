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

struct MyIISGradebookMessageSnapshot: Codable, Equatable, Sendable {
    let number: String
    let overallAverageText: String
    let updatedAt: Date
    let semesters: [Semester]

    var latestSemester: Semester? {
        semesters.last
    }

    struct Semester: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let averageText: String
        let subjects: [Subject]

        var title: String {
            String(format: NSLocalizedString("gradebook_share_semester_format", comment: ""), id)
        }
    }

    struct Subject: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let abbreviation: String
        let fullName: String
        let controlForm: String
        let grade: String
        let averageText: String
        let retakesText: String
        let dateText: String
        let teacherText: String
    }
}

enum MyIISDataStore {
    private enum Key {
        static let sharedData = "myiis_shared_data"
        static let gradebookMessageSnapshot = "myiis_gradebook_message_snapshot_v1"
    }

    private static var defaults: UserDefaults? {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) != nil else {
            return nil
        }
        return UserDefaults(suiteName: AppGroup.identifier)
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

    static func saveGradebookMessageSnapshot(_ snapshot: MyIISGradebookMessageSnapshot) {
        guard let defaults else { return }
        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
        _ = UserDefaultsPayloadStore.save(encoded, forKey: Key.gradebookMessageSnapshot, in: defaults)
    }

    static func loadGradebookMessageSnapshot() -> MyIISGradebookMessageSnapshot? {
        guard let defaults,
              let data = UserDefaultsPayloadStore.load(forKey: Key.gradebookMessageSnapshot, from: defaults)
        else {
            return nil
        }
        return try? JSONDecoder().decode(MyIISGradebookMessageSnapshot.self, from: data)
    }

    static func clear() {
        guard let defaults else { return }
        UserDefaultsPayloadStore.clear(forKey: Key.sharedData, from: defaults)
        UserDefaultsPayloadStore.clear(forKey: Key.gradebookMessageSnapshot, from: defaults)
        ClassScheduleWidgetDataStore.clear()
        SessionScheduleWidgetDataStore.clear()
    }
}
