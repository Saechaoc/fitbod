import XCTest

/// A bodyweight move logs with no added weight, even when the upstream
/// catalog left its equipment blank (Parallel Bar Dip had `null`).
final class BodyweightSetUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testParallelBarDipFinishesAtZeroAddedWeight() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(UITestNavigation.appears(resume, within: 90))
        resume.tap()
        let bench = app.staticTexts["Barbell Bench Press - Medium Grip"].firstMatch
        XCTAssertTrue(UITestNavigation.appears(bench))
        bench.press(forDuration: 1)
        let swap = app.buttons["Swap Exercise…"]
        XCTAssertTrue(UITestNavigation.appears(swap, within: 5))
        swap.tap()
        let search = app.textFields["library.search.picker"]
        XCTAssertTrue(UITestNavigation.appears(search))
        search.tap()
        search.typeText("Parallel Bar Dip")
        let dip = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "exercise.pick.", "Parallel Bar Dip,"
        )).firstMatch
        XCTAssertTrue(UITestNavigation.appears(dip))
        dip.tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts["Parallel Bar Dip"].firstMatch))

        let skip = app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Skip all warm-up sets")).firstMatch
        if skip.waitForExistence(timeout: 3) {
            UITestNavigation.revealInLogger(skip, in: app)
            skip.tap()
        }
        let weight = app.textFields.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "set.weight.1.S1"
        )).firstMatch
        XCTAssertTrue(UITestNavigation.appears(weight))
        UITestNavigation.revealInLogger(weight, in: app)
        UITestNavigation.enter("0", into: weight)
        UITestNavigation.keyboardDone(in: app).tap()
        let reps = app.textFields["set.reps.1.S1"]
        UITestNavigation.revealInLogger(reps, in: app)
        UITestNavigation.enter("10", into: reps)
        UITestNavigation.keyboardDone(in: app).tap()

        let done = app.buttons["set.complete.1.S1"]
        UITestNavigation.revealInLogger(done, in: app)
        XCTAssertTrue(done.isEnabled, "A bodyweight dip must finish with no added weight")
        done.tap()
        XCTAssertTrue(UITestNavigation.appears(app.buttons.matching(NSPredicate(
            format: "identifier == %@ AND label == %@", "set.complete.1.S1", "Set 1 complete"
        )).firstMatch))
    }
}
