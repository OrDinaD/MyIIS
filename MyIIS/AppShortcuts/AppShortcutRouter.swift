//
//  AppShortcutRouter.swift
//  MyIIS
//
//  Created by OpenAI Assistant on 11.03.2026.
//

import UIKit
import Combine

enum AppShortcut: String, Identifiable {
    case addAttendanceWidget = "com.OrDinaD.MyIIS.shortcuts.addWidget"

    var id: String { rawValue }
}

@MainActor
final class AppShortcutRouter: ObservableObject {
    static let shared = AppShortcutRouter()

    @Published var presentedShortcut: AppShortcut?

    private init() {}

    func handle(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let shortcut = AppShortcut(rawValue: shortcutItem.type) else { return false }
        presentedShortcut = shortcut
        return true
    }
}
