@testable import MyIIS
import SwiftUI
import XCTest

@MainActor
final class StaleDataBannerTests: XCTestCase {

    func testDateStaleDataFormattedDateTime() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy HH:mm"

        let date = Date(timeIntervalSince1970: 1_686_000_000)

        XCTAssertEqual(date.staleDataFormattedDateTime, formatter.string(from: date))
    }

    func testBannerInitialization() async {
        let date = Date()
        var actionCalled = false

        let banner = StaleDataBanner(lastUpdateTime: date, errorMessage: "Error") {
            actionCalled = true
        }

        XCTAssertEqual(banner.errorMessage, "Error")
        XCTAssertEqual(banner.lastUpdateTime, date)

        await banner.action()
        XCTAssertTrue(actionCalled)
    }

    func testErrorDetailsViewInitialization() async {
        var retryCalled = false
        let date = Date()
        let view = ErrorDetailsView(errorMessage: "Test", lastUpdateTime: date) {
            retryCalled = true
        }

        XCTAssertEqual(view.errorMessage, "Test")
        XCTAssertEqual(view.lastUpdateTime, date)

        await view.retryAction()
        XCTAssertTrue(retryCalled)
    }
}
