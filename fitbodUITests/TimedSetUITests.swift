import XCTest

/// A timed exercise logs a time, not reps, and History still shows that
/// time after the app is reopened (RM-062). Cardio logs a time with a
/// machine level the same way.
final class TimedSetUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPlankLogsATimeAndHistoryShowsItAfterRelaunch() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        swapFirstExercise(to: "Plank", in: app)

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
        assertHistoryShows("Plank", set: "Set 1, 1:30", in: app)
    }

    /// The plan's cardio check: Stair Climber at 20:00 and level 8 finishes
    /// and is in History after a relaunch.
    @MainActor
    func testStairClimberLogsTimeAndLevelAndHistoryShowsItAfterRelaunch() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        swapFirstExercise(to: "Stair Climber", in: app)

        let time = app.textFields["set.time.1.S1"]
        XCTAssertTrue(UITestNavigation.appears(time))
        let level = app.textFields["set.level.1.S1"]
        XCTAssertTrue(level.exists, "A stair climber set records its level")
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
        completeFirstSetAndFinish(in: app)
        assertHistoryShows("Stair Climber", set: "Set 1, 20:00 · level 8", in: app)
    }

    // MARK: - Steps

    /// Opens the seeded workout and swaps its first exercise for `name`.
    @MainActor
    private func swapFirstExercise(to name: String, in app: XCUIApplication) {
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
    private func completeFirstSetAndFinish(in app: XCUIApplication) {
        let done = app.buttons["set.complete.1.S1"]
        UITestNavigation.revealInLogger(done, in: app)
        XCTAssertTrue(done.isEnabled)
        done.tap()
        XCTAssertTrue(UITestNavigation.appears(app.buttons.matching(NSPredicate(
            format: "identifier == %@ AND label == %@", "set.complete.1.S1", "Set 1 complete"
        )).firstMatch))

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
