import XCTest
import SwiftUI
@testable import MyIIS

@MainActor
final class StaleDataBannerTests: XCTestCase {
    
    func testDateStaleDataFormattedDateTime() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        
        let date = Date(timeIntervalSince1970: 1686000000)
        
        XCTAssertEqual(date.staleDataFormattedDateTime, formatter.string(from: date))
    }
    
    func testBannerInitialization() {
        let date = Date()
        var actionCalled = false
        
        let banner = StaleDataBanner(lastUpdateTime: date, errorMessage: "Error") {
            actionCalled = true
        }
        
        XCTAssertEqual(banner.errorMessage, "Error")
        XCTAssertEqual(banner.lastUpdateTime, date)
        
        banner.action()
        XCTAssertTrue(actionCalled)
    }
    
    func testErrorDetailsViewInitialization() {
        var retryCalled = false
        let date = Date()
        let view = ErrorDetailsView(errorMessage: "Test", lastUpdateTime: date) {
            retryCalled = true
        }
        
        XCTAssertEqual(view.errorMessage, "Test")
        XCTAssertEqual(view.lastUpdateTime, date)
        
        view.retryAction()
        XCTAssertTrue(retryCalled)
    }
}