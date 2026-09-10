@testable import MyIIS
import XCTest

@MainActor
final class AccountSettingsModelsTests: XCTestCase {

    func testAccountSettingsTab() {
        XCTAssertEqual(AccountSettingsTab.password.id, "password")
        XCTAssertEqual(AccountSettingsTab.password.icon, "lock")
        XCTAssertEqual(AccountSettingsTab.password.title, NSLocalizedString("settings_tab_password", comment: ""))

        XCTAssertEqual(AccountSettingsTab.contacts.id, "contacts")
        XCTAssertEqual(AccountSettingsTab.contacts.icon, "phone")
        XCTAssertEqual(AccountSettingsTab.contacts.title, NSLocalizedString("settings_tab_contacts", comment: ""))

        XCTAssertEqual(AccountSettingsTab.photo.id, "photo")
        XCTAssertEqual(AccountSettingsTab.photo.icon, "camera")
        XCTAssertEqual(AccountSettingsTab.photo.title, NSLocalizedString("settings_tab_photo", comment: ""))
    }

    func testContactTypeRawValues() {
        XCTAssertEqual(ContactType.mobilePhone.rawValue, 4)
        XCTAssertEqual(ContactType.email.rawValue, 6)
    }

    func testContactDTODecoding() throws {
        let json = """
        {
            "id": 1,
            "contactValue": "test@example.com",
            "contactTypeId": 6,
            "confirmed": true,
            "codeExpirationTime": "2023-01-01T12:00:00Z"
        }
        """
        let data = Data(json.utf8)
        let contact = try JSONDecoder().decode(ContactDTO.self, from: data)

        XCTAssertEqual(contact.id, 1)
        XCTAssertEqual(contact.contactValue, "test@example.com")
        XCTAssertEqual(contact.contactTypeId, 6)
        XCTAssertTrue(contact.confirmed)
        XCTAssertEqual(contact.codeExpirationTime, "2023-01-01T12:00:00Z")
    }

    func testContactSettingsDTODecoding() throws {
        let json = """
        {
            "contactDtoList": [],
            "mobilePhoneAttempts": 3,
            "emailAttempts": 0,
            "contactBanExpiredTime": null
        }
        """
        let data = Data(json.utf8)
        let settings = try JSONDecoder().decode(ContactSettingsDTO.self, from: data)

        XCTAssertEqual(settings.contactDtoList.count, 0)
        XCTAssertEqual(settings.mobilePhoneAttempts, 3)
        XCTAssertEqual(settings.emailAttempts, 0)
        XCTAssertNil(settings.contactBanExpiredTime)
    }

    func testPasswordValidation() {
        let viewModel = AccountSettingsViewModel()

        XCTAssertTrue(viewModel.isPasswordValid("Abcdef1!"))
        XCTAssertTrue(viewModel.isPasswordValid("P@ssw0rd2026#Valid"))

        // Too short (< 8)
        XCTAssertFalse(viewModel.isPasswordValid("Ab1!"))
        // Too long (> 30)
        XCTAssertFalse(viewModel.isPasswordValid("A1!" + String(repeating: "a", count: 28)))
        // Missing uppercase
        XCTAssertFalse(viewModel.isPasswordValid("abcdef1!"))
        // Missing lowercase
        XCTAssertFalse(viewModel.isPasswordValid("ABCDEF1!"))
        // Missing digit
        XCTAssertFalse(viewModel.isPasswordValid("Abcdefg!"))
        // Missing special char
        XCTAssertFalse(viewModel.isPasswordValid("Abcdef12"))
        // Disallowed char (e.g. whitespace or Cyrillic)
        XCTAssertFalse(viewModel.isPasswordValid("Abcdef1! "))
        XCTAssertFalse(viewModel.isPasswordValid("Abcdef1!Пароль"))
    }
}
