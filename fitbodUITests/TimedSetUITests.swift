import XCTest

/// A timed exercise logs a time, not reps, and History still shows that
/// time after the app is reopened (RM-062). Cardio logs one bout of a time
/// with the machine's number, which a stair machine names its speed.
final class TimedSetUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPlankLogsATimeAndHistoryShowsItAfterRelaunch() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        swapFirstExercise(to: "Plank (Front)", in: app)

        // A timed row has a time field, no reps field, and needs a time.
        let time = app.textFields["set.time.1.S1"]
        XCTAssertTrue(UITestNavigation.appears(time))
        XCTAssertFalse(app.textFields["set.reps.1.S1"].exists, "A timed set has no reps")
        let done = app.buttons["set.complete.1.S1"]
        UITestNavigation.revealInLogger(done, in: app)
        XCTAssertFalse(done.isEnabled, "A timed set needs a time before it can be done")

        type("130", into: time, in: app)
        XCTAssertEqual(time.value as? String, "1:30", "Digits typed read as minutes and seconds")
        completeFirstSetAndFinish(in: app)
        assertHistoryShows("Plank (Front)", set: "Set 1, 1:30", in: app)
    }

    /// The plan's cardio check: Stair Climber at 20:00 and speed 8 finishes
    /// as one bout and is in History after a relaunch.
    @MainActor
    func testStairClimberLogsTimeAndLevelAndHistoryShowsItAfterRelaunch() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        swapFirstExercise(to: "Stair Climber", in: app)

        let time = app.textFields["set.time.1.S1"]
        XCTAssertTrue(UITestNavigation.appears(time))
        let level = app.textFields["set.level.1.S1"]
        XCTAssertTrue(level.exists, "A stair climber bout records its speed")
        XCTAssertFalse(app.textFields["set.weight.1.S1"].exists, "A cardio set has no weight")
        // Typed fast, every digit counts, the one right after the field puts
        // its colons in too: rewritten from onChange, the field lost it in
        // about one round in ten (RM-062).
        for _ in 1...10 {
            type("13000", into: time, in: app)
            XCTAssertEqual(time.value as? String, "1:30:00")
        }
        type("2000", into: time, in: app)
        XCTAssertEqual(time.value as? String, "20:00")
        type("8", into: level, in: app)
        completeFirstSetAndFinish(in: app, label: "Bout 1 complete")
        assertHistoryShows("Stair Climber", set: "Bout 1, 20:00 · speed 8", in: app)
    }

    /// A stair climber planned in its routine at 20:00 and speed 8 starts as
    /// one bout that offers the plan: Done saves it untouched and starts no
    /// rest, and History has it after a relaunch (RM-062).
    @MainActor
    func testPlannedStairClimberSavesItsPlanWithNoRest() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        XCTAssertTrue(UITestNavigation.appears(app.buttons["Library"], within: 90))
        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.hittable(app.buttons, "+ NEW", exactLabel: true).tap()
        UITestNavigation.hittable(app.buttons, "+ New routine", exactLabel: true).tap()
        let routineName = app.textFields["newRoutine.name"]
        XCTAssertTrue(routineName.waitForExistence(timeout: 10))
        UITestNavigation.type("Cardio Plan", into: routineName)
        app.buttons.labeled("Save").tap()
        tapButton("+ Add session", in: app)
        tapButton("+ New session", in: app)
        let sessionName = app.textFields.matching(NSPredicate(
            format: "label ==[c] %@ OR placeholderValue ==[c] %@", "Session name", "Session name"
        )).firstMatch
        XCTAssertTrue(UITestNavigation.appears(sessionName))
        sessionName.tap()
        sessionName.typeText("Cardio\n")
        tapButton("Add exercise", in: app)
        pick("Stair Climber", in: app)

        // A cardio row plans a time and the stair speed, not sets or rest.
        let row = app.buttons["routine.exercise.name.1"].firstMatch
        XCTAssertTrue(UITestNavigation.appears(row))
        row.tap()
        let details = app.buttons["prescription.details"].firstMatch
        XCTAssertTrue(UITestNavigation.appears(details))
        details.tap()
        typePlan("2000", into: "prescription.plan.time", in: app)
        typePlan("8", into: "prescription.plan.level", in: app)
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "speed 8")).firstMatch.exists,
            "The plan names the stair machine's number its speed"
        )
        tapButton("Save session ▸", in: app)
        let session = app.staticTexts["Cardio"].firstMatch
        XCTAssertTrue(UITestNavigation.appears(session, within: 10))
        UITestNavigation.waitUntilStill(session)
        session.tap()
        tapButton("Start workout ▸", in: app)

        // One bout, offering the plan, with no row to add another.
        XCTAssertTrue(UITestNavigation.appears(app.textFields["set.time.1.S1"], within: 15))
        XCTAssertFalse(app.textFields["set.time.1.S2"].exists, "Cardio starts as one bout")
        XCTAssertFalse(app.buttons["card.addSet.1"].exists, "A bout has no add-set row")
        let done = app.buttons["set.complete.1.S1"]
        UITestNavigation.revealInLogger(done, in: app)
        XCTAssertTrue(done.isEnabled, "The planned time is enough to finish the bout")
        done.tap()
        XCTAssertTrue(UITestNavigation.appears(app.buttons.matching(NSPredicate(
            format: "identifier == %@ AND label == %@", "set.complete.1.S1", "Bout 1 complete"
        )).firstMatch))
        let rest = app.descendants(matching: .any).matching(identifier: "rest.status").firstMatch
        XCTAssertFalse(rest.waitForExistence(timeout: 3), "A bout starts no rest")
        finish(in: app)
        assertHistoryShows("Stair Climber", set: "Bout 1, 20:00 · speed 8", in: app)
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
        pick(name, in: app)
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts[name].firstMatch))
    }

    /// Searches the open exercise picker for `name` and picks it.
    @MainActor
    private func pick(_ name: String, in app: XCUIApplication) {
        let search = app.textFields["library.search.picker"]
        XCTAssertTrue(UITestNavigation.appears(search))
        search.tap()
        search.typeText(name)
        let row = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "exercise.pick.", name + ","
        )).firstMatch
        XCTAssertTrue(UITestNavigation.appears(row))
        row.tap()
    }

    @MainActor
    private func tapButton(_ label: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons.matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
        XCTAssertTrue(UITestNavigation.appears(button, within: 15), "Missing \(label)", file: file, line: line)
        UITestNavigation.reveal(button, in: app)
        button.tap()
    }

    /// Types into one of the routine editor's plan fields and closes the
    /// keyboard.
    @MainActor
    private func typePlan(_ text: String, into identifier: String, in app: XCUIApplication) {
        let field = app.textFields[identifier].firstMatch
        XCTAssertTrue(UITestNavigation.appears(field), "Missing \(identifier)")
        UITestNavigation.reveal(field, in: app)
        field.tap()
        field.typeText(text)
        UITestNavigation.keyboardDone(in: app).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "DONE must close the keyboard")
    }

    @MainActor
    private func type(_ digits: String, into field: XCUIElement, in app: XCUIApplication) {
        UITestNavigation.revealInLogger(field, in: app)
        UITestNavigation.enter(digits, into: field)
        UITestNavigation.keyboardDone(in: app).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "DONE must close the keyboard")
    }

    @MainActor
    private func completeFirstSetAndFinish(in app: XCUIApplication, label: String = "Set 1 complete") {
        let done = app.buttons["set.complete.1.S1"]
        UITestNavigation.revealInLogger(done, in: app)
        XCTAssertTrue(done.isEnabled)
        done.tap()
        XCTAssertTrue(UITestNavigation.appears(app.buttons.matching(NSPredicate(
            format: "identifier == %@ AND label == %@", "set.complete.1.S1", label
        )).firstMatch))
        finish(in: app)
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

    /// Reopened, History reads the set from the store. `set` is the start
    /// of the row's label, which goes on to say it is the best set.
    @MainActor
    private func assertHistoryShows(_ name: String, set: String, in app: XCUIApplication) {
        UITestNavigation.relaunch(app)
        UITestNavigation.selectTab("Progress", in: app)
        app.buttons["progress.history"].tap()
        let workout = app.buttons.matching(identifier: "history.row").firstMatch
        XCTAssertTrue(UITestNavigation.appears(workout))
        workout.tap()
        let exercise = app.buttons.matching(NSPredicate(
            format: "identifier == %@ AND label CONTAINS %@", "summary.exercise", name
        )).firstMatch
        XCTAssertTrue(UITestNavigation.appears(exercise), "The workout's summary should list \(name)")
        exercise.tap()
        let logged = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", set)).firstMatch
        XCTAssertTrue(UITestNavigation.appears(logged, within: 5), "History should show \(set)")
    }
}
