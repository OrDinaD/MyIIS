@testable import MyIIS
import XCTest

@MainActor
final class NetworkSecurityPolicyTests: XCTestCase {
    func testTrustedLMSURLRequiresHTTPSAndExactHost() {
        XCTAssertTrue(NetworkSecurityPolicy.isTrustedLMSURL(URLFactory.require("https://lms.bsuir.by/course/view.php?id=1")))
        XCTAssertTrue(NetworkSecurityPolicy.isTrustedLMSURL(URLFactory.require("https://lms.bsuir.by:443/mod/page/view.php?id=2")))

        XCTAssertFalse(NetworkSecurityPolicy.isTrustedLMSURL(URLFactory.require("http://lms.bsuir.by/course/view.php?id=1")))
        XCTAssertFalse(NetworkSecurityPolicy.isTrustedLMSURL(URLFactory.require("https://lms.bsuir.by.evil.example/course")))
        XCTAssertFalse(NetworkSecurityPolicy.isTrustedLMSURL(URLFactory.require("https://user:password@lms.bsuir.by/course")))
        XCTAssertFalse(NetworkSecurityPolicy.isTrustedLMSURL(URLFactory.require("https://lms.bsuir.by:8443/course")))
    }

    func testTrustedLMSURLResolvesRelativeLinksAndRejectsExternalLinks() {
        let relative = NetworkSecurityPolicy.trustedLMSURL("/mod/quiz/view.php?id=42")
        XCTAssertEqual(relative?.absoluteString, "https://lms.bsuir.by/mod/quiz/view.php?id=42")

        XCTAssertNil(NetworkSecurityPolicy.trustedLMSURL("https://evil.example/collect"))
        XCTAssertNil(NetworkSecurityPolicy.trustedLMSURL("javascript:alert(1)"))
    }

    func testSecureURLAllowsExplicitExternalHTTPSModuleWithoutCredentials() {
        XCTAssertNotNil(NetworkSecurityPolicy.secureURL("https://example.org/material"))
        XCTAssertNil(NetworkSecurityPolicy.secureURL("http://example.org/material"))
        XCTAssertNil(NetworkSecurityPolicy.secureURL("https://user:secret@example.org/material"))
    }

    func testSanitizedFilenameDropsTraversalAndUnsafeCharacters() {
        XCTAssertEqual(
            NetworkSecurityPolicy.sanitizedFilename("../../report?.xlsx", fallback: "download.xlsx"),
            "report_.xlsx"
        )
        XCTAssertEqual(
            NetworkSecurityPolicy.sanitizedFilename(#"..\\..\\secret:notes.pdf"#, fallback: "download.pdf"),
            "secret_notes.pdf"
        )
        XCTAssertEqual(
            NetworkSecurityPolicy.sanitizedFilename("...", fallback: "download.bin"),
            "download.bin"
        )
    }

    func testCookieRemovalIsScopedToRequestedHost() throws {
        let storage = HTTPCookieStorage.shared
        let suffix = UUID().uuidString
        let iisCookie = try XCTUnwrap(HTTPCookie(properties: [
            .domain: NetworkSecurityPolicy.iisHost,
            .path: "/",
            .name: "IIS-\(suffix)",
            .value: "secret",
            .secure: "TRUE"
        ]))
        let lmsCookie = try XCTUnwrap(HTTPCookie(properties: [
            .domain: NetworkSecurityPolicy.lmsHost,
            .path: "/",
            .name: "LMS-\(suffix)",
            .value: "secret",
            .secure: "TRUE"
        ]))
        storage.setCookie(iisCookie)
        storage.setCookie(lmsCookie)
        defer {
            storage.deleteCookie(iisCookie)
            storage.deleteCookie(lmsCookie)
        }

        NetworkSecurityPolicy.removeCookies(forHost: NetworkSecurityPolicy.iisHost, from: storage)

        XCTAssertFalse(storage.cookies?.contains(where: { $0.name == iisCookie.name }) == true)
        XCTAssertTrue(storage.cookies?.contains(where: { $0.name == lmsCookie.name }) == true)
    }

    func testLMSConfigurationDoesNotAcceptThirdPartyCookiesUnconditionally() {
        let configuration = NetworkSecurityPolicy.makeLMSConfiguration()
        XCTAssertEqual(configuration.httpCookieAcceptPolicy, .onlyFromMainDocumentDomain)
        XCTAssertTrue(configuration.httpShouldSetCookies)
    }

    func testCredentialStoresWithDifferentServicesAreIsolated() throws {
        let suffix = UUID().uuidString
        let iisStore = CredentialStore(service: "by.bsuir.MyIIS.tests.iis.\(suffix)")
        let lmsStore = CredentialStore(service: "by.bsuir.MyIIS.tests.lms.\(suffix)")
        defer {
            try? iisStore.clear()
            try? lmsStore.clear()
        }

        try iisStore.save(StoredCredentials(username: "iis-user", password: "iis-password"))
        try lmsStore.save(StoredCredentials(username: "lms-user", password: "lms-password"))

        XCTAssertEqual(try iisStore.retrieve()?.username, "iis-user")
        XCTAssertEqual(try lmsStore.retrieve()?.username, "lms-user")
        XCTAssertNotEqual(try iisStore.retrieve()?.password, try lmsStore.retrieve()?.password)
    }
}
