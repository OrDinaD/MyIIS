import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

enum WatchScheduleTransfer {
    nonisolated static let snapshotKey = "classScheduleSnapshot"
}

final class WatchScheduleConnectivityService: NSObject, @unchecked Sendable {
    static let shared = WatchScheduleConnectivityService()

#if canImport(WatchConnectivity)
    private let session = WCSession.default
    private let lock = NSLock()
    private var pendingSnapshotData: Data?
#endif

    private override init() {
        super.init()
    }

    func activate() {
#if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
#endif
    }

    func send(_ snapshot: SessionScheduleWidgetSnapshot) {
#if canImport(WatchConnectivity) && os(iOS)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        lock.withLock {
            pendingSnapshotData = data
        }
        sendPendingSnapshotIfPossible()
#endif
    }

#if canImport(WatchConnectivity) && os(iOS)
    private func sendPendingSnapshotIfPossible() {
        guard session.activationState == .activated, session.isWatchAppInstalled else { return }
        guard let data = lock.withLock({ pendingSnapshotData }) else { return }

        do {
            try session.updateApplicationContext([WatchScheduleTransfer.snapshotKey: data])
            lock.withLock {
                if pendingSnapshotData == data {
                    pendingSnapshotData = nil
                }
            }
        } catch {
            assertionFailure("Failed to send schedule to Apple Watch: \(error)")
        }
    }
#endif
}

#if canImport(WatchConnectivity)
extension WatchScheduleConnectivityService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
#if os(iOS)
        guard activationState == .activated, error == nil else { return }
        Task { @MainActor [weak self] in
            self?.sendPendingSnapshotIfPossible()
        }
#endif
    }

#if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            self?.sendPendingSnapshotIfPossible()
        }
    }
#endif
}
#endif
