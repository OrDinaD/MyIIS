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
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService) // Внедряем его в окружение
                .onChange(of: scenePhase) { _, phase in
                    handleScenePhaseChange(phase)
                }
        }
        .commands {
            AppSceneCommands()
        }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            guard authService.isSessionReady, !authService.isLoading else { return }
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
        AcademicChangeNotificationService.shared.configureAtLaunch()
        return true
    }
}
