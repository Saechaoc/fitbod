//
//  BodySilhouetteUITests.swift
//  fitbodUITests
//
//  Phase 5 VOL-05 — smoke test that the Muscle Heatmap section
//  renders on the Today tab AND the Front/Back segmented control is
//  reachable.
//
//  Tap-to-navigate-into-PerMuscleDetailView is exercised in
//  PerMuscleDetailUITests via the volume-bar tap path (the bar's
//  accessibility tree is more stable than the per-region Path
//  hit-test geometry across simulator runs).
//

import XCTest

final class BodySilhouetteUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

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
    private func selectTodayTab(_ app: XCUIApplication) {
        let today = app.tabBars.buttons["Today"]
        if today.waitForExistence(timeout: 10) { today.tap() }
    }

    @MainActor
    private func scrollUntilVisible(_ app: XCUIApplication, text: String, maxSwipes: Int = 10) -> Bool {
        let target = app.staticTexts[text]
        if target.exists { return true }
        for _ in 0..<maxSwipes {
            app.swipeUp()
            if target.exists { return true }
        }
        return target.exists
    }

    @MainActor
    func testHeatmapSectionRendersOnTodayTab() throws {
        let app = XCUIApplication()
        app.launch()
        waitForSeedComplete(app)
        selectTodayTab(app)

        let reached = scrollUntilVisible(app, text: "Muscle Heatmap")
        XCTAssertTrue(reached, "Expected 'Muscle Heatmap' section header on Today tab")
    }

    @MainActor
    func testFrontBackSegmentedControlPresent() throws {
        let app = XCUIApplication()
        app.launch()
        waitForSeedComplete(app)
        selectTodayTab(app)
        _ = scrollUntilVisible(app, text: "Muscle Heatmap")

        // Segmented control buttons render as XCUIElements of type
        // .button inside .segmentedControls.
        let frontButton = app.buttons["Front"]
        let backButton = app.buttons["Back"]
        XCTAssertTrue(frontButton.waitForExistence(timeout: 5), "Front segmented control button missing")
        XCTAssertTrue(backButton.exists, "Back segmented control button missing")
    }
}
