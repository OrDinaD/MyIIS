//
//  ContentView.swift
//  MyIIS
//
//  Created by Влад on 13.10.25.
//

import SwiftUI

struct ContentView: View {
    /// Получаем доступ к сервису аутентификации из окружения
    @EnvironmentObject var authService: AuthenticationService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var router = AppRouter.shared
    @State private var showSplash = true

    var body: some View {
        Group {
            // Динамически показываем нужный экран в зависимости от состояния авторизации
            if authService.currentUser != nil {
                MainTabView()
            } else {
                UnauthorizedTabView()
            }
        }
        .redacted(reason: showSplash ? .placeholder : [])
        .allowsHitTesting(!showSplash)
        .reduceMotionSensitive()
        .onAppear {
            // Скелетон (полосочки вместо текста) для эффекта мгновенной загрузки
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                AccessibilitySupport.update(reduceMotion: reduceMotion, animation: .easeOut(duration: 0.4)) {
                    showSplash = false
                }
            }
        }
        .onOpenURL { url in
            router.handleURL(url)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationService.shared)
}
