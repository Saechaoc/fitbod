import XCTest

/// Ticket T112, findings F229 to F231. An exercise's history shows a row
/// for every workout: its date, intent chip, e1RM, TOP line and set chips.
/// Every row was blank, because each date section and its one row shared
/// the workout's id. A row whose workout set a PR shows "★ PR".
///
/// The progress-history seed logs four bench press workouts, a week
/// apart. The newest is a strength workout of 107.5×2 @9.5, 95×6 @8 and
/// 90×5 @7, so its e1RM is 120.3, and its 107.5 is the heaviest bench yet.
final class ExerciseHistoryRowsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNewestWorkoutRowShowsItsE1RMAndSetChips() throws {
        let app = openBenchPressHistory()
        let e1RM = e1RMs(in: app).firstMatch
        XCTAssertTrue(e1RM.waitForExistence(timeout: 10), "The history must show its workout rows")
        XCTAssertEqual(e1RM.label, "e1RM 120.3", "The first row must be the newest workout")
        for chip in ["107.5×2 @9.5", "95×6 @8", "90×5 @7"] {
            XCTAssertTrue(app.staticTexts[chip].exists, "The newest workout's row must show its set chip \(chip)")
        }
        XCTAssertTrue(app.staticTexts["107.5×2 @9.5"].frame.minY > e1RM.frame.maxY,
                      "The set chips must sit under the row's top line")
        // The row's date line shows the date, and no section header repeats it.
        XCTAssertEqual(e1RMs(in: app).count, 4, "Each of the four bench workouts must have its row")
        let date = try XCTUnwrap(dateLine(of: e1RM, in: app), "The newest row must show its date")
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", date.label)).count, 1,
                       "The date \(date.label) must show once, not in a header and the row")
    }

    @MainActor
    func testWorkoutThatSetAPRShowsThePRChip() throws {
        let app = openBenchPressHistory()
        let e1RM = e1RMs(in: app).firstMatch
        XCTAssertTrue(e1RM.waitForExistence(timeout: 10), "The history must show its workout rows")
        let prChips = app.staticTexts.matching(NSPredicate(format: "label == %@", "★ PR"))
        let onNewestRow = prChips.allElementsBoundByIndex.contains { abs($0.frame.midY - e1RM.frame.midY) < 20 }
        XCTAssertTrue(onNewestRow, "The newest workout's 107.5 is a weight PR, so its row must show ★ PR")
    }

    // MARK: - Helpers

    /// Every workout row's e1RM, top row first.
    @MainActor
    private func e1RMs(in app: XCUIApplication) -> XCUIElementQuery {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "e1RM "))
    }

    /// The text at the leading end of `e1RM`'s line: the row's date.
    @MainActor
    private func dateLine(of e1RM: XCUIElement, in app: XCUIApplication) -> XCUIElement? {
        app.staticTexts.allElementsBoundByIndex
            .filter { abs($0.frame.midY - e1RM.frame.midY) < 20 && $0.frame.minX < 40 }
            .first
    }

    /// Library > the seeded bench press > VIEW ALL HISTORY.
    @MainActor
    private func openBenchPressHistory(textSize: UITestNavigation.TextSize? = nil) -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory, textSize: textSize)
        UITestNavigation.selectTab("Library", in: app)
        UITestNavigation.type("Barbell Bench Press", into: app.textFields["library.search.browser"], replacing: false)
        let bench = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Barbell Bench Press - Medium Grip")).firstMatch
        tapWhenReady(bench, in: app)
        tapWhenReady(app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "View all history")).firstMatch, in: app)
        let prs = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "PRs · 30d")).firstMatch
        XCTAssertTrue(prs.waitForExistence(timeout: 10), "VIEW ALL HISTORY must open the bench press's history")
        UITestNavigation.waitUntilStill(prs, interval: 0.3)
        return app
    }

    @MainActor
    private func tapWhenReady(_ control: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(control.waitForExistence(timeout: 15), "Missing \(control)", file: file, line: line)
        UITestNavigation.reveal(control, in: app)
        let deadline = Date.now.addingTimeInterval(10)
        while !control.isHittable && Date.now < deadline { Thread.sleep(forTimeInterval: 0.25) }
        control.tap()
    }
}
