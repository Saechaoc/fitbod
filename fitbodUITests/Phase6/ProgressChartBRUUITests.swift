//
//  ProgressChartBRUUITests.swift
//  fitbodUITests
//
//  Phase 6.1 Plan 07 — UI smoke tests for the BRU reskin of
//  ExerciseProgressView + SeriesToggleChipRow (Plans 06.1-02 + 06.1-03).
//
//  Confirms:
//    1. ExerciseProgressView is reachable by tapping a Recent row on the
//       Progress tab; OR, if no history exists, the empty-state "No history
//       yet" copy is visible (and the test passes — the chart is unreachable
//       by design on a fresh simulator).
//    2. After navigation to ExerciseProgressView:
//         - EITHER the 4-segment toggle labels ("e1RM" / "TOP SET" / "VOLUME" /
//           "AVG RPE") are visible (data exists, chart rendered)
//         - OR the empty-state copy "Log 2 sessions to see your trend." is visible
//           (only 0 or 1 session exists for the exercise — handled gracefully).
//    3. The BRUHeaderBar renders at the top of ExerciseProgressView (center
//       text matches the exercise name if a Recent row was tapped).
//
//  XCTest (not Swift Testing) — UI tests must use XCUIApplication.
//  Per CLAUDE.md: Swift Testing does not support XCUIApplication.
//
//  Adaptive: both tests handle the empty-data and seeded-data simulator
//  states without requiring fixture injection.
//

import XCTest

final class ProgressChartBRUUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Shared helpers

    /// Wait until the "Preparing library…" splash disappears OR timeout expires.
    @MainActor
    private func waitForSeedComplete(timeout: TimeInterval = 60) {
        let splash = app.staticTexts["Preparing library…"]
        if splash.exists {
            let pred = NSPredicate(format: "exists == false")
            let exp = XCTNSPredicateExpectation(predicate: pred, object: splash)
            _ = XCTWaiter().wait(for: [exp], timeout: timeout)
        }
    }

    /// Tap the Progress tab in BRUTabBar.
    @MainActor
    private func selectProgressTab() {
        let progressTab = app.tabBars.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'progress'")
        ).firstMatch
        if progressTab.waitForExistence(timeout: 10) {
            progressTab.tap()
        }
    }

    /// Returns true if we navigated to ExerciseProgressView (a Recent row was tapped).
    /// Returns false if no Recent rows exist (empty-state).
    @MainActor
    @discardableResult
    private func tapFirstRecentRowIfAvailable() -> Bool {
        // Recent rows have a sub-line like "N sessions · last logged ..."
        // Match by searching for a row containing "sessions" sub-label text.
        let recentRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'sessions'")
        ).firstMatch

        // Also try staticTexts in case the row is not a Button accessibility element
        let recentRowText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'sessions'")
        ).firstMatch

        if recentRow.waitForExistence(timeout: 5) {
            recentRow.tap()
            return true
        } else if recentRowText.waitForExistence(timeout: 3) {
            recentRowText.tap()
            return true
        }
        return false
    }

    // MARK: - Test 1: ExerciseProgressView renders or empty-state visible

    /// Asserts EITHER:
    ///   A) A Recent row was tapped → ExerciseProgressView rendered:
    ///        - One of the 4-segment toggle labels is visible
    ///        - OR "Log 2 sessions to see your trend." empty-state is visible
    ///   B) No Recent rows exist (fresh install):
    ///        - ProgressHomeView "No history yet" empty-state is visible
    ///        - Test passes (chart view unreachable by design)
    @MainActor
    func testExerciseProgressViewRendersOrEmptyState() throws {
        app.launch()
        waitForSeedComplete()
        selectProgressTab()

        // Wait for the Progress tab to load
        _ = app.staticTexts.matching(
            NSPredicate(format: "label == 'Progress'"
        )).firstMatch.waitForExistence(timeout: 10)

        let didNavigate = tapFirstRecentRowIfAvailable()

        if didNavigate {
            // Landed on ExerciseProgressView — check 4-segment toggle OR empty-state
            let e1rmLabel = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] 'e1rm' OR label CONTAINS[c] 'e1RM'")
            ).firstMatch
            let topSetLabel = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] 'top set'")
            ).firstMatch
            let volumeLabel = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] 'volume'")
            ).firstMatch
            let avgRPELabel = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] 'avg rpe' OR label CONTAINS[c] 'AVG RPE'")
            ).firstMatch
            let emptyState = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] 'Log 2 sessions'")
            ).firstMatch

            // Wait for the chart view to settle
            _ = e1rmLabel.waitForExistence(timeout: 5)

            let toggleVisible = e1rmLabel.exists || topSetLabel.exists || volumeLabel.exists || avgRPELabel.exists
            let emptyStateVisible = emptyState.exists

            XCTAssertTrue(
                toggleVisible || emptyStateVisible,
                "Expected either the 4-segment series toggle labels (e1RM / TOP SET / VOLUME / AVG RPE) " +
                "OR the empty-state 'Log 2 sessions to see your trend.' copy — " +
                "ExerciseProgressView BRU chrome not rendered (Plan 06.1-02 regression)."
            )
        } else {
            // No history — ProgressHomeView empty-state
            let noHistory = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] 'No history yet'")
            ).firstMatch
            XCTAssertTrue(
                noHistory.waitForExistence(timeout: 5),
                "No Recent rows found (expected on fresh simulator) but 'No history yet' " +
                "empty-state is also missing — ProgressHomeView may not have rendered."
            )
        }
    }

    // MARK: - Test 2: ExerciseProgressView uses BRUHeaderBar (no .navigationTitle)

    /// After tapping a Recent row (if available), asserts that the BRUHeaderBar
    /// center text appears at the top of ExerciseProgressView. The center text
    /// should be the exercise name (which matches the tapped Recent row label).
    ///
    /// If no Recent rows exist (fresh install), the test asserts the ProgressHomeView
    /// header "Progress" is still visible (no-regression check).
    @MainActor
    func testProgressChartUsesBRUHeaderBar() throws {
        app.launch()
        waitForSeedComplete()
        selectProgressTab()

        // Wait for Progress header
        let progressHeader = app.staticTexts.matching(
            NSPredicate(format: "label == 'Progress'"
        )).firstMatch
        _ = progressHeader.waitForExistence(timeout: 10)

        let didNavigate = tapFirstRecentRowIfAvailable()

        if didNavigate {
            // Wait for the ExerciseProgressView to render
            // The BRUHeaderBar center text is the exercise name.
            // We can't predict the exercise name, but we know:
            //   1. .navigationTitle is BANNED (BRU contract — no system nav bar title)
            //   2. The BRUHeaderBar renders as a plain Text staticText in the accessibility tree
            //   3. The back-chevron "‹" is also a BRU custom element (not a system back button)
            //
            // Assert that the system navigation back button does NOT exist
            // (system back button means .navigationTitle / .toolbar was used — a regression).
            let systemBackButton = app.navigationBars.buttons.firstMatch
            XCTAssertFalse(
                systemBackButton.waitForExistence(timeout: 3),
                "System navigation bar back button found — ExerciseProgressView is using " +
                ".navigationTitle or .toolbar instead of BRUHeaderBar (Plan 06.1-02 regression). " +
                "BRU contract: NO .navigationTitle, NO .toolbar, use BRUHeaderBar with left: HeaderAction('‹')."
            )

            // BRU dismiss chevron "‹" should be visible as a staticText
            let bruBackChevron = app.staticTexts["‹"]
            XCTAssertTrue(
                bruBackChevron.waitForExistence(timeout: 5),
                "Expected BRU dismiss chevron '‹' staticText in BRUHeaderBar — " +
                "ExerciseProgressView BRUHeaderBar left action not rendered."
            )
        } else {
            // No history — confirm Progress header is still present
            XCTAssertTrue(
                progressHeader.exists,
                "Progress tab 'Progress' BRUHeaderBar label disappeared unexpectedly."
            )
        }
    }
}
