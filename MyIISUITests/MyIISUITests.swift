import XCTest

final class MyIISUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testGenerateAppStoreScreenshots() throws {
        let app = makeScreenshotApp()
        app.launch()

        loginWithDemoAccount(app)

        selectTab(app, title: "Профиль")
        capture(app, name: "01_Profile")

        revealProfileContacts(app)
        capture(app, name: "02_ProfileContacts")

        selectTab(app, title: "Пропуски")
        capture(app, name: "03_Attendance")

        selectTab(app, title: "Рейтинг")
        capture(app, name: "04_Rating")

        expandElement(app, identifier: "ratingDiscipline_gradebook_Базы данных")
        capture(app, name: "05_RatingExpandedSubject")

        selectTab(app, title: "Сервисы")
        capture(app, name: "06_Services")

        openService(app, identifier: "serviceLink_gradebook")
        expandElement(app, identifier: "gradebookMark_Математика")
        capture(app, name: "07_GradebookExpandedSubject")
        goBackToServices(app)

        openService(app, identifier: "serviceLink_study")
        capture(app, name: "08_Study")
        goBackToServices(app)

        openService(app, identifier: "serviceLink_dormitory", title: "Общежитие")
        capture(app, name: "09_Dormitory")
        goBackToServices(app)

        openService(app, identifier: "serviceLink_group")
        capture(app, name: "10_Group")
    }

    @MainActor
    private func makeScreenshotApp() -> XCUIApplication {
        let app = XCUIApplication()
        setupSnapshot(app, waitForAnimations: false)
        app.launchArguments += [
            "-UITesting",
            "-ui_testing",
            "-hasSeenLaunchReveal", "YES",
            "-enable_beta_sections", "NO",
            "-show_tab_profile", "YES",
            "-show_tab_attendance", "YES",
            "-show_tab_rating", "YES",
            "-AppleLanguages", "(ru-RU)",
            "-AppleLocale", "ru_RU"
        ]
        app.launchEnvironment["UI_SCREENSHOT_MODE"] = "1"
        return app
    }

    @MainActor
    private func loginWithDemoAccount(_ app: XCUIApplication) {
        XCTContext.runActivity(named: "Login with demo account") { _ in
            let usernameField = app.textFields["usernameField"]
            if !usernameField.waitForExistence(timeout: 5) {
                let signInButton = app.buttons["Войти в аккаунт"].firstMatch
                XCTAssertTrue(signInButton.waitForExistence(timeout: 5), "Sign in button did not appear")
                signInButton.tap()
            }

            XCTAssertTrue(usernameField.waitForExistence(timeout: 10), "Username field did not appear")
            usernameField.tap()
            usernameField.typeText("demo")

            let passwordField = app.secureTextFields["passwordField"]
            XCTAssertTrue(passwordField.waitForExistence(timeout: 5), "Password field did not appear")
            passwordField.tap()
            passwordField.typeText("demo")

            let loginButton = app.buttons["loginButton"]
            XCTAssertTrue(loginButton.waitForExistence(timeout: 5), "Login button did not appear")
            loginButton.tap()

            let tabBar = app.tabBars.firstMatch
            XCTAssertTrue(tabBar.waitForExistence(timeout: 20), "Main tab bar did not appear after demo login")
            dismissSystemAlertsIfNeeded()
            waitForUIToSettle()
        }
    }

    @MainActor
    private func selectTab(_ app: XCUIApplication, title: String) {
        XCTContext.runActivity(named: "Open tab: \(title)") { _ in
            let tabBar = app.tabBars.firstMatch
            XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar is missing")

            let exactButton = tabBar.buttons[title]
            if exactButton.waitForExistence(timeout: 3) {
                exactButton.tap()
            } else {
                let predicate = NSPredicate(format: "label CONTAINS[c] %@", title)
                let matchingButton = tabBar.buttons.matching(predicate).firstMatch
                XCTAssertTrue(matchingButton.waitForExistence(timeout: 5), "Tab '\(title)' is missing")
                matchingButton.tap()
            }
            waitForUIToSettle()
        }
    }

    @MainActor
    private func revealProfileContacts(_ app: XCUIApplication) {
        XCTContext.runActivity(named: "Reveal profile contacts") { _ in
            let showButton = app.buttons["Показать"]
            if showButton.waitForExistence(timeout: 5) {
                showButton.tap()
                waitForUIToSettle()
            }
        }
    }

    @MainActor
    private func openService(_ app: XCUIApplication, identifier: String, title: String? = nil) {
        XCTContext.runActivity(named: "Open service: \(identifier)") { _ in
            var serviceLink = findServiceLink(app, identifier: identifier, title: title)
            if !serviceLink.waitForExistence(timeout: 5) {
                app.swipeUp()
                serviceLink = findServiceLink(app, identifier: identifier, title: title)
            }
            XCTAssertTrue(serviceLink.waitForExistence(timeout: 5), "Service link '\(identifier)' is missing")
            tap(serviceLink)
            waitForUIToSettle()
        }
    }

    @MainActor
    private func findServiceLink(_ app: XCUIApplication, identifier: String, title: String?) -> XCUIElement {
        let identifiedElement = element(app, identifier: identifier)
        guard let title else { return identifiedElement }
        if identifiedElement.exists { return identifiedElement }

        let button = app.buttons[title]
        if button.exists { return button }

        let staticText = app.staticTexts[title]
        if staticText.exists { return staticText }

        return identifiedElement
    }

    @MainActor
    private func expandElement(_ app: XCUIApplication, identifier: String) {
        XCTContext.runActivity(named: "Expand: \(identifier)") { _ in
            let expandable = element(app, identifier: identifier)
            XCTAssertTrue(expandable.waitForExistence(timeout: 10), "Expandable element '\(identifier)' is missing")
            tap(expandable)
            waitForUIToSettle()
        }
    }

    @MainActor
    private func goBackToServices(_ app: XCUIApplication) {
        XCTContext.runActivity(named: "Back to services") { _ in
            let labels = ["Сервисы", "Назад", "Back"]
            if let backButton = labels
                .map({ app.navigationBars.buttons[$0] })
                .first(where: { $0.waitForExistence(timeout: 1) }) {
                backButton.tap()
            } else {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.08)).tap()
            }

            waitForUIToSettle()
            let servicesRootMarker = element(app, identifier: "serviceLink_gradebook")
            XCTAssertTrue(servicesRootMarker.waitForExistence(timeout: 5), "Services root did not reappear")
        }
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        XCTContext.runActivity(named: name) { activity in
            waitForUIToSettle()
            snapshot(name, timeWaitingForIdle: 0)

            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = name
            attachment.lifetime = .keepAlways
            activity.add(attachment)

            writeScreenshot(screenshot, name: name)
        }
    }

    @MainActor
    private func writeScreenshot(_ screenshot: XCUIScreenshot, name: String) {
        let outputDirectory = ProcessInfo.processInfo.environment["SHOWCASE_SCREENSHOT_OUTPUT_DIR"]
            ?? "/Users/vlad/MyIIS/fastlane/screenshots/ru-RU"
        let destinationDirectory = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        let destinationURL = destinationDirectory.appendingPathComponent("\(name).png")

        do {
            try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
            try screenshot.pngRepresentation.write(to: destinationURL, options: .atomic)
        } catch {
            XCTFail("Failed to save screenshot '\(name)': \(error.localizedDescription)")
        }
    }

    @MainActor
    private func element(_ app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @MainActor
    private func tap(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    @MainActor
    private func waitForUIToSettle() {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.2))
    }

    @MainActor
    private func dismissSystemAlertsIfNeeded() {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.0))
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
