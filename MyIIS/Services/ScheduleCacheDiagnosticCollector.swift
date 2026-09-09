import Foundation

nonisolated enum ScheduleCacheDiagnosticCollector {
    private struct WidgetSnapshotSummary: Sendable {
        let bytes: Int64?
        let eventCount: Int?
        let duplicateCount: Int?
        let ageSeconds: Double?
    }

    static func collect(appGroupIdentifier: String) async -> CrashDiagnosticManager.ScheduleCacheSnapshot {
        await Task.detached(priority: .utility) {
            collectSynchronously(appGroupIdentifier: appGroupIdentifier)
        }.value
    }

    private static func collectSynchronously(
        appGroupIdentifier: String
    ) -> CrashDiagnosticManager.ScheduleCacheSnapshot {
        let fileManager = FileManager.default
        let defaults = UserDefaults(suiteName: appGroupIdentifier) ?? .standard
        let selectedGroup = defaults.string(forKey: "services.schedule.lastGroup")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let payloadDirectory = payloadDirectory(
            fileManager: fileManager,
            appGroupIdentifier: appGroupIdentifier
        )
        let responseFiles = responseCacheFiles(
            payloadDirectory: payloadDirectory,
            fileManager: fileManager
        )
        let responseValues = responseFiles.compactMap {
            try? $0.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        }
        let responseAges = responseValues.compactMap {
            $0.contentModificationDate.map { max(0, Date().timeIntervalSince($0)) }
        }
        let sessionWidget = widgetSnapshot(
            key: "session_schedule_widget_snapshot_v1",
            payloadDirectory: payloadDirectory,
            defaults: defaults
        )
        let classWidget = widgetSnapshot(
            key: "class_schedule_widget_snapshot_v2",
            payloadDirectory: payloadDirectory,
            defaults: defaults
        )

        return CrashDiagnosticManager.ScheduleCacheSnapshot(
            hasSelectedGroup: selectedGroup?.isEmpty == false,
            responseCacheFileCount: responseFiles.count,
            responseCacheBytes: responseValues.reduce(Int64(0)) {
                $0 + Int64($1.fileSize ?? 0)
            },
            oldestResponseCacheAgeSeconds: responseAges.max(),
            newestResponseCacheAgeSeconds: responseAges.min(),
            sessionWidgetSnapshotBytes: sessionWidget.bytes,
            sessionWidgetEventCount: sessionWidget.eventCount,
            sessionWidgetDuplicateEventCount: sessionWidget.duplicateCount,
            sessionWidgetSnapshotAgeSeconds: sessionWidget.ageSeconds,
            classWidgetSnapshotBytes: classWidget.bytes,
            classWidgetEventCount: classWidget.eventCount,
            classWidgetDuplicateEventCount: classWidget.duplicateCount,
            classWidgetSnapshotAgeSeconds: classWidget.ageSeconds
        )
    }

    private static func payloadDirectory(
        fileManager: FileManager,
        appGroupIdentifier: String
    ) -> URL? {
        fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent("PayloadStore", isDirectory: true)
            ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
                .appendingPathComponent("PayloadStore", isDirectory: true)
    }

    private static func responseCacheFiles(
        payloadDirectory: URL?,
        fileManager: FileManager
    ) -> [URL] {
        guard let payloadDirectory else { return [] }
        let files = (try? fileManager.contentsOfDirectory(
            at: payloadDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return files.filter {
            $0.lastPathComponent.hasPrefix("ServiceEndpointsAPI.cache.")
        }
    }

    private static func widgetSnapshot(
        key: String,
        payloadDirectory: URL?,
        defaults: UserDefaults
    ) -> WidgetSnapshotSummary {
        let safeKey = key
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let fileURL = payloadDirectory?.appendingPathComponent("\(safeKey).dat")
        let data = defaults.data(forKey: key)
            ?? fileURL.flatMap { try? Data(contentsOf: $0) }
        guard let data,
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any],
              let events = dictionary["events"] as? [Any] else {
            return WidgetSnapshotSummary(
                bytes: nil,
                eventCount: nil,
                duplicateCount: nil,
                ageSeconds: nil
            )
        }

        let fingerprints = events.compactMap {
            try? JSONSerialization.data(withJSONObject: $0, options: [.sortedKeys])
        }
        let updatedAt = (dictionary["updatedAt"] as? TimeInterval)
            .map { Date(timeIntervalSinceReferenceDate: $0) }

        return WidgetSnapshotSummary(
            bytes: Int64(data.count),
            eventCount: events.count,
            duplicateCount: max(0, events.count - Set(fingerprints).count),
            ageSeconds: updatedAt.map { max(0, Date().timeIntervalSince($0)) }
        )
    }
}
