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

    var body: some View {
        // Динамически показываем нужный экран в зависимости от состояния авторизации
        if authService.currentUser != nil {
            MainTabView()
        } else {
            LoginView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationService.shared)
}
