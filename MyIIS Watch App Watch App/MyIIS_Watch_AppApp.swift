import SwiftUI

@main
struct MyIIS_Watch_App_Watch_AppApp: App {
    @StateObject private var scheduleReceiver = WatchScheduleReceiver.shared

    init() {
        WatchScheduleReceiver.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(receiver: scheduleReceiver)
        }
    }
}
