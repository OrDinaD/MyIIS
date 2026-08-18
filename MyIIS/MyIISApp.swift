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
        if let snapshot = ClassScheduleWidgetDataStore.loadSnapshot() {
            WatchScheduleConnectivityService.shared.send(snapshot)
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                ScreenshotBrandOverlay()
            }
            .environmentObject(authService) // Внедряем его в окружение
            .onAppear {
                handlePendingAppIntentNavigation()
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
        return true
    }
}
