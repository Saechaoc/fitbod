import XCTest

final class WorkoutSwapJourneyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSwapHasOneHeaderAndPersistsOnlyInTheWorkout() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-fitbod-reset-store", "-fitbod-seed-demo-workout"]
        app.launch()
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 90))
        resume.tap()
        let benchName = "Barbell Bench Press - Medium Grip"
        let bench = app.staticTexts[benchName].firstMatch
        XCTAssertTrue(bench.waitForExistence(timeout: 10))
        bench.press(forDuration: 1)
        let swap = app.buttons["Swap Exercise…"]
        XCTAssertTrue(swap.waitForExistence(timeout: 5))
        swap.tap()
        let search = app.textFields["library.search.picker"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Cancel")).count, 1)
        search.tap()
        search.typeText("Incline Push-Up Wide")
        let replacement = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "exercise.pick.", "Incline Push-Up Wide,"
        )).firstMatch
        XCTAssertTrue(replacement.waitForExistence(timeout: 10))
        replacement.tap()
        XCTAssertTrue(app.staticTexts["Incline Push-Up Wide"].firstMatch.waitForExistence(timeout: 10))

        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(resume.waitForExistence(timeout: 30))
        resume.tap()
        XCTAssertTrue(app.staticTexts["Incline Push-Up Wide"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["Back"].firstMatch.tap()
        app.buttons["today.sessions"].tap()
        let history = app.buttons["history.row"].firstMatch
        XCTAssertTrue(history.waitForExistence(timeout: 10))
        history.tap()
        XCTAssertTrue(app.staticTexts[benchName].firstMatch.waitForExistence(timeout: 10),
                      "Swapping the active exercise must not rewrite finished history")
    }
}
