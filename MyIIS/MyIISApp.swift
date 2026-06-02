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

    /// Создаем и удерживаем экземпляр сервиса аутентификации
    @StateObject private var authService = AuthenticationService.shared

    init() {
        AppTheme.configureAppearances()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService) // Внедряем его в окружение
        }
        .commands {
            AppSceneCommands()
        }
    }

}

// MARK: - App Delegate

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        return true
    }
}
