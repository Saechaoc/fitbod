import XCTest

/// Ticket T32, review item 20: a new custom exercise saves each muscle's
/// role and weight, and EDIT reopens them after a relaunch.
final class CustomExerciseEditorBRUUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Acceptance

    /// A new exercise with one primary and one secondary muscle saves, and
    /// after a relaunch EDIT reopens it with both roles and weights.
    @MainActor
    func testSavedMusclesReopenWithTheirRolesAndWeights() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        let exerciseName = "T32 Landmine Press"
        openNewExercise(in: app)
        UITestNavigation.type(exerciseName, into: app.textFields["customExercise.name"])
        addMuscle("chest", in: app)
        addMuscle("triceps", in: app)
        // Triceps starts at the secondary default, 50%; a tick sets 25%.
        tapTick("triceps", percent: 25, in: app)
        assertMuscle("chest", role: "Primary", percent: 100, in: app)
        assertMuscle("triceps", role: "Secondary", percent: 25, in: app)
        XCTAssertEqual(status(in: app), "Valid, 1 primary mapped. Ready to save.")
        UITestNavigation.saveScreenshot("T32", "editor-new-before-save")

        UITestNavigation.hittable(app.buttons, "Save", exactLabel: true).tap()
        XCTAssertTrue(app.textFields["customExercise.name"].waitForNonExistence(timeout: 5), "SAVE must close the editor")

        // A relaunch reads the exercise back from the store.
        UITestNavigation.relaunch(app)
        UITestNavigation.selectTab("Library", in: app)
        let search = app.textFields["library.search.browser"]
        UITestNavigation.type(exerciseName, into: search, replacing: false, pressingReturn: false)
        let row = app.staticTexts[exerciseName]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The saved exercise must be in the Library")
        row.tap()
        UITestNavigation.hittable(app.buttons, "Edit", exactLabel: true).tap()
        XCTAssertTrue(app.textFields["customExercise.name"].waitForExistence(timeout: 10), "EDIT must open the editor")
        XCTAssertEqual(app.textFields["customExercise.name"].value as? String, exerciseName)

        assertMuscle("chest", role: "Primary", percent: 100, in: app)
        assertMuscle("triceps", role: "Secondary", percent: 25, in: app)
        let secondaryHead = editorText("Secondary stimulus", in: app)
        XCTAssertLessThan(muscleRow("chest", in: app).frame.maxY, secondaryHead.frame.minY,
                          "Chest must sit in the primary section")
        XCTAssertLessThan(secondaryHead.frame.maxY, muscleRow("triceps", in: app).frame.minY,
                          "Triceps must sit in the secondary section")
        XCTAssertTrue(app.staticTexts.labeled("Edit exercise").exists, "EDIT must title the editor Edit exercise")
        let delete = app.buttons.labeled("Delete exercise")
        UITestNavigation.reveal(delete, in: app)
        UITestNavigation.saveScreenshot("T32", "editor-edit-reopened")
    }

    // MARK: - Helpers

    /// Library "+ New" → an empty editor.
    @MainActor
    private func openNewExercise(in app: XCUIApplication) {
        UITestNavigation.selectTab("Library", in: app)
        UITestNavigation.hittable(app.buttons, "+ New", exactLabel: true).tap()
        XCTAssertTrue(app.textFields["customExercise.name"].waitForExistence(timeout: 10), "+ NEW must open the editor")
    }

    /// A text in the editor sheet, not on the detail screen under it.
    @MainActor
    private func editorText(_ label: String, in app: XCUIApplication) -> XCUIElement {
        let text = editorSheet(in: app).staticTexts.matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 10), "The editor must show \(label)")
        return text
    }

    /// The sheet on top: the editor, unless a picker is open over it.
    @MainActor
    private func editorSheet(in app: XCUIApplication) -> XCUIElement {
        let sheet = UITestNavigation.topSheet(in: app)
        XCTAssertNotNil(sheet, "The editor must be a sheet")
        return sheet ?? app
    }

    /// "+ ADD MUSCLE" → the picker → `slug`'s row, scrolled into view.
    @MainActor
    private func addMuscle(_ slug: String, in app: XCUIApplication) {
        let add = app.buttons.matching(NSPredicate(
            format: "label IN %@", ["Add Primary Muscle", "Add Another Muscle"]
        )).firstMatch
        UITestNavigation.reveal(add, in: app)
        add.tap()
        let row = app.buttons["musclePicker.\(slug)"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The muscle picker must open")
        UITestNavigation.reveal(row, in: app)
        row.tap()
        XCTAssertTrue(row.waitForNonExistence(timeout: 5), "Picking a muscle must close the picker")
    }

    /// A muscle row's container, identified by the muscle's slug.
    @MainActor
    private func muscleRow(_ slug: String, in app: XCUIApplication) -> XCUIElement {
        let row = app.descendants(matching: .any)["customExercise.muscle.\(slug)"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The editor must list \(slug)")
        return row
    }

    @MainActor
    private func tapTick(_ slug: String, percent: Int, in app: XCUIApplication) {
        let tick = app.buttons["customExercise.weight.\(slug).\(percent)"]
        UITestNavigation.reveal(tick, in: app)
        tick.tap()
        XCTAssertTrue(tick.isSelected, "The \(percent)% tick must hold \(slug)'s weight")
    }

    /// The row's chip reads its role, its percent reads its weight, and the
    /// matching tick is the selected one.
    @MainActor
    private func assertMuscle(
        _ slug: String, role: String, percent: Int, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let chip = app.buttons["customExercise.role.\(slug)"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "The editor must list \(slug)", file: file, line: line)
        // BRU labels reach accessibility uppercased.
        XCTAssertEqual(chip.label.lowercased(), role.lowercased(), "\(slug)'s role", file: file, line: line)
        XCTAssertEqual(app.staticTexts["customExercise.percent.\(slug)"].label, "\(percent)%",
                       "\(slug)'s weight", file: file, line: line)
        XCTAssertTrue(app.buttons["customExercise.weight.\(slug).\(percent)"].isSelected,
                      "\(slug)'s \(percent)% tick must be selected", file: file, line: line)
    }

    /// What the status footer says, as VoiceOver reads it.
    @MainActor
    private func status(in app: XCUIApplication) -> String {
        let footer = app.descendants(matching: .any)["customExercise.status"]
        XCTAssertTrue(footer.waitForExistence(timeout: 10), "The editor must show its status line")
        return footer.label
    }
}
