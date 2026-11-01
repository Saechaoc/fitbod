// WorkoutLoggerJourneyUITests.swift
// fitbodUITests
//
// End-to-end checks for the workout logger (milestone 1), run against the
// DEBUG demo workout: `-fitbod-reset-store` wipes the store and
// `-fitbod-seed-demo-workout` seeds a "Push A" template, a finished Push A
// from three days ago (bench 100 x 5) and an in-progress Push A today.
// Exercise 1 is the barbell bench press: three working sets, 180 s rest.
//
// Each test launches through UITestNavigation.launch, which fails unless
// the reset really happened, so a run of this suite alone never opens the
// previous run's store (F11). Relaunches drop the launch arguments, so the
// second launch opens the same store the way a user reopening the app would.

import XCTest

final class WorkoutLoggerJourneyUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Logging and persistence

    /// A completed set is saved: it is still logged after the app is
    /// killed and reopened.
    @MainActor
    func testLoggedSetSurvivesRelaunch() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        openWorkout(app)

        logSet(app, "1.S1", reps: "7")
        XCTAssertEqual(app.buttons["set.complete.1.S1"].label, "Set 1 complete")

        UITestNavigation.relaunch(app)
        openWorkout(app)
        let reps = app.textFields["set.reps.1.S1"]
        XCTAssertEqual(reps.value as? String, "7")
        XCTAssertEqual(app.buttons["set.complete.1.S1"].label, "Set 1 complete")
    }

    /// Adding a set appends S4, swipe-to-delete removes it, and tapping a
    /// completed checkmark marks the set as not done.
    @MainActor
    func testAddDeleteAndUncompleteSets() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        openWorkout(app)

        let addSet = app.buttons["card.addSet.1"]
        scrollUntilHittable(addSet, in: app)
        addSet.tap()
        let fourth = app.textFields["set.reps.1.S4"]
        XCTAssertTrue(UITestNavigation.appears(fourth, within: 5), "Add set should append S4")

        let row = app.cells.containing(.textField, identifier: "set.reps.1.S4").firstMatch
        scrollUntilHittable(row, in: app)
        row.swipeLeft()
        let delete = app.buttons["Delete"]
        if UITestNavigation.appears(delete, within: 2) { delete.tap() }
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

    // MARK: - Discard

    /// With a set checked off, Discard on Today asks first: Cancel keeps
    /// the workout, Discard removes it for good.
    @MainActor
    func testDiscardWithLoggedSetsAsksFirst() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        openWorkout(app)
        logSet(app, "1.S1", reps: "6")
        app.buttons["Back"].firstMatch.tap()

        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(UITestNavigation.appears(resume))

        let discard = app.buttons["resumeSlab.discard"]
        discard.tap()
        let alert = app.alerts["Discard workout?"]
        XCTAssertTrue(UITestNavigation.appears(alert, within: 5), "Discarding a logged set should ask first")
        XCTAssertTrue(alert.staticTexts["1 logged set will be deleted."].exists)
        alert.buttons["Cancel"].tap()
        XCTAssertTrue(UITestNavigation.appears(resume, within: 5), "Cancel should keep the workout")

        discard.tap()
        XCTAssertTrue(UITestNavigation.appears(alert, within: 5))
        alert.buttons["Discard"].tap()
        XCTAssertTrue(waitForDisappearance(resume), "Discard should remove the workout")

        UITestNavigation.relaunch(app)
        XCTAssertTrue(UITestNavigation.appears(app.buttons["today.sessions"], within: 30))
        XCTAssertFalse(app.buttons["resumeSlab.resume"].exists, "A discarded workout must stay gone")
    }

    /// With nothing checked off there is nothing to lose, so Discard
    /// removes the workout without a question.
    @MainActor
    func testDiscardWithNothingLoggedSkipsTheQuestion() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(UITestNavigation.appears(resume, within: 90))

        app.buttons["resumeSlab.discard"].tap()
        XCTAssertTrue(waitForDisappearance(resume), "Discard should remove the empty workout")
        XCTAssertFalse(app.alerts.firstMatch.exists, "Nothing logged, so no question")
    }

    // MARK: - Finish, summary, history

    /// A record set shows the PR banner. Finishing opens the summary, and
    /// the workout then appears in History with its summary.
    @MainActor
    func testFinishShowsSummaryThenHistory() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        openWorkout(app)

        // The seeded history tops out at 5 reps, so 9 reps at the
        // prescribed weight is a record.
        logSet(app, "1.S1", reps: "9")
        let banner = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@ AND label CONTAINS %@", "personal record", "pounds, 9 reps"))
            .firstMatch
        XCTAssertTrue(UITestNavigation.appears(banner, within: 3), "PR banner should name the lift in pounds")

        app.buttons["More"].tap()
        let finish = app.buttons["Finish"]
        XCTAssertTrue(UITestNavigation.appears(finish, within: 5))
        finish.tap()
        let confirm = app.buttons["Finish"]
        XCTAssertTrue(UITestNavigation.appears(confirm, within: 5))
        confirm.tap()

        let done = app.buttons["summary.done"]
        XCTAssertTrue(UITestNavigation.appears(done), "Finish should open the summary")
        XCTAssertTrue(app.staticTexts["WORKOUT COMPLETE"].exists)
        done.tap()

        let sessions = app.buttons["today.sessions"]
        XCTAssertTrue(UITestNavigation.appears(sessions))
        XCTAssertFalse(app.buttons["resumeSlab.resume"].exists, "A finished workout is not resumable")
        sessions.tap()

        let rows = app.buttons.matching(identifier: "history.row")
        XCTAssertTrue(UITestNavigation.appears(rows.firstMatch))
        XCTAssertEqual(rows.count, 2, "History should list the seeded workout and today's")
        // 100×9 opens the 7-10 rep range, so today's one set tops all four
        // kinds, as the banner said. The row counts them, not just the first.
        XCTAssertTrue(rows.firstMatch.label.contains("4 personal records"), rows.firstMatch.label)

        rows.firstMatch.tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts["Push A"], within: 5))
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(UITestNavigation.appears(rows.firstMatch, within: 5))
    }

    // MARK: - Helpers

    @MainActor
    private func openWorkout(_ app: XCUIApplication) {
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(UITestNavigation.appears(resume, within: 90), "Today should offer the workout")
        resume.tap()
        XCTAssertTrue(UITestNavigation.appears(app.textFields["set.reps.1.S1"]))
    }

    /// Types reps into a set and checks it off. The prescribed weight is
    /// already filled in, so reps are the only input needed.
    @MainActor
    private func logSet(_ app: XCUIApplication, _ id: String, reps: String) {
        let field = app.textFields["set.reps.\(id)"]
        scrollUntilHittable(field, in: app)
        UITestNavigation.enter(reps, into: field)
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

    @MainActor
    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        UITestNavigation.disappears(element, within: timeout)
    }

    @MainActor
    private func waitForLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval = 5) -> Bool {
        UITestNavigation.waitUntil(timeout: timeout) { element.exists && element.label == label }
    }
}
