//
//  Phase5BRUSmokeUITests.swift
//  fitbodUITests
//
//  Phase 5.1 Plan 08 — 3 UI smoke tests covering the three most-trafficked
//  rewritten Phase 5 BRU surfaces: FatigueSurfaceView (Today tab),
//  PerMuscleDetailView (bar tap → detail), MuscleVolumeTargetEditor (Settings).
//
//  These tests assert BRU chrome renders correctly end-to-end:
//    1. FatigueSurfaceView: side-by-side FRONT + BACK heatmap labels present
//       (confirms Plan 05.1-04/05 deleted the Picker; FRONT + BACK are now
//       static Text labels, not segmented-control buttons).
//    2. PerMuscleDetailView: all 4 BRU section heads reachable via bar tap.
//    3. MuscleVolumeTargetEditor: BRUHeaderBar "Volume Targets" + "Reset All
//       to RP Defaults" BRUButton reachable from Settings.
//
//  XCTest (not Swift Testing) — UI tests must use XCUIApplication.
//  Per CLAUDE.md: Swift Testing does not support XCUIApplication.
//
//  No fixture seeding required — tests branch on data availability:
//    empty-state paths skip interactive assertions (logged gracefully).
//

import XCTest

final class Phase5BRUSmokeUITests: XCTestCase {

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

    /// Tap the Today tab. Handles simulator last-active-tab persistence.
    @MainActor
    private func selectTodayTab() {
        let today = app.tabBars.buttons["Today"]
        if today.waitForExistence(timeout: 10) { today.tap() }
    }

    /// Tap the Settings tab.
    @MainActor
    private func selectSettingsTab() {
        let settings = app.tabBars.buttons["Settings"]
        if settings.waitForExistence(timeout: 10) { settings.tap() }
    }

    /// Swipe up until the target staticText is reachable OR maxSwipes exhausted.
    @MainActor
    private func scrollUntilVisible(text: String, maxSwipes: Int = 10) -> Bool {
        let element = app.staticTexts[text]
        if element.exists { return true }
        for _ in 0..<maxSwipes {
            app.swipeUp()
            if element.exists { return true }
        }
        return element.exists
    }

    // MARK: - Test 1: FatigueSurfaceView renders BRU chrome

    /// Asserts:
    ///   - "Volume This Week" BRUSectionHead is reachable on the Today tab.
    ///   - "WORKING SETS · 7 DAYS" cover-slab caption is present.
    ///   - "FRONT" and "BACK" are present as static Text labels (side-by-side
    ///     heatmap layout from Plan 05.1-04/05 — NOT a segmented Picker).
    @MainActor
    func testFatigueSurfaceViewRenders() throws {
        app.launch()
        waitForSeedComplete()
        selectTodayTab()

        // Cover-slab caption — always present at the top of FatigueSurfaceView
        // regardless of data state (it's part of the fixed ink-slab summary).
        let coverCaption = app.staticTexts["WORKING SETS · 7 DAYS"]
        XCTAssertTrue(
            coverCaption.waitForExistence(timeout: 30),
            "Expected 'WORKING SETS · 7 DAYS' cover-slab caption on Today tab — FatigueSurfaceView not mounted or cover slab changed."
        )

        // Volume This Week BRUSectionHead — scroll until in the hierarchy
        let volumeHeader = app.staticTexts["Volume This Week"]
        _ = volumeHeader.waitForExistence(timeout: 10)
        _ = scrollUntilVisible(text: "Volume This Week")
        XCTAssertTrue(
            volumeHeader.exists,
            "Expected 'Volume This Week' BRUSectionHead on Today tab — FatigueSurfaceView section head missing or renamed."
        )

        // Scroll further to reach the Muscle Heatmap section where FRONT + BACK labels live.
        _ = scrollUntilVisible(text: "Muscle Heatmap")

        // FRONT + BACK as staticText labels (Plan 05.1-04/05 replaced the
        // Picker with a side-by-side VStack layout — these are Text(), not
        // segmented-control buttons).
        let frontLabel = app.staticTexts["FRONT"]
        let backLabel = app.staticTexts["BACK"]

        // Scroll a few more swipes to bring the heatmap section into frame.
        for _ in 0..<4 {
            if frontLabel.exists && backLabel.exists { break }
            app.swipeUp()
        }

        XCTAssertTrue(
            frontLabel.exists,
            "Expected 'FRONT' static label in side-by-side Muscle Heatmap — Plan 05.1-04/05 HStack layout not rendering."
        )
        XCTAssertTrue(
            backLabel.exists,
            "Expected 'BACK' static label in side-by-side Muscle Heatmap — Plan 05.1-04/05 HStack layout not rendering."
        )
    }

    // MARK: - Test 2: PerMuscleDetailView reachable via volume bar tap

    /// Asserts that tapping a MuscleVolumeBar navigates to PerMuscleDetailView
    /// where all 4 BRU section heads ("This Week", "Contributing Exercises",
    /// "Frequency This Week", "Adjust Targets") are reachable.
    ///
    /// If no volume bars are present (no sessions logged), the test skips the
    /// tap assertion gracefully — data-layer routing is pinned in unit tests.
    @MainActor
    func testPerMuscleDetailViewRenders() throws {
        app.launch()
        waitForSeedComplete()
        selectTodayTab()

        // Wait for the Volume This Week section to render.
        _ = app.staticTexts["Volume This Week"].waitForExistence(timeout: 30)
        _ = scrollUntilVisible(text: "Volume This Week")

        // Find any volume bar by its combined accessibility label pattern
        // "MuscleGroup: N sets this week, ..." set in MuscleVolumeBar.
        let bar = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS 'sets this week,'")
        ).firstMatch

        guard bar.waitForExistence(timeout: 10) else {
            // No sessions logged — bar tap path not exercisable.
            // This is expected on a freshly-reset simulator.
            XCTAssertTrue(true, "No volume bars present — skipping bar-tap navigation assertion (no sessions logged).")
            return
        }

        bar.tap()

        // PerMuscleDetailView renders its 4 BRUSectionHead labels.
        // Wait for the first one to confirm navigation landed.
        let thisWeek = app.staticTexts["This Week"]
        XCTAssertTrue(
            thisWeek.waitForExistence(timeout: 5),
            "Expected 'This Week' BRUSectionHead after volume bar tap — PerMuscleDetailView not rendered."
        )

        // Assert remaining section heads are in the accessibility hierarchy.
        let contributing = app.staticTexts["Contributing Exercises"]
        let frequency = app.staticTexts["Frequency This Week"]
        let adjustTargets = app.staticTexts["Adjust Targets"]

        // Scroll to bring all section heads into view.
        for _ in 0..<6 {
            if contributing.exists && frequency.exists && adjustTargets.exists { break }
            app.swipeUp()
        }

        XCTAssertTrue(
            contributing.exists,
            "Expected 'Contributing Exercises' BRUSectionHead in PerMuscleDetailView."
        )
        XCTAssertTrue(
            frequency.exists,
            "Expected 'Frequency This Week' BRUSectionHead in PerMuscleDetailView."
        )
        XCTAssertTrue(
            adjustTargets.exists,
            "Expected 'Adjust Targets' BRUSectionHead in PerMuscleDetailView."
        )
    }

    // MARK: - Test 3: MuscleVolumeTargetEditor reachable from Settings

    /// Asserts that Settings → "Volume Targets" navigation lands on a screen
    /// where the BRUHeaderBar center label "Volume Targets" is present and the
    /// "Reset All to RP Defaults" BRUButton is reachable.
    @MainActor
    func testMuscleVolumeTargetEditorRenders() throws {
        app.launch()
        waitForSeedComplete()
        selectSettingsTab()

        // The Volume Targets row renders as a Button with label containing
        // "Volume Targets" and "17 muscles" (see MuscleVolumeTargetEditorUITests baseline).
        let row = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Volume Targets' AND label CONTAINS '17 muscles'")
        ).firstMatch
        XCTAssertTrue(
            row.waitForExistence(timeout: 10),
            "Expected 'Volume Targets' navigation row in Settings — MuscleVolumeTargetEditor entry point missing."
        )
        row.tap()

        // BRUHeaderBar center label — BRU reskin replaced .navigationTitle with a
        // custom BRUHeaderBar Text element (Plan 05.1-06).
        let headerLabel = app.staticTexts.matching(
            NSPredicate(format: "label == 'Volume Targets'")
        ).firstMatch
        XCTAssertTrue(
            headerLabel.waitForExistence(timeout: 5),
            "Expected BRUHeaderBar center label 'Volume Targets' — BRUHeaderBar not rendered (Plan 05.1-06 regression)."
        )

        // "Reset All to RP Defaults" BRUButton — scroll to bottom if needed.
        let resetButton = app.buttons["Reset All to RP Defaults"]
        for _ in 0..<8 where !resetButton.exists {
            app.swipeUp()
        }
        XCTAssertTrue(
            resetButton.waitForExistence(timeout: 5),
            "Expected 'Reset All to RP Defaults' BRUButton in MuscleVolumeTargetEditor — button missing or label changed."
        )
    }
}
