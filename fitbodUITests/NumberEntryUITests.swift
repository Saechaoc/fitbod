//
//  NumberEntryUITests.swift
//  fitbodUITests
//
//  Ticket T39, review item 5: a digit typed into a number field that shows
//  a value joined it, so a target of 6 reps became 16, and the UI tests,
//  which cleared each field before typing, never saw it. Each case types
//  over values the way a user does, with UITestNavigation.enter, on one
//  screen and one launch: every number field selects its value as it takes
//  focus, sits above the keyboard and the screen's bottom bar while it has
//  focus, and closes its number pad with the screen's DONE.
//

import XCTest

final class NumberEntryUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Workout logger

    /// A weight typed over set 1's replaces it, and the field emptied and
    /// closed with DONE shows the set's weight again (change 8). With rest
    /// running, one tap high on set 2's empty reps field ends the rest and
    /// takes the first digit (change 7, F264), and reps typed over reps
    /// replace them. A tap on the weight cell's padding focuses its field,
    /// and the focused row stays clear of DONE.
    @MainActor
    func testLoggerWeightAndRepsTypeOver() throws {
        let app = UITestNavigation.openSeededWorkout()
        let weight = app.textFields["set.weight.1.S1"]
        UITestNavigation.revealInLogger(weight, in: app)
        XCTAssertEqual(weight.value as? String, "100 lb", "Set 1 starts at its prescription")
        XCTAssertEqual(UITestNavigation.enter("90", into: weight), "90 lb", "90 typed over 100 must replace it")
        UITestNavigation.assertAboveKeyboard(weight, in: app)
        // The set's plates show under it while the field has focus (T125).
        UITestNavigation.assertAboveKeyboard(app.descendants(matching: .any)["set.plates.1.S1"], in: app)
        closeKeyboard(in: app)
        empty(weight)
        closeKeyboard(in: app)
        XCTAssertEqual(weight.value as? String, "90 lb", "An emptied weight field must show the set's weight again")

        XCTAssertEqual(UITestNavigation.enter("5", into: app.textFields["set.reps.1.S1"]), "5")
        app.buttons["set.complete.1.S1"].tap()
        let rest = app.descendants(matching: .any).matching(identifier: "rest.status").firstMatch
        XCTAssertTrue(rest.waitForExistence(timeout: 5), "Logging set 1 must start the rest")
        let reps = app.textFields["set.reps.1.S2"]
        UITestNavigation.revealInLogger(reps, in: app)
        tapAboveText(of: reps)
        reps.typeText("5")
        XCTAssertEqual(reps.value as? String, "5", "The first digit after one tap must land")
        closeKeyboard(in: app)
        // The rest dock steps aside for the keyboard, so only with the
        // keyboard gone does it show whether the rest ended.
        XCTAssertFalse(rest.exists, "The tap must end the rest")
        XCTAssertEqual(UITestNavigation.enter("6", into: reps), "6", "6 typed over 5 must replace it")
        UITestNavigation.assertAboveKeyboard(reps, in: app)
        closeKeyboard(in: app)

        let next = app.textFields["set.weight.1.S2"]
        tapAboveText(of: next)
        next.typeText("95")
        XCTAssertEqual(next.value as? String, "95 lb", "95 typed after a tap on the padding must replace 100")
        UITestNavigation.assertAboveKeyboard(next, in: app)
        // The focused row's completion box stays clear of DONE too (F19).
        UITestNavigation.assertAboveKeyboard(app.buttons["set.complete.1.S2"], in: app)
        UITestNavigation.saveScreenshot("T39", "logger-weight")
    }

    // MARK: - Session editor

    /// A tempo given 2, then 3 typed over it, reads 3, and the save bar
    /// steps aside while the keyboard is up. The session's next workout
    /// tracks tempo and partial reps, whose fields type over theirs too.
    @MainActor
    func testTempoAndPartialRepsTypeOver() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        openSessionEditor(in: app)
        let save = app.buttons["Save session ▸"]
        let tempo = app.otherElements["prescription.tempo.1"].textFields.firstMatch
        UITestNavigation.reveal(tempo, in: app)
        XCTAssertEqual(UITestNavigation.enter("2", into: tempo), "2")
        // The lifter moves on to the next field, then comes back to fix it.
        XCTAssertEqual(UITestNavigation.enter("1", into: app.otherElements["prescription.tempo.2"].textFields.firstMatch), "1")
        XCTAssertEqual(UITestNavigation.enter("3", into: tempo), "3", "3 typed over 2 must replace it")
        UITestNavigation.assertAboveKeyboard(tempo, in: app)
        // The row's last field sits at the trailing end, under DONE's column.
        UITestNavigation.assertAboveKeyboard(app.otherElements["prescription.tempo.4"].textFields.firstMatch, in: app)
        XCTAssertFalse(save.exists, "The save bar must step aside while the keyboard is up")
        UITestNavigation.saveScreenshot("T39", "session-editor-tempo")
        closeKeyboard(in: app)
        XCTAssertTrue(save.waitForExistence(timeout: 5), "The save bar must come back with the keyboard gone")

        let trackPartials = app.switches["Track partial reps"]
        UITestNavigation.reveal(trackPartials, in: app)
        trackPartials.tap()
        save.tap()
        UITestNavigation.hittable(app.buttons, "Start workout ▸", exactLabel: true).tap()
        let ecc = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "set.tempo.ecc.")).firstMatch
        XCTAssertTrue(ecc.waitForExistence(timeout: 10), "The workout must track tempo")
        UITestNavigation.revealInLogger(ecc, in: app)
        XCTAssertEqual(UITestNavigation.enter("3", into: ecc), "3")
        closeKeyboard(in: app)
        XCTAssertEqual(UITestNavigation.enter("4", into: ecc), "4", "4 typed over 3 must replace it")
        UITestNavigation.assertAboveKeyboard(ecc, in: app)
        closeKeyboard(in: app)

        let partials = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "set.partials.")).firstMatch
        UITestNavigation.revealInLogger(partials, in: app)
        XCTAssertEqual(UITestNavigation.enter("2", into: partials), "2")
        closeKeyboard(in: app)
        XCTAssertEqual(UITestNavigation.enter("1", into: partials), "1", "1 typed over 2 must replace it")
        UITestNavigation.assertAboveKeyboard(partials, in: app)
    }

    // MARK: - Plate Inventory

    /// 20 typed over the bar's 45 reads 20, while Done ▸ steps aside for the
    /// keyboard, and a plate weight typed over another in Add Plate replaces
    /// it.
    @MainActor
    func testPlateInventoryWeightsTypeOver() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.openSettings(in: app)
        let inventory = app.buttons.labeled("Plate Inventory")
        UITestNavigation.reveal(inventory, in: app)
        inventory.tap()
        let bar = app.textFields["plateInventory.barWeight"]
        let footer = app.buttons.labeled("Done ▸")
        XCTAssertEqual(UITestNavigation.enter("20", into: bar), "20", "20 typed over 45 must replace it")
        UITestNavigation.assertAboveKeyboard(bar, in: app)
        XCTAssertFalse(footer.exists, "Done ▸ must step aside while the keyboard is up")
        UITestNavigation.saveScreenshot("T39", "plate-inventory-bar")
        closeKeyboard(in: app)
        XCTAssertTrue(footer.waitForExistence(timeout: 5), "Done ▸ must come back with the keyboard gone")

        let add = app.buttons.labeled("+ Add plate")
        UITestNavigation.reveal(add, in: app)
        add.tap()
        let plate = app.textFields["addPlate.weight"]
        XCTAssertEqual(UITestNavigation.enter("25", into: plate), "25")
        UITestNavigation.assertAboveKeyboard(plate, in: app)
        closeKeyboard(in: app)
        XCTAssertEqual(UITestNavigation.enter("30", into: plate), "30", "30 typed over 25 must replace it")
    }

    // MARK: - Exercise detail

    /// The bench press's smallest increment and bar weight override each
    /// take a number typed over the one they show.
    @MainActor
    func testExerciseSettingsTypeOver() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Library", in: app)
        UITestNavigation.type("Barbell Bench Press", into: app.textFields["library.search.browser"], replacing: false)
        let bench = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Barbell Bench Press - Medium Grip")).firstMatch
        UITestNavigation.reveal(bench, in: app)
        bench.tap()
        for (field, first, second) in [("Smallest Increment", "5", "2.5"), ("Bar Weight Override", "35", "25")] {
            let setting = app.textFields[field]
            UITestNavigation.reveal(setting, in: app)
            XCTAssertEqual(UITestNavigation.enter(first, into: setting), first)
            UITestNavigation.assertAboveKeyboard(setting, in: app)
            closeKeyboard(in: app)
            XCTAssertEqual(UITestNavigation.enter(second, into: setting), second, "\(second) typed over \(first) must replace it")
            closeKeyboard(in: app)
        }
        UITestNavigation.saveScreenshot("T39", "exercise-settings")
    }

    // MARK: - Navigation

    /// The session editor on the active-block seed's "Live Push", opened
    /// from its routine on Program, with its exercise's prescription open
    /// and tempo tracked.
    @MainActor
    private func openSessionEditor(in app: XCUIApplication) {
        UITestNavigation.selectTab("Program", in: app)
        let routine = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Live Routine")).firstMatch
        XCTAssertTrue(routine.exists || routine.waitForExistence(timeout: 10), "Program must list Live Routine")
        UITestNavigation.reveal(routine, in: app)
        routine.tap()
        let session = app.buttons["Session 1: Live Push"]
        XCTAssertTrue(session.exists || session.waitForExistence(timeout: 10), "Live Routine must list Live Push")
        UITestNavigation.reveal(session, in: app)
        session.tap()
        UITestNavigation.hittable(app.buttons, "Edit", exactLabel: true).tap()
        let name = app.descendants(matching: .any).matching(identifier: "routine.exercise.name.1").firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 10), "Edit must open the session editor on its exercise")
        name.tap()
        let details = app.buttons["prescription.details"]
        UITestNavigation.reveal(details, in: app)
        details.tap()
        let trackTempo = app.switches["Track tempo"]
        XCTAssertTrue(trackTempo.exists || trackTempo.waitForExistence(timeout: 10), "The details must offer Track tempo")
        // The details are still opening, and on the 440pt phone XCUI calls
        // the switch hittable behind the save bar, where a tap misses (F387).
        UITestNavigation.waitUntilStill(trackTempo)
        revealAboveSaveBar(trackTempo, in: app)
        trackTempo.tap()
    }

    /// Drags the session editor in its leading margin, holding at the end of
    /// each drag so the page does not coast on, until `element` sits whole
    /// between the pinned header and the save bar, which covers the end of
    /// the page.
    @MainActor
    private func revealAboveSaveBar(_ element: XCUIElement, in app: XCUIApplication,
                                    file: StaticString = #filePath, line: UInt = #line) {
        let bar = app.buttons["Save session ▸"]
        for _ in 0..<6 {
            let page = app.scrollViews.allElementsBoundByIndex.last(where: \.isHittable)?.frame ?? app.frame
            let (top, bottom) = (page.minY + 8, bar.frame.minY - 8)
            let frame = element.frame
            if frame.minY >= top && frame.maxY <= bottom && element.isHittable { return }
            // Positive drags the page down, to bring back an element above the span.
            let distance = (top + bottom) / 2 - frame.midY
            let startY = distance > 0 ? top + 20 : bottom - 20
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: 8, dy: startY)).press(
                forDuration: 0.05,
                thenDragTo: origin.withOffset(CGVector(dx: 8, dy: min(bottom - 20, max(top + 20, startY + distance)))),
                withVelocity: .slow,
                thenHoldForDuration: 0.3
            )
            UITestNavigation.waitUntilStill(element)
        }
        XCTFail("\(element) must scroll above the save bar", file: file, line: line)
    }

    // MARK: - Helpers

    /// Taps `field`, which selects its number, and deletes every digit it
    /// shows, the way a lifter empties it.
    @MainActor
    private func empty(_ field: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let shown = (field.value as? String ?? "").split(separator: " ").first.map(String.init) ?? ""
        field.tap()
        UITestNavigation.assertKeyboardFocus(field, file: file, line: line)
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: shown.count))
    }

    /// One tap high on `field`'s target, above its text, where a thumb often
    /// lands, and a wait until the field has keyboard focus.
    @MainActor
    private func tapAboveText(of field: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        UITestNavigation.waitUntilStill(field)
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        UITestNavigation.assertKeyboardFocus(field, file: file, line: line)
    }

    /// Taps the keyboard's DONE and waits for the keyboard to go.
    @MainActor
    private func closeKeyboard(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        UITestNavigation.keyboardDone(in: app, file: file, line: line).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "DONE must close the keyboard",
                      file: file, line: line)
    }
}
