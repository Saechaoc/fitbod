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

        UITestNavigation.hittable(app.buttons, "Save", exactLabel: true).tap()
        XCTAssertTrue(UITestNavigation.disappears(app.textFields["customExercise.name"], within: 5), "SAVE must close the editor")

        // A relaunch reads the exercise back from the store.
        UITestNavigation.relaunch(app)
        UITestNavigation.selectTab("Library", in: app)
        let search = app.textFields["library.search.browser"]
        UITestNavigation.type(exerciseName, into: search, replacing: false, pressingReturn: false)
        let row = app.staticTexts[exerciseName]
        XCTAssertTrue(UITestNavigation.appears(row), "The saved exercise must be in the Library")
        row.tap()
        UITestNavigation.hittable(app.buttons, "Edit", exactLabel: true).tap()
        XCTAssertTrue(UITestNavigation.appears(app.textFields["customExercise.name"]), "EDIT must open the editor")
        XCTAssertEqual(app.textFields["customExercise.name"].value as? String, exerciseName)

        assertMuscle("chest", role: "Primary", percent: 100, in: app)
        assertMuscle("triceps", role: "Secondary", percent: 25, in: app)
        XCTAssertTrue(app.staticTexts.labeled("Edit exercise").exists, "EDIT must title the editor Edit exercise")
    }

    // MARK: - Helpers

    /// Library "+ New" → an empty editor.
    @MainActor
    private func openNewExercise(in app: XCUIApplication) {
        UITestNavigation.selectTab("Library", in: app)
        UITestNavigation.hittable(app.buttons, "+ New", exactLabel: true).tap()
        XCTAssertTrue(UITestNavigation.appears(app.textFields["customExercise.name"]), "+ NEW must open the editor")
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
        XCTAssertTrue(UITestNavigation.appears(row), "The muscle picker must open")
        UITestNavigation.reveal(row, in: app)
        row.tap()
        XCTAssertTrue(UITestNavigation.disappears(row, within: 5), "Picking a muscle must close the picker")
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
        XCTAssertTrue(UITestNavigation.appears(chip), "The editor must list \(slug)", file: file, line: line)
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
        XCTAssertTrue(UITestNavigation.appears(footer), "The editor must show its status line")
        return footer.label
    }
}
