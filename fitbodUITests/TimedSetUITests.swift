import XCTest

/// A timed exercise logs a time, not reps, and History still shows that
/// time after the app is reopened (RM-062).
final class TimedSetUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPlankLogsATimeAndHistoryShowsItAfterRelaunch() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(UITestNavigation.appears(resume, within: 90))
        resume.tap()

        // Swap the first exercise for Plank, which the catalog tracks by time.
        let bench = app.staticTexts["Barbell Bench Press - Medium Grip"].firstMatch
        XCTAssertTrue(UITestNavigation.appears(bench))
        bench.press(forDuration: 1)
        let swap = app.buttons["Swap Exercise…"]
        XCTAssertTrue(UITestNavigation.appears(swap, within: 5))
        swap.tap()
        let search = app.textFields["library.search.picker"]
        XCTAssertTrue(UITestNavigation.appears(search))
        search.tap()
        search.typeText("Plank")
        let plank = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "exercise.pick.", "Plank,"
        )).firstMatch
        XCTAssertTrue(UITestNavigation.appears(plank))
        plank.tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts["Plank"].firstMatch))

        // A timed row has a time field, no reps field, and needs a time.
        let time = app.textFields["set.time.1.S1"]
        XCTAssertTrue(UITestNavigation.appears(time))
        XCTAssertFalse(app.textFields["set.reps.1.S1"].exists, "A timed set has no reps")
        let done = app.buttons["set.complete.1.S1"]
        UITestNavigation.revealInLogger(done, in: app)
        XCTAssertFalse(done.isEnabled, "A timed set needs a time before it can be done")

        UITestNavigation.revealInLogger(time, in: app)
        UITestNavigation.enter("130", into: time)
        UITestNavigation.keyboardDone(in: app).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "DONE must close the keyboard")
        XCTAssertEqual(time.value as? String, "1:30", "Digits typed read as minutes and seconds")
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

        // Reopened, History reads the set from the store.
        UITestNavigation.relaunch(app)
        UITestNavigation.selectTab("Progress", in: app)
        app.buttons["progress.history"].tap()
        let workout = app.buttons.matching(identifier: "history.row").firstMatch
        XCTAssertTrue(UITestNavigation.appears(workout))
        workout.tap()
        let exercise = app.buttons.matching(NSPredicate(
            format: "identifier == %@ AND label CONTAINS %@", "summary.exercise", "Plank"
        )).firstMatch
        XCTAssertTrue(UITestNavigation.appears(exercise), "The workout's summary should list Plank")
        exercise.tap()
        // The row's label goes on to say it is the best set.
        let logged = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Set 1, 1:30")).firstMatch
        XCTAssertTrue(UITestNavigation.appears(logged, within: 5), "History should show the plank's time")
    }
}
