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

        UITestNavigation.hittable(app.buttons, "+ New session", exactLabel: true).tap()
        let name = app.textFields["Session name"]
        XCTAssertTrue(UITestNavigation.appears(name))
        name.tap()
        name.typeText("Push C\n")
        UITestNavigation.dragSheetDown(from: title, in: app)
        assertStaysOpen(title, "A swipe-down must not close a session editor with unsaved edits")
        XCTAssertEqual(name.value as? String, "Push C", "The edit must survive the swipe")

        UITestNavigation.hittable(app.buttons, "Cancel", exactLabel: true).tap()
        keepEditing(in: app, dialog: "Discard changes?")
        assertStaysOpen(title, "Keep editing must leave the session editor open")
        XCTAssertEqual(name.value as? String, "Push C", "Keep editing must keep the edit")

        UITestNavigation.hittable(app.buttons, "Cancel", exactLabel: true).tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts.labeled("Discard changes?"), within: 5),
                      "CANCEL must still ask before discarding")
        UITestNavigation.hittable(app.buttons, "Discard", exactLabel: true).tap()
        assertCloses(title, "Discard must close the session editor")
    }

    @MainActor
    func testCustomExerciseEditorResistsSwipeDownOnlyWithUnsavedEdits() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Library", in: app)
        let title = app.staticTexts.labeled("New Exercise")
        UITestNavigation.hittable(app.buttons, "+ New", exactLabel: true).tap()
        XCTAssertTrue(UITestNavigation.appears(title))
        UITestNavigation.dragSheetDown(from: title, in: app)
        assertCloses(title, "An untouched custom exercise editor must close on swipe-down")

        UITestNavigation.hittable(app.buttons, "+ New", exactLabel: true).tap()
        XCTAssertTrue(UITestNavigation.appears(title))
        let isolation = UITestNavigation.hittable(app.buttons, "Isolation", exactLabel: true)
        isolation.tap()
        UITestNavigation.dragSheetDown(from: title, in: app)
        assertStaysOpen(title, "A swipe-down must not close a custom exercise editor with unsaved edits")
        XCTAssertTrue(isolation.isSelected, "The edit must survive the swipe")

        UITestNavigation.hittable(app.buttons, "Cancel", exactLabel: true).tap()
        keepEditing(in: app, dialog: "Discard Changes?")
        assertStaysOpen(title, "Keep editing must leave the custom exercise editor open")
        XCTAssertTrue(isolation.isSelected, "Keep editing must keep the edit")

        UITestNavigation.hittable(app.buttons, "Cancel", exactLabel: true).tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts.labeled("Discard Changes?"), within: 5),
                      "Cancel must still ask before discarding")
        UITestNavigation.hittable(app.buttons, "Discard", exactLabel: true).tap()
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

        // The routine picker closes with its CANCEL, and a swipe still closes it.
        UITestNavigation.hittable(app.buttons, "+ ATTACH ▸", exactLabel: true).tap()
        let picker = app.staticTexts.labeled("Choose Routine")
        UITestNavigation.dragSheetDown(from: picker, in: app)
        assertCloses(picker, "A picker opened from an edited builder must still close on swipe-down")
        assertStaysOpen(title, "Closing the picker must leave the builder open")

        UITestNavigation.hittable(app.buttons, "Cancel", exactLabel: true).tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts.labeled("Discard this block?"), within: 5),
                      "CANCEL must ask before it discards an edited block")
        UITestNavigation.hittable(app.buttons, "Discard", exactLabel: true).tap()
        assertCloses(title, "Discard must close the New Block builder")
    }

    /// CANCEL and "< TODAY" close an untouched New Block at once, and ask
    /// before they throw away an edited one.
    @MainActor
    func testNewBlockCancelAsksOnlyWithUnsavedEdits() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        let title = app.staticTexts.labeled("NEW BLOCK")
        let dialog = app.staticTexts.labeled("Discard this block?")
        openNewBlock(in: app)
        UITestNavigation.hittable(app.buttons, "Cancel", exactLabel: true).tap()
        assertCloses(title, "CANCEL must close an untouched New Block builder at once")
        XCTAssertFalse(dialog.exists, "CANCEL must not ask when nothing changed")

        openNewBlock(in: app)
        let name = blockNameField(in: app)
        UITestNavigation.type("Summer Base", into: name)
        UITestNavigation.hittable(app.buttons, "Cancel", exactLabel: true).tap()
        keepEditing(in: app, dialog: "Discard this block?")
        assertStaysOpen(title, "Keep editing must leave the New Block builder open")
        XCTAssertEqual(name.value as? String, "Summer Base", "Keep editing must keep the name")

        UITestNavigation.hittable(app.buttons, "< TODAY", exactLabel: true).tap()
        XCTAssertTrue(UITestNavigation.appears(dialog, within: 5), "< TODAY must also ask before it discards an edited block")
        UITestNavigation.hittable(app.buttons, "Discard", exactLabel: true).tap()
        assertCloses(title, "Discard must close the New Block builder")
    }

    @MainActor
    private func openNewBlock(in app: XCUIApplication) {
        let start = app.buttons.labeled("Start a block")
        UITestNavigation.reveal(start, in: app)
        start.tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts.labeled("NEW BLOCK")))
    }

    /// The builder's only text field. It has no label; its placeholder
    /// "NAME YOUR BLOCK" is a separate text.
    @MainActor
    private func blockNameField(in app: XCUIApplication) -> XCUIElement {
        app.textFields.firstMatch
    }

    /// Waits for the discard dialog and taps its "Keep editing", which must
    /// be visible: iOS 26 hides a cancel-role button.
    @MainActor
    private func keepEditing(
        in app: XCUIApplication, dialog title: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let dialog = app.staticTexts.labeled(title)
        XCTAssertTrue(UITestNavigation.appears(dialog, within: 5), "Missing the \"\(title)\" dialog", file: file, line: line)
        UITestNavigation.hittable(app.buttons, "Keep editing", exactLabel: true, file: file, line: line).tap()
        XCTAssertTrue(UITestNavigation.disappears(dialog, within: 5), "Keep editing must close the dialog", file: file, line: line)
    }

    @MainActor
    private func assertStaysOpen(
        _ header: XCUIElement, _ message: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        // Waits the whole 3 s: an editor a swipe or a dialog wrongly let go
        // leaves within it.
        XCTAssertFalse(header.waitForNonExistence(timeout: 3), message, file: file, line: line)
        XCTAssertTrue(header.isHittable, message, file: file, line: line)
    }

    @MainActor
    private func assertCloses(
        _ header: XCUIElement, _ message: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(UITestNavigation.disappears(header, within: 5), message, file: file, line: line)
    }
}
