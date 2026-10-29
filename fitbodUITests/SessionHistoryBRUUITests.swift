// SessionHistoryBRUUITests.swift
// fitbodUITests
//
// Phase 2.1 Plan 11 — BRU surface smoke tests for SessionHistoryView.
// UI-REVIEW Wave G item 67 / UI-SPEC § SessionHistoryView (lines 370-396).
//
// History is reachable from Progress → Workouts and Today → Sessions.
// These cases use a dedicated store and fail if the route disappears.
//

import XCTest

final class SessionHistoryBRUUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    @MainActor
    private func waitForSeedComplete(_ app: XCUIApplication, timeout: TimeInterval = 60) {
        let splash = app.staticTexts["Preparing library…"]
        if splash.exists {
            let pred = NSPredicate(format: "exists == false")
            let exp = XCTNSPredicateExpectation(predicate: pred, object: splash)
            _ = XCTWaiter().wait(for: [exp], timeout: timeout)
        }
    }

    @MainActor
    private func selectProgressTab(_ app: XCUIApplication) {
        let progress = app.buttons["Progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 90))
        progress.tap()
    }

    /// Navigate to SessionHistoryView via Progress → Workouts.
    /// Returns true if navigation succeeded.
    @MainActor
    @discardableResult
    private func navigateToSessionHistory(_ app: XCUIApplication) -> Bool {
        selectProgressTab(app)

        let historyButton = app.buttons["progress.history"]
        guard historyButton.waitForExistence(timeout: 10) else { return false }
        UITestNavigation.reveal(historyButton, in: app)
        historyButton.tap()
        return true
    }

    // MARK: - Tests

    /// The seeded finished workout opens from Progress; the active one stays out.
    @MainActor
    func testFinishedWorkoutOpensFromProgressHistory() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-fitbod-reset-store", "-fitbod-seed-demo-workout"]
        app.launch()
        waitForSeedComplete(app)

        XCTAssertTrue(navigateToSessionHistory(app))
        let rows = app.buttons.matching(identifier: "history.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(rows.count, 1, "Only the finished seeded workout belongs in History")
        rows.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["WORKOUT COMPLETE"].waitForExistence(timeout: 10))
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
    }

    /// Fresh stores show an explicit empty state through the same route.
    @MainActor
    func testFreshStoreShowsHistoryEmptyState() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-fitbod-reset-store"]
        app.launch()
        waitForSeedComplete(app)

        XCTAssertTrue(navigateToSessionHistory(app))
        let emptyHeading = app.staticTexts["No sessions yet"]
        let emptyBody = app.staticTexts["Finish a workout to see it here."]
        XCTAssertTrue(emptyHeading.waitForExistence(timeout: 10))
        XCTAssertTrue(emptyBody.exists)
        XCTAssertEqual(app.buttons.matching(identifier: "history.row").count, 0)
    }
}
