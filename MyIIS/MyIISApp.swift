//
//  MyIISApp.swift
//  MyIIS
//
//  Created by Влад on 13.10.25.
//

import SwiftUI
import UIKit

@main
struct MyIISApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    /// Создаем и удерживаем экземпляр сервиса аутентификации
    @StateObject private var authService = AuthenticationService.shared

    init() {
        AppTheme.configureAppearances()
        WatchScheduleConnectivityService.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                ScreenshotBrandOverlay()
            }
            .environmentObject(authService) // Внедряем его в окружение
            .task(priority: .utility) {
                if let snapshot = ClassScheduleWidgetDataStore.loadSnapshot() {
                    WatchScheduleConnectivityService.shared.send(snapshot)
                }
            }
            .onAppear {
                handlePendingAppIntentNavigation()
            }
            .task(id: authService.currentUser?.education.group) {
                await WidgetScheduleRefreshService.shared.updateAccountGroup(authService.currentUser?.education.group)
                await RemoteNotificationService.shared.registerOnGateway()
            }
            .onChange(of: scenePhase) { _, phase in
                handleScenePhaseChange(phase)
            }
        }
        .commands {
            AppSceneCommands()
        }
    }

    private func handlePendingAppIntentNavigation() {
        guard let section = AppIntentNavigationStore.takePendingSection() else {
            return
        }
        AppRouter.shared.navigate(to: section)
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            handlePendingAppIntentNavigation()
            Task {
                async let widgetRefresh: Void = WidgetScheduleRefreshService.shared.refresh()
                async let registration: Void = RemoteNotificationService.shared.registerOnGateway()
                await ScheduleNotificationMonitorService.shared.checkForUpdates()
                await registration
                await widgetRefresh
            }
            guard authService.isSessionReady,
                  !authService.isLoading,
                  !authService.isRestoringSession else { return }
            AcademicChangeNotificationService.shared.checkWhenAppBecomesActive()
        case .background:
            AcademicChangeNotificationService.shared.scheduleBackgroundRefresh()
        case .inactive:
            break
        @unknown default:
            break
        }
    }

}

// MARK: - App Delegate

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        CrashDiagnosticManager.shared.start()
        AcademicChangeNotificationService.shared.configureAtLaunch()
        RemoteNotificationService.shared.requestAuthorizationAndRegister()
        Task {
            await ScheduleNotificationMonitorService.shared.checkForUpdates()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        RemoteNotificationService.shared.handleDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        LogService.shared.log("⚠️ Remote notification registration failed: \(error.localizedDescription)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            let result = await RemoteNotificationService.shared.handleRemoteNotification(userInfo)
            completionHandler(result)
        }
    }
}
