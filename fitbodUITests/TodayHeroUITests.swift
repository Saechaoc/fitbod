import XCTest

extension UITestNavigation {
    /// A fresh store plus the block-states seed 22 days in, so Today sits
    /// in Spring Block's deload week (BlockStatesSeed).
    static let blockStatesDeload = [resetFlag, "-fitbod-seed-block-states-deload"]
}

/// Redesign step 1.2. Today's hero names the session's place in the cycle,
/// counts the working sets the phase yields and sits above the fold; the
/// Exercises head opens the session; a deload week says so and its rows
/// read the cut sets.
final class TodayHeroUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// On the active block the hero reads NEXT UP · 1 OF 1 with its set
    /// count and estimate, Start workout ▸ is tappable without scrolling,
    /// and View › opens the session.
    @MainActor
    func testStartWorkoutSitsAboveTheFold() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts.labeled("NEXT UP · 1 OF 1"), within: 10),
                      "The hero must name the session's place in the cycle")
        XCTAssertTrue(app.staticTexts.labeled("3 SETS").exists, "The hero must count the working sets")
        XCTAssertTrue(app.staticTexts.labeled("~11 MIN").exists, "The hero must estimate the session")
        let start = UITestNavigation.hittable(app.buttons, "Start workout ▸")
        XCTAssertLessThan(start.frame.maxY, UITestNavigation.tab("Today", in: app).frame.minY,
                          "Start workout ▸ must sit above the tab bar without scrolling")
        UITestNavigation.hittable(app.buttons, "View ›").tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts.labeled("Session"), within: 5),
                      "View › must open the session")
    }

    /// In the deload week the hero cuts its set count and says why, and the
    /// rows read the cut sets with no chip beside them.
    @MainActor
    func testDeloadWeekShowsTheCutSets() throws {
        let app = UITestNavigation.launch(UITestNavigation.blockStatesDeload)
        for label in ["NEXT UP · 1 OF 2", "UPPER A", "1 SET", "~5 MIN", "DELOAD WEEK · LIGHTER SETS", "1 × 5-8"] {
            XCTAssertTrue(UITestNavigation.appears(app.staticTexts.labeled(label), within: 10), "Missing \(label)")
        }
        XCTAssertFalse(app.staticTexts.labeled("Compound").exists, "No chip remains on a row")
        XCTAssertFalse(app.staticTexts.labeled("Work").exists, "No chip remains on a row")
    }
}
