//
//  AccountSettingsViewModel.swift
//  MyIIS
//
import Combine
import Foundation
import SwiftUI
import UIKit

enum AccountSettingsImagePolicy {
    static let maxProfilePhotoPixelSize: CGFloat = 1_024
    static let jpegCompressionQuality: CGFloat = 0.86
}

@MainActor
final class AccountSettingsViewModel: ObservableObject {
    struct AlertMessage: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private struct Snapshot {
        let lastPasswordChangeDate: String
        let passwordAttemptsLeft: Int
        let passwordBanExpiredTime: String?
        let contacts: [ContactDTO]
        let phoneValue: String
        let phoneConfirmed: Bool
        let emailValue: String
        let emailConfirmed: Bool
        let mobileAttempts: Int
        let emailAttempts: Int
        let contactBanExpiredTime: String?
        let canEditContacts: Bool
        let photoImage: UIImage?
        let photoURL: URL?
        let showPhoto: Bool
    }

    private static var cachedSnapshot: Snapshot?

    @Published var selectedTab: AccountSettingsTab = .password
    @Published var isLoading = false
    @Published var alert: AlertMessage?

    @Published var lastPasswordChangeDate: String = "—"
    @Published var passwordAttemptsLeft: Int = 0
    @Published var passwordBanExpiredTime: String?

    @Published var oldPassword = ""
    @Published var newPassword = ""
    @Published var confirmPassword = ""
    @Published var isChangingPassword = false

    @Published var phoneValue = ""
    @Published var phoneConfirmed = false
    @Published var emailValue = ""
    @Published var emailConfirmed = false
    @Published var mobileAttempts = 0
    @Published var emailAttempts = 0
    @Published var contactBanExpiredTime: String?
    @Published var isUpdatingContact = false

    @Published var isConfirmSheetPresented = false
    @Published var confirmationCode = ""
    @Published var confirmationTargetDescription = ""
    @Published var isSendingCode = false
    @Published var isConfirmingCode = false

    @Published var photoImage: UIImage?
    @Published var photoURL: URL?
    @Published var showPhoto = false
    @Published var isUploadingPhoto = false
    @Published var isUpdatingShowPhoto = false
    @Published var canEditContacts = true // Default to true, or add logic here if needed

    private let service: AccountSettingsService
    let authService: AuthenticationService
    var contacts: [ContactDTO] = []
    private var pendingConfirmationContactId: Int?

    let passwordRegex =
        #"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!-/:-@[-`{-~])[A-Za-z\d!-/:-@[-`{-~]{8,30}$"#

    init(
        service: AccountSettingsService? = nil,
        authService: AuthenticationService? = nil
    ) {
        self.service = service ?? AccountSettingsService()
        self.authService = authService ?? .shared

        if let snapshot = Self.cachedSnapshot {
            applySnapshot(snapshot)
        } else {
            self.photoURL = self.authService.currentUser?.photoURL
        }
    }

    var hasVisibleSettingsContent: Bool {
        Self.cachedSnapshot != nil
            || photoImage != nil
            || photoURL != nil
            || !contacts.isEmpty
            || lastPasswordChangeDate != "—"
    }

    func load() async {
        guard !isLoading else { return }

        let shouldShowLoadError = !hasVisibleSettingsContent
        isLoading = true
        defer { isLoading = false }

        do {
            async let lastPasswordDate = service.fetchLastPasswordChange()
            async let passwordAttempts = service.fetchPasswordAttempts()
            async let contactsData = service.fetchContacts()
            async let photoBase64 = service.fetchPhotoBase64()
            async let showPhotoValue = service.fetchShowPhoto()

            lastPasswordChangeDate = formatDate(try await lastPasswordDate)

            let attemptsData = try await passwordAttempts
            passwordAttemptsLeft = attemptsData.passwordAttempts
            passwordBanExpiredTime = attemptsData.passwordBanExpiredTime

            let contactsResult = try await contactsData
            applyContacts(contactsResult)

            if let base64 = try await photoBase64, let decoded = decodeBase64Image(base64) {
                photoImage = decoded
            }

            showPhoto = try await showPhotoValue
            saveSnapshot()
        } catch {
            if shouldShowLoadError {
                showError("Ошибка загрузки", error.localizedDescription)
            }
        }
    }

    func changePassword() async {
        guard !isChangingPassword else { return }
        guard oldPassword != newPassword else {
            showError("Ошибка", "Новый пароль не должен совпадать со старым.")
            return
        }
        guard newPassword == confirmPassword else {
            showError("Ошибка", "Пароли не совпадают.")
            return
        }
        guard isPasswordValid(newPassword) else {
            showError("Ошибка", "Пароль не соответствует требованиям.")
            return
        }

        isChangingPassword = true
        defer { isChangingPassword = false }

        do {
            try await service.changePassword(oldPassword: oldPassword, newPassword: newPassword)
            oldPassword = ""
            newPassword = ""
            confirmPassword = ""

            let attempts = try await service.fetchPasswordAttempts()
            passwordAttemptsLeft = attempts.passwordAttempts
            passwordBanExpiredTime = attempts.passwordBanExpiredTime

            lastPasswordChangeDate = formatDate(try await service.fetchLastPasswordChange())
            saveSnapshot()
            alert = AlertMessage(title: "Готово", message: "Пароль успешно изменен.")
        } catch {
            if let attempts = try? await service.fetchPasswordAttempts() {
                passwordAttemptsLeft = attempts.passwordAttempts
                passwordBanExpiredTime = attempts.passwordBanExpiredTime
            }
            showError("Ошибка", error.localizedDescription)
        }
    }

    func updateContact(type: ContactType, value: String) async {
        guard !isUpdatingContact else { return }
        guard let contact = contact(for: type) else { return }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            showError("Ошибка", "Поле контакта не может быть пустым.")
            return
        }

        isUpdatingContact = true
        defer { isUpdatingContact = false }

        do {
            try await service.updateContact(
                ContactUpdateRequest(
                    id: contact.id,
                    contactTypeId: contact.contactTypeId,
                    contactValue: trimmedValue
                )
            )
            _ = try await service.sendContactConfirmation(contactId: contact.id)

            pendingConfirmationContactId = contact.id
            confirmationCode = ""
            confirmationTargetDescription = trimmedValue
            isConfirmSheetPresented = true

            alert = AlertMessage(
                title: "Код отправлен",
                message: "Код подтверждения отправлен на \(trimmedValue)."
            )
        } catch {
            showError("Ошибка обновления контакта", error.localizedDescription)
        }
    }

    func confirmPendingContact() async {
        guard !isConfirmingCode else { return }
        guard let contactId = pendingConfirmationContactId else { return }
        guard !confirmationCode.isEmpty else {
            showError("Ошибка", "Введите код подтверждения.")
            return
        }

        isConfirmingCode = true
        defer { isConfirmingCode = false }

        do {
            try await service.confirmContact(contactId: contactId, code: confirmationCode)
            let contactsData = try await service.fetchContacts()
            applyContacts(contactsData)
            saveSnapshot()
            isConfirmSheetPresented = false
            pendingConfirmationContactId = nil
            alert = AlertMessage(title: "Готово", message: "Контакт успешно подтвержден.")
        } catch {
            showError("Ошибка подтверждения", error.localizedDescription)
        }
    }

    func resendCode() async {
        guard !isSendingCode else { return }
        guard let contactId = pendingConfirmationContactId else { return }

        isSendingCode = true
        defer { isSendingCode = false }

        do {
            _ = try await service.sendContactConfirmation(contactId: contactId)
            alert = AlertMessage(title: "Код отправлен", message: "Код подтверждения отправлен повторно.")
        } catch {
            showError("Ошибка", error.localizedDescription)
        }
    }

    func updatePhoto(from imageData: Data) async {
        guard !isUploadingPhoto else { return }
        guard let image = ImageDownsampler.image(
            from: imageData,
            maxPixelSize: AccountSettingsImagePolicy.maxProfilePhotoPixelSize
        ) else {
            showError("Ошибка", "Не удалось прочитать изображение.")
            return
        }
        guard let uploadData = image.jpegData(
            compressionQuality: AccountSettingsImagePolicy.jpegCompressionQuality
        ) ?? image.pngData() else {
            showError("Ошибка", "Не удалось подготовить изображение.")
            return
        }

        isUploadingPhoto = true
        defer { isUploadingPhoto = false }

        do {
            let base64 = uploadData.base64EncodedString()
            if let returnedBase64 = try await service.changePhoto(base64: base64),
               let returnedImage = decodeBase64Image(returnedBase64) {
                photoImage = returnedImage
            } else {
                photoImage = image
            }
            saveSnapshot()
            alert = AlertMessage(title: "Готово", message: "Фото успешно обновлено.")
        } catch {
            showError("Ошибка обновления фото", error.localizedDescription)
        }
    }

    func toggleShowPhoto() async {
        guard !isUpdatingShowPhoto else { return }

        isUpdatingShowPhoto = true
        defer { isUpdatingShowPhoto = false }

        do {
            showPhoto = try await service.changeShowPhoto(!showPhoto)
            saveSnapshot()
        } catch {
            showError("Ошибка", error.localizedDescription)
        }
    }

    private func applySnapshot(_ snapshot: Snapshot) {
        lastPasswordChangeDate = snapshot.lastPasswordChangeDate
        passwordAttemptsLeft = snapshot.passwordAttemptsLeft
        passwordBanExpiredTime = snapshot.passwordBanExpiredTime
        contacts = snapshot.contacts
        phoneValue = snapshot.phoneValue
        phoneConfirmed = snapshot.phoneConfirmed
        emailValue = snapshot.emailValue
        emailConfirmed = snapshot.emailConfirmed
        mobileAttempts = snapshot.mobileAttempts
        emailAttempts = snapshot.emailAttempts
        contactBanExpiredTime = snapshot.contactBanExpiredTime
        canEditContacts = snapshot.canEditContacts
        photoImage = snapshot.photoImage
        photoURL = snapshot.photoURL ?? authService.currentUser?.photoURL
        showPhoto = snapshot.showPhoto
    }

    private func saveSnapshot() {
        Self.cachedSnapshot = Snapshot(
            lastPasswordChangeDate: lastPasswordChangeDate,
            passwordAttemptsLeft: passwordAttemptsLeft,
            passwordBanExpiredTime: passwordBanExpiredTime,
            contacts: contacts,
            phoneValue: phoneValue,
            phoneConfirmed: phoneConfirmed,
            emailValue: emailValue,
            emailConfirmed: emailConfirmed,
            mobileAttempts: mobileAttempts,
            emailAttempts: emailAttempts,
            contactBanExpiredTime: contactBanExpiredTime,
            canEditContacts: canEditContacts,
            photoImage: photoImage,
            photoURL: photoURL,
            showPhoto: showPhoto
        )
    }

}
