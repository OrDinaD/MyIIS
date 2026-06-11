//
//  MyIISUITestsLaunchTests.swift
//  MyIISUITests
//
//  Created by Влад on 11/5/26.
//

import XCTest

class MyIISUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // UI tests are temporarily disabled: the UI test runner does not launch reliably in Xcode 26.5.
    // @MainActor
    // func disabledLaunch() throws {
    //     let app = XCUIApplication()
    //     app.launch()
    //
    //     // Insert steps here to perform after app launch but before taking a screenshot,
    //     // such as logging into a test account or navigating somewhere in the app
    //     // XCUIAutomation Documentation
    //     // https://developer.apple.com/documentation/xcuiautomation
    //
    //     let attachment = XCTAttachment(screenshot: app.screenshot())
    //     attachment.name = "Launch Screen"
    //     attachment.lifetime = .keepAlways
    //     add(attachment)
    // }
}
