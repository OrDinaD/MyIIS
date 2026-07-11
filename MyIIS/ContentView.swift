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
            // Не запускаем защищённые экраны, пока silent login не подтвердил SESSION.
            if authService.isRestoringSession {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            } else if authService.currentUser != nil, authService.isSessionReady {
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
