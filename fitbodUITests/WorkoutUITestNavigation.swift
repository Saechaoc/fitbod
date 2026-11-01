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

    /// One tap on set 1's WHY control, as a user opens Why-this-weight.
    static func openWeightExplanation(in app: XCUIApplication) {
        let why = app.buttons["set.why.1.S1"]
        reveal(why, in: app)
        why.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS[c] %@", "RECOMMENDED"
        )).firstMatch.waitForExistence(timeout: 10))
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
        let newRoutine = app.buttons["+ New routine"]
        reveal(newRoutine, in: app)
        newRoutine.tap()
        // + New routine opens the name step; SAVE opens the routine.
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
