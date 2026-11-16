//
//  CalibratingWeightUITests.swift
//  fitbodUITests
//
//  The exercise shows the calibration range while each set holds an editable weight.
//  A first-time variant offers its family sibling's last top set (RM-022).
//

import XCTest

extension UITestNavigation {
    /// A fresh store plus "Calibrating Bench": an RPE-autoregulated bench
    /// press still calibrating, with today's workout in progress (see
    /// CalibratingSetSeed).
    static let calibratingSet = [resetFlag, "-fitbod-seed-calibrating-set"]
}

final class CalibratingWeightUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testAcceptingBothSuggestionsSurvivesRelaunch() throws {
        let app = openWorkout()
        let weight = weightField("1.S1", in: app)
        let reps = app.textFields["set.reps.1.S1"]
        XCTAssertEqual(weight.value as? String, "100 lb")
        XCTAssertEqual(reps.value as? String, "8")
        UITestNavigation.saveScreenshot("RM-024", "set-suggestions")

        let complete = app.buttons["set.complete.1.S1"]
        UITestNavigation.revealInLogger(complete, in: app)
        XCTAssertTrue(complete.isEnabled)
        complete.tap()
        XCTAssertTrue(UITestNavigation.waitUntil(timeout: 5) { complete.label == "Set 1 complete" })

        UITestNavigation.relaunch(app)
        resumeWorkout(in: app)
        XCTAssertEqual(weight.value as? String, "100 lb")
        XCTAssertEqual(reps.value as? String, "8")
        XCTAssertEqual(complete.label, "Set 1 complete")
        UITestNavigation.saveScreenshot("RM-024", "accepted-suggestions-relaunched")
    }

    /// A calibrating set can be edited directly and logged while the range stays visible.
    @MainActor
    func testCompletedSetShowsLoggedWeight() throws {
        let app = openWorkout()
        let guidance = app.buttons["card.why.1"]
        XCTAssertTrue(UITestNavigation.appears(guidance))
        XCTAssertTrue(guidance.label.contains("95–105 lb"), guidance.label)

        let field = weightField("1.S1", in: app)
        XCTAssertEqual(field.value as? String, "100 lb")
        UITestNavigation.revealInLogger(field, in: app)
        UITestNavigation.enter("97.5", into: field)
        UITestNavigation.keyboardDone(in: app).tap()

        let reps = app.textFields["set.reps.1.S1"]
        XCTAssertEqual(reps.value as? String, "8")
        UITestNavigation.revealInLogger(reps, in: app)
        UITestNavigation.enter("5", into: reps)
        XCTAssertEqual(reps.value as? String, "5", "Set 1 must read the typed reps")
        UITestNavigation.keyboardDone(in: app).tap()
        let complete = app.buttons["set.complete.1.S1"]
        UITestNavigation.revealInLogger(complete, in: app)
        complete.tap()
        XCTAssertTrue(UITestNavigation.waitUntil(timeout: 5) { complete.exists && complete.label == "Set 1 complete" },
                      "Set 1 must be logged")

        XCTAssertEqual(field.value as? String, "97.5 lb", "The completed set must show the weight it logged")
        XCTAssertTrue(guidance.label.contains("95–105 lb"), "The suggestion stays after logging")
        revealSet("1.S2", in: app)
        XCTAssertEqual(weightField("1.S2", in: app).value as? String, "97.5 lb")
        XCTAssertEqual(app.textFields["set.reps.1.S2"].value as? String, "5")
    }

    /// A first-time variant takes its family sibling's last top set as its
    /// starting weight (RM-022): the paused bench, swapped in for the bench
    /// press, logs the bench press's 110 lb when set 1 takes the suggestion.
    @MainActor
    func testFirstTimeVariantLogsItsSiblingsTopSet() throws {
        let app = UITestNavigation.launch(UITestNavigation.calibratingSet)
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(UITestNavigation.appears(resume))
        UITestNavigation.reveal(resume, in: app)
        resume.tap()
        XCTAssertTrue(UITestNavigation.appears(app.otherElements["workout.header"]), "The workout never opened")
        swapFirstExercise(to: "Bench Press (Paused)", in: app)

        let weight = weightField("1.S1", in: app)
        revealSet("1.S1", in: app)
        // The card reads the estimate off the main actor once it draws.
        XCTAssertTrue(
            UITestNavigation.waitUntil(timeout: 5) { weight.value as? String == "110 lb" },
            "Set 1 must offer the bench press's last top set, not \(weight.value ?? "nothing")"
        )
        let complete = app.buttons["set.complete.1.S1"]
        UITestNavigation.revealInLogger(complete, in: app)
        complete.tap()
        XCTAssertTrue(UITestNavigation.waitUntil(timeout: 5) { complete.label == "Set 1 complete" }, "Set 1 must be logged")

        UITestNavigation.relaunch(app)
        resumeWorkout(in: app)
        XCTAssertEqual(weightField("1.S1", in: app).value as? String, "110 lb", "Set 1 must have logged 110 lb")
        XCTAssertEqual(complete.label, "Set 1 complete")
    }

    // MARK: - Navigation

    /// Swaps the first exercise for `name` through its ••• menu.
    @MainActor
    private func swapFirstExercise(to name: String, in app: XCUIApplication) {
        let menu = app.buttons["card.menu.1"]
        XCTAssertTrue(UITestNavigation.appears(menu))
        menu.tap()
        let swap = app.buttons["Swap Exercise…"]
        XCTAssertTrue(UITestNavigation.appears(swap, within: 5))
        swap.tap()
        let search = app.textFields["library.search.picker"]
        XCTAssertTrue(UITestNavigation.appears(search))
        search.tap()
        search.typeText(name)
        let row = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "exercise.pick.", name + ","
        )).firstMatch
        XCTAssertTrue(UITestNavigation.appears(row))
        row.tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts[name].firstMatch), "\(name) never replaced the first exercise")
    }

    /// Launches the calibrating seed and opens today's workout.
    @MainActor
    private func openWorkout() -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.calibratingSet)
        resumeWorkout(in: app)
        return app
    }

    /// Opens today's workout from Today's resume slab, with set 1 in view.
    @MainActor
    private func resumeWorkout(in app: XCUIApplication) {
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(UITestNavigation.appears(resume))
        UITestNavigation.reveal(resume, in: app)
        resume.tap()
        XCTAssertTrue(UITestNavigation.appears(app.otherElements["workout.header"]), "The workout never opened")
        revealSet("1.S1", in: app)
    }

    /// Scrolls the logger until set `set`'s row is in view. Rows load as
    /// they scroll in, so it first scrolls down until the row exists.
    @MainActor
    private func revealSet(_ set: String, in app: XCUIApplication) {
        let reps = app.textFields["set.reps.\(set)"]
        for _ in 0..<10 where !reps.exists {
            let (top, bottom) = UITestNavigation.loggerSpan(in: app)
            UITestNavigation.dragLogger(from: bottom - 20, to: top + 20, in: app)
        }
        XCTAssertTrue(reps.exists, "Set \(set) never loaded")
        UITestNavigation.revealInLogger(reps, in: app)
    }

    // MARK: - Elements

    @MainActor
    private func weightField(_ set: String, in app: XCUIApplication) -> XCUIElement {
        app.textFields.matching(identifier: "set.weight.\(set)").firstMatch
    }
}
