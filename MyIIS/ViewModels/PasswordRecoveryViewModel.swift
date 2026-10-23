import Foundation
import Observation

@Observable
@MainActor
final class PasswordRecoveryViewModel {
    enum Step {
        case contact, account, code, password, completed
    }

    var contact = ""
    var code = ""
    var newPassword = ""
    var repeatedPassword = ""
    private(set) var step = Step.contact
    private(set) var accounts: [PasswordRecoveryAccount] = []
    private(set) var selectedAccount: PasswordRecoveryAccount?
    private(set) var expiresAt: Date?
    private(set) var attempts: Int?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var didSignIn = false
    private var confirmation: PasswordRecoveryConfirmation?
    private var resolvedContact = ""
    private let service: AccountSettingsService
    private let authService: AuthenticationService
    let suggestedLogin: String

    init(
        authService: AuthenticationService,
        suggestedLogin: String = "",
        service: AccountSettingsService = AccountSettingsService()
    ) {
        self.authService = authService
        self.suggestedLogin = suggestedLogin
        self.service = service
    }

    var canSavePassword: Bool {
        guard let confirmation else { return false }
        return IISPasswordPolicy.isValid(newPassword, login: confirmation.login)
            && newPassword == repeatedPassword
    }

    func lookupAccounts() async {
        guard !isLoading else { return }
        resolvedContact = contact.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !resolvedContact.isEmpty else { return }
        await perform {
            let result = try await self.service.recoveryAccounts(contact: self.resolvedContact)
            try Task.checkCancellation()
            guard !result.isEmpty else { throw PasswordRecoveryFailure(key: "password_recovery_not_found") }
            self.accounts = result
            self.step = .account
        }
    }

    func selectAccount(_ account: PasswordRecoveryAccount) async {
        guard !isLoading else { return }
        guard !account.isBlocked else {
            errorMessage = NSLocalizedString("password_recovery_blocked", comment: "")
            return
        }
        await perform {
            let expiration = try await self.service.recoveryCodeExpiration(
                accountID: account.id, contact: self.resolvedContact
            )
            let attempts = try await self.service.recoveryRemainingAttempts(accountID: account.id)
            try Task.checkCancellation()
            self.selectedAccount = account
            self.expiresAt = expiration
            self.attempts = attempts
            self.code = ""
            self.step = .code
        }
    }

    func sendCode() async {
        guard !isLoading, let account = selectedAccount,
              (expiresAt ?? .distantPast) <= Date() else { return }
        await perform {
            let remaining = try await self.service.recoveryRemainingAttempts(accountID: account.id)
            self.attempts = remaining
            guard remaining > 0 else { throw PasswordRecoveryFailure(key: "password_recovery_blocked") }
            let seconds = try await self.service.sendRecoveryCode(accountID: account.id, contact: self.resolvedContact)
            try Task.checkCancellation()
            guard seconds > 0 else { throw APIError.invalidResponse }
            self.expiresAt = Date().addingTimeInterval(TimeInterval(seconds))
            self.code = ""
            self.attempts = max(0, remaining - 1)
        }
    }

    func confirmCode() async {
        guard !isLoading, let account = selectedAccount, !code.isEmpty else { return }
        guard let expiresAt, expiresAt > Date() else {
            errorMessage = NSLocalizedString("password_recovery_code_expired", comment: "")
            return
        }
        await perform {
            let result = try await self.service.confirmRecoveryCode(
                accountID: account.id, contact: self.resolvedContact,
                code: self.code.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            try Task.checkCancellation()
            guard result.login == account.login, !result.token.isEmpty else { throw APIError.invalidResponse }
            self.confirmation = result
            self.code = ""
            self.step = .password
        }
    }

    func savePassword() async {
        guard !isLoading, canSavePassword, let confirmation else { return }
        let password = newPassword
        await perform {
            try await self.service.setRecoveredPassword(confirmation: confirmation, password: password)
            // The mutation has succeeded. Never send it again if the subsequent sign-in fails.
            self.confirmation = nil
            self.newPassword = ""
            self.repeatedPassword = ""
            self.step = .completed
            try? CredentialStore.shared.save(StoredCredentials(username: confirmation.login, password: password))
            guard !Task.isCancelled else { return }
            self.didSignIn = await self.authService.login(username: confirmation.login, password: password)
            if !self.didSignIn {
                self.errorMessage = NSLocalizedString("password_recovery_login_later", comment: "")
            }
        }
    }

    func restart() {
        guard !isLoading else { return }
        accounts = []
        selectedAccount = nil
        confirmation = nil
        resolvedContact = ""
        code = ""
        newPassword = ""
        repeatedPassword = ""
        expiresAt = nil
        attempts = nil
        errorMessage = nil
        step = .contact
    }

    func clearSecrets() {
        confirmation = nil
        code = ""
        newPassword = ""
        repeatedPassword = ""
    }

    private func perform(_ operation: () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await operation()
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
}
