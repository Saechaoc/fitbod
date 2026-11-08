import XCTest

/// The logger lives on Today's stack only (FT-02): however the workout in
/// progress was opened, ‹ lands on Today, where RESUME ▸ brings the lifter
/// back to it.
final class WorkoutExitUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testBackFromAWorkoutOpenedOnProgramLandsOnToday() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)

        // START WORKOUT ▸ on a session reached from Program.
        UITestNavigation.selectTab("Program", in: app)
        let routine = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Live Routine")).firstMatch
        XCTAssertTrue(UITestNavigation.appears(routine), "Program must list Live Routine")
        UITestNavigation.reveal(routine, in: app)
        routine.tap()
        let session = app.buttons["Session 1: Live Push"]
        XCTAssertTrue(UITestNavigation.appears(session), "Live Routine must list Live Push")
        UITestNavigation.reveal(session, in: app)
        session.tap()
        UITestNavigation.hittable(app.buttons, "Start workout ▸", exactLabel: true).tap()
        XCTAssertTrue(UITestNavigation.appears(app.textFields["set.reps.1.S1"], within: 15), "START WORKOUT ▸ must open the logger")
        back(in: app)
        assertOnToday(app)

        // RESUME ▸ on Program's root.
        UITestNavigation.selectTab("Program", in: app)
        // Program kept its screens: the session, then the routine.
        back(in: app)
        back(in: app)
        let resume = app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Resume ▸")).firstMatch
        XCTAssertTrue(UITestNavigation.appears(resume), "Program must offer RESUME ▸ for the workout in progress")
        resume.tap()
        XCTAssertTrue(UITestNavigation.appears(app.textFields["set.reps.1.S1"], within: 15), "RESUME ▸ must open the logger")
        back(in: app)
        assertOnToday(app)
    }

    /// The header's back control reads BACK on the detail screens and ‹,
    /// spoken "Back", in the logger.
    @MainActor
    private func back(in app: XCUIApplication) {
        let button = app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Back")).firstMatch
        XCTAssertTrue(UITestNavigation.appears(button), "Missing Back")
        button.tap()
    }

    @MainActor
    private func assertOnToday(_ app: XCUIApplication) {
        XCTAssertTrue(UITestNavigation.appears(app.buttons["resumeSlab.resume"], within: 15), "‹ must land on Today, which shows RESUME ▸")
        XCTAssertTrue(UITestNavigation.tab("Today", in: app).isSelected, "‹ must land on the Today tab")
    }
}
