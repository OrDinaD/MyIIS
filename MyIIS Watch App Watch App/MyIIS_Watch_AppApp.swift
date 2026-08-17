import SwiftUI

// Target-generated app type keeps the product name used by Xcode.
@main
// swiftlint:disable:next type_name
struct MyIIS_Watch_App_Watch_AppApp: App {
    @StateObject private var scheduleReceiver = WatchScheduleReceiver.shared

    init() {
        WatchScheduleReceiver.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(receiver: scheduleReceiver)
        }
        .backgroundTask(.watchConnectivity) {
            await WatchScheduleReceiver.shared.activate()
        }
    }
}
