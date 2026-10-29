import XCTest

/// Review items 33, 41 and 42: the workout, set and pinned note sheets.
final class NoteSheetsUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// Item 41: the demo bench press has warm-ups, and its first working
    /// set's note is still SET 1 NOTE.
    @MainActor
    func testFirstWorkingSetNoteIsSetOne() throws {
        let app = UITestNavigation.openSeededWorkout()
        openSetNote(in: app)
        let title = app.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH[c] 'SET ' AND label ENDSWITH[c] ' NOTE'"
        )).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label.uppercased(), "SET 1 NOTE",
                       "Warm-ups must not count in the set note's number")
    }

    /// Item 42: the Pinned Note sheet uses the BRU header and editor of
    /// WorkoutNotesSheet, not a system navigation bar and Form.
    @MainActor
    func testPinnedNoteSheetIsBRU() throws {
        let app = UITestNavigation.openSeededWorkout()
        openPinnedNote(in: app)
        XCTAssertTrue(element(app.staticTexts, "Pinned note").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app.buttons, "Cancel").exists)
        XCTAssertTrue(element(app.buttons, "Save").exists)
        XCTAssertFalse(app.navigationBars["Pinned Note"].exists, "The sheet must not use the system navigation bar")
        attachScreenshot(of: app, named: "pinned-note-empty")

        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.exists, "The sheet must use the BRU text editor")
        editor.tap()
        editor.typeText("Pause one second on the chest, elbows tucked at 45 degrees")
        attachScreenshot(of: app, named: "pinned-note-typed")
    }

    @MainActor
    private func openSetNote(in app: XCUIApplication) {
        let note = app.buttons["Note for set 1"].firstMatch
        UITestNavigation.reveal(note, in: app)
        note.tap()
    }

    /// The first exercise's long-press menu, as a user creates the first pinned note.
    @MainActor
    private func openPinnedNote(in app: XCUIApplication) {
        app.staticTexts["Barbell Bench Press - Medium Grip"].firstMatch.press(forDuration: 1.2)
        let edit = app.buttons["Edit Pinned Note"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// BRU labels reach accessibility uppercased, so match without case.
    @MainActor
    private func element(_ query: XCUIElementQuery, _ label: String) -> XCUIElement {
        query.matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
    }
}
