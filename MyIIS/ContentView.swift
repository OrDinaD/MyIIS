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
    @AppStorage(FirstLaunchView.completionKey) private var hasCompletedFirstLaunch = false

    var body: some View {
        Group {
            if authService.currentUser != nil {
                MainTabView()
            } else if hasCompletedFirstLaunch {
                UnauthorizedTabView()
            } else {
                FirstLaunchView {
                    hasCompletedFirstLaunch = true
                }
            }
        }
        .reduceMotionSensitive()
        .onAppear {
            if authService.currentUser != nil {
                hasCompletedFirstLaunch = true
            }
        }
        .onChange(of: authService.currentUser != nil) { _, isSignedIn in
            if isSignedIn {
                hasCompletedFirstLaunch = true
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
