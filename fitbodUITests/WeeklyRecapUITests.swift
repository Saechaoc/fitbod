//
//  WeeklyRecapUITests.swift
//  fitbodUITests
//
//  Phase 5 VOL-07 — smoke test that the WeeklyRecapSheet does NOT
//  spuriously appear on a fresh launch (no test-seed fixture has
//  been written for "force-show recap" yet — the trigger algorithm
//  is pinned at the data layer via 5 GREEN WeeklyRecapTriggerTests).
//
//  Once the simulator state has been through one Monday cycle with
//  no sessions logged in the prior week, the trigger's "mark seen"
//  branch fires (Pitfall #8) and subsequent launches are quiet.
//

import XCTest

final class WeeklyRecapUITests: XCTestCase {

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
    func testTodayTabDoesNotSpuriouslyShowRecap() throws {
        let app = XCUIApplication()
        app.launch()
        waitForSeedComplete(app)
        selectTodayTab(app)

        // The recap sheet's nav bar is "Weekly Recap". If it spuriously
        // appears (without test-seeded prior-week sessions), the
        // trigger logic is wrong. We wait briefly then assert absent.
        let recap = app.navigationBars["Weekly Recap"]
        // Give the .task time to evaluate.
        _ = recap.waitForExistence(timeout: 3)
        XCTAssertFalse(recap.exists, "WeeklyRecapSheet should not auto-present without prior-week sessions on a fresh simulator")
    }
}
