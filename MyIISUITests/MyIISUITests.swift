import XCTest

final class MyIISUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // UI tests are temporarily disabled: the UI test runner does not launch reliably in Xcode 26.5.
    // @MainActor
    // func disabledGenerateScreenshots() throws {
    //     let app = XCUIApplication()
    //     app.launchArguments = ["-UITesting", "-hasSeenLaunchReveal", "YES"]
    //     setupSnapshot(app)
    //     app.launch()
    //
    //     let tabBar = loginAndOpenMainScreen(app: app)
    //
    //     captureTabScreenshot(app: app, tabBar: tabBar, index: 0, snapshotName: "02_ProfileScreen")
    //     captureTabScreenshot(app: app, tabBar: tabBar, index: 1, snapshotName: "03_AttendanceScreen")
    //     captureTabScreenshot(app: app, tabBar: tabBar, index: 2, snapshotName: "04_RatingScreen")
    //     captureTabScreenshot(app: app, tabBar: tabBar, index: 3, snapshotName: "05_ServicesScreen")
    //     captureGradebookScreenshot(app: app)
    // }

    @MainActor
    private func loginAndOpenMainScreen(app: XCUIApplication) -> XCUIElement {
        XCTContext.runActivity(named: "01 Login") { _ in
            let usernameField = app.textFields["usernameField"]
            XCTAssertTrue(usernameField.waitForExistence(timeout: 10), "Username field did not appear")
            captureShowcaseScreenshot(app: app, name: "01_LoginScreen")

            usernameField.tap()
            usernameField.typeText("demo")

            let passwordField = app.secureTextFields["passwordField"]
            if passwordField.waitForExistence(timeout: 5) {
                passwordField.tap()
                passwordField.typeText("demo")
            }

            dismissKeyboardIfNeeded(app: app)

            let loginButton = app.buttons["loginButton"]
            XCTAssertTrue(loginButton.waitForExistence(timeout: 5), "Login button not found")
            loginButton.tap()
        }

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20), "Main screen did not load after login")

        dismissSystemAlertsIfNeeded()
        waitForUIToSettle()
        return tabBar
    }

    @MainActor
    private func captureTabScreenshot(app: XCUIApplication, tabBar: XCUIElement, index: Int, snapshotName: String) {
        let tab = tabBar.buttons.element(boundBy: index)
        guard tab.waitForExistence(timeout: 5) else {
            XCTFail("Tab at index \(index) is missing")
            return
        }

        XCTContext.runActivity(named: snapshotName) { _ in
            tab.tap()
            waitForUIToSettle()
            captureShowcaseScreenshot(app: app, name: snapshotName)
        }
    }

    @MainActor
    private func captureGradebookScreenshot(app: XCUIApplication) {
        XCTContext.runActivity(named: "06 Gradebook") { _ in
            let gradebookPredicate = NSPredicate(
                format: "label CONTAINS[c] 'Зач' OR label CONTAINS[c] 'Markbook' OR label CONTAINS[c] 'Gradebook'"
            )

            let gradebookButton = app.buttons.matching(gradebookPredicate).firstMatch
            if gradebookButton.waitForExistence(timeout: 8) {
                gradebookButton.tap()
            } else {
                let gradebookCell = app.cells.matching(gradebookPredicate).firstMatch
                XCTAssertTrue(gradebookCell.waitForExistence(timeout: 8), "Gradebook entry not found")
                gradebookCell.tap()
            }

            waitForUIToSettle()
            captureShowcaseScreenshot(app: app, name: "06_GradebookScreen")
        }
    }

    @MainActor
    private func captureShowcaseScreenshot(app: XCUIApplication, name: String) {
        snapshot(name)

        let outputDirectory =
            ProcessInfo.processInfo.environment["SHOWCASE_SCREENSHOT_OUTPUT_DIR"]
            ?? "/Users/vlad/MyIIS/fastlane/screenshots/en-US"

        let screenshot = XCUIScreen.main.screenshot()
        let simulatorName = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "Simulator"
        let sanitizedSimulatorName = simulatorName.replacingOccurrences(of: "/", with: "-")

        let destinationDirectory = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        let destinationURL = destinationDirectory.appendingPathComponent("\(sanitizedSimulatorName)-\(name).png")

        do {
            try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
            try screenshot.pngRepresentation.write(to: destinationURL)
        } catch {
            XCTFail("Failed to save screenshot '\(name)': \(error.localizedDescription)")
        }
    }

    @MainActor
    private func dismissKeyboardIfNeeded(app: XCUIApplication) {
        guard app.keyboards.firstMatch.exists else { return }

        if app.toolbars.buttons["Done"].exists {
            app.toolbars.buttons["Done"].tap()
            return
        }

        app.swipeDown()
    }

    @MainActor
    private func waitForUIToSettle() {
        sleep(2)
    }

    @MainActor
    private func dismissSystemAlertsIfNeeded() {
        sleep(2)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alerts = springboard.alerts
        guard alerts.firstMatch.exists else { return }

        let alert = alerts.firstMatch
        let notNowRu = alert.buttons["Не сейчас"]
        let notNowEn = alert.buttons["Not Now"]
        if notNowRu.exists {
            notNowRu.tap()
        } else if notNowEn.exists {
            notNowEn.tap()
        } else {
            alert.buttons.element(boundBy: 0).tap()
        }
    }
}
