import XCTest

/// RM-066: the machine is picked in the workout, from a short list or by a
/// name the lifter types. A switch partway through keeps the finished set on
/// the machine it was done on, and the workout's summary names that machine
/// after the app is reopened.
final class MachinePickerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMachinePickedInTheWorkoutStaysWithItsSets() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        swapFirstExercise(to: "Hack Squat (Machine)", in: app)

        // A known model for the family is one tap away.
        let line = app.buttons["card.machine.1"]
        UITestNavigation.revealInLogger(line, in: app)
        XCTAssertEqual(line.label, "Machine, none")
        line.tap()
        let panatta = app.buttons["machine.known.Panatta Super Hack Squat"]
        XCTAssertTrue(UITestNavigation.appears(panatta), "The picker must suggest the family's known machines")
        XCTAssertTrue(app.buttons["machine.none"].isSelected)
        panatta.tap()
        XCTAssertTrue(UITestNavigation.disappears(panatta, within: 5), "A pick must close the picker")
        XCTAssertEqual(line.label, "Machine, Panatta Super Hack Squat")

        type("140", into: app.textFields["set.weight.1.S1"], in: app)
        type("8", into: app.textFields["set.reps.1.S1"], in: app)
        let done = app.buttons["set.complete.1.S1"]
        UITestNavigation.revealInLogger(done, in: app)
        done.tap()
        XCTAssertTrue(UITestNavigation.appears(app.buttons.matching(NSPredicate(
            format: "identifier == %@ AND label == %@", "set.complete.1.S1", "Set 1 complete"
        )).firstMatch))

        // The rest goes on a machine the lifter names; set 1 was on the Panatta.
        UITestNavigation.revealInLogger(line, in: app)
        line.tap()
        let new = app.buttons["machine.new"]
        XCTAssertTrue(UITestNavigation.appears(new))
        new.tap()
        UITestNavigation.type("Gym 2 hack", into: app.textFields["machine.model"])
        UITestNavigation.hittable(app.buttons, "Use", exactLabel: true).tap()
        let wasOnPanatta = app.buttons.matching(NSPredicate(format: "label == %@", "Panatta Super Hack Squat")).firstMatch
        XCTAssertTrue(UITestNavigation.appears(wasOnPanatta, within: 5), "A finished set must ask where it was done")
        wasOnPanatta.tap()

        XCTAssertTrue(UITestNavigation.appears(app.buttons["card.machine.2"]), "The switch must split the exercise")
        XCTAssertEqual(app.buttons["card.machine.1"].label, "Machine, Panatta Super Hack Squat")
        XCTAssertEqual(app.buttons["card.machine.2"].label, "Machine, Gym 2 hack")

        finish(in: app)
        UITestNavigation.relaunch(app)
        UITestNavigation.selectTab("Progress", in: app)
        app.buttons["progress.history"].tap()
        let workout = app.buttons.matching(identifier: "history.row").firstMatch
        XCTAssertTrue(UITestNavigation.appears(workout))
        workout.tap()
        let exercise = app.buttons.matching(NSPredicate(
            format: "identifier == %@ AND label CONTAINS %@ AND label CONTAINS %@",
            "summary.exercise", "Hack Squat (Machine)", "Panatta Super Hack Squat"
        )).firstMatch
        XCTAssertTrue(UITestNavigation.appears(exercise), "The summary must name the machine set 1 was done on")
    }

    // MARK: - Steps

    /// Opens the seeded workout and swaps its first exercise for `name`.
    @MainActor
    private func swapFirstExercise(to name: String, in app: XCUIApplication) {
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(UITestNavigation.appears(resume, within: 90))
        resume.tap()
        let bench = app.staticTexts["Bench Press (Barbell)"].firstMatch
        XCTAssertTrue(UITestNavigation.appears(bench))
        bench.press(forDuration: 1)
        let swap = app.buttons["Swap Exercise…"]
        XCTAssertTrue(UITestNavigation.appears(swap, within: 5))
        swap.tap()
        let search = app.textFields["library.search.picker"]
        XCTAssertTrue(UITestNavigation.appears(search))
        search.tap()
        search.typeText(name)
        let pick = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "exercise.pick.", name + ","
        )).firstMatch
        XCTAssertTrue(UITestNavigation.appears(pick))
        pick.tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts[name].firstMatch))
    }

    @MainActor
    private func type(_ digits: String, into field: XCUIElement, in app: XCUIApplication) {
        UITestNavigation.revealInLogger(field, in: app)
        UITestNavigation.enter(digits, into: field)
        UITestNavigation.keyboardDone(in: app).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "DONE must close the keyboard")
    }

    @MainActor
    private func finish(in app: XCUIApplication) {
        app.buttons["More"].tap()
        let finish = app.buttons["Finish"]
        XCTAssertTrue(UITestNavigation.appears(finish, within: 5))
        finish.tap()
        let confirm = app.buttons["finish.confirm"]
        XCTAssertTrue(UITestNavigation.appears(confirm, within: 5))
        confirm.tap()
        let summaryDone = app.buttons["summary.done"]
        XCTAssertTrue(UITestNavigation.appears(summaryDone), "Finish should open the summary")
        summaryDone.tap()
    }
}
