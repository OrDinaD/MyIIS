import SwiftUI

struct PasswordRecoveryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: PasswordRecoveryViewModel
    @State private var operation: Task<Void, Never>?

    init(authService: AuthenticationService, username: String) {
        _model = State(initialValue: PasswordRecoveryViewModel(
            authService: authService, suggestedLogin: username
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                stepContent
                if let error = model.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if model.isLoading {
                    Section {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel(Text("password_recovery_loading"))
                    }
                }
            }
            .disabled(model.isLoading)
            .navigationTitle(Text("password_recovery_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_close") { dismiss() }
                        .disabled(model.isLoading)
                }
            }
            .interactiveDismissDisabled(model.isLoading)
            .onChange(of: model.didSignIn) { _, signedIn in
                if signedIn { dismiss() }
            }
            .onDisappear {
                operation?.cancel()
                model.clearSecrets()
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch model.step {
        case .contact:
            contactSection
        case .account:
            accountSection
        case .code:
            codeSection
        case .password:
            passwordSection
        case .completed:
            Section {
                Label("password_recovery_success", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
                Text("password_recovery_success_description")
                Button("common_close") { dismiss() }
            }
        }
    }

    private var contactSection: some View {
        Section {
            TextField("password_recovery_contact", text: $model.contact)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("recoveryContactField")
            Button("password_recovery_find") {
                perform { await model.lookupAccounts() }
            }
            .disabled(model.contact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } header: {
            Text("password_recovery_contact")
        } footer: {
            Text("password_recovery_contact_description")
        }
    }

    private var accountSection: some View {
        Section {
            ForEach(model.accounts) { account in
                Button {
                    perform { await model.selectAccount(account) }
                } label: {
                    HStack {
                        Text(account.login)
                        Spacer()
                        if account.login == model.suggestedLogin {
                            Image(systemName: "person.crop.circle")
                                .accessibilityHidden(true)
                        }
                        Image(systemName: account.isBlocked ? "lock" : "chevron.right")
                            .accessibilityHidden(true)
                    }
                }
            }
            Button("password_recovery_other_contact") { model.restart() }
        } header: {
            Text("password_recovery_choose_account")
        }
    }

    private var codeSection: some View {
        Section {
            if let account = model.selectedAccount {
                LabeledContent("login_username_label", value: account.login)
            }
            Text(model.contact)
                .foregroundStyle(.secondary)
            TextField("password_recovery_code", text: $model.code)
                .textContentType(.oneTimeCode)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("recoveryCodeField")
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let active = (model.expiresAt ?? .distantPast) > context.date
                if active, let expiresAt = model.expiresAt {
                    HStack {
                        Text("password_recovery_code_valid")
                        Text(expiresAt, style: .relative)
                            .monospacedDigit()
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                Button("password_recovery_confirm") {
                    perform { await model.confirmCode() }
                }
                .disabled(!active || model.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("password_recovery_send_code") {
                    perform { await model.sendCode() }
                }
                .disabled(active || model.attempts == 0)
            }
            if let attempts = model.attempts {
                Text(String(format: NSLocalizedString("password_recovery_attempts", comment: ""), Int64(attempts)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button("password_recovery_other_contact") { model.restart() }
        } header: {
            Text("password_recovery_code")
        } footer: {
            Text("password_recovery_code_description")
        }
    }

    private var passwordSection: some View {
        Section {
            SecureField("password_recovery_new", text: $model.newPassword)
                .textContentType(.newPassword)
                .accessibilityIdentifier("recoveryNewPasswordField")
            SecureField("password_recovery_repeat", text: $model.repeatedPassword)
                .textContentType(.newPassword)
                .accessibilityIdentifier("recoveryRepeatPasswordField")
            Button("password_recovery_save") {
                perform { await model.savePassword() }
            }
            .disabled(!model.canSavePassword)
        } header: {
            Text("password_recovery_new")
        } footer: {
            Text("password_recovery_requirements")
        }
    }

    private func perform(_ action: @escaping @MainActor () async -> Void) {
        operation?.cancel()
        operation = Task { await action() }
    }
}

#if DEBUG
#Preview {
    PasswordRecoveryView(authService: AuthenticationService(allowSessionRestore: false), username: "")
}
#endif
