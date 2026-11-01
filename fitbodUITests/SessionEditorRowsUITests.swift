//
//  SessionEditorRowsUITests.swift
//  fitbodUITests
//
//  Ticket T111, in the session editor: the rows' swipe actions never
//  fired, because the rows sit in a stack, not a List, so only the
//  long-press menu, which nothing on screen shows, could remove an
//  exercise.
//
//  Each test opens the active-block seed's "Live Push", which holds one
//  bench press, the way a user does: Program, Live Routine, its session,
//  then Edit.
//

import XCTest

final class SessionEditorRowsUITests: XCTestCase {
    // The tests and helpers are @MainActor because XCUIApplication and
    // XCUIElement are main-actor isolated.

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - REMOVE

    /// The open editor shows REMOVE, a 44pt target under the exercise's
    /// name, which asks first: Keep exercise closes the question and keeps
    /// the exercise, and Remove removes it.
    @MainActor
    func testRemoveInTheOpenEditorAsksFirst() throws {
        let app = openEditor()
        let name = exerciseName(in: app)
        let exercise = name.label
        name.tap()
        let remove = removeControl(in: app)
        showInEditor(remove, in: app)
        UITestNavigation.saveScreenshot("T111", "editor-remove")
        try assertRemoveIsWhole(remove)
        XCTAssertGreaterThan(remove.frame.minY, name.frame.maxY, "REMOVE must sit in the open editor, under the name")
        XCTAssertEqual(remove.label, "Remove \(exercise)", "VoiceOver must name the exercise that REMOVE removes")

        remove.tap()
        let question = app.staticTexts.labeled("Remove \(exercise)?")
        XCTAssertTrue(question.waitForExistence(timeout: 5), "REMOVE must ask before it removes")
        UITestNavigation.saveScreenshot("T111", "remove-question")
        dialogButton("Keep exercise", in: app).tap()
        XCTAssertTrue(question.waitForNonExistence(timeout: 5), "Keep exercise must close the question")
        XCTAssertTrue(name.exists, "Keep exercise must keep \(exercise)")

        remove.tap()
        XCTAssertTrue(question.waitForExistence(timeout: 5), "REMOVE must ask again")
        dialogButton("Remove", in: app).tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5), "Remove must remove \(exercise)")
    }

    // MARK: - Navigation

    /// The session editor on the active-block seed's "Live Push", opened
    /// from its routine on Program.
    @MainActor
    private func openEditor(textSize: UITestNavigation.TextSize? = nil) -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock, textSize: textSize)
        UITestNavigation.selectTab("Program", in: app)
        let routine = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Live Routine")).firstMatch
        XCTAssertTrue(routine.exists || routine.waitForExistence(timeout: 10), "Program must list Live Routine")
        UITestNavigation.reveal(routine, in: app)
        routine.tap()
        let session = app.buttons["Session 1: Live Push"]
        XCTAssertTrue(session.exists || session.waitForExistence(timeout: 10), "Live Routine must list Live Push")
        UITestNavigation.reveal(session, in: app)
        session.tap()
        UITestNavigation.hittable(app.buttons, "Edit", exactLabel: true).tap()
        let save = app.buttons["Save session ▸"]
        XCTAssertTrue(save.exists || save.waitForExistence(timeout: 10), "Edit must open the session editor")
        return app
    }

    /// Drags the editor's list in its leading margin, clear of the rows'
    /// controls, until `element` sits inside the list and above the bottom
    /// bar, where a tap reaches it rather than DISCARD or SAVE SESSION.
    @MainActor
    private func showInEditor(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let list = (UITestNavigation.topSheet(in: app) ?? app).scrollViews.firstMatch.frame
        let top = list.minY + 4
        let bottom = min(list.maxY, app.buttons["Save session ▸"].frame.minY) - 4
        let start = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 8, dy: (top + bottom) / 2))
        for _ in 0..<12 {
            let frame = element.frame
            if frame.minY >= top && frame.maxY <= bottom { return }
            let distance = max(-400, min(400, (top + bottom) / 2 - frame.midY))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)),
                        withVelocity: .slow, thenHoldForDuration: 0.3)
        }
        XCTFail("\(element) must scroll into the editor's list, above its bottom bar", file: file, line: line)
    }

    // MARK: - Elements

    /// The first exercise's name, found by its identifier whatever its type.
    @MainActor
    private func exerciseName(in app: XCUIApplication) -> XCUIElement {
        let name = app.descendants(matching: .any).matching(identifier: "routine.exercise.name.1").firstMatch
        XCTAssertTrue(name.exists || name.waitForExistence(timeout: 10), "The editor must list its first exercise")
        return name
    }

    /// The first exercise's REMOVE control.
    @MainActor
    private func removeControl(in app: XCUIApplication) -> XCUIElement {
        let remove = app.buttons["routine.exercise.remove.1"]
        XCTAssertTrue(remove.exists || remove.waitForExistence(timeout: 10), "The open editor must show a REMOVE control")
        return remove
    }

    /// REMOVE is a 44pt target that draws its whole word.
    @MainActor
    private func assertRemoveIsWhole(_ remove: XCUIElement, file: StaticString = #filePath, line: UInt = #line) throws {
        UITestNavigation.assertTapTarget(remove, file: file, line: line)
        let shown = try UITestNavigation.readText(in: remove.frame, of: XCUIScreen.main.screenshot())
        XCTAssertTrue(shown.uppercased().contains("REMOVE"), "REMOVE must draw its whole word, but shows \"\(shown)\"",
                      file: file, line: line)
    }

    /// A button in the open question, labeled exactly `label`.
    @MainActor
    private func dialogButton(_ label: String, in app: XCUIApplication) -> XCUIElement {
        let button = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
        XCTAssertTrue(button.exists || button.waitForExistence(timeout: 5), "The question must offer \(label)")
        return button
    }
}
