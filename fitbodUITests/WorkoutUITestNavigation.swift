import XCTest

extension UITestNavigation {
    static func openSeededWorkout() -> XCUIApplication {
        let app = launch(seededWorkout)
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10))
        resume.tap()
        XCTAssertTrue(app.textFields["set.reps.1.S1"].waitForExistence(timeout: 10))
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

    static func openEmptySessionBuilder() -> XCUIApplication {
        let app = launch(freshStore)
        let newRoutine = app.buttons["+ New routine"]
        reveal(newRoutine, in: app)
        newRoutine.tap()
        let addSession = app.buttons["+ Add session"]
        XCTAssertTrue(addSession.waitForExistence(timeout: 10))
        addSession.tap()
        let newSession = app.buttons["+ New session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 10))
        newSession.tap()
        XCTAssertTrue(app.textFields["Session name"].waitForExistence(timeout: 10))
        return app
    }
}
