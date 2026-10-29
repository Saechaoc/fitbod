// WorkoutLoggerJourneyUITests.swift
// fitbodUITests
//
// End-to-end checks for the workout logger (milestone 1), run against the
// DEBUG demo workout: `-fitbod-reset-store` wipes the store and
// `-fitbod-seed-demo-workout` seeds a "Push A" template, a finished Push A
// from three days ago (bench 100 x 5) and an in-progress Push A today.
// Exercise 1 is the barbell bench press: three working sets, 180 s rest.
//
// Relaunches clear the launch arguments, so the second launch opens the
// same store the way a user reopening the app would.

import XCTest

final class WorkoutLoggerJourneyUITests: XCTestCase {

    private let seededLaunch = ["-fitbod-reset-store", "-fitbod-seed-demo-workout"]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Logging and persistence

    /// A completed set is saved: it is still logged after the app is
    /// killed and reopened.
    @MainActor
    func testLoggedSetSurvivesRelaunch() throws {
        let app = launch(seededLaunch)
        openWorkout(app)

        logSet(app, "1.S1", reps: "7")
        XCTAssertEqual(app.buttons["set.complete.1.S1"].label, "Set 1 complete")
        attach(app, "logger-01-set-logged")

        relaunch(app)
        openWorkout(app)
        let reps = app.textFields["set.reps.1.S1"]
        XCTAssertEqual(reps.value as? String, "7")
        XCTAssertEqual(app.buttons["set.complete.1.S1"].label, "Set 1 complete")
        attach(app, "logger-02-after-relaunch")
    }

    /// Adding a set appends S4, swipe-to-delete removes it, and tapping a
    /// completed checkmark marks the set as not done.
    @MainActor
    func testAddDeleteAndUncompleteSets() throws {
        let app = launch(seededLaunch)
        openWorkout(app)

        let addSet = app.buttons["card.addSet.1"]
        scrollUntilHittable(addSet, in: app)
        addSet.tap()
        let fourth = app.textFields["set.reps.1.S4"]
        XCTAssertTrue(fourth.waitForExistence(timeout: 5), "Add set should append S4")
        attach(app, "logger-03-set-added")

        let row = app.cells.containing(.textField, identifier: "set.reps.1.S4").firstMatch
        scrollUntilHittable(row, in: app)
        row.swipeLeft()
        let delete = app.buttons["Delete"]
        if delete.waitForExistence(timeout: 2) { delete.tap() }
        XCTAssertTrue(waitForDisappearance(fourth), "Swipe delete should remove S4")

        scrollUntilHittable(app.textFields["set.reps.1.S1"], in: app, upward: false)
        logSet(app, "1.S1", reps: "8")
        let complete = app.buttons["set.complete.1.S1"]
        XCTAssertEqual(complete.label, "Set 1 complete")
        complete.tap()
        XCTAssertTrue(
            waitForLabel(complete, "Mark set 1 complete"),
            "Tapping a completed set should mark it as not done"
        )
    }

    // MARK: - Rest timer

    /// Completing a set starts the rest timer. ±15 s adjust it, the
    /// countdown keeps running in the background and across a kill and
    /// relaunch (it counts to an absolute deadline), and Skip ends it.
    @MainActor
    func testRestTimerAdjustsAndSurvivesBackgroundAndRelaunch() throws {
        let app = launch(seededLaunch)
        openWorkout(app)
        logSet(app, "1.S1", reps: "6")

        // The countdown row is one combined element with the button trait.
        let status = app.descendants(matching: .any).matching(identifier: "rest.status").firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 5), "Rest timer should start after a set")
        let start = try XCTUnwrap(restSeconds(status), "Unreadable label: \(status.label)")
        XCTAssertTrue((150...180).contains(start), "Bench rest is 180 s; got \(start)")
        attach(app, "logger-04-rest-started")

        // Each tap takes a second or two, so allow for the clock running.
        app.buttons["rest.plus15"].tap()
        let added = try XCTUnwrap(restSeconds(status))
        XCTAssertTrue((start + 8...start + 16).contains(added), "+15s: \(start) -> \(added)")

        app.buttons["rest.minus15"].tap()
        app.buttons["rest.minus15"].tap()
        let subtracted = try XCTUnwrap(restSeconds(status))
        XCTAssertTrue((added - 42...added - 28).contains(subtracted), "-30s: \(added) -> \(subtracted)")

        // Background for a few seconds: the countdown keeps going.
        XCUIDevice.shared.press(.home)
        sleep(6)
        app.activate()
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        let afterBackground = try XCTUnwrap(restSeconds(status))
        XCTAssertLessThanOrEqual(afterBackground, subtracted - 5, "Timer should run while backgrounded")

        // Kill and reopen: the timer resumes from the saved deadline.
        relaunch(app)
        openWorkout(app)
        XCTAssertTrue(status.waitForExistence(timeout: 10), "Rest timer should come back after relaunch")
        let afterRelaunch = try XCTUnwrap(restSeconds(status))
        XCTAssertLessThan(afterRelaunch, afterBackground, "Timer should keep counting down across relaunch")
        XCTAssertGreaterThan(afterRelaunch, afterBackground - 90, "Relaunch should not reset or lose the timer")
        attach(app, "logger-05-rest-after-relaunch")

        app.buttons["rest.skip"].tap()
        XCTAssertTrue(waitForDisappearance(status), "Skip should end the rest timer")
    }

    // MARK: - Discard

    /// With a set checked off, Discard on Today asks first: Cancel keeps
    /// the workout, Discard removes it for good.
    @MainActor
    func testDiscardWithLoggedSetsAsksFirst() throws {
        let app = launch(seededLaunch)
        openWorkout(app)
        logSet(app, "1.S1", reps: "6")
        app.buttons["Back"].firstMatch.tap()

        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10))
        attach(app, "today-01-resume-slab")

        let discard = app.buttons["resumeSlab.discard"]
        discard.tap()
        let alert = app.alerts["Discard workout?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Discarding a logged set should ask first")
        XCTAssertTrue(alert.staticTexts["1 logged set will be deleted."].exists)
        attach(app, "today-02-discard-alert")
        alert.buttons["Cancel"].tap()
        XCTAssertTrue(resume.waitForExistence(timeout: 5), "Cancel should keep the workout")

        discard.tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Discard"].tap()
        XCTAssertTrue(waitForDisappearance(resume), "Discard should remove the workout")

        relaunch(app)
        XCTAssertTrue(app.buttons["today.sessions"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["resumeSlab.resume"].exists, "A discarded workout must stay gone")
    }

    /// With nothing checked off there is nothing to lose, so Discard
    /// removes the workout without a question.
    @MainActor
    func testDiscardWithNothingLoggedSkipsTheQuestion() throws {
        let app = launch(seededLaunch)
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 90))

        app.buttons["resumeSlab.discard"].tap()
        XCTAssertTrue(waitForDisappearance(resume), "Discard should remove the empty workout")
        XCTAssertFalse(app.alerts.firstMatch.exists, "Nothing logged, so no question")
    }

    // MARK: - Finish, summary, history

    /// A record set shows the PR banner. Finishing opens the summary, and
    /// the workout then appears in History with its summary.
    @MainActor
    func testFinishShowsSummaryThenHistory() throws {
        let app = launch(seededLaunch)
        openWorkout(app)

        // The seeded history tops out at 5 reps, so 9 reps at the
        // prescribed weight is a record.
        logSet(app, "1.S1", reps: "9")
        let banner = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@ AND label CONTAINS %@", "personal record", "pounds, 9 reps"))
            .firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 3), "PR banner should name the lift in pounds")
        attach(app, "logger-06-pr-banner")

        app.buttons["More"].tap()
        let finish = app.buttons["Finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()
        let confirm = app.buttons["Finish"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        let done = app.buttons["summary.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "Finish should open the summary")
        XCTAssertTrue(app.staticTexts["WORKOUT COMPLETE"].exists)
        attach(app, "summary-01-after-finish")
        done.tap()

        let sessions = app.buttons["today.sessions"]
        XCTAssertTrue(sessions.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["resumeSlab.resume"].exists, "A finished workout is not resumable")
        sessions.tap()

        let rows = app.buttons.matching(identifier: "history.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(rows.count, 2, "History should list the seeded workout and today's")
        // 100×9 opens the 7-10 rep range, so today's one set tops all four
        // kinds, as the banner said. The row counts them, not just the first.
        XCTAssertTrue(rows.firstMatch.label.contains("4 personal records"), rows.firstMatch.label)
        attach(app, "history-01-list")

        rows.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Push A"].waitForExistence(timeout: 5))
        attach(app, "history-02-summary")
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    @MainActor
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    /// Kill and reopen without launch arguments, like a user would.
    @MainActor
    private func relaunch(_ app: XCUIApplication) {
        app.terminate()
        app.launchArguments = []
        app.launch()
    }

    @MainActor
    private func openWorkout(_ app: XCUIApplication) {
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 90), "Today should offer the workout")
        resume.tap()
        XCTAssertTrue(app.textFields["set.reps.1.S1"].waitForExistence(timeout: 10))
    }

    /// Types reps into a set and checks it off. The prescribed weight is
    /// already filled in, so reps are the only input needed.
    @MainActor
    private func logSet(_ app: XCUIApplication, _ id: String, reps: String) {
        let field = app.textFields["set.reps.\(id)"]
        scrollUntilHittable(field, in: app)
        focus(field)
        field.typeText(reps)
        let complete = app.buttons["set.complete.\(id)"]
        scrollUntilHittable(complete, in: app)
        complete.tap()
        XCTAssertTrue(
            waitForLabel(complete, "Set \(id.split(separator: "S").last ?? "") complete"),
            "Set \(id) should be complete"
        )
    }

    /// Scrolls until `element` can take a tap: on screen and below the
    /// pinned workout header. Rows scroll under that header, and
    /// accessibility still calls them hittable there, but a tap lands on
    /// the header. A row hidden under it is brought back down.
    @MainActor
    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication, upward: Bool = true) {
        let list = app.collectionViews.firstMatch
        let header = app.otherElements["workout.header"]
        func underHeader() -> Bool {
            header.exists && element.frame.minY < header.frame.maxY
        }
        var tries = 0
        while !(element.exists && element.isHittable && !underHeader()) && tries < 8 {
            let down = !upward || (element.exists && underHeader())
            if down { list.swipeDown(velocity: .slow) } else { list.swipeUp(velocity: .slow) }
            tries += 1
        }
    }

    /// Taps a text field until it has keyboard focus. A tap that lands
    /// while the list is still settling after a scroll only stops it.
    @MainActor
    private func focus(_ field: XCUIElement) {
        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        for _ in 0..<3 {
            field.tap()
            let wait = XCTNSPredicateExpectation(predicate: focused, object: field)
            if XCTWaiter().wait(for: [wait], timeout: 2) == .completed { return }
        }
        XCTFail("\(field.identifier) never took keyboard focus")
    }

    /// Seconds left, read from "Rest timer: 2 minutes 45 seconds".
    private func restSeconds(_ status: XCUIElement) -> Int? {
        let label = status.label
        let numbers = label
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
        if label.contains("minute"), numbers.count >= 2 { return numbers[0] * 60 + numbers[1] }
        if label.contains("second"), let seconds = numbers.first { return seconds }
        return nil
    }

    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }

    private func waitForLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval = 5) -> Bool {
        let match = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)
        return XCTWaiter().wait(for: [match], timeout: timeout) == .completed
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
