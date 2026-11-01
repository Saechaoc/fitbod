//
//  ProgressRowsTapOnlyUITests.swift
//  fitbodUITests
//
//  T137, finding F320, on ProgressHistorySeed's four finished workouts:
//  Progress's own rows (Workouts, the recent exercises, Weekly Tonnage,
//  Personal Records and This week vs last week) open only on a tap, as
//  T106's rows do. They were full-width plain buttons, which open on any
//  lift inside them, so a sideways drag or an edge swipe that started on
//  one opened it.
//

import XCTest

final class ProgressRowsTapOnlyUITests: XCTestCase {

    // The test is @MainActor because XCUIApplication and XCUIElement are
    // main-actor types.

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Progress is a root screen, so the drag starts 1pt inside the left
    /// edge, where an edge swipe starts. `ProgressHomeView.progressRow`
    /// draws every Progress row, so the Workouts row stands for all five.
    @MainActor
    func testSidewaysDragOnAProgressRowOpensNothing() throws {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory)
        UITestNavigation.selectTab("Progress", in: app)
        let workouts = app.buttons["progress.history"]
        let history = app.buttons.matching(identifier: "history.row").firstMatch
        XCTAssertTrue(workouts.exists || workouts.waitForExistence(timeout: 10), "Progress must show its Workouts row")
        UITestNavigation.waitUntilStill(workouts)
        UITestNavigation.saveScreenshot("T137", "progress")

        let before = workouts.frame
        let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: before.minX + 1, dy: before.midY))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 200, dy: 0)),
                    withVelocity: .default, thenHoldForDuration: 0)
        // A row opens its screen as the finger lifts, so a screen the drag
        // opened shows well within this wait; nothing showing takes all of it.
        XCTAssertFalse(history.waitForExistence(timeout: 2), "A sideways drag on the Workouts row must not open History")
        XCTAssertTrue(workouts.isHittable, "A sideways drag on the Workouts row must leave Progress on screen")
        XCTAssertEqual(workouts.frame, before, "A sideways drag on the Workouts row must leave it where it was")

        workouts.tap()
        XCTAssertTrue(history.waitForExistence(timeout: 10), "A tap on the Workouts row must open History")
    }
}
