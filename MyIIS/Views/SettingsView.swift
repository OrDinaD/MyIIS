//
//  SettingsView.swift
//  MyIIS
//
//  Created by GitHub Copilot on 13.10.25.
//

import SwiftUI

@MainActor
struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    init() {
        self.init(viewModel: SettingsViewModel())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                content
            }
            .navigationTitle("Настройки")
            .toolbar { toolbarContent }
            .sheet(isPresented: $viewModel.isPresentingChangePasswordSheet) {
                ChangePasswordSheet(viewModel: viewModel)
                    .presentationDetents([.medium])
            }
            .alert(item: $viewModel.alert) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("Ок")))
            }
        }
        .appBackground()
    }

    private var content: some View {
        VStack(spacing: 24) {
            header

            List {
                ForEach(viewModel.sections) { section in
                    Section {
                        ForEach(viewModel.items(for: section)) { item in
                            settingsRow(for: item)
                                .listRowBackground(Color.clear)
                        }
                    } header: {
                        sectionHeader(for: section)
                            .textCase(nil)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .disabled(viewModel.isSaving)
        }
        .padding(.top, 32)
        .overlay(alignment: .center) {
            if viewModel.isSaving {
                ProgressView()
                    .progressViewStyle(.circular)
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 16)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.hasPendingChanges)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isSaving)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(.linearGradient(colors: [.purple.opacity(0.8), .blue.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                .shadow(color: .purple.opacity(0.2), radius: 12, y: 10)

            Text("Управляйте своим профилем")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Text("Обновляйте данные, безопасность и уведомления в одном месте")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
        }
        .padding(.horizontal, 16)
    }

    private func sectionHeader(for section: SettingsSection) -> some View {
        HStack(spacing: 10) {
            Image(systemName: section.systemIcon)
                .font(.callout)
                .foregroundStyle(.purple)
            Text(section.title)
                .font(.headline)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func settingsRow(for item: SettingsItem) -> some View {
        switch item.accessory {
        case .toggle:
            Toggle(isOn: binding(for: item)) {
                rowLabel(for: item)
            }
            .toggleStyle(SwitchToggleStyle(tint: .purple))

        case .navigation:
            Button {
                viewModel.presentChangePassword()
            } label: {
                rowLabel(for: item)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .button:
            Button {
                // Reserved for future actions
            } label: {
                rowLabel(for: item)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .destructive:
            Button {
                viewModel.logout()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: item.systemIcon)
                        .foregroundStyle(.red)
                    Text(item.title)
                        .foregroundStyle(.red)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func rowLabel(for item: SettingsItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.systemIcon)
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func binding(for item: SettingsItem) -> Binding<Bool> {
        switch item {
        case .publicProfile:
            Binding(
                get: { viewModel.isPublicProfile },
                set: { viewModel.setToggle(for: .publicProfile, to: $0) }
            )
        case .jobSearch:
            Binding(
                get: { viewModel.isJobSearchEnabled },
                set: { viewModel.setToggle(for: .jobSearch, to: $0) }
            )
        case .showRating:
            Binding(
                get: { viewModel.isRatingVisible },
                set: { viewModel.setToggle(for: .showRating, to: $0) }
            )
        case .twoFactorAuth:
            Binding(
                get: { viewModel.isTwoFactorEnabled },
                set: { viewModel.setToggle(for: .twoFactorAuth, to: $0) }
            )
        case .academicNotifications:
            Binding(
                get: { viewModel.academicNotificationsEnabled },
                set: { viewModel.setToggle(for: .academicNotifications, to: $0) }
            )
        case .eventNotifications:
            Binding(
                get: { viewModel.eventNotificationsEnabled },
                set: { viewModel.setToggle(for: .eventNotifications, to: $0) }
            )
        case .changePassword, .logout:
            Binding.constant(false)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if viewModel.hasPendingChanges {
                Button {
                    Task { await viewModel.saveChanges() }
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Text("Сохранить")
                    }
                }
                .disabled(viewModel.isSaving)
            }
        }
    }
}

private struct ChangePasswordSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Capsule()
                    .frame(width: 48, height: 4)
                    .foregroundStyle(.secondary.opacity(0.3))
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Изменить пароль")
                        .font(.title3)
                        .fontWeight(.semibold)

                    SecureField("Текущий пароль", text: $currentPassword)
                        .textContentType(.password)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    SecureField("Новый пароль", text: $newPassword)
                        .textContentType(.newPassword)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    SecureField("Повторите новый пароль", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Text("Пароль должен содержать минимум 8 символов, цифры и буквы в разных регистрах")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 18, y: 8)
                )
                .padding(.horizontal, 24)

                Button {
                    Task {
                        await viewModel.changePassword(
                            currentPassword: currentPassword,
                            newPassword: newPassword,
                            confirmPassword: confirmPassword
                        )
                    }
                } label: {
                    Text(viewModel.isProcessingPasswordChange ? "Сохранение..." : "Сохранить пароль")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.purple.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
                .disabled(viewModel.isProcessingPasswordChange)

                Spacer()
            }
            .padding(.bottom, 16)
            .background(
                LinearGradient(
                    colors: [Color(uiColor: .systemGroupedBackground), Color(uiColor: .secondarySystemGroupedBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
        }
    }
}

#if DEBUG
private final class PreviewSettingsService: SettingsServiceProtocol {
    var currentUserSettings: UserSettings
    var currentSecuritySettings: SecuritySettings
    var currentNotificationSettings: NotificationSettings

    init(
        userSettings: UserSettings = .default,
        security: SecuritySettings = .default,
        notifications: NotificationSettings = .default
    ) {
        self.currentUserSettings = userSettings
        self.currentSecuritySettings = security
        self.currentNotificationSettings = notifications
    }

    func update(userSettings: UserSettings, security: SecuritySettings, notifications: NotificationSettings) async throws {
        currentUserSettings = userSettings
        currentSecuritySettings = security
        currentNotificationSettings = notifications
    }

    func changePassword(currentPassword: String, newPassword: String) async throws {}

    func logout() {}
}

#Preview {
    let previewService = PreviewSettingsService(
        userSettings: UserSettings(isPublicProfile: true, isSearchJob: true, isShowRating: true),
        security: SecuritySettings(isTwoFactorEnabled: true),
        notifications: NotificationSettings(academicUpdates: true, eventsAndNews: true)
    )
    return SettingsView(viewModel: SettingsViewModel(service: previewService))
}
#endif
