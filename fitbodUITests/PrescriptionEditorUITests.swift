import XCTest

/// Review item 5: target reps in the session editor's prescription details.
final class PrescriptionEditorUITests: XCTestCase {

    private let exerciseName = "Barbell Bench Press - Medium Grip"

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// Item 5: a barbell bench press starts at 4–6 reps. Raising the top of
    /// the range to 8 must read 8 (typing into the old field gave 68 or 86),
    /// and neither end can step past the other.
    @MainActor
    func testHighRepsChangesFromSixToEight() throws {
        let app = UITestNavigation.openEmptySessionBuilder()
        addExercise(in: app)
        openDetails(in: app)
        let high = control("prescription.reps.high", in: app)
        XCTAssertEqual(high.value as? String, "6")
        UITestNavigation.step(high, to: 8)
        XCTAssertTrue(app.staticTexts["4–8 reps"].exists, "The prescription chip must read the new range")

        let low = control("prescription.reps.low", in: app)
        XCTAssertGreaterThanOrEqual(low.frame.height, 44)
        UITestNavigation.step(low, to: 8)
        UITestNavigation.tapStepper(low, increment: true)
        XCTAssertEqual(low.value as? String, "8", "Low reps must not step above high reps")
        UITestNavigation.tapStepper(high, increment: false)
        XCTAssertEqual(high.value as? String, "8", "High reps must not step below low reps")
    }

    /// Adds the bench press to the open session editor.
    @MainActor
    private func addExercise(in app: XCUIApplication) {
        app.buttons["Add exercise"].tap()
        let search = app.textFields["library.search.picker"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText(exerciseName)
        let row = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH[c] %@", "exercise.pick.", exerciseName
        )).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
    }

    /// Expands the exercise's card and opens EDIT PRESCRIPTION.
    @MainActor
    private func openDetails(in app: XCUIApplication) {
        let card = app.staticTexts.matching(NSPredicate(format: "label == %@", exerciseName))
        XCTAssertTrue(card.firstMatch.waitForExistence(timeout: 10))
        let visible = card.allElementsBoundByIndex.first(where: { $0.isHittable })
        XCTAssertNotNil(visible, "The exercise's card must be visible")
        visible?.tap()
        let details = app.buttons["prescription.details"]
        XCTAssertTrue(details.waitForExistence(timeout: 10))
        details.tap()
    }

    @MainActor
    private func control(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        let element = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 10), "Missing control: \(identifier)")
        UITestNavigation.reveal(element, in: app)
        return element
    }
}
