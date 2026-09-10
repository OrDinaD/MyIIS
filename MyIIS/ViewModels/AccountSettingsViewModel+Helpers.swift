import UIKit

extension AccountSettingsViewModel {
    func applyContacts(_ contactsData: ContactSettingsDTO) {
        contacts = contactsData.contactDtoList
        mobileAttempts = contactsData.mobilePhoneAttempts
        emailAttempts = contactsData.emailAttempts
        contactBanExpiredTime = contactsData.contactBanExpiredTime
        canEditContacts = contactBanExpiredTime == nil || contactBanExpiredTime?.isEmpty == true

        if let phone = contacts.first(where: { $0.contactTypeId == ContactType.mobilePhone.rawValue }) {
            phoneValue = phone.contactValue
            phoneConfirmed = phone.confirmed
        }

        if let email = contacts.first(where: { $0.contactTypeId == ContactType.email.rawValue }) {
            emailValue = email.contactValue
            emailConfirmed = email.confirmed
        }
    }

    func contact(for type: ContactType) -> ContactDTO? {
        contacts.first(where: { $0.contactTypeId == type.rawValue })
    }

    nonisolated private static let parserDateFormatter: DateFormatter = {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        return parser
    }()

    nonisolated private static let outputDateFormatter: DateFormatter = {
        let output = DateFormatter()
        output.locale = .autoupdatingCurrent
        output.dateFormat = "dd.MM.yyyy"
        return output
    }()

    func formatDate(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "—" }
        if let date = Self.parserDateFormatter.date(from: raw) {
            return Self.outputDateFormatter.string(from: date)
        }
        return raw
    }

    func decodeBase64Image(_ base64: String) -> UIImage? {
        let normalized = base64
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: normalized) else {
            return nil
        }
        return ImageDownsampler.image(
            from: data,
            maxPixelSize: AccountSettingsImagePolicy.maxProfilePhotoPixelSize
        )
    }

    func isPasswordValid(_ password: String) -> Bool {
        guard password.count >= 8, password.count <= 30 else { return false }
        let hasLower = password.contains(where: { ("a"..."z").contains($0) })
        let hasUpper = password.contains(where: { ("A"..."Z").contains($0) })
        let hasDigit = password.contains(where: { ("0"..."9").contains($0) })
        let specialCharacters = Set("!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~")
        let hasSpecial = password.contains(where: { specialCharacters.contains($0) })

        let allowedCharacters = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"
        )
        let hasOnlyAllowed = password.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }

        guard hasLower, hasUpper, hasDigit, hasSpecial, hasOnlyAllowed else { return false }

        let login = authService.currentUser?.id.description ?? ""
        if !login.isEmpty && password.localizedCaseInsensitiveContains(login) {
            return false
        }
        return true
    }

    func showError(_ title: String, _ message: String) {
        alert = AlertMessage(title: title, message: message)
    }
}
