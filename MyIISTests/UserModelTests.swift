@testable import MyIIS
import XCTest

@MainActor
final class UserModelTests: XCTestCase {
    func testFullNameInitialsAndPhotoURL() {
        let user = makeUser(photo: "https://example.com/photo.png")

        XCTAssertEqual(user.fullName, "Иванов Иван Иванович")
        XCTAssertEqual(user.initials, "ИИ")
        XCTAssertEqual(user.photoURL?.absoluteString, "https://example.com/photo.png")
    }

    func testDisplayRatingRespectsSettingsVisibility() {
        let hidden = makeUser(settings: UserSettings(isPublicProfile: true, isSearchJob: false, isShowRating: false))
        let shown = makeUser(settings: UserSettings(isPublicProfile: true, isSearchJob: false, isShowRating: true))

        XCTAssertEqual(hidden.displayRating, 0)
        XCTAssertEqual(shown.displayRating, shown.rating)
    }

    func testUpdatingSettingsReturnsUpdatedCopy() {
        let original = makeUser(settings: .default)
        let updatedSettings = UserSettings(isPublicProfile: false, isSearchJob: true, isShowRating: false)

        let updated = original.updatingSettings(updatedSettings)

        XCTAssertEqual(updated.settings, updatedSettings)
        XCTAssertEqual(updated.id, original.id)
        XCTAssertEqual(updated.education, original.education)
        XCTAssertEqual(updated.skills, original.skills)
    }

    private func makeUser(photo: String? = nil, settings: UserSettings = .default) -> User {
        User(
            id: 1,
            firstName: "Иван",
            lastName: "Иванов",
            middleName: "Иванович",
            belarusianFirstName: nil,
            belarusianLastName: nil,
            belarusianMiddleName: nil,
            birthDay: "01.01.2000",
            email: "ivan@example.com",
            phone: "+375291112233",
            photo: photo,
            summary: nil,
            rating: 9,
            education: Education(faculty: "ФКП", course: 3, speciality: "ПОИТ", group: "123456"),
            skills: [UserSkill(id: 1, name: "Swift")],
            references: [UserReference(id: 1, name: "telegram", reference: "https://t.me/user")],
            settings: settings
        )
    }
}
