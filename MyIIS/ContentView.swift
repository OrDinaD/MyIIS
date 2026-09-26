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
    private var router = AppRouter.shared
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
        .safeAreaInset(edge: .top, spacing: 0) {
            if OfflineDataStatus.shared.shouldWarn {
                Label("offline_saved_data_warning", systemImage: "wifi.exclamationmark")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(.regularMaterial)
                    .accessibilityIdentifier("offlineDataBanner")
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
