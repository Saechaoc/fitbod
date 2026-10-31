//
//  SessionComparisonUITests.swift
//  fitbodUITests
//
//  T102. Compare ("This week vs last week") on the small phone, with
//  logged Push As six days and one day ago and an empty one between them
//  (-fitbod-seed-empty-between). Every lift is 2.5 heavier the second
//  time, so each e1RM change keeps its formula's digits, such as 2.8125
//  for the bench press's five reps.
//
//    - The header goes back with ‹ BACK, which returns to Progress.
//    - No e1RM change shows more than one decimal.
//

import XCTest

final class SessionComparisonUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Compare is a pushed screen, so its header goes back with ‹ BACK
    /// rather than a bare ‹. VoiceOver calls both "Back", so the shown text
    /// comes off a screenshot.
    @MainActor
    func testHeaderGoesBackWithBack() throws {
        let app = openCompare()
        let back = UITestNavigation.hittable(app.buttons, "Back", exactLabel: true)
        let title = UITestNavigation.hittable(app.staticTexts, "This week vs last week", exactLabel: true)
        UITestNavigation.waitUntilStill(back, interval: 0.3)
        UITestNavigation.saveScreenshot("T102", "compare")

        let shown = UITestNavigation.latin(try UITestNavigation.readText(in: back.frame, of: XCUIScreen.main.screenshot()))
        XCTAssertTrue(shown.contains("BACK"), "Compare's back control must read ‹ BACK, but reads \"\(shown)\"")
        UITestNavigation.assertInside(back, app.windows.firstMatch)
        UITestNavigation.assertTapTarget(back)
        UITestNavigation.assertNoOverlap(back, title)

        back.tap()
        XCTAssertTrue(app.staticTexts["Δ"].waitForNonExistence(timeout: 10), "‹ BACK must close Compare")
        let returned = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: compareRow(in: app))
        XCTAssertEqual(XCTWaiter().wait(for: [returned], timeout: 10), .completed, "‹ BACK must return to Progress")
    }

    /// Each e1RM change shows one decimal at most, such as "+2.8 e1RM lb"
    /// for the bench press's 2.8125, and a whole change shows none.
    @MainActor
    func testE1RMChangesShowOneDecimalAtMost() throws {
        let app = openCompare()
        let changes = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[+\u{2212}].* e1RM .*$"))
        XCTAssertTrue(changes.firstMatch.waitForExistence(timeout: 10), "Compare shows no e1RM change")
        let labels = changes.allElementsBoundByIndex.map(\.label)
        let tooPrecise = labels.filter {
            $0.range(of: "^[+\u{2212}][0-9]+(\\.[0-9])? e1RM \\S+$", options: .regularExpression) == nil
        }
        XCTAssertEqual(tooPrecise, [], "No e1RM change may show more than one decimal, but Compare shows \(labels)")
    }

    // MARK: - Helpers

    /// Progress's Compare row, tapped, once Compare's column header is up.
    @MainActor
    private func openCompare() -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.emptyBetween)
        UITestNavigation.selectTab("Progress", in: app)
        scrollToCompare(in: app)
        let row = compareRow(in: app)
        XCTAssertTrue(row.exists, "Two logged workouts must unlock Compare")
        row.tap()
        XCTAssertTrue(app.staticTexts["Δ"].waitForExistence(timeout: 10), "Compare must open on its columns")
        return app
    }

    /// Progress's "This week vs last week" row.
    @MainActor
    private func compareRow(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "This week vs last week")).firstMatch
    }

    /// Scrolls Progress down until its Compare section sits above the tab
    /// bar. Hidden tabs keep their scroll views, so it swipes the one a
    /// user can touch.
    @MainActor
    private func scrollToCompare(in app: XCUIApplication) {
        UITestNavigation.reveal(app.staticTexts["Compare"], in: app)
        app.scrollViews.allElementsBoundByIndex.last(where: { $0.isHittable })?.swipeUp(velocity: .slow)
    }
}
