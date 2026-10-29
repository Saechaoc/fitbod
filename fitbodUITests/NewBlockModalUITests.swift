//
//  NewBlockModalUITests.swift
//  fitbodUITests
//
//  Smoke coverage for Program + NEW -> + New block.
//

import XCTest

final class NewBlockModalUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testProgramNewBlockOpensBlankBuilder() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-fitbod-start-program"]
        app.launch()

        tapElement(label: "+ NEW", in: app, timeout: 60)
        tapElement(label: "+ New block", in: app, timeout: 5)
        tapElement(label: "Blank Block", in: app, timeout: 5)

        XCTAssertTrue(app.staticTexts["NEW BLOCK"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["NAME YOUR BLOCK"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["PHASES · 3"].waitForExistence(timeout: 5))
        // The save button reads NAME FIRST and stays disabled until the
        // block has a name. Its bookmark icon is decorative.
        let save = app.buttons["NAME FIRST"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "New Block blank modal"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    private func tapElement(label: String, in app: XCUIApplication, timeout: TimeInterval) {
        let button = app.buttons[label].firstMatch
        if button.waitForExistence(timeout: timeout) {
            button.tap()
            return
        }

        let staticText = app.staticTexts[label].firstMatch
        XCTAssertTrue(staticText.waitForExistence(timeout: timeout), "Missing \(label)")
        staticText.tap()
    }
}
