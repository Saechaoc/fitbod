import XCTest

/// Exercises actual authoring and persistence, without a pre-created workout.
/// Use a dedicated simulator: the initial launch deliberately resets its test store.
final class MilestoneOneJourneyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    override func tearDownWithError() throws {
        if let app {
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
        XCTAssertTrue(app.buttons["Library"].waitForExistence(timeout: 90))
        attach("01-today-empty")

        app.buttons["Library"].tap()
        XCTAssertTrue(app.textFields["library.search.browser"].waitForExistence(timeout: 10))
        attach("02-library")
        tapFilter("library.filter.muscle")
        tap("Chest")
        tap("Done")
        tapFilter("library.filter.equipment")
        tap("Barbell")
        tap("Done")
        enter("Barbell Bench", into: app.textFields["library.search.browser"])
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Barbell Bench Press")).firstMatch.waitForExistence(timeout: 10))
        attach("02a-muscle-equipment-filtered")
        enter("M1-no-such-exercise", into: app.textFields["library.search.browser"])
        XCTAssertTrue(app.staticTexts["No exercises match \"M1-no-such-exercise\""].waitForExistence(timeout: 10))
        attach("02b-no-matches")
        tap("Clear search")
        tapFilter("library.clearFilters")
        tap("+ New")
        XCTAssertTrue(app.textFields["customExercise.name"].waitForExistence(timeout: 10))
        tap("Save")
        XCTAssertTrue(app.staticTexts["customExercise.nameError"].waitForExistence(timeout: 5))
        attach("03-custom-validation")
        let exerciseName = "M1 Cambered Bar Bench Press with Medium Grip"
        enter(exerciseName, into: app.textFields["customExercise.name"])
        tap("Add Primary Muscle")
        let chest = app.buttons["musclePicker.chest"]
        XCTAssertTrue(chest.waitForExistence(timeout: 10))
        chest.tap()
        tap("Save")
        XCTAssertTrue(app.textFields["library.search.browser"].waitForExistence(timeout: 10))
        enter("M1 Cambered", into: app.textFields["library.search.browser"])
        let custom = app.staticTexts[exerciseName]
        XCTAssertTrue(custom.waitForExistence(timeout: 10))
        custom.tap()
        attach("04-custom-detail")
        tap("Back")
        if app.keyboards.buttons["Search"].exists { app.keyboards.buttons["Search"].tap() }
        XCTAssertTrue(app.buttons["Today"].waitForExistence(timeout: 10))
        app.buttons["Today"].tap()
        tap("+ New routine")
        // The name step: SAVE stays off until the routine has a name, and
        // replaces the step with the routine's editor.
        let routineName = field("Routine name")
        XCTAssertTrue(routineName.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons.labeled("Save").isEnabled, "SAVE must wait for a routine name")
        enter("M1 Upper Body", into: routineName)
        routineName.typeText("\n")
        attach("04a-routine-name-step")
        tap("Save")
        XCTAssertTrue(app.staticTexts.labeled("New routine").waitForNonExistence(timeout: 10),
                      "SAVE must replace the name step with the routine's editor")
        XCTAssertEqual(field("Routine name").value as? String, "M1 Upper Body",
                       "The routine's editor must show the saved name")
        tap("+ Add session")
        tap("+ New session")
        let sessionName = field("Session name")
        XCTAssertTrue(sessionName.waitForExistence(timeout: 10))
        enter("M1 Push A", into: sessionName)
        sessionName.typeText("\n")
        attach("05-session-empty")
        tap("Add exercise")
        let pickerSearch = app.textFields["library.search.picker"]
        XCTAssertTrue(pickerSearch.waitForExistence(timeout: 10))
        enter("M1 Cambered", into: pickerSearch)
        let pickedExercise = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH[c] %@",
            "exercise.pick.", exerciseName
        )).firstMatch
        XCTAssertTrue(pickedExercise.waitForExistence(timeout: 10))
        pickedExercise.tap()
        XCTAssertEqual(field("Session name").value as? String, "M1 Push A",
                       "Returning from the picker must preserve the unsaved name")
        tap("Add exercise")
        pickExercise("Incline Dumbbell Press")
        let reorderSecond = app.buttons.matching(NSPredicate(format:
            "identifier == %@ AND label == %@", "routine.exercise.reorder.2", "Reorder exercise 2"
        )).firstMatch
        XCTAssertTrue(reorderSecond.waitForExistence(timeout: 10))
        reveal(reorderSecond)
        reorderSecond.tap()
        tap("Move up")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format:
            "identifier == %@ AND label BEGINSWITH %@",
            "routine.exercise.reorder.1", "01, Incline Dumbbell Press"
        )).firstMatch.waitForExistence(timeout: 5))
        let reorderFirst = app.buttons.matching(NSPredicate(format:
            "identifier == %@ AND label == %@", "routine.exercise.reorder.1", "Reorder exercise 1"
        )).firstMatch
        reveal(reorderFirst)
        reorderFirst.tap()
        tap("Move down")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format:
            "identifier == %@ AND label CONTAINS %@ AND label BEGINSWITH %@",
            "routine.exercise.reorder.1", exerciseName, "01,"
        )).firstMatch.waitForExistence(timeout: 5))
        attach("06-session-populated")
        tap("Save session ▸")
        let session = app.staticTexts["M1 Push A"].firstMatch
        XCTAssertTrue(session.waitForExistence(timeout: 15))
        session.tap()
        tap("Edit")
        let editableName = app.staticTexts.matching(NSPredicate(format: "label == %@", exerciseName))
            .allElementsBoundByIndex.first(where: { $0.isHittable })
        XCTAssertNotNil(editableName)
        editableName?.tap()
        app.buttons["prescription.details"].tap()
        let sets = app.otherElements["prescription.sets"].firstMatch
        XCTAssertTrue(sets.waitForExistence(timeout: 10))
        reveal(sets)
        UITestNavigation.step(sets, to: 2)
        let repsLow = app.otherElements["prescription.reps.low"].firstMatch
        reveal(repsLow)
        UITestNavigation.step(repsLow, to: 6)
        let repsHigh = app.otherElements["prescription.reps.high"].firstMatch
        reveal(repsHigh)
        UITestNavigation.step(repsHigh, to: 10)
        attach("06a-edit-prescription")
        tap("Save session ▸")
        tap("Start workout ▸")
        XCTAssertTrue(app.textFields["set.reps.1.S1"].waitForExistence(timeout: 15))
        let addSet = app.buttons["card.addSet.1"]
        reveal(addSet)
        addSet.tap()
        let added = app.textFields["set.reps.1.S3"]
        XCTAssertTrue(added.waitForExistence(timeout: 10))
        reveal(added)
        let rowY = app.buttons["set.complete.1.S3"].frame.midY / app.frame.height
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: rowY))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: rowY)))
        if added.exists { tap("Delete") }
        XCTAssertFalse(added.exists)
        let weight = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "set.weight.1.S1")).firstMatch
        let weightInput = weight.exists ? weight : app.textFields["—"].firstMatch
        reveal(weightInput)
        enter("80", into: weightInput)
        let reps = app.textFields["set.reps.1.S1"]
        enter("8", into: reps)
        reveal(app.buttons["set.complete.1.S1"])
        app.buttons["set.complete.1.S1"].tap()
        XCTAssertTrue(app.buttons["rest.plus15"].waitForExistence(timeout: 10))
        app.buttons["rest.plus15"].tap()
        app.buttons["rest.minus15"].tap()
        attach("07-logged-set-and-rest")

        // Reset is ONLY on the initial launch. Real relaunch reopens persisted data.
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.buttons["resumeSlab.resume"].waitForExistence(timeout: 30))
        attach("08-resume-after-relaunch")
        app.buttons["resumeSlab.resume"].tap()
        XCTAssertTrue(app.buttons["rest.plus15"].waitForExistence(timeout: 15))
        reveal(app.textFields["set.reps.1.S1"])
        XCTAssertEqual(app.textFields["set.reps.1.S1"].value as? String, "8")
        attach("09-rest-restored")
        app.buttons["rest.skip"].tap()
        tap("More")
        tap("Finish")
        tap("Finish")
        XCTAssertTrue(app.staticTexts["WORKOUT COMPLETE"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts[exerciseName].exists)
        attach("10-workout-summary")
        app.buttons["summary.done"].tap()
        app.buttons["Progress"].tap()
        let history = app.buttons["progress.history"]
        XCTAssertTrue(history.waitForExistence(timeout: 10))
        reveal(history)
        history.tap()
        let historyRow = app.buttons["history.row"].firstMatch
        XCTAssertTrue(historyRow.waitForExistence(timeout: 15))
        XCTAssertTrue(historyRow.label.contains("M1 Push A"))
        XCTAssertTrue(historyRow.label.contains("640"))
        historyRow.tap()
        XCTAssertTrue(app.staticTexts["WORKOUT COMPLETE"].waitForExistence(timeout: 10))
        attach("11-completed-history")
        tap("Back")
        tap("Back")
        app.buttons["Today"].tap()
        let sessionToOpen = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "M1 Push A"))
            .allElementsBoundByIndex.first(where: { $0.isHittable })
        XCTAssertNotNil(sessionToOpen)
        sessionToOpen?.tap()
        tap("Start workout ▸")
        let previous = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Previous: 80 × 8")).firstMatch
        XCTAssertTrue(previous.waitForExistence(timeout: 15))
        attach("12-previous-performance")
        tap("More")
        tap("Discard")
        tap("Discard")
    }

    @MainActor
    func testComponentGalleryInteractions() throws {
        app = UITestNavigation.launch(UITestNavigation.freshStore)
        XCTAssertTrue(app.buttons["Today"].waitForExistence(timeout: 90))
        tap("Settings")
        let gallery = app.buttons["settings.componentGallery"]
        reveal(gallery)
        XCTAssertTrue(gallery.waitForExistence(timeout: 10))
        gallery.tap()
        XCTAssertTrue(app.staticTexts["gallery.lastAction"].waitForExistence(timeout: 10))
        tap("Signal action ▸")
        XCTAssertEqual(app.staticTexts["gallery.lastAction"].label, "Signal button activated.")
        attach("gallery-actions")
        tap("Compact action")
        XCTAssertEqual(app.staticTexts["gallery.lastAction"].label, "Compact button activated.")
        let targetSets = app.otherElements.matching(NSPredicate(format: "label == %@", "Target sets")).firstMatch
        reveal(targetSets)
        attach("gallery-inputs")
    }

    /// Run with simctl content_size set before launch; no fixed text-size override.
    @MainActor
    func testWorkoutLayoutAndTouchTargets() throws {
        app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 90))
        reveal(resume)
        resume.tap()
        let reps = app.textFields["set.reps.1.S1"]
        reveal(reps)
        XCTAssertTrue(reps.waitForExistence(timeout: 15))
        attach("layout-workout-before-entry")
        enter("8", into: reps)
        // XCUITest may call a cell hittable even when the fixed header covers
        // it. Finish keyboard entry, then ensure the target is visibly below
        // that header before tapping (especially with accessibility text).
        let keyboardDone = app.toolbars.buttons["DONE"].firstMatch
        if keyboardDone.exists { keyboardDone.tap() }
        let complete = app.buttons["set.complete.1.S1"]
        reveal(complete)
        let headerBottom = app.otherElements["workout.header"].firstMatch.frame.maxY
        XCTAssertTrue(complete.isHittable)
        XCTAssertGreaterThan(complete.frame.midY, headerBottom)
        XCTAssertGreaterThanOrEqual(complete.frame.width, 44)
        XCTAssertGreaterThanOrEqual(complete.frame.height, 44)
        XCTAssertGreaterThanOrEqual(reps.frame.width, 44)
        XCTAssertGreaterThanOrEqual(reps.frame.height, 44)
        XCTAssertGreaterThanOrEqual(complete.frame.minX, 0)
        XCTAssertLessThanOrEqual(complete.frame.maxX, app.frame.width)
        complete.tap()
        let plus = app.buttons["rest.plus15"]
        XCTAssertTrue(plus.waitForExistence(timeout: 10))
        XCTAssertTrue(plus.isHittable)
        XCTAssertGreaterThanOrEqual(plus.frame.height, 44)
        plus.tap()
        app.buttons["rest.minus15"].tap()
        attach("layout-workout-with-rest")
        app.descendants(matching: .any).matching(identifier: "rest.status").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["REST TIMER"].waitForExistence(timeout: 10))
        let expandedPlus = app.buttons["rest.expanded.plus15"]
        reveal(expandedPlus)
        XCTAssertTrue(expandedPlus.isHittable)
        XCTAssertGreaterThanOrEqual(expandedPlus.frame.height, 44)
        expandedPlus.tap()
        app.buttons["rest.expanded.minus15"].tap()
        attach("layout-expanded-rest")
        tap("Done")
        app.buttons["rest.skip"].tap()
        tap("More")
        tap("Finish")
        tap("Finish")
        XCTAssertTrue(app.staticTexts["WORKOUT COMPLETE"].waitForExistence(timeout: 15))
        attach("layout-completed-summary")
    }

    @MainActor
    private func field(_ name: String) -> XCUIElement {
        let query = NSPredicate(format: "label ==[c] %@ OR placeholderValue ==[c] %@", name, name)
        let text = app.textFields.matching(query).firstMatch
        return text.exists ? text : app.textViews.matching(query).firstMatch
    }

    @MainActor
    private func tapFilter(_ identifier: String) {
        let button = app.buttons[identifier]
        let filters = app.scrollViews["library.filters"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        for _ in 0..<12 {
            let frame = button.frame
            if frame.minX >= app.frame.minX && frame.maxX <= app.frame.maxX {
                break
            }
            let moveLeft = frame.midX > app.frame.midX
            let start = filters.coordinate(withNormalizedOffset: CGVector(dx: moveLeft ? 0.7 : 0.3, dy: 0.5))
            let end = filters.coordinate(withNormalizedOffset: CGVector(dx: moveLeft ? 0.4 : 0.6, dy: 0.5))
            start.press(forDuration: 0.1, thenDragTo: end,
                        withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        XCTAssertTrue(button.isHittable, "Filter must be reachable by horizontal scrolling")
        button.tap()
    }

    @MainActor
    private func tap(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons.matching(NSPredicate(format: "label ==[c] %@", name)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15), "Missing button: \(name)", file: file, line: line)
        reveal(button)
        button.tap()
    }

    @MainActor
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<14 {
            let exists = element.exists
            let header = app.otherElements["workout.header"].firstMatch
            let isSetInput = exists && element.identifier.hasPrefix("set.")
            let headerBottom = isSetInput && header.exists
                ? header.frame.maxY : 0
            let keyboard = app.keyboards.firstMatch
            let visibleBottom = isSetInput && keyboard.exists
                ? keyboard.frame.minY - 58 : app.frame.maxY - 24
            let fits = !isSetInput || (element.frame.minY >= headerBottom + 8
                && element.frame.maxY <= visibleBottom)
            if exists && element.isHittable && fits { return }
            if let container = app.collectionViews.allElementsBoundByIndex.last(where: { $0.isHittable })
                ?? app.scrollViews.allElementsBoundByIndex.last(where: { $0.isHittable }) {
                if isSetInput {
                    let top = headerBottom + 8
                    let middle = (top + visibleBottom) / 2
                    let delta = middle - element.frame.midY
                    let startY = delta > 0 ? top + 20 : visibleBottom - 20
                    let endY = min(visibleBottom - 20, max(top + 20, startY + delta))
                    let start = app.coordinate(withNormalizedOffset: .zero)
                        .withOffset(CGVector(dx: app.frame.width - 24, dy: startY))
                    let end = app.coordinate(withNormalizedOffset: .zero)
                        .withOffset(CGVector(dx: app.frame.width - 24, dy: endY))
                    start.press(forDuration: 0.1, thenDragTo: end,
                                withVelocity: .slow, thenHoldForDuration: 0.2)
                    continue
                }
                if element.exists && element.frame != .zero && element.frame.minY < max(headerBottom, container.frame.minY + 44) {
                    container.swipeDown(velocity: .slow)
                } else {
                    container.swipeUp(velocity: .slow)
                }
            } else { app.swipeUp(velocity: .slow) }
        }
    }

    @MainActor
    private func pickExercise(_ name: String) {
        let search = app.textFields["library.search.picker"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        enter(name, into: search)
        let row = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH[c] %@", "exercise.pick.", name
        )).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
    }

    /// Types the way a user does: tap the field, then type. A prefilled name
    /// is selected with a triple tap and typed over, as a user would, so
    /// nothing depends on where a tap leaves the caret. A number is never
    /// deleted first, so leftover digits fail the check below; a
    /// delete-first helper once hid reps entry that turned 10 into 106.
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
        if !element.identifier.hasPrefix("set."), !existing.isEmpty, existing != element.placeholderValue {
            element.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        }
        element.typeText(text)
        let actual = (element.value as? String) ?? ""
        if element.identifier.hasPrefix("set.weight.") {
            // The accessible weight includes its unit, unlike reps and names.
            let numericValue = actual.split(separator: " ").first.map(String.init) ?? ""
            XCTAssertEqual(Double(numericValue), Double(text), "Weight entry must keep the entered load")
        } else {
            XCTAssertEqual(actual, text, "Typing must not add a prefix or suffix")
        }
    }

    @MainActor
    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
