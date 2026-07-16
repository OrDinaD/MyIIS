import Combine
import Foundation
import WatchConnectivity
import WidgetKit

struct WatchScheduleSnapshot: Codable, Sendable {
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
        let lessonType: String?
        let kind: Kind

        enum Kind: String, Codable, Sendable {
            case announcement
            case exam
            case consultation
            case other
        }

        func interval(calendar: Calendar = .current) -> DateInterval? {
            guard let date else { return nil }
            let startParts = startTime.split(separator: ":").compactMap { Int($0) }
            let endParts = endTime.split(separator: ":").compactMap { Int($0) }
            guard startParts.count == 2, endParts.count == 2 else { return nil }

            var startComponents = calendar.dateComponents([.year, .month, .day], from: date)
            startComponents.hour = startParts[0]
            startComponents.minute = startParts[1]
            var endComponents = startComponents
            endComponents.hour = endParts[0]
            endComponents.minute = endParts[1]

            guard let start = calendar.date(from: startComponents),
                  let end = calendar.date(from: endComponents),
                  end > start else {
                return nil
            }
            return DateInterval(start: start, end: end)
        }

        func isCurrent(at date: Date) -> Bool {
            interval()?.contains(date) == true
        }
    }

    func upcomingEvents(at date: Date) -> [Event] {
        events
            .filter { ($0.interval()?.end ?? $0.date ?? .distantPast) >= date }
            .sorted {
                ($0.interval()?.start ?? $0.date ?? .distantFuture) <
                ($1.interval()?.start ?? $1.date ?? .distantFuture)
            }
    }
}

enum WatchScheduleStore {
    nonisolated static let appGroupIdentifier = "group.com.OrDinaD.MyIIS"
    nonisolated static let snapshotKey = "watch_class_schedule_snapshot_v1"
    nonisolated static let transferKey = "classScheduleSnapshot"

    static func save(_ data: Data) throws {
        guard let defaults = appGroupDefaults else {
            throw CocoaError(.fileNoSuchFile)
        }
        _ = try JSONDecoder().decode(WatchScheduleSnapshot.self, from: data)
        defaults.set(data, forKey: snapshotKey)
    }

    static func load() -> WatchScheduleSnapshot? {
        guard let data = appGroupDefaults?.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WatchScheduleSnapshot.self, from: data)
    }

    private static var appGroupDefaults: UserDefaults? {
        guard FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) != nil else {
            return nil
        }
        return UserDefaults(suiteName: appGroupIdentifier)
    }
}

@MainActor
final class WatchScheduleReceiver: NSObject, ObservableObject {
    @Published private(set) var snapshot: WatchScheduleSnapshot?
    @Published private(set) var connectionError: String?

    override init() {
        snapshot = WatchScheduleStore.load()
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()

        if let data = session.receivedApplicationContext[WatchScheduleStore.transferKey] as? Data {
            accept(data)
        }
    }

    private func accept(_ data: Data) {
        do {
            try WatchScheduleStore.save(data)
            snapshot = WatchScheduleStore.load()
            connectionError = nil
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            connectionError = error.localizedDescription
        }
    }
}

extension WatchScheduleReceiver: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                connectionError = error.localizedDescription
                return
            }
            if let data = session.receivedApplicationContext[WatchScheduleStore.transferKey] as? Data {
                accept(data)
            }
        }
    }

#if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
#endif

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard let data = applicationContext[WatchScheduleStore.transferKey] as? Data else { return }
        Task { @MainActor in
            accept(data)
        }
    }
}
