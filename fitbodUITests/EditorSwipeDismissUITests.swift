import XCTest

/// Review item 3: a swipe-down used to close an editor sheet and throw its
/// edits away, while Cancel and Back ask first. An editor with unsaved
/// edits now resists the swipe; an untouched editor still closes on it.
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
        assertCloses(title, "CANCEL must close the New Block builder")
    }

    @MainActor
    private func openNewBlock(in app: XCUIApplication) {
        let start = app.buttons.labeled("Start a block")
        UITestNavigation.reveal(start, in: app)
        start.tap()
        XCTAssertTrue(app.staticTexts.labeled("NEW BLOCK").waitForExistence(timeout: 10))
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
