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
        let title = element(app.staticTexts, "New session")
        swipeDown(from: title, in: app)
        assertCloses(title, "An untouched session editor must close on swipe-down")

        hittable(app.buttons, "+ New session").tap()
        let name = app.textFields["Session name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.tap()
        name.typeText("Push C\n")
        swipeDown(from: title, in: app)
        assertStaysOpen(title, "A swipe-down must not close a session editor with unsaved edits")
        XCTAssertEqual(name.value as? String, "Push C", "The edit must survive the swipe")

        hittable(app.buttons, "Back").tap()
        XCTAssertTrue(element(app.staticTexts, "Discard changes?").waitForExistence(timeout: 5),
                      "Back must still ask before discarding")
        hittable(app.buttons, "Discard").tap()
        assertCloses(title, "Discard must close the session editor")
    }

    @MainActor
    func testCustomExerciseEditorResistsSwipeDownOnlyWithUnsavedEdits() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Library", in: app)
        let title = element(app.staticTexts, "New Exercise")
        hittable(app.buttons, "+ New").tap()
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        swipeDown(from: title, in: app)
        assertCloses(title, "An untouched custom exercise editor must close on swipe-down")

        hittable(app.buttons, "+ New").tap()
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let isolation = hittable(app.buttons, "Isolation")
        isolation.tap()
        swipeDown(from: title, in: app)
        assertStaysOpen(title, "A swipe-down must not close a custom exercise editor with unsaved edits")
        XCTAssertTrue(isolation.isSelected, "The edit must survive the swipe")

        hittable(app.buttons, "Cancel").tap()
        XCTAssertTrue(element(app.staticTexts, "Discard Changes?").waitForExistence(timeout: 5),
                      "Cancel must still ask before discarding")
        hittable(app.buttons, "Discard").tap()
        assertCloses(title, "Discard must close the custom exercise editor")
    }

    /// Today's Start a block CTA presents the New Block builder as a sheet.
    @MainActor
    func testNewBlockBuilderResistsSwipeDownOnlyWithUnsavedEdits() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        let title = element(app.staticTexts, "NEW BLOCK")
        openNewBlock(in: app)
        swipeDown(from: title, in: app)
        assertCloses(title, "An untouched New Block builder must close on swipe-down")

        openNewBlock(in: app)
        let fixedWeekly = element(app.buttons, "FIXED WEEKLY scheduling")
        UITestNavigation.reveal(fixedWeekly, in: app)
        fixedWeekly.tap()
        swipeDown(from: title, in: app)
        assertStaysOpen(title, "A swipe-down must not close a New Block builder with unsaved edits")
        XCTAssertTrue(fixedWeekly.isSelected, "The edit must survive the swipe")

        hittable(app.buttons, "Cancel").tap()
        assertCloses(title, "CANCEL must close the New Block builder")
    }

    @MainActor
    private func openNewBlock(in app: XCUIApplication) {
        let start = element(app.buttons, "Start a block")
        UITestNavigation.reveal(start, in: app)
        start.tap()
        XCTAssertTrue(element(app.staticTexts, "NEW BLOCK").waitForExistence(timeout: 10))
    }

    /// Drags from the sheet's header to the bottom of the screen.
    @MainActor
    private func swipeDown(from header: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(header.waitForExistence(timeout: 10))
        header.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.05,
            thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
        )
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

    /// BRU labels reach accessibility uppercased, so match without case.
    @MainActor
    private func element(_ query: XCUIElementQuery, _ label: String) -> XCUIElement {
        query.matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
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
