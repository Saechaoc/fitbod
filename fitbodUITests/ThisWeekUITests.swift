import XCTest

/// Program's This week (RM-015): TODAY ▸ starts the planned session in the
/// logger on Today's stack, where the logger lives, and a done row opens
/// its workout's summary on Program's own stack.
final class ThisWeekUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTodayStartsTheSessionInTodaysLogger() throws {
        let app = UITestNavigation.launch([UITestNavigation.resetFlag, "-fitbod-seed-today-weekly", "-fitbod-start-program"])
        UITestNavigation.selectTab("Program", in: app)

        let start = app.buttons["program.thisWeek.start"]
        XCTAssertTrue(UITestNavigation.appears(start), "This week must offer TODAY ▸ while Today is T-TODAY")
        UITestNavigation.reveal(start, in: app)
        start.tap()

        XCTAssertTrue(UITestNavigation.appears(app.otherElements["workout.header"], within: 15), "TODAY ▸ must open the logger")
        back(in: app)
        XCTAssertTrue(UITestNavigation.appears(app.buttons["resumeSlab.resume"], within: 15), "‹ must land on Today's RESUME ▸")
        XCTAssertTrue(UITestNavigation.tab("Today", in: app).isSelected, "the logger must open on the Today tab")
    }

    @MainActor
    func testTodaysDoneRowOpensItsSummaryOnProgram() throws {
        let app = UITestNavigation.launch([UITestNavigation.resetFlag, "-fitbod-seed-today-done-weekly", "-fitbod-start-program"])
        UITestNavigation.selectTab("Program", in: app)

        // The seed finishes the session the block plans today, so today's group has a done row on every weekday.
        let weekday = Date.now.formatted(Date.FormatStyle(locale: Locale(identifier: "en_US")).weekday(.wide))
        let done = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND value BEGINSWITH 'Done'", "\(weekday):")).firstMatch
        XCTAssertTrue(UITestNavigation.appears(done), "This week must list today's workout as done")
        UITestNavigation.reveal(done, in: app)
        done.tap()

        XCTAssertTrue(UITestNavigation.appears(app.staticTexts["Summary"]), "the done row must open its summary")
        XCTAssertTrue(UITestNavigation.tab("Program", in: app).isSelected, "the summary must open on Program's stack")
        back(in: app)
        XCTAssertTrue(UITestNavigation.appears(done), "‹ must return to This week")
        XCTAssertTrue(UITestNavigation.tab("Program", in: app).isSelected, "‹ must stay on Program")
    }

    /// The header's back control reads BACK on the detail screens and ‹,
    /// spoken "Back", in the logger.
    @MainActor
    private func back(in app: XCUIApplication) {
        let button = app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Back")).firstMatch
        XCTAssertTrue(UITestNavigation.appears(button), "Missing Back")
        button.tap()
    }
}
