import XCTest
@testable import MyIIS

final class GroupModelsTests: XCTestCase {

    func testPhoneFormattingProducesReadableFormat() {
        let contact = ContactItem(type: .phone, value: "+375291234567")
        XCTAssertEqual(contact.formattedValue, "+375 (29) 123-45-67")
    }

    func testMemberMatchingUsesContactsAndName() {
        let contacts = [
            ContactItem(type: .phone, value: "+375291112233"),
            ContactItem(type: .email, value: "student@example.com")
        ]
        let member = GroupMember(
            id: 1,
            firstName: "Мария",
            lastName: "Сидорова",
            middleName: "Александровна",
            role: .student,
            contacts: contacts
        )

        XCTAssertTrue(member.matches(searchText: "Сидорова"))
        XCTAssertTrue(member.matches(searchText: "1122"))
        XCTAssertTrue(member.matches(searchText: "example"))
        XCTAssertFalse(member.matches(searchText: "Несуществующий"))
    }
}
