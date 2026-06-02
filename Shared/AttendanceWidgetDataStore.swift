//
//  AttendanceWidgetDataStore.swift
//  MyIIS
//
import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Shared app group identifier used by the main app and the widget extension.
enum AppGroup {
    /// Update this identifier to match the App Group configured in Xcode.
    static let identifier = "group.com.OrDinaD.MyIIS"
}

/// Snapshot of the current month's unexcused omission hours used by the widget.
struct AttendanceWidgetSnapshot: Codable, Sendable {
    let monthTitle: String
    let unexcusedHours: Int
    let updatedAt: Date
}

/// Persists the latest attendance snapshot so WidgetKit can render without
/// duplicating network calls or depending on session state inside the extension.
enum AttendanceWidgetDataStore {
    private enum Key {
        static let snapshot = "attendance_snapshot"
    }

    private static var defaults: UserDefaults? {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) != nil else {
            return nil
        }
        return UserDefaults(suiteName: AppGroup.identifier)
    }

    /// Saves snapshot data that was fetched inside the main app.
    static func save(_ snapshot: AttendanceWidgetSnapshot) {
        guard let defaults else { return }
        do {
            let data = try JSONEncoder().encode(snapshot)
            _ = UserDefaultsPayloadStore.save(data, forKey: Key.snapshot, in: defaults)
        } catch {
            assertionFailure("Failed to encode AttendanceWidgetSnapshot: \(error)")
        }
    }

    /// Loads the cached snapshot for the widget.
    static func loadSnapshot() -> AttendanceWidgetSnapshot? {
        guard
            let defaults,
            let data = UserDefaultsPayloadStore.load(forKey: Key.snapshot, from: defaults)
        else {
            return nil
        }

        return try? JSONDecoder().decode(AttendanceWidgetSnapshot.self, from: data)
    }

    /// Removes cached data (for example, after logout) and refreshes timelines.
    static func clear() {
        guard let defaults else { return }
        defaults.removeObject(forKey: Key.snapshot)
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: AttendanceWidgetConstants.kind)
#endif
    }
}
