//
//  DeloadAdvisoryBannerUITests.swift
//  fitbodUITests
//
//  Phase 5 PROG-06 — smoke test that the Today tab still renders
//  cleanly after the DeloadAdvisoryBanner wiring lands.
//
//  Driving the banner ON in a UI test requires a test-seeded
//  ModelContainer with 6 sessions matching e1RMDropFixture (the app
//  doesn't currently expose a fixture-seed env var route). The full
//  banner-appears-and-dismisses round-trip is tested at the
//  data-layer via DeloadAdvisorTests (13 GREEN @Test functions).
//  This UI test asserts that the wiring doesn't regress the Today
//  tab's normal render (the safeAreaInset is empty when
//  currentAdvisory is nil, so the tab should appear identical to
//  pre-04).
//

import XCTest

final class DeloadAdvisoryBannerUITests: XCTestCase {

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
        let today = app.buttons["Today"]
        if today.waitForExistence(timeout: 10) {
            today.tap()
        }
    }

    @MainActor
    func testTodayTabRendersWithDeloadBannerWiring() throws {
        let app = XCUIApplication()
        app.launch()
        waitForSeedComplete(app)
        selectTodayTab(app)

        // The Today tab still renders the Volume This Week section
        // even when no advisory is active (currentAdvisory == nil →
        // safeAreaInset returns an empty render slot, so the FatigueSurfaceView
        // stays at its normal position in the stack).
        let header = app.staticTexts["Volume This Week"]
        XCTAssertTrue(header.waitForExistence(timeout: 30))
    }

    @MainActor
    func testDeloadBannerIsAbsentWhenNoSignalsFire() throws {
        let app = XCUIApplication()
        app.launch()
        waitForSeedComplete(app)
        selectTodayTab(app)

        // Without seeded signals the banner copy substring should NOT
        // be present on screen — confirms the banner is hidden by
        // default (currentAdvisory is nil for fresh installs).
        let banner = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Consider deload'")
        ).firstMatch
        XCTAssertFalse(banner.waitForExistence(timeout: 3))
    }
}
