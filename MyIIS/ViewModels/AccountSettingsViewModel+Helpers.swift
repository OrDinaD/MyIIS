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

    func formatDate(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "—" }
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        if let date = parser.date(from: raw) {
            let output = DateFormatter()
            output.locale = Locale(identifier: "ru_RU")
            output.dateFormat = "dd.MM.yyyy"
            return output.string(from: date)
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
        return UIImage(data: data)
    }

    func isPasswordValid(_ password: String) -> Bool {
        let predicate = NSPredicate(format: "SELF MATCHES %@", passwordRegex)
        let login = authService.currentUser?.id.description ?? ""
        return predicate.evaluate(with: password)
            && !password.localizedCaseInsensitiveContains(login)
    }

    func showError(_ title: String, _ message: String) {
        alert = AlertMessage(title: title, message: message)
    }
}
