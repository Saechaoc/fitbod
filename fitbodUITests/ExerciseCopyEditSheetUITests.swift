import XCTest

/// Review item 1: one tap on COPY (built-in exercise) or EDIT (custom
/// exercise) opens a filled editor. The first tap used to open a blank sheet.
final class ExerciseCopyEditSheetUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testCopyOpensFilledEditorOnFirstTap() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Library", in: app)
        openExercise("Barbell Bench Press - Medium Grip", in: app)

        tapOnce(app.buttons["Copy"])
        let name = app.textFields["customExercise.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3), "One tap on COPY must open a filled editor")
        XCTAssertEqual(name.value as? String, "Barbell Bench Press - Medium Grip (Copy)")
    }

    @MainActor
    func testEditOpensFilledEditorOnFirstTap() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Library", in: app)
        let source = "Barbell Bench Press - Medium Grip"
        openExercise(source, in: app)
        // A saved copy is a custom exercise. Saving needs no typing, which
        // keeps the simulator keyboard out of the sheet.
        tapOnce(app.buttons["Copy"])
        tapOnce(app.buttons["Save"])
        tapOnce(app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Back")).firstMatch)
        let copyName = "\(source) (Copy)"
        let copyRow = app.staticTexts[copyName]
        XCTAssertTrue(copyRow.waitForExistence(timeout: 10))
        copyRow.tap()

        tapOnce(app.buttons["Edit"])
        let name = app.textFields["customExercise.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3), "One tap on EDIT must open a filled editor")
        XCTAssertEqual(name.value as? String, copyName)
    }

    /// Library search → the exercise's detail screen.
    @MainActor
    private func openExercise(_ exerciseName: String, in app: XCUIApplication) {
        let search = app.textFields["library.search.browser"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText(exerciseName)
        let row = app.staticTexts[exerciseName]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
    }

    @MainActor
    private func tapOnce(_ button: XCUIElement) {
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
    }
}
