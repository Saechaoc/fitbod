//
//  SessionEditorRowsUITests.swift
//  fitbodUITests
//
//  Ticket T111, findings F217, F219 and F220, in the session editor:
//
//  - T29 stopped an exercise's row from merging its parts, so its name was
//    plain text, and VoiceOver no longer said that a tap opens its editor.
//  - The rows' swipe actions never fired, because the rows sit in a stack,
//    not a List, so only the long-press menu, which nothing on screen
//    shows, could remove an exercise.
//  - The tempo fields were 40pt wide and 22pt tall on the small phone,
//    under the 44pt target.
//
//  Each test opens the active-block seed's "Live Push", which holds one
//  bench press, the way a user does: Program, Live Routine, its session,
//  then Edit.
//

import XCTest

final class SessionEditorRowsUITests: XCTestCase {
    // The tests and helpers are @MainActor because XCUIApplication and
    // XCUIElement are main-actor isolated.

    private static let tempoPlaceholders = ["Ecc", "Bot", "Con", "Top"]

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - The exercise's name

    /// VoiceOver reads the first exercise's name as a button, whose value
    /// says whether its editor is open, and a tap on it opens the editor.
    @MainActor
    func testNameIsAButtonThatSaysWhetherItsEditorIsOpen() throws {
        let app = openEditor()
        let name = exerciseName(in: app)
        XCTAssertEqual(name.elementType, .button, "VoiceOver must read the exercise's name as a button")
        XCTAssertEqual(name.value as? String, "Editor closed", "The name must say that its editor is closed")
        name.tap()
        let details = app.buttons["prescription.details"]
        XCTAssertTrue(details.exists || details.waitForExistence(timeout: 10), "A tap on the name must open its editor")
        XCTAssertEqual(name.value as? String, "Editor open", "The name must say that its editor is open")
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

    /// At AX3 the open editor's REMOVE still reads whole inside the screen,
    /// and stays a 44pt target.
    @MainActor
    func testRemoveFitsAtAX3() throws {
        let app = openEditor(textSize: .ax3)
        let name = exerciseName(in: app)
        showInEditor(name, in: app)
        name.tap()
        let remove = removeControl(in: app)
        showInEditor(remove, in: app)
        UITestNavigation.saveScreenshot("T111", "editor-remove", textSize: .ax3)
        UITestNavigation.assertInside(remove, app.windows.firstMatch)
        try assertRemoveIsWhole(remove)
    }

    // MARK: - Tempo

    /// With Track tempo on, each tempo field has a touch target at least
    /// 44pt square that covers no other target and neither switch beside
    /// it, and a tap at the top of a target, above the field's text,
    /// focuses that field.
    @MainActor
    func testTempoFieldsHave44PtTargets() throws {
        let app = openEditor()
        exerciseName(in: app).tap()
        let details = app.buttons["prescription.details"]
        XCTAssertTrue(details.exists || details.waitForExistence(timeout: 10), "A tap on the name must open its editor")
        showInEditor(details, in: app)
        details.tap()
        let trackTempo = toggle("Track tempo", in: app)
        let partialReps = toggle("Track partial reps", in: app)
        // The tempo row opens between these two switches.
        showInEditor(partialReps, in: app)
        trackTempo.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)).withOffset(CGVector(dx: -24, dy: 0)).tap()
        let on = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1"), object: trackTempo)
        XCTAssertEqual(XCTWaiter().wait(for: [on], timeout: 5), .completed, "Track tempo must turn on")

        let fields = Self.tempoPlaceholders.map {
            app.textFields.matching(NSPredicate(format: "placeholderValue == %@", $0)).firstMatch
        }
        XCTAssertTrue(fields[0].exists || fields[0].waitForExistence(timeout: 5), "Track tempo must show the tempo fields")
        UITestNavigation.saveScreenshot("T111", "editor-tempo")

        // Each frame is read once, because every read snapshots the app.
        let targets = fields.indices.map { tempoTarget(index: $0, field: fields[$0], in: app) }
        let frames = targets.map(\.frame)
        let switches = [("Track tempo", trackTempo.frame), ("Track partial reps", partialReps.frame)]
        var problems: [String] = []
        for (placeholder, frame) in zip(Self.tempoPlaceholders, frames) {
            if frame.width < 43.99 || frame.height < 43.99 {
                problems.append("The \(placeholder) field's target is \(frame.width) x \(frame.height)pt, under 44 x 44pt")
            }
            for (control, controlFrame) in switches where Self.overlap(frame, controlFrame) {
                problems.append("The \(placeholder) field's target covers \(control)")
            }
        }
        for later in frames.indices.dropFirst() {
            for earlier in frames.indices[..<later] where Self.overlap(frames[earlier], frames[later]) {
                problems.append("The \(Self.tempoPlaceholders[earlier]) and \(Self.tempoPlaceholders[later]) targets overlap")
            }
        }
        XCTAssertEqual(problems, [], "Each tempo field needs a 44pt target that covers no other control")

        for (field, target) in zip(fields, targets) {
            target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 0, dy: 2)).tap()
            let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)
            XCTAssertEqual(XCTWaiter().wait(for: [focused], timeout: 5), .completed,
                           "A tap at the top of the \(field.placeholderValue ?? "tempo") field's target must focus it")
        }
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

    @MainActor
    private func toggle(_ name: String, in app: XCUIApplication) -> XCUIElement {
        let toggle = app.switches.matching(NSPredicate(format: "label == %@", name)).firstMatch
        XCTAssertTrue(toggle.exists || toggle.waitForExistence(timeout: 10), "Missing \(name)")
        return toggle
    }

    /// A tempo field's touch target: the area around the field that its
    /// identifier names, or, where nothing reaches past the field, the
    /// field itself.
    @MainActor
    private func tempoTarget(index: Int, field: XCUIElement, in app: XCUIApplication) -> XCUIElement {
        let target = app.descendants(matching: .any).matching(identifier: "prescription.tempo.\(index + 1)").firstMatch
        return target.exists ? target : field
    }

    /// Whether two frames share more than the half point a common edge can
    /// round to.
    private static func overlap(_ a: CGRect, _ b: CGRect) -> Bool {
        let shared = a.intersection(b)
        return !shared.isNull && shared.width > 0.5 && shared.height > 0.5
    }
}
