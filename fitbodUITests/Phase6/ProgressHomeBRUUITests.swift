//
//  ProgressHomeBRUUITests.swift
//  fitbodUITests
//
//  Phase 6.1 Plan 07 — UI smoke tests for the Phase 6 BRU reskin of
//  ProgressHomeView (Plan 06.1-01). Confirms:
//    1. The BRUHeaderBar "Progress" center label renders after navigation
//       to the Progress tab in BRUTabBar.
//    2. The 3 BRUSectionHead labels (Recent, Trends, Compare) are
//       reachable in the accessibility hierarchy — even on a fresh
//       simulator with no seeded data (they render via empty-state copy).
//    3. The Progress tab itself is hittable (basic accessibility check).
//
//  XCTest (not Swift Testing) — UI tests must use XCUIApplication.
//  Per CLAUDE.md: Swift Testing does not support XCUIApplication.
//
//  Adaptive: tests branch on data availability. All 3 BRUSectionHeads
//  render regardless of session data since empty-state is always shown.
//

import XCTest

final class ProgressHomeBRUUITests: XCTestCase {

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
    /// First launch seeds ~800 exercises, which can take 10–30s on a fresh simulator.
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
        // BRUTabBar uses accessibility identifier matching the label text.
        let progressTab = app.tabBars.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'progress'")
        ).firstMatch
        if progressTab.waitForExistence(timeout: 10) {
            progressTab.tap()
        }
    }

    // MARK: - Test 1: BRUHeaderBar "Progress" title renders

    /// Asserts:
    ///   - Progress tab is tappable in the BRUTabBar.
    ///   - BRUHeaderBar center label "Progress" exists after tab navigation.
    @MainActor
    func testProgressTabRendersWithBRUHeaderBar() throws {
        app.launch()
        waitForSeedComplete()
        selectProgressTab()

        // BRUHeaderBar renders "Progress" as a plain Text staticText.
        // Wait up to 10s for the header to appear after tab tap.
        let progressHeader = app.staticTexts.matching(
            NSPredicate(format: "label == 'Progress'")
        ).firstMatch
        XCTAssertTrue(
            progressHeader.waitForExistence(timeout: 10),
            "Expected BRUHeaderBar center label 'Progress' on the Progress tab — " +
            "BRUHeaderBar not rendered or label changed (Plan 06.1-01 regression)."
        )
    }

    // MARK: - Test 2: 3 BRUSectionHead labels visible (Recent / Trends / Compare)

    /// Asserts all 3 BRUSectionHead labels are reachable in the accessibility
    /// hierarchy after navigation to the Progress tab. These headers render
    /// regardless of data state (Recent + Trends + Compare always render,
    /// showing empty-state copy when no sessions exist).
    ///
    /// Uses case-insensitive CONTAINS predicate for robustness against
    /// BRUSectionHead uppercase/mixed-case rendering variants.
    @MainActor
    func testProgressHomeSectionHeadsVisible() throws {
        app.launch()
        waitForSeedComplete()
        selectProgressTab()

        // Wait for the page to settle
        _ = app.staticTexts.matching(
            NSPredicate(format: "label == 'Progress'")
        ).firstMatch.waitForExistence(timeout: 10)

        // "Recent" BRUSectionHead (Plan 06.1-01 renders as "Recent")
        let recentLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'recent'")
        ).firstMatch
        XCTAssertTrue(
            recentLabel.waitForExistence(timeout: 5),
            "Expected 'Recent' BRUSectionHead on ProgressHomeView — " +
            "section head missing or renamed (Plan 06.1-01 regression)."
        )

        // "Trends" BRUSectionHead
        let trendsLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'trends'")
        ).firstMatch
        XCTAssertTrue(
            trendsLabel.waitForExistence(timeout: 5),
            "Expected 'Trends' BRUSectionHead on ProgressHomeView — " +
            "section head missing or renamed."
        )

        // "Compare" BRUSectionHead — may require a scroll on shorter devices
        var compareLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'compare'")
        ).firstMatch
        if !compareLabel.exists {
            app.swipeUp()
            compareLabel = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] 'compare'")
            ).firstMatch
        }
        XCTAssertTrue(
            compareLabel.exists,
            "Expected 'Compare' BRUSectionHead on ProgressHomeView — " +
            "section head missing, renamed, or off-screen."
        )
    }

    // MARK: - Test 3: Progress tab is accessible (basic hittability + label check)

    /// Asserts that:
    ///   - The Progress tab button in BRUTabBar is hittable.
    ///   - At least one staticText element exists on the Progress tab
    ///     (confirms the view rendered, not a blank screen).
    @MainActor
    func testProgressTabIsAccessible() throws {
        app.launch()
        waitForSeedComplete()

        // Assert the tab exists and is hittable before tapping
        let progressTab = app.tabBars.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'progress'")
        ).firstMatch
        XCTAssertTrue(
            progressTab.waitForExistence(timeout: 10),
            "Progress tab button not found in BRUTabBar."
        )
        XCTAssertTrue(
            progressTab.isHittable,
            "Progress tab button exists but is not hittable (may be off-screen or obscured)."
        )

        progressTab.tap()

        // At least one static text element should be present
        // (BRUHeaderBar "Progress" is always rendered).
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 10)
        XCTAssertFalse(
            app.staticTexts.firstMatch.label.isEmpty,
            "Expected at least one non-empty staticText on the Progress tab — " +
            "screen may have rendered blank."
        )
    }
}
