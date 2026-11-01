import XCTest

/// Ticket T04, review items 2 and 25. A skip collapses the ramp to a
/// "WARM-UPS SKIPPED" line with UNDO, and skipped warm-ups never count as
/// logged sets. Finish with no logged work set offers Discard workout
/// instead of saving (decision 6), and the Finish and Discard dialogs show
/// a visible Keep logging.
final class SkipWarmupsUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Skip and undo

    @MainActor
    func testSkipCollapsesRampLogsNothingAndUndoRestores() throws {
        let app = UITestNavigation.openSeededWorkout()
        let skip = element(app.buttons, "Skip all warm-up sets")
        UITestNavigation.reveal(skip, in: app)
        skip.tap()

        let skipped = element(app.staticTexts, "Warm-ups skipped")
        XCTAssertTrue(UITestNavigation.appears(skipped, within: 5), "One tap on SKIP WARM-UPS must collapse the ramp")
        XCTAssertFalse(skip.exists, "The ramp must collapse after a skip")

        app.buttons["Back"].firstMatch.tap()
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(UITestNavigation.appears(resume))
        let noneLogged = element(app.staticTexts, "0 sets logged")
        XCTAssertTrue(UITestNavigation.appears(noneLogged, within: 5), "Skipped warm-ups must not count as logged sets")

        resume.tap()
        XCTAssertTrue(UITestNavigation.appears(skipped), "The skip must persist")
        element(app.buttons, "Undo skipped warm-ups").tap()
        XCTAssertTrue(UITestNavigation.appears(skip, within: 5), "UNDO must restore the ramp")
        XCTAssertFalse(skipped.exists)
        let firstWarmup = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Warm-up set 1:")).firstMatch
        XCTAssertTrue(firstWarmup.exists, "UNDO must bring back the ramp's warm-up rows")

        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(UITestNavigation.appears(resume))
        XCTAssertTrue(UITestNavigation.appears(noneLogged, within: 5), "The slab count must not change through skip and undo")
    }

    // MARK: - Finish and Discard

    /// Finish with no logged work set offers Discard workout, not Finish
    /// (decision 6). Keep logging closes the dialog and leaves the workout
    /// open, and Discard workout deletes this workout and no other.
    @MainActor
    func testFinishWithNothingLoggedOffersDiscardWorkout() throws {
        let app = UITestNavigation.openSeededWorkout()
        openFinish(in: app)
        let discardWorkout = app.buttons["Discard workout"]
        XCTAssertTrue(UITestNavigation.appears(discardWorkout, within: 5), "Finish with nothing logged must offer Discard workout")
        let keepLogging = app.buttons["Keep logging"]
        XCTAssertTrue(keepLogging.exists && keepLogging.isHittable, "The Finish dialog needs a visible Keep logging")
        XCTAssertFalse(app.buttons["Finish"].exists, "With nothing logged, Finish must not save")
        XCTAssertFalse(app.buttons["Cancel"].exists, "Keep logging is the dialog's one way back")
        XCTAssertTrue(text(beginningWith: "0 sets logged ·", in: app).exists, "The Finish dialog counts logged work sets")

        keepLogging.tap()
        XCTAssertTrue(waitForDisappearance(discardWorkout), "Keep logging must close the dialog")
        XCTAssertTrue(app.otherElements["workout.header"].exists, "Keep logging leaves the workout open")

        openFinish(in: app)
        XCTAssertTrue(UITestNavigation.appears(discardWorkout, within: 5))
        discardWorkout.tap()
        let sessions = app.buttons["today.sessions"]
        XCTAssertTrue(UITestNavigation.appears(sessions), "Discard workout must return to Today")
        XCTAssertFalse(app.buttons["resumeSlab.resume"].exists, "The discarded workout must be gone")
        sessions.tap()
        let rows = app.buttons.matching(identifier: "history.row")
        XCTAssertTrue(UITestNavigation.appears(rows.firstMatch))
        XCTAssertEqual(rows.count, 1, "Discard must delete only this workout; the earlier finished one stays")
    }

    /// The Discard dialog still asks before it deletes, and its visible
    /// Keep logging, its one way back, closes it and leaves the workout open.
    @MainActor
    func testDiscardDialogKeepLoggingLeavesWorkoutOpen() throws {
        let app = UITestNavigation.openSeededWorkout()
        app.buttons["More"].tap()
        let discard = app.buttons["Discard"]
        XCTAssertTrue(UITestNavigation.appears(discard, within: 5))
        discard.tap()
        let question = app.staticTexts["Discard workout?"]
        XCTAssertTrue(UITestNavigation.appears(question, within: 5), "Discard must ask before it deletes")
        let keepLogging = app.buttons["Keep logging"]
        XCTAssertTrue(keepLogging.exists && keepLogging.isHittable, "The Discard dialog needs a visible Keep logging")
        XCTAssertTrue(app.buttons["Discard"].exists)
        XCTAssertFalse(app.buttons["Cancel"].exists, "Keep logging is the dialog's one way back")

        keepLogging.tap()
        XCTAssertTrue(waitForDisappearance(question), "Keep logging must close the dialog")
        XCTAssertTrue(app.otherElements["workout.header"].exists, "Keep logging leaves the workout open")
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(UITestNavigation.appears(app.buttons["resumeSlab.resume"]), "The workout must still be running")
    }

    // MARK: - Helpers

    /// BRU labels reach accessibility uppercased, so match without case.
    @MainActor
    private func element(_ query: XCUIElementQuery, _ label: String) -> XCUIElement {
        query.matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
    }

    @MainActor
    private func text(beginningWith prefix: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH[c] %@", prefix)).firstMatch
    }

    /// Taps the logger's ••• menu, then its Finish.
    @MainActor
    private func openFinish(in app: XCUIApplication) {
        app.buttons["More"].tap()
        let finish = app.buttons["Finish"]
        XCTAssertTrue(UITestNavigation.appears(finish, within: 5))
        finish.tap()
    }

    @MainActor
    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        UITestNavigation.disappears(element, within: timeout)
    }
}
