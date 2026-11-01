import XCTest

/// Ticket T04, review items 2 and 25. SKIP WARM-UPS, and every other button
/// in the exercise card's header row, works on the first tap anywhere in its
/// 44pt target. A skip collapses the ramp to a "WARM-UPS SKIPPED" line with
/// UNDO, and skipped warm-ups never count as logged sets. Finish with no
/// logged work set offers Discard workout instead of saving (decision 6),
/// and the Finish and Discard dialogs show a visible Keep logging.
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
        // The whole full-width 44pt row takes the tap, not just the words:
        // tap near its leading edge and its top, away from the label.
        UITestNavigation.assertTapTarget(skip)
        XCTAssertGreaterThanOrEqual(skip.frame.width, app.frame.width - 1, "SKIP WARM-UPS must span the row: \(skip.frame)")
        skip.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.1)).tap()

        let skipped = element(app.staticTexts, "Warm-ups skipped")
        XCTAssertTrue(skipped.waitForExistence(timeout: 5), "One tap on SKIP WARM-UPS must collapse the ramp")
        XCTAssertFalse(skip.exists, "The ramp must collapse after a skip")
        UITestNavigation.saveScreenshot("T04", "warmups-skipped")

        app.buttons["Back"].firstMatch.tap()
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10))
        let noneLogged = element(app.staticTexts, "0 sets logged")
        XCTAssertTrue(noneLogged.waitForExistence(timeout: 5), "Skipped warm-ups must not count as logged sets")

        resume.tap()
        XCTAssertTrue(skipped.waitForExistence(timeout: 10), "The skip must persist")
        let undo = element(app.buttons, "Undo skipped warm-ups")
        UITestNavigation.assertTapTarget(undo)
        undo.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
        XCTAssertTrue(skip.waitForExistence(timeout: 5), "UNDO must restore the ramp")
        XCTAssertFalse(skipped.exists)
        let firstWarmup = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Warm-up set 1:")).firstMatch
        XCTAssertTrue(firstWarmup.exists && firstWarmup.frame.maxY <= skip.frame.minY,
                      "UNDO must bring back the ramp's warm-up rows above SKIP WARM-UPS")

        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(resume.waitForExistence(timeout: 10))
        XCTAssertTrue(noneLogged.waitForExistence(timeout: 5), "The slab count must not change through skip and undo")
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
        XCTAssertTrue(discardWorkout.waitForExistence(timeout: 5), "Finish with nothing logged must offer Discard workout")
        let keepLogging = app.buttons["Keep logging"]
        XCTAssertTrue(keepLogging.exists && keepLogging.isHittable, "The Finish dialog needs a visible Keep logging")
        XCTAssertFalse(app.buttons["Finish"].exists, "With nothing logged, Finish must not save")
        XCTAssertFalse(app.buttons["Cancel"].exists, "Keep logging is the dialog's one way back")
        XCTAssertTrue(text(beginningWith: "0 sets logged ·", in: app).exists, "The Finish dialog counts logged work sets")
        UITestNavigation.saveScreenshot("T04", "finish-nothing-logged")

        keepLogging.tap()
        XCTAssertTrue(waitForDisappearance(discardWorkout), "Keep logging must close the dialog")
        XCTAssertTrue(app.otherElements["workout.header"].exists, "Keep logging leaves the workout open")

        openFinish(in: app)
        XCTAssertTrue(discardWorkout.waitForExistence(timeout: 5))
        discardWorkout.tap()
        let sessions = app.buttons["today.sessions"]
        XCTAssertTrue(sessions.waitForExistence(timeout: 10), "Discard workout must return to Today")
        XCTAssertFalse(app.buttons["resumeSlab.resume"].exists, "The discarded workout must be gone")
        sessions.tap()
        let rows = app.buttons.matching(identifier: "history.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(rows.count, 1, "Discard must delete only this workout; the earlier finished one stays")
    }

    /// The Discard dialog still asks before it deletes, and its visible
    /// Keep logging, its one way back, closes it and leaves the workout open.
    @MainActor
    func testDiscardDialogKeepLoggingLeavesWorkoutOpen() throws {
        let app = UITestNavigation.openSeededWorkout()
        app.buttons["More"].tap()
        let discard = app.buttons["Discard"]
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        discard.tap()
        let question = app.staticTexts["Discard workout?"]
        XCTAssertTrue(question.waitForExistence(timeout: 5), "Discard must ask before it deletes")
        let keepLogging = app.buttons["Keep logging"]
        XCTAssertTrue(keepLogging.exists && keepLogging.isHittable, "The Discard dialog needs a visible Keep logging")
        XCTAssertTrue(app.buttons["Discard"].exists)
        XCTAssertFalse(app.buttons["Cancel"].exists, "Keep logging is the dialog's one way back")
        UITestNavigation.saveScreenshot("T04", "discard-dialog")

        keepLogging.tap()
        XCTAssertTrue(waitForDisappearance(question), "Keep logging must close the dialog")
        XCTAssertTrue(app.otherElements["workout.header"].exists, "Keep logging leaves the workout open")
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(app.buttons["resumeSlab.resume"].waitForExistence(timeout: 10), "The workout must still be running")
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
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()
    }

    @MainActor
    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }
}
