import XCTest

extension UITestNavigation {
    static func openSeededWorkout() -> XCUIApplication {
        let app = launch(seededWorkout)
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(appears(resume))
        resume.tap()
        XCTAssertTrue(appears(app.textFields["set.reps.1.S1"]))
        return app
    }

    /// Opens the calculation from the exercise's inline reason.
    static func openWeightExplanation(in app: XCUIApplication) {
        let why = app.buttons["card.why.1"]
        revealInLogger(why, in: app)
        why.tap()
        let details = app.buttons["card.weightDetails.1"]
        XCTAssertTrue(appears(details))
        revealInLogger(details, in: app)
        details.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS[c] %@", "RECOMMENDED"
        )).firstMatch.waitForExistence(timeout: 10))
    }

    static func suggestedWeightAction(for set: String, in app: XCUIApplication) -> XCUIElement {
        let actions = app.buttons["set.type.\(set)"]
        revealInLogger(actions, in: app)
        actions.tap()
        let use = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Use ")).firstMatch
        XCTAssertTrue(appears(use, within: 5))
        return use
    }

    /// Taps a button in the decimal RPE picker's header and waits for the
    /// picker to close. A screen under the sheet can show a button with the
    /// same label, so this takes the lowest one.
    static func tapPickerButton(_ label: String, in app: XCUIApplication) {
        let wheel = app.pickerWheels.firstMatch
        let button = app.buttons.matching(NSPredicate(format: "label ==[c] %@", label))
            .allElementsBoundByIndex.max(by: { $0.frame.minY < $1.frame.minY })
        XCTAssertNotNil(button, "Missing picker button: \(label)")
        button?.tap()
        XCTAssertTrue(disappears(wheel, within: 5), "\(label) must close the picker")
    }

    static func openEmptySessionBuilder() -> XCUIApplication {
        let app = launch(freshStore)
        let newRoutine = app.buttons["today.planRoutine"]
        reveal(newRoutine, in: app)
        newRoutine.tap()
        // Plan a routine or block opens the name step; SAVE opens the routine.
        type("Push Pull Legs", into: app.textFields["newRoutine.name"])
        hittable(app.buttons, "Save", exactLabel: true).tap()
        let addSession = app.buttons["+ Add session"]
        XCTAssertTrue(appears(addSession))
        addSession.tap()
        let newSession = app.buttons["+ New session"]
        XCTAssertTrue(appears(newSession))
        newSession.tap()
        XCTAssertTrue(appears(app.textFields["Session name"]))
        return app
    }
}
