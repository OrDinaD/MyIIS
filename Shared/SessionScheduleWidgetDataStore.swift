//
//  SessionScheduleWidgetDataStore.swift
//  MyIIS
//
import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum SessionScheduleWidgetEventKind: String, Codable, Sendable {
    case announcement
    case exam
    case consultation
    case other
}

struct SessionScheduleWidgetSnapshot: Codable, Sendable {
    let groupName: String
    let startDate: Date?
    let endDate: Date?
    let events: [Event]
    let updatedAt: Date

    struct Event: Codable, Identifiable, Sendable {
        let id: String
        let date: Date?
        let startTime: String
        let endTime: String
        let title: String
        let subtitle: String?
        let location: String?
        let kind: SessionScheduleWidgetEventKind
    }
}

enum SessionScheduleWidgetConstants {
    static let kind = "com.OrDinaD.MyIIS.sessionSchedule"
}

enum SessionScheduleWidgetDataStore {
    private enum Key {
        static let snapshot = "session_schedule_widget_snapshot_v1"
    }

    private static var defaults: UserDefaults? {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) != nil else {
            return nil
        }
        return UserDefaults(suiteName: AppGroup.identifier)
    }

    static func save(_ snapshot: SessionScheduleWidgetSnapshot) {
        guard let defaults else { return }
        do {
            let data = try JSONEncoder().encode(snapshot)
            _ = UserDefaultsPayloadStore.save(data, forKey: Key.snapshot, in: defaults)
#if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: SessionScheduleWidgetConstants.kind)
#endif
        } catch {
            assertionFailure("Failed to encode SessionScheduleWidgetSnapshot: \(error)")
        }
    }

    static func loadSnapshot() -> SessionScheduleWidgetSnapshot? {
        guard let defaults,
              let data = UserDefaultsPayloadStore.load(forKey: Key.snapshot, from: defaults) else {
            return nil
        }
        return try? JSONDecoder().decode(SessionScheduleWidgetSnapshot.self, from: data)
    }

    static func clear() {
        guard let defaults else { return }
        defaults.removeObject(forKey: Key.snapshot)
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: SessionScheduleWidgetConstants.kind)
#endif
    }
}
