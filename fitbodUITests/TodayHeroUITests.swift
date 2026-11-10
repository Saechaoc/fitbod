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

    /// With no block Today leads with the suggested session, and the session
    /// sheet marks it NEXT, says what another session skips and starts that
    /// session on a tap (RM-006).
    @MainActor
    func testNoBlockHeroAndSessionSheet() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore + ["-fitbod-seed-today-pick"])
        for label in ["NEXT UP · PUSH PULL LEGS", "PULL A"] {
            XCTAssertTrue(UITestNavigation.appears(app.staticTexts.labeled(label), within: 10), "Missing \(label)")
        }
        let choose = app.buttons["today.chooseSession"]
        XCTAssertTrue(UITestNavigation.appears(choose), "Today must offer another session")
        choose.tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts.labeled("Start a workout")), "The session sheet must open")

        func row(_ name: String) -> XCUIElement {
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", name)).firstMatch
        }
        XCTAssertTrue(row("Pull A").label.localizedCaseInsensitiveContains("Next"), "The suggested session must be marked NEXT")
        XCTAssertTrue(row("Push A").label.localizedCaseInsensitiveContains("skips Pull A, Legs A"),
                      "A session past NEXT must say what it skips, but reads \"\(row("Push A").label)\"")
        XCTAssertFalse(row("Legs A").isEnabled, "A session with no exercises must not start")
        XCTAssertTrue(row("Arms").exists, "A session in no routine must be listed")
        UITestNavigation.saveScreenshot("RM006", "session-sheet")

        row("Arms").tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts.labeled("Session"), within: 5),
                      "An Other sessions row must open its session detail")
        XCTAssertTrue(app.staticTexts.labeled("Arms").exists)
        UITestNavigation.hittable(app.buttons, "Back").tap()
        XCTAssertTrue(UITestNavigation.appears(choose))
        choose.tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts.labeled("Start a workout")))

        row("Push A").tap()
        XCTAssertTrue(UITestNavigation.appears(app.textFields["set.reps.1.S1"], within: 15),
                      "A sheet row must start its workout")
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
