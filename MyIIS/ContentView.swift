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
    @StateObject private var router = AppRouter.shared
    @State private var showSplash = true

    var body: some View {
        Group {
            // Динамически показываем нужный экран в зависимости от состояния авторизации
            if authService.currentUser != nil {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .redacted(reason: showSplash ? .placeholder : [])
        .allowsHitTesting(!showSplash)
        .onAppear {
            // Скелетон (полосочки вместо текста) для эффекта мгновенной загрузки
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.4)) {
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
