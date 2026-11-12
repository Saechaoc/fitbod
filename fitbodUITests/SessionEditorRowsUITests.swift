//
//  SessionEditorRowsUITests.swift
//  fitbodUITests
//
//  Ticket T111, in the session editor: the rows' swipe actions never
//  fired, because the rows sit in a stack, not a List, so only the
//  long-press menu, which nothing on screen shows, could remove an
//  exercise.
//
//  The REMOVE test opens the active-block seed's "Live Push", which holds
//  one bench press, the way a user does: Program, Live Routine, its
//  session, then Edit. The superset test builds a new session of two lifts.
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

    // MARK: - Supersets (RM-002, RM-026)

    /// One trip pairs two lifts in a new session, the superset saves with
    /// the session and survives a relaunch, and Discard after an edit keeps
    /// it as saved.
    @MainActor
    func testOneTripSupersetSavesWithANewSessionAndDiscardKeepsIt() throws {
        let app = UITestNavigation.openEmptySessionBuilder()
        UITestNavigation.type("Superset Push", into: app.textFields["Session name"])
        addExercise("Bench Press (Incline Dumbbell)", in: app)
        addExercise("Push-Up (Incline)", in: app)

        openSuperset("Make superset…", in: app)
        let acting = app.staticTexts.matching(NSPredicate(
            format: "label ==[c] %@", "Long-pressed: Bench Press (Incline Dumbbell)"
        )).firstMatch
        XCTAssertTrue(acting.exists, "The sheet must name the long-pressed lift")
        let pair = app.buttons["superset.pair"]
        XCTAssertFalse(pair.isEnabled, "One lift is no superset")
        app.buttons["superset.lift.2"].tap()
        XCTAssertTrue(UITestNavigation.waitUntil { pair.isEnabled && pair.label == "Pair 2 lifts ▸" },
                      "Checking a partner must offer the pair")
        UITestNavigation.saveScreenshot("RM026", "superset-new-session")
        pair.tap()
        assertSuperset(true, "PAIR must group both lifts", in: app)
        UITestNavigation.hittable(app.buttons, "Save session ▸", exactLabel: true).tap()
        XCTAssertTrue(UITestNavigation.disappears(app.buttons["Save session ▸"]))

        UITestNavigation.relaunch(app)
        openEditor(in: app, routine: "Push Pull Legs", session: "Superset Push")
        assertSuperset(true, "The superset must save with the new session", in: app)
        pressFirstLift(in: app)
        UITestNavigation.hittable(app.buttons, "Remove from superset", exactLabel: true).tap()
        assertSuperset(false, "A partner left alone must leave the superset too", in: app)
        UITestNavigation.hittable(app.buttons, "Discard", exactLabel: true).tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts.labeled("Discard changes?")))
        UITestNavigation.hittable(app.buttons, "Discard", exactLabel: true).tap()
        XCTAssertTrue(UITestNavigation.disappears(app.buttons["Save session ▸"]))
        UITestNavigation.hittable(app.buttons, "Edit", exactLabel: true).tap()
        assertSuperset(true, "Discard must keep the saved superset", in: app)
        openSuperset("Edit superset…", in: app)
        XCTAssertTrue(app.buttons["superset.lift.2"].isSelected, "The sheet must check the saved partner")
    }

    /// Adds `name` from the library picker, found by search.
    @MainActor
    private func addExercise(_ name: String, in app: XCUIApplication) {
        UITestNavigation.hittable(app.buttons, "Add exercise").tap()
        let search = app.textFields["library.search.picker"]
        XCTAssertTrue(UITestNavigation.appears(search))
        UITestNavigation.type(name, into: search)
        let row = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH[c] %@", "exercise.pick.", name
        )).firstMatch
        XCTAssertTrue(UITestNavigation.appears(row), "The picker must find \(name)")
        row.tap()
        XCTAssertTrue(UITestNavigation.disappears(search), "Picking must close the picker")
    }

    @MainActor
    private func pressFirstLift(in app: XCUIApplication) {
        let exercise = exerciseName(in: app)
        UITestNavigation.reveal(exercise, in: app)
        exercise.press(forDuration: 1.1)
    }

    @MainActor
    private func openSuperset(_ action: String, in app: XCUIApplication) {
        pressFirstLift(in: app)
        UITestNavigation.hittable(app.buttons, action, exactLabel: true).tap()
        XCTAssertTrue(UITestNavigation.appears(app.buttons["superset.pair"]), "\(action) must open the superset sheet")
    }

    /// The first two lifts' numbers read "Superset" while they are paired.
    @MainActor
    private func assertSuperset(
        _ paired: Bool, _ message: String, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        for position in 1...2 {
            let number = app.descendants(matching: .any)
                .matching(identifier: "routine.exercise.number.\(position)").firstMatch
            let expected = paired ? "Superset" : String(format: "%02d", position)
            XCTAssertTrue(UITestNavigation.waitUntil { number.exists && number.label == expected },
                          "\(message): lift \(position) reads \"\(number.label)\"", file: file, line: line)
        }
    }

    // MARK: - Navigation

    /// The session editor, opened from its routine on Program: by default
    /// the active-block seed's "Live Push".
    @MainActor
    private func openEditor(textSize: UITestNavigation.TextSize? = nil) -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock, textSize: textSize)
        openEditor(in: app)
        return app
    }

    @MainActor
    private func openEditor(in app: XCUIApplication, routine routineName: String = "Live Routine", session sessionName: String = "Live Push") {
        UITestNavigation.selectTab("Program", in: app)
        let routine = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", routineName)).firstMatch
        XCTAssertTrue(routine.exists || routine.waitForExistence(timeout: 10), "Program must list \(routineName)")
        UITestNavigation.reveal(routine, in: app)
        routine.tap()
        let session = app.buttons["Session 1: \(sessionName)"]
        XCTAssertTrue(session.exists || session.waitForExistence(timeout: 10), "\(routineName) must list \(sessionName)")
        UITestNavigation.reveal(session, in: app)
        session.tap()
        UITestNavigation.hittable(app.buttons, "Edit", exactLabel: true).tap()
        let save = app.buttons["Save session ▸"]
        XCTAssertTrue(save.exists || save.waitForExistence(timeout: 10), "Edit must open the session editor")
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
