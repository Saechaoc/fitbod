// SessionHistoryBRUUITests.swift
// fitbodUITests
//
// Phase 2.1 Plan 11 — BRU surface smoke tests for SessionHistoryView.
// UI-REVIEW Wave G item 67 / UI-SPEC § SessionHistoryView (lines 370-396).
//
// History is reachable from Progress → Workouts and Today → Sessions.
// These cases use a dedicated store and fail if the route disappears.
//

import XCTest

final class SessionHistoryBRUUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    @MainActor
    private func waitForSeedComplete(_ app: XCUIApplication, timeout: TimeInterval = 60) {
        let splash = app.staticTexts["Preparing library…"]
        if splash.exists {
            let pred = NSPredicate(format: "exists == false")
            let exp = XCTNSPredicateExpectation(predicate: pred, object: splash)
            _ = XCTWaiter().wait(for: [exp], timeout: timeout)
        }
    }

    @MainActor
    private func selectProgressTab(_ app: XCUIApplication) {
        let progress = app.buttons["Progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 90))
        progress.tap()
    }

    /// Navigate to SessionHistoryView via Progress → Workouts.
    /// Returns true if navigation succeeded.
    @MainActor
    @discardableResult
    private func navigateToSessionHistory(_ app: XCUIApplication) -> Bool {
        selectProgressTab(app)

        let historyButton = app.buttons["progress.history"]
        guard historyButton.waitForExistence(timeout: 10) else { return false }
        UITestNavigation.reveal(historyButton, in: app)
        historyButton.tap()
        return true
    }

    // MARK: - Tests

    /// The seeded finished workout opens from Progress; the active one stays out.
    @MainActor
    func testFinishedWorkoutOpensFromProgressHistory() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-fitbod-reset-store", "-fitbod-seed-demo-workout"]
        app.launch()
        waitForSeedComplete(app)

        XCTAssertTrue(navigateToSessionHistory(app))
        let rows = app.buttons.matching(identifier: "history.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(rows.count, 1, "Only the finished seeded workout belongs in History")
        rows.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["WORKOUT COMPLETE"].waitForExistence(timeout: 10))
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
    }

    @MainActor
    func testCorrectionSaveCancelDeleteAndRelaunch() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        openHistorySummary(in: app)
        tap("Edit", in: app)
        let weight = app.textFields["Weight, set 1"].firstMatch
        XCTAssertTrue(UITestNavigation.appears(weight))
        UITestNavigation.enter("110", into: weight)
        tap("Cancel", in: app)
        let discard = button("Discard changes", in: app)
        XCTAssertTrue(UITestNavigation.appears(app.sheets["Discard changes?"]))
        // iOS hides the cancel-role button: the dismiss region keeps editing.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        XCTAssertTrue(UITestNavigation.disappears(discard))
        XCTAssertEqual(weight.value as? String, "110")
        tap("Save", in: app)
        XCTAssertTrue(UITestNavigation.disappears(app.buttons["edit.date"]))
        XCTAssertTrue(setLabel(containing: "110 lb by 5", in: app).exists)

        UITestNavigation.relaunch(app)
        openHistorySummary(in: app)
        XCTAssertTrue(setLabel(containing: "110 lb by 5", in: app).exists)
        tap("Edit", in: app)
        // Revealed by slow swipes first: XCTest's own scroll-then-tap lands
        // while the scroll view still moves, and the tap only stops it.
        let delete = app.buttons["edit.delete"]
        UITestNavigation.reveal(delete, in: app)
        delete.tap()
        let dialog = app.sheets["Delete this workout?"]
        XCTAssertTrue(UITestNavigation.appears(dialog))
        dialog.buttons["Delete workout"].tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts["No sessions yet"])
            || UITestNavigation.appears(app.buttons["progress.history"]))
        XCTAssertFalse(app.buttons["history.row"].exists)
    }

    @MainActor
    func testCommaDecimalCorrectionSurvivesRelaunch() throws {
        let app = UITestNavigation.launch(
            UITestNavigation.freshStore + ["-AppleLocale", "de_DE", "-AppleLanguages", "(en)"]
        )
        let start = app.buttons["today.startEmpty"]
        XCTAssertTrue(UITestNavigation.appears(start))
        start.tap()
        tap("Add exercise", in: app)
        let search = app.textFields["library.search.picker"]
        XCTAssertTrue(UITestNavigation.appears(search))
        UITestNavigation.type("Incline Push-Up Wide", into: search)
        let picked = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@",
            "exercise.pick.", "Incline Push-Up Wide,"
        )).firstMatch
        XCTAssertTrue(UITestNavigation.appears(picked))
        picked.tap()
        let loggedWeight = app.textFields.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "set.weight.1.S1"
        )).firstMatch
        XCTAssertTrue(UITestNavigation.appears(loggedWeight))
        UITestNavigation.revealInLogger(loggedWeight, in: app)
        UITestNavigation.enter("10", into: loggedWeight)
        let reps = app.textFields["set.reps.1.S1"]
        UITestNavigation.revealInLogger(reps, in: app)
        UITestNavigation.enter("5", into: reps)
        let complete = app.buttons["set.complete.1.S1"]
        UITestNavigation.revealInLogger(complete, in: app)
        complete.tap()
        XCTAssertEqual(complete.label, "Set 1 complete")
        tap("More", in: app)
        tap("Finish", in: app)
        let confirmFinish = app.buttons["finish.confirm"]
        XCTAssertTrue(UITestNavigation.appears(confirmFinish))
        confirmFinish.tap()
        XCTAssertTrue(UITestNavigation.appears(app.buttons["summary.done"]))
        app.buttons["summary.done"].tap()
        let view = app.buttons["doneToday.view"]
        XCTAssertTrue(UITestNavigation.appears(view))
        view.tap()
        tap("Edit", in: app)
        let weight = app.textFields["Weight, set 1"].firstMatch
        XCTAssertTrue(UITestNavigation.appears(weight))
        UITestNavigation.enter("7,5", into: weight)
        XCTAssertEqual(weight.value as? String, "7,5")
        tap("Save", in: app)
        XCTAssertTrue(UITestNavigation.disappears(app.buttons["edit.date"]))
        tap("Edit", in: app)
        XCTAssertTrue(UITestNavigation.appears(weight))
        XCTAssertEqual(weight.value as? String, "7,5", "Initial text must use the parser's locale")
        tap("Cancel", in: app)
        XCTAssertTrue(UITestNavigation.disappears(app.buttons["edit.date"]))

        UITestNavigation.relaunch(app)
        openHistorySummary(in: app)
        XCTAssertTrue(setLabel(containing: "7.5 lb by 5", in: app).exists)
    }

    @MainActor
    func testInvalidCorrectionBlocksSaveAndLeavesStoredWorkoutIntact() throws {
        let app = UITestNavigation.launch(
            UITestNavigation.seededWorkout + ["-AppleLocale", "en_US", "-AppleLanguages", "(en)"]
        )
        openHistorySummary(in: app)
        tap("Edit", in: app)
        let weight = app.textFields["Weight, set 1"].firstMatch
        XCTAssertTrue(UITestNavigation.appears(weight))
        UITestNavigation.enter("10000000000000000000", into: weight)
        UITestNavigation.keyboardDone(in: app).tap()
        XCTAssertEqual(app.state, .runningForeground)
        let save = button("Save", in: app)
        XCTAssertFalse(save.isEnabled)
        tap("Cancel", in: app)
        XCTAssertTrue(UITestNavigation.appears(app.sheets["Discard changes?"]))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        XCTAssertTrue(UITestNavigation.disappears(app.sheets["Discard changes?"]))
        XCTAssertEqual(weight.value as? String, "10000000000000000000")

        UITestNavigation.enter("7.5x", into: weight)
        UITestNavigation.keyboardDone(in: app).tap()
        let otherReps = app.textFields["Reps, set 2"].firstMatch
        UITestNavigation.enter("6", into: otherReps)
        UITestNavigation.keyboardDone(in: app).tap()
        XCTAssertFalse(save.isEnabled, "A different valid edit cannot save a stale weight")
        UITestNavigation.enter("105", into: weight)
        UITestNavigation.keyboardDone(in: app).tap()
        XCTAssertTrue(UITestNavigation.waitUntil { save.isEnabled }, "Fixing an invalid row restores Save")
        UITestNavigation.enter("7,5", into: weight)
        UITestNavigation.keyboardDone(in: app).tap()
        XCTAssertFalse(save.isEnabled, "A wrong-locale separator is not a parsed prefix")
        app.buttons["Delete set 1"].firstMatch.tap()
        XCTAssertTrue(UITestNavigation.waitUntil { save.isEnabled }, "Deleting an invalid row restores Save")
        tap("Cancel", in: app)
        let discardDialog = app.sheets["Discard changes?"]
        XCTAssertTrue(UITestNavigation.appears(discardDialog))
        discardDialog.buttons["Discard changes"].tap()
        XCTAssertTrue(UITestNavigation.disappears(app.buttons["edit.date"]))

        UITestNavigation.relaunch(app)
        openHistorySummary(in: app)
        XCTAssertTrue(setLabel(containing: "100 lb by 5", in: app).exists)
        tap("Edit", in: app)
        XCTAssertTrue(UITestNavigation.appears(weight))
        XCTAssertEqual(weight.value as? String, "100")
        XCTAssertEqual(app.textFields["Reps, set 2"].firstMatch.value as? String, "5")
    }

    @MainActor
    func testKilogramExerciseOverrideSurvivesHistoryCorrectionAndRelaunch() throws {
        try exerciseOverrideJourney(global: "lb", override: "kg")
    }

    @MainActor
    func testPoundExerciseOverrideSurvivesHistoryCorrectionAndRelaunch() throws {
        try exerciseOverrideJourney(global: "kg", override: "lb")
    }

    @MainActor
    private func exerciseOverrideJourney(global: String, override: String) throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        if global == "kg" {
            UITestNavigation.openSettings(in: app)
            let kg = button("kg", in: app)
            XCTAssertTrue(UITestNavigation.appears(kg))
            kg.tap()
            XCTAssertTrue(kg.isSelected)
            tap("Close", in: app)
        }
        UITestNavigation.selectTab("Library", in: app)
        let search = app.textFields["library.search.browser"]
        XCTAssertTrue(UITestNavigation.appears(search))
        let name = "Barbell Bench Press - Medium Grip"
        UITestNavigation.type(name, into: search)
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        XCTAssertTrue(UITestNavigation.appears(row))
        row.tap()
        let unit = button("Weight unit: \(override)", in: app)
        UITestNavigation.reveal(unit, in: app)
        unit.tap()
        XCTAssertTrue(UITestNavigation.waitUntil { unit.isSelected })
        UITestNavigation.selectTab("Today", in: app)

        openHistorySummary(in: app)
        XCTAssertTrue(setLabel(containing: "100 \(override) by 5", in: app).exists)
        XCTAssertTrue(exerciseVolume(containing: "1,500 \(override)", in: app).exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label ==[c] %@", "Volume · \(global)"
        )).firstMatch.exists, "The whole-workout aggregate keeps the global unit policy")
        tap("Edit", in: app)
        let weight = app.textFields["Weight, set 1"].firstMatch
        XCTAssertTrue(UITestNavigation.appears(weight))
        XCTAssertEqual(weight.value as? String, "100")
        XCTAssertTrue(exerciseVolume(containing: "1,500 \(override)", in: app).exists)
        let reps = app.textFields["Reps, set 1"].firstMatch
        UITestNavigation.enter("6", into: reps)
        UITestNavigation.keyboardDone(in: app).tap()
        XCTAssertTrue(exerciseVolume(containing: "1,600 \(override)", in: app).exists)
        UITestNavigation.saveScreenshot("REG-04", "editor-\(override)-override")
        tap("Save", in: app)
        XCTAssertTrue(UITestNavigation.disappears(app.buttons["edit.date"]))
        XCTAssertTrue(setLabel(containing: "100 \(override) by 6", in: app).exists)

        UITestNavigation.relaunch(app)
        openHistorySummary(in: app)
        XCTAssertTrue(setLabel(containing: "100 \(override) by 6", in: app).exists)
        XCTAssertTrue(exerciseVolume(containing: "1,600 \(override)", in: app).exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label ==[c] %@", "Volume · \(global)"
        )).firstMatch.exists)
        tap("Edit", in: app)
        XCTAssertTrue(UITestNavigation.appears(weight))
        XCTAssertEqual(weight.value as? String, "100", "An override relabels, never converts")
        XCTAssertEqual(reps.value as? String, "6")
        XCTAssertTrue(exerciseVolume(containing: "1,600 \(override)", in: app).exists)
    }

    @MainActor
    private func exerciseVolume(containing value: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS[c] %@ AND label CONTAINS[c] %@", "3 sets", value
        )).firstMatch
    }

    @MainActor
    private func openHistorySummary(in app: XCUIApplication) {
        XCTAssertTrue(UITestNavigation.appears(app.otherElements["today.root"]))
        UITestNavigation.selectTab("Progress", in: app)
        app.buttons["progress.history"].tap()
        let row = app.buttons["history.row"].firstMatch
        XCTAssertTrue(UITestNavigation.appears(row))
        row.tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts["WORKOUT COMPLETE"]))
        // Exercises open compact; the first one's sets show after a tap.
        let exercise = app.buttons["summary.exercise"].firstMatch
        XCTAssertTrue(UITestNavigation.appears(exercise), "The summary must list its exercise")
        exercise.tap()
    }

    @MainActor
    private func button(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ==[c] %@", name)).firstMatch
    }

    @MainActor
    private func tap(_ name: String, in app: XCUIApplication) {
        let action = button(name, in: app)
        XCTAssertTrue(UITestNavigation.appears(action), "Missing button \(name)")
        action.tap()
    }

    @MainActor
    private func setLabel(containing value: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(
            format: "label BEGINSWITH %@ AND label CONTAINS %@", "Set 1,", value
        )).firstMatch
    }
}
