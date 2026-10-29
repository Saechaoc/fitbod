import XCTest

/// Review item 2: SKIP WARM-UPS works on the first tap, collapses the ramp to
/// a "WARM-UPS SKIPPED" line with UNDO, and skipped warm-ups never count as
/// logged sets.
final class SkipWarmupsUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testSkipCollapsesRampLogsNothingAndUndoRestores() throws {
        let app = UITestNavigation.openSeededWorkout()
        let skip = element(app.buttons, "Skip all warm-up sets")
        UITestNavigation.reveal(skip, in: app)
        skip.tap()

        let skipped = element(app.staticTexts, "Warm-ups skipped")
        XCTAssertTrue(skipped.waitForExistence(timeout: 5), "One tap on SKIP WARM-UPS must collapse the ramp")
        XCTAssertFalse(skip.exists, "The ramp must collapse after a skip")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "warmups-skipped"
        shot.lifetime = .keepAlways
        add(shot)

        app.buttons["Back"].firstMatch.tap()
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10))
        XCTAssertTrue(element(app.staticTexts, "0 sets logged").waitForExistence(timeout: 5),
                      "Skipped warm-ups must not count as logged sets")

        resume.tap()
        XCTAssertTrue(skipped.waitForExistence(timeout: 10), "The skip must persist")
        element(app.buttons, "Undo skipped warm-ups").tap()
        XCTAssertTrue(skip.waitForExistence(timeout: 5), "UNDO must restore the ramp")
        XCTAssertFalse(skipped.exists)
    }

    /// BRU labels reach accessibility uppercased, so match without case.
    @MainActor
    private func element(_ query: XCUIElementQuery, _ label: String) -> XCUIElement {
        query.matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
    }
}
