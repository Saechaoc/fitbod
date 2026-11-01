import XCTest

final class WorkoutSwapJourneyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSwapHasOneHeaderAndPersistsOnlyInTheWorkout() throws {
        // The shared launch fails unless the reset really happened, so a run
        // of this suite alone never opens the previous run's store (F11).
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(UITestNavigation.appears(resume, within: 90))
        resume.tap()
        let benchName = "Barbell Bench Press - Medium Grip"
        let bench = app.staticTexts[benchName].firstMatch
        XCTAssertTrue(UITestNavigation.appears(bench))
        // The long press that opens the exercise's menu.
        bench.press(forDuration: 1)
        let swap = app.buttons["Swap Exercise…"]
        XCTAssertTrue(UITestNavigation.appears(swap, within: 5))
        swap.tap()
        let search = app.textFields["library.search.picker"]
        XCTAssertTrue(UITestNavigation.appears(search))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Cancel")).count, 1)
        search.tap()
        search.typeText("Incline Push-Up Wide")
        let replacement = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "exercise.pick.", "Incline Push-Up Wide,"
        )).firstMatch
        XCTAssertTrue(UITestNavigation.appears(replacement))
        replacement.tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts["Incline Push-Up Wide"].firstMatch))

        UITestNavigation.relaunch(app)
        XCTAssertTrue(UITestNavigation.appears(resume, within: 30))
        resume.tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts["Incline Push-Up Wide"].firstMatch))
        app.buttons["Back"].firstMatch.tap()
        app.buttons["today.sessions"].tap()
        let history = app.buttons["history.row"].firstMatch
        XCTAssertTrue(UITestNavigation.appears(history))
        history.tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts[benchName].firstMatch),
                      "Swapping the active exercise must not rewrite finished history")
    }
}
