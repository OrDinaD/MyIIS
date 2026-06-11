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
        .blur(radius: showSplash ? 20 : 0)
        .scaleEffect(showSplash ? 1.05 : 1.0)
        .allowsHitTesting(!showSplash)
        .onAppear {
            // Эффект молниеносного запуска: экран размыт и немного увеличен, затем фокусируется
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
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
