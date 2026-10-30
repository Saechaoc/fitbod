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
        XCTAssertTrue(app.staticTexts.labeled("Pinned note").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.labeled("Cancel").exists)
        XCTAssertTrue(app.buttons.labeled("Save").exists)
        XCTAssertFalse(app.navigationBars["Pinned Note"].exists, "The sheet must not use the system navigation bar")
        attachScreenshot(of: app, named: "pinned-note-empty")

        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.exists, "The sheet must use the BRU text editor")
        editor.tap()
        editor.typeText("Pause one second on the chest, elbows tucked at 45 degrees")
        attachScreenshot(of: app, named: "pinned-note-typed")
    }

    /// Item 33: SAVE writes the note; CANCEL and swipe-down throw the edit away.
    @MainActor
    func testWorkoutNoteSavesOnlyOnSave() throws {
        let app = UITestNavigation.openSeededWorkout()
        assertSaveKeepsAndDismissDiscards(in: app, title: "Workout notes") {
            app.buttons["More"].tap()
            let item = app.buttons["Workout notes"]
            XCTAssertTrue(item.waitForExistence(timeout: 5))
            item.tap()
        }
    }

    @MainActor
    func testSetNoteSavesOnlyOnSave() throws {
        let app = UITestNavigation.openSeededWorkout()
        assertSaveKeepsAndDismissDiscards(in: app, title: "Set 1 note") { openSetNote(in: app) }
    }

    @MainActor
    func testPinnedNoteSavesOnlyOnSave() throws {
        let app = UITestNavigation.openSeededWorkout()
        assertSaveKeepsAndDismissDiscards(in: app, title: "Pinned note") { openPinnedNote(in: app) }
    }

    @MainActor
    private func assertSaveKeepsAndDismissDiscards(
        in app: XCUIApplication, title: String, open: () -> Void,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let header = app.staticTexts.labeled(title)
        let editor = app.textViews.firstMatch
        func reopen() {
            open()
            XCTAssertTrue(header.waitForExistence(timeout: 5), "\(title) sheet did not open", file: file, line: line)
        }
        func type(_ text: String) {
            editor.tap()
            editor.typeText(text)
        }
        func waitUntilClosed() {
            let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: header)
            XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed,
                           "\(title) sheet did not close", file: file, line: line)
        }

        reopen()
        type("Kept")
        app.buttons.labeled("Save").tap()
        waitUntilClosed()
        reopen()
        XCTAssertEqual(editor.value as? String, "Kept", "SAVE must write the note", file: file, line: line)
        attachScreenshot(of: app, named: "\(title) sheet")

        type(" draft")
        app.buttons.labeled("Cancel").tap()
        waitUntilClosed()
        reopen()
        XCTAssertEqual(editor.value as? String, "Kept", "CANCEL must throw the edit away", file: file, line: line)

        type(" draft")
        UITestNavigation.dragSheetDown(from: header, in: app)
        waitUntilClosed()
        reopen()
        XCTAssertEqual(editor.value as? String, "Kept", "Swipe-down must throw the edit away", file: file, line: line)
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
}
