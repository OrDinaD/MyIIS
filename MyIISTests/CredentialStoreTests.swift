@testable import MyIIS
import XCTest

@MainActor
final class CredentialStoreTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        try CredentialStore.shared.clear()
    }

    override func tearDown() async throws {
        try CredentialStore.shared.clear()
        try await super.tearDown()
    }

    func testSaveAndRetrieveCredentials() throws {
        let store = CredentialStore.shared

        let initial = try store.retrieve()
        XCTAssertNil(initial)

        let creds = StoredCredentials(username: "testuser", password: "testpassword")
        try store.save(creds)

        let retrieved = try store.retrieve()
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.username, "testuser")
        XCTAssertEqual(retrieved?.password, "testpassword")
    }

    func testClearCredentials() throws {
        let store = CredentialStore.shared

        let creds = StoredCredentials(username: "user2", password: "pwd")
        try store.save(creds)

        XCTAssertNotNil(try store.retrieve())

        try store.clear()

        let afterClear = try store.retrieve()
        XCTAssertNil(afterClear)
    }

    func testErrorDescriptions() {
        let err1 = CredentialStoreError.decodingFailed
        XCTAssertEqual(err1.errorDescription, "Не удалось прочитать сохранённые учетные данные.")

        let err2 = CredentialStoreError.unexpectedStatus(errSecParam)
        XCTAssertNotNil(err2.errorDescription)
    }
}
