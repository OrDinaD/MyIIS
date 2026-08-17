import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

enum WatchScheduleTransfer {
    nonisolated static let snapshotKey = "classScheduleSnapshot"
    nonisolated static let clearKey = "clearClassScheduleSnapshot"
}

final class WatchScheduleConnectivityService: NSObject, @unchecked Sendable {
    static let shared = WatchScheduleConnectivityService()

#if canImport(WatchConnectivity)
    private enum PendingTransfer: Equatable {
        case snapshot(Data)
        case clear
    }

    private let session = WCSession.default
    private let lock = NSLock()
    private var pendingTransfer: PendingTransfer?
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
            pendingTransfer = .snapshot(data)
        }
        sendPendingTransferIfPossible()
#endif
    }

    func clear() {
#if canImport(WatchConnectivity) && os(iOS)
        lock.withLock {
            pendingTransfer = .clear
        }
        sendPendingTransferIfPossible()
#endif
    }

#if canImport(WatchConnectivity) && os(iOS)
    private func sendPendingTransferIfPossible() {
        guard session.activationState == .activated, session.isWatchAppInstalled else { return }
        guard let transfer = lock.withLock({ pendingTransfer }) else { return }

        let context: [String: Any]
        switch transfer {
        case let .snapshot(data):
            context = [WatchScheduleTransfer.snapshotKey: data]
        case .clear:
            context = [WatchScheduleTransfer.clearKey: true]
        }

        do {
            try session.updateApplicationContext(context)
            lock.withLock {
                if pendingTransfer == transfer {
                    pendingTransfer = nil
                }
            }
        } catch {
            assertionFailure("Failed to update Apple Watch schedule: \(error)")
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
            self?.sendPendingTransferIfPossible()
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
            self?.sendPendingTransferIfPossible()
        }
    }
#endif
}
#endif
