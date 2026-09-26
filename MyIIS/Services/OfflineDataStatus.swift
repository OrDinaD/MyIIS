import Foundation
import Network
import Observation

@Observable
@MainActor
final class OfflineDataStatus {
    static let shared = OfflineDataStatus()
    private(set) var isOffline = false
    private var staleEndpoints: Set<String> = []
    private let monitor = NWPathMonitor()

    var shouldWarn: Bool { isOffline || !staleEndpoints.isEmpty }

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let offline = path.status != .satisfied
            Task { @MainActor [weak self] in
                self?.isOffline = offline
            }
        }
        monitor.start(queue: DispatchQueue(label: "MyIIS.connectivity"))
    }

    func usedCache(for url: URL?) {
        if let url { staleEndpoints.insert(url.absoluteString) }
    }

    func reset() {
        staleEndpoints.removeAll()
    }

    func refreshed(_ url: URL?) {
        if let url { staleEndpoints.remove(url.absoluteString) }
    }
}
