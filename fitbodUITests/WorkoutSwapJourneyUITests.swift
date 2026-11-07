import XCTest

final class WorkoutSwapJourneyUITests: XCTestCase {
    private var appUnderTest: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    override func tearDownWithError() throws {
        if let app = appUnderTest, let testRun, testRun.totalFailureCount > 0, app.state == .runningForeground {
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "variation-failure-state"
            tree.lifetime = .keepAlways
            add(tree)
        }
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
        UITestNavigation.selectTab("Progress", in: app)
        app.buttons["progress.history"].tap()
        let history = app.buttons["history.row"].firstMatch
        XCTAssertTrue(UITestNavigation.appears(history))
        history.tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts[benchName].firstMatch),
                      "Swapping the active exercise must not rewrite finished history")
    }

    @MainActor
    func testVariationUndoRestoresPendingInputsAndSurvivesRelaunch() throws {
        let app = openVariationWorkout()
        let skip = action("Skip all warm-up sets", in: app)
        XCTAssertTrue(UITestNavigation.appears(skip))
        UITestNavigation.revealInLogger(skip, in: app)
        skip.tap()
        enterPending(weight: "112.5", reps: "7", in: app)
        let eight = app.buttons["RPE 8"].firstMatch
        UITestNavigation.revealInLogger(eight, in: app)
        eight.press(forDuration: 1)
        let wheel = app.pickerWheels.firstMatch
        XCTAssertTrue(UITestNavigation.appears(wheel))
        wheel.adjust(toPickerWheelValue: "8.5")
        UITestNavigation.tapPickerButton("Done", in: app)

        pickVariation(in: app)
        XCTAssertEqual(app.textFields["set.reps.1.S1"].value as? String, "—",
                       "The variation keeps the explicit swap's input reset")
        enterPending(weight: "67.5", reps: "9", in: app)
        let undo = app.buttons["card.undoVariation"]
        UITestNavigation.revealInLogger(undo, in: app)
        undo.tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts["Barbell Bench Press - Medium Grip"].firstMatch))
        assertRestoredInputs(in: app)
        XCTAssertTrue(action("Undo skipped warm-ups", in: app).exists)
        XCTAssertFalse(undo.exists)
        UITestNavigation.saveScreenshot("REG-02", "variation-undo-restored")

        UITestNavigation.relaunch(app)
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(UITestNavigation.appears(resume))
        resume.tap()
        assertRestoredInputs(in: app)
        XCTAssertTrue(action("Undo skipped warm-ups", in: app).exists)
    }

    @MainActor
    func testCommittingVariationPermanentlyInvalidatesUndo() throws {
        let app = openVariationWorkout()
        enterPending(weight: "112.5", reps: "7", in: app)
        pickVariation(in: app)
        enterPending(weight: "60", reps: "7", in: app)
        let complete = app.buttons["set.complete.1.S1"]
        UITestNavigation.revealInLogger(complete, in: app)
        complete.tap()
        XCTAssertEqual(complete.label, "Set 1 complete")
        XCTAssertFalse(app.buttons["card.undoVariation"].exists)
        complete.tap()
        XCTAssertEqual(complete.label, "Mark set 1 complete")
        XCTAssertFalse(app.buttons["card.undoVariation"].exists,
                       "Uncompleting a set cannot revive an invalidated Undo")
    }

    @MainActor
    func testExplicitSwapInvalidatesVariationUndo() throws {
        let app = openVariationWorkout()
        pickVariation(in: app)
        let undo = app.buttons["card.undoVariation"]
        XCTAssertTrue(UITestNavigation.appears(undo))
        let name = app.staticTexts["Dumbbell Bench Press"].firstMatch
        UITestNavigation.revealInLogger(name, in: app)
        name.press(forDuration: 1)
        let swap = app.buttons["Swap Exercise…"]
        XCTAssertTrue(UITestNavigation.appears(swap))
        swap.tap()
        let search = app.textFields["library.search.picker"]
        XCTAssertTrue(UITestNavigation.appears(search))
        UITestNavigation.type("Incline Push-Up Wide", into: search)
        let replacement = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@",
            "exercise.pick.", "Incline Push-Up Wide,"
        )).firstMatch
        XCTAssertTrue(UITestNavigation.appears(replacement))
        replacement.tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts["Incline Push-Up Wide"].firstMatch))
        XCTAssertFalse(undo.exists)
    }

    @MainActor
    private func openVariationWorkout() -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.freshStore + ["-fitbod-seed-variation-undo"])
        appUnderTest = app
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(UITestNavigation.appears(resume))
        resume.tap()
        XCTAssertTrue(UITestNavigation.appears(app.buttons["Suggested: Try variation."]),
                      "The DEBUG fixture must reach the real detector's variation branch")
        return app
    }

    @MainActor
    private func pickVariation(in app: XCUIApplication) {
        let action = app.buttons["Suggested: Try variation."]
        UITestNavigation.revealInLogger(action, in: app)
        action.tap()
        let candidate = app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH %@", "Dumbbell Bench Press"
        )).firstMatch
        XCTAssertTrue(UITestNavigation.appears(candidate), "A logged, matching candidate must be selectable")
        UITestNavigation.waitUntilStill(candidate)
        UITestNavigation.reveal(candidate, in: app)
        candidate.tap()
        XCTAssertTrue(UITestNavigation.appears(app.buttons["card.undoVariation"]))
        XCTAssertTrue(app.staticTexts["Dumbbell Bench Press"].firstMatch.exists)
    }

    @MainActor
    private func enterPending(weight: String, reps: String, in app: XCUIApplication) {
        let field = app.textFields.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "set.weight.1.S1"
        )).firstMatch
        XCTAssertTrue(UITestNavigation.appears(field))
        UITestNavigation.revealInLogger(field, in: app)
        UITestNavigation.enter(weight, into: field)
        UITestNavigation.keyboardDone(in: app).tap()
        let repsField = app.textFields["set.reps.1.S1"]
        UITestNavigation.revealInLogger(repsField, in: app)
        UITestNavigation.enter(reps, into: repsField)
        UITestNavigation.keyboardDone(in: app).tap()
    }

    @MainActor
    private func assertRestoredInputs(in app: XCUIApplication) {
        let field = app.textFields.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "set.weight.1.S1"
        )).firstMatch
        XCTAssertTrue(UITestNavigation.appears(field))
        XCTAssertEqual(field.value as? String, "112.5 lb")
        XCTAssertEqual(app.textFields["set.reps.1.S1"].value as? String, "7")
        let rpe = app.buttons["RPE 8.5"].firstMatch
        XCTAssertTrue(rpe.exists)
        XCTAssertTrue(rpe.isSelected)
    }

    @MainActor
    private func action(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
    }
}
