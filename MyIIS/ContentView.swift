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
    @ObservedObject private var router = AppRouter.shared

    var body: some View {
        Group {
            // Динамически показываем нужный экран в зависимости от состояния авторизации
            if authService.currentUser != nil {
                MainTabView()
            } else {
                UnauthorizedTabView()
            }
        }
        .reduceMotionSensitive()
        .onOpenURL { url in
            router.handleURL(url)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationService.shared)
}
