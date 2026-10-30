import XCTest

/// Review item 19: CREATE CUSTOM EXERCISE after a search with no match used
/// to open the editor with an empty name. The name now starts as the trimmed
/// search text. Every way into the custom exercise editor opens it filled on
/// the first tap, cancels and reopens cleanly, and saves to the right
/// exercise.
final class CustomExerciseEntryUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testCreateFromNoMatchSearchFillsName() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Library", in: app)
        searchWithNoMatch("Zercher Probe", in: app)

        hittable(app.buttons, "Create Custom Exercise").tap()
        let name = app.textFields["customExercise.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3), "One tap on CREATE CUSTOM EXERCISE must open the editor")
        XCTAssertEqual(name.value as? String, "Zercher Probe", "The name must start as the search text")
        UITestNavigation.saveScreenshot("T03", "library-no-match-editor")
    }

    /// Each opening gets its own draft: the no-match button fills the search
    /// text without its spaces every time, and "+ New" still starts empty.
    @MainActor
    func testNoMatchEditorCancelsAndReopens() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Library", in: app)
        searchWithNoMatch(" Zercher Probe ", in: app)
        let query = app.textFields["library.search.browser"].value as? String ?? ""
        XCTAssertTrue(query.hasSuffix(" "), "The search must keep its trailing space for the trim to show")
        let name = app.textFields["customExercise.name"]

        for attempt in ["first", "second"] {
            hittable(app.buttons, "Create Custom Exercise").tap()
            XCTAssertTrue(name.waitForExistence(timeout: 3), "The \(attempt) tap must open the editor")
            XCTAssertEqual(name.value as? String, "Zercher Probe",
                           "The \(attempt) editor must hold the search text without its spaces")
            hittable(app.buttons, "Cancel").tap()
            XCTAssertTrue(name.waitForNonExistence(timeout: 5), "CANCEL must close an untouched editor")
        }

        hittable(app.buttons, "+ New").tap()
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        XCTAssertEqual(text(of: name), "", "+ NEW must start with an empty name")
    }

    /// Saving a copy adds a custom exercise and leaves the built-in one as
    /// it was.
    @MainActor
    func testCopyCancelsReopensAndSavesANewExercise() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Library", in: app)
        let source = "Barbell Bench Press - Medium Grip"
        let copyName = "\(source) (Copy)"
        search(source, in: app)
        open(source, in: app)
        let name = app.textFields["customExercise.name"]

        hittable(app.buttons, "Copy").tap()
        XCTAssertTrue(name.waitForExistence(timeout: 3), "One tap on COPY must open a filled editor")
        XCTAssertEqual(name.value as? String, copyName)
        hittable(app.buttons, "Cancel").tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5), "CANCEL must close an untouched copy")

        hittable(app.buttons, "Copy").tap()
        XCTAssertTrue(name.waitForExistence(timeout: 3), "COPY must reopen a filled editor")
        XCTAssertEqual(name.value as? String, copyName)
        hittable(app.buttons, "Save").tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5), "SAVE must close the editor")

        hittable(app.buttons, "Back").tap()
        XCTAssertTrue(app.staticTexts[copyName].waitForExistence(timeout: 10), "The copy must be a new exercise")
        XCTAssertTrue(app.staticTexts[source].exists, "The built-in exercise must stay")
        XCTAssertTrue(app.staticTexts.labeled("2 matches").exists)
    }

    /// Saving an edit renames the custom exercise in place: the old name is
    /// gone and no second exercise appears.
    @MainActor
    func testEditCancelsReopensAndSavesOverTheSameExercise() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Library", in: app)
        createFromNoMatch("Zercher Probe", in: app)
        open("Zercher Probe", in: app)
        let name = app.textFields["customExercise.name"]

        hittable(app.buttons, "Edit").tap()
        XCTAssertTrue(name.waitForExistence(timeout: 3), "One tap on EDIT must open a filled editor")
        XCTAssertEqual(name.value as? String, "Zercher Probe")
        hittable(app.buttons, "Cancel").tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5), "CANCEL must close an untouched edit")

        hittable(app.buttons, "Edit").tap()
        XCTAssertTrue(name.waitForExistence(timeout: 3), "EDIT must reopen a filled editor")
        XCTAssertEqual(name.value as? String, "Zercher Probe")
        replaceText(of: name, with: "Zercher Probe Edited")
        hittable(app.buttons, "Save").tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5), "SAVE must close the editor")
        XCTAssertTrue(app.staticTexts["Zercher Probe Edited"].waitForExistence(timeout: 5),
                      "The detail screen must show the new name")

        // The Library still searches "Zercher Probe", which both names match.
        hittable(app.buttons, "Back").tap()
        XCTAssertTrue(app.staticTexts["Zercher Probe Edited"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Zercher Probe"].exists, "The edit must rename the exercise, not add one")
        XCTAssertTrue(app.staticTexts.labeled("1 match").exists)
    }

    // MARK: - Helpers

    /// Types into the Library search, the way a user does.
    @MainActor
    private func search(_ query: String, in app: XCUIApplication) {
        let field = app.textFields["library.search.browser"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        let clear = app.buttons["Clear search"]
        if clear.exists { clear.tap() }
        focus(field)
        field.typeText(query)
    }

    /// Searches for a name the catalog does not have and waits for the
    /// no-match state.
    @MainActor
    private func searchWithNoMatch(_ query: String, in app: XCUIApplication) {
        search(query, in: app)
        let heading = app.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH[c] %@", "No exercises match \""
        )).firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 10), "The search must have no match")
    }

    /// Creates a custom exercise from the no-match state: the name comes
    /// from the search, and Chest makes it valid to save.
    @MainActor
    private func createFromNoMatch(_ exerciseName: String, in app: XCUIApplication) {
        searchWithNoMatch(exerciseName, in: app)
        hittable(app.buttons, "Create Custom Exercise").tap()
        let name = app.textFields["customExercise.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        XCTAssertEqual(name.value as? String, exerciseName)
        hittable(app.buttons, "Add Primary Muscle").tap()
        let chest = app.buttons["musclePicker.chest"]
        XCTAssertTrue(chest.waitForExistence(timeout: 10))
        chest.tap()
        hittable(app.buttons, "Save").tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5), "SAVE must close the editor")
    }

    /// A Library row → the exercise's detail screen.
    @MainActor
    private func open(_ exerciseName: String, in app: XCUIApplication) {
        let row = app.staticTexts[exerciseName]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Missing Library row: \(exerciseName)")
        row.tap()
        XCTAssertTrue(app.staticTexts.labeled("Exercise").waitForExistence(timeout: 10))
    }

    /// Clears a filled field from its end and types `replacement`. Extra
    /// deletes cover a first keystroke that the field drops.
    @MainActor
    private func replaceText(of field: XCUIElement, with replacement: String) {
        let old = text(of: field)
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        waitForFocus(field)
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count + 4) + replacement)
        XCTAssertEqual(field.value as? String, replacement)
    }

    /// Taps a text field until it has keyboard focus.
    @MainActor
    private func focus(_ field: XCUIElement) {
        for _ in 0..<3 {
            field.tap()
            if hasFocus(field) { return }
        }
        XCTFail("\(field.identifier) never took keyboard focus")
    }

    @MainActor
    private func waitForFocus(_ field: XCUIElement) {
        XCTAssertTrue(hasFocus(field), "\(field.identifier) never took keyboard focus")
    }

    @MainActor
    private func hasFocus(_ field: XCUIElement) -> Bool {
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)
        return XCTWaiter().wait(for: [focused], timeout: 2) == .completed
    }

    /// A text field's text: its value, or "" while it shows its placeholder.
    @MainActor
    private func text(of field: XCUIElement) -> String {
        let value = field.value as? String ?? ""
        return value == field.placeholderValue ? "" : value
    }

    /// The match a user can tap. A sheet leaves same-named controls, such as
    /// the Library's own Cancel, underneath it.
    @MainActor
    private func hittable(
        _ query: XCUIElementQuery, _ label: String,
        file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement {
        let matches = query.matching(NSPredicate(format: "label ==[c] %@", label))
        XCTAssertTrue(matches.firstMatch.waitForExistence(timeout: 10), "Missing \(label)", file: file, line: line)
        for _ in 0..<10 {
            if let match = matches.allElementsBoundByIndex.first(where: { $0.isHittable }) { return match }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTFail("No tappable \(label)", file: file, line: line)
        return matches.firstMatch
    }
}
