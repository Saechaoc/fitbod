import XCTest

final class HistoryAndTodayUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTodayHistoryAndSettingsReturnToTheSameWorkout() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-fitbod-reset-store", "-fitbod-seed-demo-workout"]
        app.launch()
        let sessions = app.buttons["today.sessions"]
        XCTAssertTrue(sessions.waitForExistence(timeout: 90))
        sessions.tap()
        let rows = app.buttons.matching(identifier: "history.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(rows.count, 1)
        rows.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["WORKOUT COMPLETE"].waitForExistence(timeout: 10))
        app.buttons["Back"].firstMatch.tap()
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(app.buttons["resumeSlab.resume"].waitForExistence(timeout: 10))

        UITestNavigation.openSettings(in: app)
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["resumeSlab.resume"].waitForExistence(timeout: 10))

        // Hidden tabs must not leak actionable library controls to VoiceOver.
        XCTAssertFalse(app.textFields["library.search.browser"].exists)
        app.buttons["Library"].tap()
        XCTAssertTrue(app.textFields["library.search.browser"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["resumeSlab.resume"].exists)
        app.buttons["Today"].tap()
        XCTAssertTrue(app.buttons["resumeSlab.resume"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testVolumeRowsHaveReadableLabelsAndOpenDetails() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-fitbod-reset-store", "-fitbod-seed-demo-workout"]
        app.launch()
        XCTAssertTrue(app.buttons["Today"].waitForExistence(timeout: 90))
        let bar = app.descendants(matching: .any).matching(NSPredicate(
            format: "label BEGINSWITH %@ AND label CONTAINS %@", "Chest:", "sets this week,"
        )).firstMatch
        UITestNavigation.reveal(bar, in: app)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "today-volume-rows"
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertGreaterThanOrEqual(bar.frame.height, 44)
        XCTAssertLessThanOrEqual(bar.frame.maxX, app.frame.maxX)
        bar.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label ==[c] %@", "This Week"
        )).firstMatch.waitForExistence(timeout: 10))
    }
}
