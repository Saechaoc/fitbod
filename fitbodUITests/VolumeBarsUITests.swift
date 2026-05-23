//
//  VolumeBarsUITests.swift
//  fitbodUITests
//
//  Phase 5 — Today-tab VolumeSurface smoke + UI-SPEC verbatim copy
//  presence checks.
//
//  This test launches the app against whatever on-disk store the
//  developer machine has (the simulator's per-user data; the test
//  doesn't reset it). The goal is twofold:
//    1. The "Volume This Week" section header is reachable from the
//       Today tab — the surface is mounted at the correct place in
//       the RootView stack (UI-SPEC §Phase 4 ↔ Phase 5 boundary).
//    2. Either the empty-state heading "No sets logged this week" OR
//       at least one of the D-06 verbatim verb strings is visible
//       (depending on whether the simulator has any sessions logged).
//
//  No fixture seeding is required — the dual-branch assertion covers
//  both the "no sessions yet" path and the "some sessions logged" path
//  without needing to control the data.
//

import XCTest

final class VolumeBarsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Wait until the splash "Preparing library…" indicator disappears
    /// OR the timeout expires, then yield control. The library seed
    /// can take 10–30s on a freshly-reset simulator.
    @MainActor
    private func waitForSeedComplete(_ app: XCUIApplication, timeout: TimeInterval = 60) {
        let splash = app.staticTexts["Preparing library…"]
        if splash.exists {
            // Wait for it to vanish.
            let pred = NSPredicate(format: "exists == false")
            let exp = XCTNSPredicateExpectation(predicate: pred, object: splash)
            _ = XCTWaiter().wait(for: [exp], timeout: timeout)
        }
    }

    /// Swipe up on the scroll view until the target staticText is hit
    /// OR we've tried `maxSwipes` times. Returns whether the target
    /// became visible (existence is not the same as "hittable" on iOS
    /// — `exists` returns true for any element in the hierarchy even
    /// when off-screen).
    @MainActor
    private func scrollUntilVisible(
        _ app: XCUIApplication,
        text: String,
        maxSwipes: Int = 8
    ) -> Bool {
        let element = app.staticTexts[text]
        if element.exists { return true }
        for _ in 0..<maxSwipes {
            if element.exists { return true }
            app.swipeUp()
        }
        return element.exists
    }

    /// Tap the Today tab (the launch tab can be Library if that was
    /// the last-active tab on the simulator's saved state).
    @MainActor
    private func selectTodayTab(_ app: XCUIApplication) {
        let today = app.tabBars.buttons["Today"]
        if today.waitForExistence(timeout: 10) {
            today.tap()
        }
    }

    @MainActor
    func testVolumeSurfaceMountedOnTodayTab() throws {
        let app = XCUIApplication()
        app.launch()
        waitForSeedComplete(app)
        selectTodayTab(app)

        // Wait for the Today tab to settle. The header may live below
        // the BlockCard + ResumeWorkoutBanner so the test scrolls
        // until the target is in the element hierarchy.
        let header = app.staticTexts["Volume This Week"]
        _ = header.waitForExistence(timeout: 30)
        let visible = scrollUntilVisible(app, text: "Volume This Week")
        XCTAssertTrue(visible, "Expected 'Volume This Week' section on the Today tab — FatigueSurfaceView is not mounted or the title was changed.")
    }

    @MainActor
    func testEitherEmptyStateOrVerbCopyIsVisible() throws {
        let app = XCUIApplication()
        app.launch()
        waitForSeedComplete(app)
        selectTodayTab(app)

        _ = app.staticTexts["Volume This Week"].waitForExistence(timeout: 30)
        _ = scrollUntilVisible(app, text: "Volume This Week")

        // Either the empty-state OR one of the D-06 verb strings
        // should be visible — depending on the simulator's existing
        // data state. We don't reset the store; we just assert that
        // SOMETHING the volume surface owns is rendered.
        let emptyState = app.staticTexts["No sets logged this week"]
        let belowMEV = app.staticTexts["Below MEV — add volume"]
        let productive = app.staticTexts["Productive range — hold/progress"]
        let nearMRV = app.staticTexts["Near MRV — deload soon if performance or recovery drops."]
        let overMRV = app.staticTexts["Over MRV — deload recommended."]

        let any = emptyState.exists
              || belowMEV.exists
              || productive.exists
              || nearMRV.exists
              || overMRV.exists

        XCTAssertTrue(any, "Expected either the empty-state copy or a D-06 verb string on the Today tab. The volume surface rendered neither — bars are not being produced.")
    }
}
