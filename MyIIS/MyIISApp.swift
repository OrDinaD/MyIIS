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
    @StateObject private var shortcutRouter = AppShortcutRouter.shared

    init() {
        AppTheme.configureAppearances()
        appDelegate.register(router: shortcutRouter)
        configureQuickActions()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService) // Внедряем его в окружение
                .sheet(item: $shortcutRouter.presentedShortcut) { shortcut in
                    WidgetAddSheet(shortcut: shortcut)
                        .presentationDetents([.medium, .large])
                }
        }
    }

    private func configureQuickActions() {
        let addWidgetShortcut = UIApplicationShortcutItem(
            type: AppShortcut.addAttendanceWidget.rawValue,
            localizedTitle: "Добавить виджет",
            localizedSubtitle: "Закрепите пропуски на экране",
            icon: UIApplicationShortcutIcon(systemImageName: "rectangle.stack.badge.plus"),
            userInfo: nil
        )
        UIApplication.shared.shortcutItems = [addWidgetShortcut]
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, UIApplicationDelegate {
    private weak var shortcutRouter: AppShortcutRouter?

    func register(router: AppShortcutRouter) {
        shortcutRouter = router
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        return true
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        Task { @MainActor [weak shortcutRouter] in
            let handled = shortcutRouter?.handle(shortcutItem) ?? false
            completionHandler(handled)
        }
    }
}
