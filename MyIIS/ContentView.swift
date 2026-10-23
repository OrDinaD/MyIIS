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
    @State private var isOfflineNoticeDismissed = false
    @State private var showsOfflineDetails = false
    @State private var showsPasswordRecovery = false
    @AppStorage(FirstLaunchView.completionKey) private var hasCompletedFirstLaunch = false

    private func offlineNoticeText(_ key: String) -> String {
        NSLocalizedString(key, tableName: "OfflineNotice", comment: "")
    }

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
            if OfflineDataStatus.shared.shouldWarn, !isOfflineNoticeDismissed {
                HStack(spacing: 8) {
                    Button {
                        showsOfflineDetails = true
                    } label: {
                        Label(offlineNoticeText("saved_data"), systemImage: "wifi.exclamationmark")
                            .font(.caption)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(offlineNoticeText("details_hint"))
                    Button {
                        isOfflineNoticeDismissed = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(offlineNoticeText("dismiss"))
                }
                .foregroundStyle(.secondary)
                .padding(.leading, 16)
                .background(.regularMaterial)
                .accessibilityIdentifier("offlineDataBanner")
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if authService.isPasswordExpired {
                Button {
                    showsPasswordRecovery = true
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("password_recovery_expired")
                            .foregroundStyle(.primary)
                        Text("password_recovery_title")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                }
                .buttonStyle(.plain)
                .background(.regularMaterial)
                .accessibilityIdentifier("passwordExpiredBanner")
            }
        }
        .sheet(isPresented: $showsPasswordRecovery) {
            PasswordRecoveryView(authService: authService, username: authService.recoveryUsername)
        }
        .alert(offlineNoticeText("saved_data"), isPresented: $showsOfflineDetails) {
            Button(NSLocalizedString("common_done", value: "Готово", comment: "")) {}
        } message: {
            Text(LocalizedStringKey("offline_saved_data_warning"))
        }
        .onChange(of: OfflineDataStatus.shared.shouldWarn) { _, shouldWarn in
            if !shouldWarn { isOfflineNoticeDismissed = false }
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
