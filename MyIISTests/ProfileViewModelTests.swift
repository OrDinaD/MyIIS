@testable import MyIIS
import XCTest

@MainActor
final class ProfileViewModelTests: XCTestCase {

    var viewModel: ProfileViewModel!
    var authService: AuthenticationService!

    override func setUp() async throws {
        try await super.setUp()
        authService = AuthenticationService(allowSessionRestore: false)
        authService.currentUser = nil
        viewModel = ProfileViewModel(authService: authService)
    }

    override func tearDown() async throws {
        viewModel = nil
        authService = nil
        try await super.tearDown()
    }

    func testUser_ReturnsCurrentUserFromAuthService() {
        // Arrange
        XCTAssertNil(viewModel.user, "User should be nil initially")

        let education = Education(faculty: "FKSIS", course: 1, speciality: "POIT", group: "123456", specialityDepartmentEducationFormId: nil)
        let user = User(
            id: 1,
            firstName: "Ivan",
            lastName: "Ivanov",
            middleName: "Ivanovich",
            belarusianFirstName: nil,
            belarusianLastName: nil,
            belarusianMiddleName: nil,
            birthDay: "01.01.2000",
            email: "ivan@example.com",
            phone: nil,
            photo: nil,
            summary: nil,
            rating: 4,
            education: education,
            skills: [],
            references: [],
            settings: UserSettings.default,
            isHeadman: false
        )

        authService.currentUser = user

        // Act & Assert
        XCTAssertNotNil(viewModel.user)
        XCTAssertEqual(viewModel.user?.firstName, "Ivan")
        XCTAssertEqual(viewModel.user?.id, 1)
    }

    func testLogout_CallsAuthServiceLogout() {
        // Arrange
        let education = Education(faculty: "FKSIS", course: 1, speciality: "POIT", group: "123456", specialityDepartmentEducationFormId: nil)
        let user = User(
            id: 1,
            firstName: "Ivan",
            lastName: "Ivanov",
            middleName: "Ivanovich",
            belarusianFirstName: nil,
            belarusianLastName: nil,
            belarusianMiddleName: nil,
            birthDay: "01.01.2000",
            email: "ivan@example.com",
            phone: nil,
            photo: nil,
            summary: nil,
            rating: 4,
            education: education,
            skills: [],
            references: [],
            settings: UserSettings.default,
            isHeadman: false
        )
        authService.currentUser = user
        XCTAssertNotNil(viewModel.user)

        // Act
        viewModel.logout()

        // Assert
        XCTAssertNil(viewModel.user, "User should be nil after logout")
    }
}
