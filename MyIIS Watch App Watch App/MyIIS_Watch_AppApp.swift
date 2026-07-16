import SwiftUI

@main
struct MyIIS_Watch_App_Watch_AppApp: App {
    @StateObject private var scheduleReceiver = WatchScheduleReceiver()

    var body: some Scene {
        WindowGroup {
            ContentView(receiver: scheduleReceiver)
                .task {
                    scheduleReceiver.activate()
                }
        }
    }
}
