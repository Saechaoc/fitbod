import XCTest

/// Exercises actual authoring and persistence, without a pre-created workout.
/// Use a dedicated simulator: the initial launch deliberately resets its test store.
final class MilestoneOneJourneyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// A failed run keeps the screen it stopped on and the whole
    /// accessibility tree; a passing run keeps neither.
    @MainActor
    override func tearDownWithError() throws {
        if let app, let run = testRun, run.totalFailureCount > 0 {
            attach("journey-final-state")
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "journey-final-accessibility-tree"
            tree.lifetime = .keepAlways
            add(tree)
        }
    }

    @MainActor
    func testAuthorRoutineLogRelaunchFinishAndHistory() throws {
        // The shared launch fails unless the reset really happened: a run's
        // first launch can lose its arguments and open the last run's store.
        app = UITestNavigation.launch(UITestNavigation.freshStore)
        XCTAssertTrue(UITestNavigation.appears(app.buttons["Library"], within: 90))

        app.buttons["Library"].tap()
        XCTAssertTrue(UITestNavigation.appears(app.textFields["library.search.browser"]))
        tap("+ New")
        XCTAssertTrue(UITestNavigation.appears(app.textFields["customExercise.name"]))
        tap("Save")
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts["customExercise.nameError"], within: 5))
        let exerciseName = "M1 Cambered Bar Bench Press with Medium Grip"
        enter(exerciseName, into: app.textFields["customExercise.name"])
        tap("Add Primary Muscle")
        let chest = app.buttons["musclePicker.chest"]
        XCTAssertTrue(UITestNavigation.appears(chest))
        chest.tap()
        tap("Save")
        XCTAssertTrue(UITestNavigation.appears(app.textFields["library.search.browser"]))
        enter("M1 Cambered", into: app.textFields["library.search.browser"])
        let custom = app.staticTexts[exerciseName]
        XCTAssertTrue(UITestNavigation.appears(custom))
        custom.tap()
        tap("Back")
        if app.keyboards.buttons["Search"].exists { app.keyboards.buttons["Search"].tap() }
        XCTAssertTrue(UITestNavigation.appears(app.buttons["Today"]))
        app.buttons["Today"].tap()
        tap("+ New routine")
        // The name step: SAVE stays off until the routine has a name, and
        // replaces the step with the routine's editor.
        let routineName = field("Routine name")
        XCTAssertTrue(UITestNavigation.appears(routineName))
        XCTAssertFalse(app.buttons.labeled("Save").isEnabled, "SAVE must wait for a routine name")
        enter("M1 Upper Body", into: routineName)
        routineName.typeText("\n")
        tap("Save")
        XCTAssertTrue(UITestNavigation.disappears(app.staticTexts.labeled("New routine")),
                      "SAVE must replace the name step with the routine's editor")
        XCTAssertEqual(field("Routine name").value as? String, "M1 Upper Body",
                       "The routine's editor must show the saved name")
        tap("+ Add session")
        tap("+ New session")
        let sessionName = field("Session name")
        XCTAssertTrue(UITestNavigation.appears(sessionName))
        enter("M1 Push A", into: sessionName)
        sessionName.typeText("\n")
        tap("Add exercise")
        let pickerSearch = app.textFields["library.search.picker"]
        XCTAssertTrue(UITestNavigation.appears(pickerSearch))
        enter("M1 Cambered", into: pickerSearch)
        let pickedExercise = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH[c] %@",
            "exercise.pick.", exerciseName
        )).firstMatch
        XCTAssertTrue(UITestNavigation.appears(pickedExercise))
        pickedExercise.tap()
        XCTAssertEqual(field("Session name").value as? String, "M1 Push A",
                       "Returning from the picker must preserve the unsaved name")
        tap("Add exercise")
        pickExercise("Incline Dumbbell Press")
        let reorderSecond = app.buttons.matching(NSPredicate(format:
            "identifier == %@ AND label == %@", "routine.exercise.reorder.2", "Move exercise 2"
        )).firstMatch
        XCTAssertTrue(UITestNavigation.appears(reorderSecond))
        reveal(reorderSecond)
        reorderSecond.tap()
        tap("Move up")
        XCTAssertTrue(UITestNavigation.appears(app.buttons.matching(NSPredicate(format:
            "identifier == %@ AND label BEGINSWITH %@",
            "routine.exercise.name.1", "Incline Dumbbell Press"
        )).firstMatch, within: 5))
        let reorderFirst = app.buttons.matching(NSPredicate(format:
            "identifier == %@ AND label == %@", "routine.exercise.reorder.1", "Move exercise 1"
        )).firstMatch
        reveal(reorderFirst)
        reorderFirst.tap()
        tap("Move down")
        XCTAssertTrue(UITestNavigation.appears(app.buttons.matching(NSPredicate(format:
            "identifier == %@ AND label == %@",
            "routine.exercise.name.1", exerciseName
        )).firstMatch, within: 5))
        tap("Save session ▸")
        let session = app.staticTexts["M1 Push A"].firstMatch
        XCTAssertTrue(UITestNavigation.appears(session, within: 15))
        // The routine's list is still moving its new row into place.
        UITestNavigation.waitUntilStill(session)
        session.tap()
        tap("Edit")
        let editableName = app.buttons.matching(NSPredicate(format: "label == %@", exerciseName))
            .allElementsBoundByIndex.first(where: { $0.isHittable })
        XCTAssertNotNil(editableName)
        editableName?.tap()
        app.buttons["prescription.details"].tap()
        let sets = app.otherElements["prescription.sets"].firstMatch
        XCTAssertTrue(UITestNavigation.appears(sets))
        reveal(sets)
        UITestNavigation.step(sets, to: 2)
        let repsLow = app.otherElements["prescription.reps.low"].firstMatch
        reveal(repsLow)
        UITestNavigation.step(repsLow, to: 6)
        let repsHigh = app.otherElements["prescription.reps.high"].firstMatch
        reveal(repsHigh)
        UITestNavigation.step(repsHigh, to: 10)
        tap("Save session ▸")
        tap("Start workout ▸")
        XCTAssertTrue(UITestNavigation.appears(app.textFields["set.reps.1.S1"], within: 15))
        let addSet = app.buttons["card.addSet.1"]
        reveal(addSet)
        addSet.tap()
        let added = app.textFields["set.reps.1.S3"]
        XCTAssertTrue(UITestNavigation.appears(added))
        reveal(added)
        let rowY = app.buttons["set.complete.1.S3"].frame.midY / app.frame.height
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: rowY))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: rowY)))
        // A full swipe deletes the set and leaves no Delete button, but its
        // row takes a moment to animate away; a shorter swipe leaves Delete.
        let swipedAway = UITestNavigation.disappears(added, within: 2)
        if !swipedAway { tap("Delete") }
        XCTAssertTrue(swipedAway || UITestNavigation.disappears(added, within: 5), "The swiped set must be deleted")
        let weight = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "set.weight.1.S1")).firstMatch
        let weightInput = weight.exists ? weight : app.textFields["—"].firstMatch
        reveal(weightInput)
        // The accessible weight includes its unit, unlike reps.
        let loggedWeight = UITestNavigation.enter("80", into: weightInput).split(separator: " ").first.map(String.init) ?? ""
        XCTAssertEqual(Double(loggedWeight), 80, "Weight entry must keep the entered load")
        let reps = app.textFields["set.reps.1.S1"]
        reveal(reps)
        XCTAssertEqual(UITestNavigation.enter("8", into: reps), "8", "Typing must not add a prefix or suffix")
        reveal(app.buttons["set.complete.1.S1"])
        app.buttons["set.complete.1.S1"].tap()
        XCTAssertTrue(UITestNavigation.appears(app.buttons["rest.plus15"]))
        app.buttons["rest.plus15"].tap()
        app.buttons["rest.minus15"].tap()

        // Reset is ONLY on the initial launch. Real relaunch reopens persisted data.
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(UITestNavigation.appears(app.buttons["resumeSlab.resume"], within: 30))
        app.buttons["resumeSlab.resume"].tap()
        XCTAssertTrue(UITestNavigation.appears(app.buttons["rest.plus15"], within: 15))
        reveal(app.textFields["set.reps.1.S1"])
        XCTAssertEqual(app.textFields["set.reps.1.S1"].value as? String, "8")
        app.buttons["rest.skip"].tap()
        tap("More")
        tap("Finish")
        tap("Finish")
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts["WORKOUT COMPLETE"], within: 15))
        XCTAssertTrue(app.staticTexts[exerciseName].exists)
        app.buttons["summary.done"].tap()
        app.buttons["Progress"].tap()
        let history = app.buttons["progress.history"]
        XCTAssertTrue(UITestNavigation.appears(history))
        reveal(history)
        history.tap()
        let historyRow = app.buttons["history.row"].firstMatch
        XCTAssertTrue(UITestNavigation.appears(historyRow, within: 15))
        XCTAssertTrue(historyRow.label.contains("M1 Push A"))
        XCTAssertTrue(historyRow.label.contains("640"))
        historyRow.tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts["WORKOUT COMPLETE"]))
        tap("Back")
        tap("Back")
        app.buttons["Today"].tap()
        let sessionToOpen = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "M1 Push A"))
            .allElementsBoundByIndex.first(where: { $0.isHittable })
        XCTAssertNotNil(sessionToOpen)
        sessionToOpen?.tap()
        tap("Start workout ▸")
        let previous = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Previous: 80 × 8")).firstMatch
        XCTAssertTrue(UITestNavigation.appears(previous, within: 15))
    }

    @MainActor
    private func field(_ name: String) -> XCUIElement {
        let query = NSPredicate(format: "label ==[c] %@ OR placeholderValue ==[c] %@", name, name)
        let text = app.textFields.matching(query).firstMatch
        return text.exists ? text : app.textViews.matching(query).firstMatch
    }

    @MainActor
    private func tap(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons.matching(NSPredicate(format: "label ==[c] %@", name)).firstMatch
        XCTAssertTrue(UITestNavigation.appears(button, within: 15), "Missing button: \(name)", file: file, line: line)
        reveal(button)
        button.tap()
    }

    /// Scrolls until `element` can take a tap, in long drags that hold at
    /// their end so the page does not coast on, each followed by a wait
    /// until the page stops. A drag moves the page by the distance the
    /// element lies from the middle of the visible span, or most of a span
    /// while a lazy list has not made the element yet. A set's field or
    /// button must sit between the workout header and the keyboard's DONE
    /// bar, because rows scroll under the header and accessibility still
    /// calls them hittable there; its drags run in the rows' trailing
    /// margin, clear of their fields. Any other element is in view once it
    /// is hittable, or once it lies clear of the keyboard and the bottom
    /// bars: accessibility can call a control in a sheet not hittable where
    /// a tap still reaches it.
    @MainActor
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<8 {
            let exists = element.exists
            let isSetInput = exists && element.identifier.hasPrefix("set.")
            if exists && !isSetInput && element.isHittable { return }
            let container = app.collectionViews.allElementsBoundByIndex.last(where: { $0.isHittable })
                ?? app.scrollViews.allElementsBoundByIndex.last(where: { $0.isHittable })
            let page = container?.frame ?? app.frame
            let header = app.otherElements["workout.header"].firstMatch
            let top = (isSetInput && header.exists ? header.frame.maxY : page.minY) + 8
            let keyboard = app.keyboards.firstMatch
            // The DONE bar sits on top of the keyboard; a tab bar or a
            // bottom bar fills the screen's last 100pt.
            let bottom = keyboard.exists ? keyboard.frame.minY - 58 : app.frame.maxY - (isSetInput ? 24 : 100)
            let frame = exists ? element.frame : .zero
            let inSpan = frame.minY >= top && frame.maxY <= bottom
            if exists && inSpan && (!isSetInput || element.isHittable) { return }
            // Positive drags the page down, to bring back an element above the span.
            let distance = exists && frame != .zero ? (top + bottom) / 2 - frame.midY : -(bottom - top) * 0.7
            let startY = distance > 0 ? top + 20 : bottom - 20
            let endY = min(bottom - 20, max(top + 20, startY + distance))
            let x = isSetInput ? app.frame.width - 24 : page.midX
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: x, dy: startY)).press(
                forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: x, dy: endY)),
                withVelocity: .default, thenHoldForDuration: 0.2
            )
            if exists {
                UITestNavigation.waitUntilStill(element)
            } else if let container {
                UITestNavigation.waitUntilStill(container)
            }
        }
    }

    @MainActor
    private func pickExercise(_ name: String) {
        let search = app.textFields["library.search.picker"]
        XCTAssertTrue(UITestNavigation.appears(search))
        enter(name, into: search)
        let row = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH[c] %@", "exercise.pick.", name
        )).firstMatch
        XCTAssertTrue(UITestNavigation.appears(row))
        row.tap()
    }

    /// Types a name or a search the way a user does: tap the field, then
    /// type. A prefilled name is selected with a triple tap and typed over,
    /// as a user would, so nothing depends on where a tap leaves the caret.
    /// Numbers go through UITestNavigation.enter, which never deletes one
    /// first: a delete-first helper once hid reps entry that turned 10 into
    /// 106.
    @MainActor
    private func enter(_ text: String, into element: XCUIElement) {
        reveal(element)
        if element.identifier.hasPrefix("library.search.") {
            let clear = app.buttons["Clear search"]
            if clear.exists { clear.tap() }
            element.tap()
            element.typeText(text)
            return
        }
        element.tap()
        let existing = (element.value as? String) ?? ""
        if !existing.isEmpty, existing != element.placeholderValue {
            element.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        }
        element.typeText(text)
        XCTAssertEqual((element.value as? String) ?? "", text, "Typing must not add a prefix or suffix")
    }

    @MainActor
    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
