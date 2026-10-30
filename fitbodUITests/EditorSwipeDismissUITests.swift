import XCTest

/// Review item 3: a swipe-down used to close an editor sheet and throw its
/// edits away, while Cancel and Back ask first. An editor with unsaved
/// edits now resists the swipe; an untouched editor still closes on it.
/// Review item 25: iOS 26 hides a dialog's cancel-role button, so each
/// discard dialog shows a plain "Keep editing", and New Block's CANCEL
/// asks before it throws edits away.
final class EditorSwipeDismissUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testSessionEditorResistsSwipeDownOnlyWithUnsavedEdits() throws {
        let app = UITestNavigation.openEmptySessionBuilder()
        let title = app.staticTexts.labeled("New session")
        UITestNavigation.dragSheetDown(from: title, in: app)
        assertCloses(title, "An untouched session editor must close on swipe-down")

        hittable(app.buttons, "+ New session").tap()
        let name = app.textFields["Session name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.tap()
        name.typeText("Push C\n")
        UITestNavigation.dragSheetDown(from: title, in: app)
        assertStaysOpen(title, "A swipe-down must not close a session editor with unsaved edits")
        XCTAssertEqual(name.value as? String, "Push C", "The edit must survive the swipe")

        hittable(app.buttons, "Back").tap()
        keepEditing(in: app, dialog: "Discard changes?", screenshot: "session-editor-discard-dialog")
        assertStaysOpen(title, "Keep editing must leave the session editor open")
        XCTAssertEqual(name.value as? String, "Push C", "Keep editing must keep the edit")

        hittable(app.buttons, "Back").tap()
        XCTAssertTrue(app.staticTexts.labeled("Discard changes?").waitForExistence(timeout: 5),
                      "Back must still ask before discarding")
        hittable(app.buttons, "Discard").tap()
        assertCloses(title, "Discard must close the session editor")
    }

    @MainActor
    func testCustomExerciseEditorResistsSwipeDownOnlyWithUnsavedEdits() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Library", in: app)
        let title = app.staticTexts.labeled("New Exercise")
        hittable(app.buttons, "+ New").tap()
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        UITestNavigation.dragSheetDown(from: title, in: app)
        assertCloses(title, "An untouched custom exercise editor must close on swipe-down")

        hittable(app.buttons, "+ New").tap()
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let isolation = hittable(app.buttons, "Isolation")
        isolation.tap()
        UITestNavigation.dragSheetDown(from: title, in: app)
        assertStaysOpen(title, "A swipe-down must not close a custom exercise editor with unsaved edits")
        XCTAssertTrue(isolation.isSelected, "The edit must survive the swipe")

        hittable(app.buttons, "Cancel").tap()
        keepEditing(in: app, dialog: "Discard Changes?", screenshot: "exercise-editor-discard-dialog")
        assertStaysOpen(title, "Keep editing must leave the custom exercise editor open")
        XCTAssertTrue(isolation.isSelected, "Keep editing must keep the edit")

        hittable(app.buttons, "Cancel").tap()
        XCTAssertTrue(app.staticTexts.labeled("Discard Changes?").waitForExistence(timeout: 5),
                      "Cancel must still ask before discarding")
        hittable(app.buttons, "Discard").tap()
        assertCloses(title, "Discard must close the custom exercise editor")
    }

    /// Today's Start a block CTA presents the New Block builder as a sheet.
    /// A picker the builder opens must still swipe away on its own.
    @MainActor
    func testNewBlockBuilderResistsSwipeDownOnlyWithUnsavedEdits() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        let title = app.staticTexts.labeled("NEW BLOCK")
        openNewBlock(in: app)
        UITestNavigation.dragSheetDown(from: title, in: app)
        assertCloses(title, "An untouched New Block builder must close on swipe-down")

        openNewBlock(in: app)
        let fixedWeekly = app.buttons.labeled("FIXED WEEKLY scheduling")
        UITestNavigation.reveal(fixedWeekly, in: app)
        fixedWeekly.tap()
        UITestNavigation.dragSheetDown(from: title, in: app)
        assertStaysOpen(title, "A swipe-down must not close a New Block builder with unsaved edits")
        XCTAssertTrue(fixedWeekly.isSelected, "The edit must survive the swipe")

        // The routine picker has no close button, so a swipe is its only way out.
        hittable(app.buttons, "+ ATTACH ▸").tap()
        let picker = app.staticTexts.labeled("Choose Routine")
        UITestNavigation.dragSheetDown(from: picker, in: app)
        assertCloses(picker, "A picker opened from an edited builder must still close on swipe-down")
        assertStaysOpen(title, "Closing the picker must leave the builder open")

        hittable(app.buttons, "Cancel").tap()
        XCTAssertTrue(app.staticTexts.labeled("Discard this block?").waitForExistence(timeout: 5),
                      "CANCEL must ask before it discards an edited block")
        hittable(app.buttons, "Discard").tap()
        assertCloses(title, "Discard must close the New Block builder")
    }

    /// The review's repro for the custom exercise editor: a name edit, then
    /// T01's swipe from the sheet's top edge.
    @MainActor
    func testCustomExerciseEditorResistsSwipeDownAfterANameEdit() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Library", in: app)
        let title = app.staticTexts.labeled("New Exercise")
        hittable(app.buttons, "+ New").tap()
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        UITestNavigation.swipeSheetDown(in: app)
        assertCloses(title, "An untouched custom exercise editor must close on swipe-down")

        hittable(app.buttons, "+ New").tap()
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let name = app.textFields["customExercise.name"]
        type("Hack Squat", into: name)
        UITestNavigation.swipeSheetDown(in: app)
        assertStaysOpen(title, "A swipe-down must not close a custom exercise editor with an unsaved name")
        XCTAssertEqual(name.value as? String, "Hack Squat", "The name must survive the swipe")
        UITestNavigation.saveScreenshot("T05", "exercise-editor-name-after-swipe")
    }

    /// The review's repro for New Block: a typed block name, then T01's
    /// swipe from the sheet's top edge.
    @MainActor
    func testNewBlockBuilderResistsSwipeDownAfterANameEdit() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        let title = app.staticTexts.labeled("NEW BLOCK")
        openNewBlock(in: app)
        UITestNavigation.swipeSheetDown(in: app)
        assertCloses(title, "An untouched New Block builder must close on swipe-down")

        openNewBlock(in: app)
        let name = blockNameField(in: app)
        type("Summer Base", into: name)
        UITestNavigation.swipeSheetDown(in: app)
        assertStaysOpen(title, "A swipe-down must not close a New Block builder with an unsaved name")
        XCTAssertEqual(name.value as? String, "Summer Base", "The name must survive the swipe")
        UITestNavigation.saveScreenshot("T05", "new-block-name-after-swipe")
    }

    /// CANCEL and "< PROGRAM" close an untouched New Block at once, and ask
    /// before they throw away an edited one.
    @MainActor
    func testNewBlockCancelAsksOnlyWithUnsavedEdits() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        let title = app.staticTexts.labeled("NEW BLOCK")
        let dialog = app.staticTexts.labeled("Discard this block?")
        openNewBlock(in: app)
        hittable(app.buttons, "Cancel").tap()
        assertCloses(title, "CANCEL must close an untouched New Block builder at once")
        XCTAssertFalse(dialog.exists, "CANCEL must not ask when nothing changed")

        openNewBlock(in: app)
        let name = blockNameField(in: app)
        type("Summer Base", into: name)
        hittable(app.buttons, "Cancel").tap()
        keepEditing(in: app, dialog: "Discard this block?", screenshot: "new-block-discard-dialog")
        assertStaysOpen(title, "Keep editing must leave the New Block builder open")
        XCTAssertEqual(name.value as? String, "Summer Base", "Keep editing must keep the name")

        hittable(app.buttons, "< PROGRAM").tap()
        XCTAssertTrue(dialog.waitForExistence(timeout: 5), "< PROGRAM must also ask before it discards an edited block")
        hittable(app.buttons, "Discard").tap()
        assertCloses(title, "Discard must close the New Block builder")
    }

    /// The same builder edits a saved block as EDIT BLOCK. Its CANCEL asks
    /// "Discard changes?", because Discard keeps the block and drops the edits.
    @MainActor
    func testEditBlockCancelAsksOnlyWithUnsavedEdits() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        // A template row opens a named block with phases, so SAVE needs no typing.
        UITestNavigation.selectTab("Program", in: app)
        let template = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Hypertrophy meso")).firstMatch
        UITestNavigation.reveal(template, in: app)
        template.tap()
        XCTAssertTrue(app.staticTexts.labeled("NEW BLOCK").waitForExistence(timeout: 10))
        hittable(app.buttons, "SAVE").tap()
        assertCloses(app.staticTexts.labeled("NEW BLOCK"), "SAVE must close the New Block builder")

        let card = app.buttons.labeled("DRAFT block: Hypertrophy Meso")
        UITestNavigation.reveal(card, in: app)
        card.tap()
        let title = app.staticTexts.labeled("EDIT BLOCK")
        hittable(app.buttons, "EDIT").tap()
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        hittable(app.buttons, "Cancel").tap()
        assertCloses(title, "CANCEL must close an untouched EDIT BLOCK at once")

        hittable(app.buttons, "EDIT").tap()
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let fixedWeekly = app.buttons.labeled("FIXED WEEKLY scheduling")
        UITestNavigation.reveal(fixedWeekly, in: app)
        fixedWeekly.tap()
        hittable(app.buttons, "Cancel").tap()
        keepEditing(in: app, dialog: "Discard changes?", screenshot: "edit-block-discard-dialog")
        assertStaysOpen(title, "Keep editing must leave EDIT BLOCK open")
        XCTAssertTrue(fixedWeekly.isSelected, "Keep editing must keep the edit")

        hittable(app.buttons, "Cancel").tap()
        XCTAssertTrue(app.staticTexts.labeled("Discard changes?").waitForExistence(timeout: 5),
                      "CANCEL must ask before it discards edits to a saved block")
        hittable(app.buttons, "Discard").tap()
        assertCloses(title, "Discard must close EDIT BLOCK")
    }

    @MainActor
    private func openNewBlock(in app: XCUIApplication) {
        let start = app.buttons.labeled("Start a block")
        UITestNavigation.reveal(start, in: app)
        start.tap()
        XCTAssertTrue(app.staticTexts.labeled("NEW BLOCK").waitForExistence(timeout: 10))
    }

    /// The builder's only text field. It has no label; its placeholder
    /// "NAME YOUR BLOCK" is a separate text.
    @MainActor
    private func blockNameField(in app: XCUIApplication) -> XCUIElement {
        app.textFields.firstMatch
    }

    /// Replaces the field's text once it has keyboard focus, because
    /// `typeText` can drop the first character, then presses return to put
    /// the keyboard away. Today's Start a block opens with "Blank Block".
    @MainActor
    private func type(
        _ text: String, into field: XCUIElement,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Missing \(field)", file: file, line: line)
        // Near the trailing edge, so the cursor lands after any text already there.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)
        XCTAssertEqual(XCTWaiter().wait(for: [focused], timeout: 5), .completed,
                       "The field never took keyboard focus", file: file, line: line)
        // An empty field reports its placeholder as its value.
        if let current = field.value as? String, !current.isEmpty, current != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(text + "\n")
        XCTAssertEqual(field.value as? String, text, "The field must hold the typed text", file: file, line: line)
    }

    /// Waits for the discard dialog, saves a screenshot of it and taps its
    /// "Keep editing", which must be visible: iOS 26 hides a cancel-role button.
    @MainActor
    private func keepEditing(
        in app: XCUIApplication, dialog title: String, screenshot: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let dialog = app.staticTexts.labeled(title)
        let asked = dialog.waitForExistence(timeout: 5)
        UITestNavigation.saveScreenshot("T05", screenshot)
        XCTAssertTrue(asked, "Missing the \"\(title)\" dialog", file: file, line: line)
        hittable(app.buttons, "Keep editing", file: file, line: line).tap()
        XCTAssertTrue(dialog.waitForNonExistence(timeout: 5), "Keep editing must close the dialog", file: file, line: line)
    }

    @MainActor
    private func assertStaysOpen(
        _ header: XCUIElement, _ message: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertFalse(header.waitForNonExistence(timeout: 3), message, file: file, line: line)
        XCTAssertTrue(header.isHittable, message, file: file, line: line)
    }

    @MainActor
    private func assertCloses(
        _ header: XCUIElement, _ message: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(header.waitForNonExistence(timeout: 5), message, file: file, line: line)
    }

    /// The match a user can tap. A sheet or dialog leaves same-named
    /// controls (such as the session editor's own Discard) underneath it.
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
