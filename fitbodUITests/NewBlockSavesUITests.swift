//
//  NewBlockSavesUITests.swift
//  fitbodUITests
//
//  Ticket T11, review item 36: New Block's two saves. The top action reads
//  SAVE DRAFT and needs only a name. The bottom action reads SAVE AS READY
//  once the block would be ready, and until then names the first missing
//  piece. EDIT BLOCK keeps one save, the bottom SAVE CHANGES.
//

import XCTest

final class NewBlockSavesUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Repro

    /// The review says the top SAVE saved a block without a name, but both
    /// saves called one save that needs a name. This records what a
    /// nameless tap does, then asks for a SAVE DRAFT that waits for a name.
    @MainActor
    func testNamelessTopSaveMakesNoBlock() throws {
        let app = openBlankNewBlock()
        let topSave = topSaveControl(in: app)
        let label = topSave.label
        let enabled = topSave.isEnabled
        topSave.tap()
        let closed = newBlockTitle(in: app).waitForNonExistence(timeout: 3)
        if !closed {
            hittable(app.buttons, "Cancel").tap()
            XCTAssertTrue(newBlockTitle(in: app).waitForNonExistence(timeout: 5),
                          "CANCEL must close an untouched New Block")
        }
        let blocks = blockCards(in: app).count
        record("Nameless top save: label \"\(label)\", enabled \(enabled), "
            + "New Block closed \(closed), blocks on Program \(blocks)")
        XCTAssertFalse(closed, "A nameless top save must not close New Block")
        XCTAssertEqual(blocks, 0, "A nameless top save must not make a block")
        XCTAssertEqual(label, "SAVE DRAFT", "The top action must say it saves a draft")
        XCTAssertFalse(enabled, "SAVE DRAFT must wait for a name")
    }

    /// With a name, the top action is SAVE DRAFT.
    @MainActor
    func testNamedBlockOffersSaveDraft() throws {
        let app = openBlankNewBlock()
        type("Spring Base", into: nameField(in: app))
        XCTAssertTrue(app.buttons.labeled("SAVE DRAFT").waitForExistence(timeout: 5),
                      "A named block must offer SAVE DRAFT; the top action reads \"\(topSaveControl(in: app).label)\"")
    }

    /// A name and phases are not enough to be ready: with no routine, the
    /// bottom action waits and asks for one.
    @MainActor
    func testBottomActionAsksForARoutine() throws {
        let app = openBlankNewBlock()
        type("Spring Base", into: nameField(in: app))
        let action = bottomAction(in: app)
        XCTAssertEqual(action.label, "PICK A ROUTINE", "The bottom action must name the missing routine")
        XCTAssertFalse(action.isEnabled, "The bottom action must wait for a routine")
    }

    // MARK: - Acceptance

    /// SAVE DRAFT saves a block with only a name, and Program lists it as a
    /// draft. Today's Start a block opens one with no phases, so the bottom
    /// action asks for a phase, and EDIT BLOCK's SAVE CHANGES still does.
    @MainActor
    func testSaveDraftSavesANameOnlyBlockAsADraft() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        openStartABlock(in: app)
        type("Name Only", into: nameField(in: app))
        expectBottomAction("ADD A PHASE", enabled: false, in: app)
        let saveDraft = app.buttons.labeled("SAVE DRAFT")
        XCTAssertTrue(saveDraft.isEnabled, "SAVE DRAFT needs only a name")
        UITestNavigation.assertTapTarget(saveDraft)
        UITestNavigation.saveScreenshot("T11", "new-block-name-only")
        saveDraft.tap()
        XCTAssertTrue(newBlockTitle(in: app).waitForNonExistence(timeout: 5), "SAVE DRAFT must close New Block")

        UITestNavigation.selectTab("Program", in: app)
        let card = app.buttons.labeled("DRAFT block: Name Only")
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Program must list the name-only block as a draft")
        UITestNavigation.saveScreenshot("T11", "program-name-only-draft")

        UITestNavigation.reveal(card, in: app)
        card.tap()
        hittable(app.buttons, "EDIT").tap()
        XCTAssertTrue(editBlockTitle(in: app).waitForExistence(timeout: 10), "EDIT must open EDIT BLOCK")
        expectBottomAction("ADD A PHASE", enabled: false, in: app)
        XCTAssertFalse(app.buttons.labeled("SAVE DRAFT").exists, "EDIT BLOCK has no SAVE DRAFT")
    }

    /// The bottom action names each missing piece, in order, as the block
    /// gains it; then SAVE AS READY saves a block Program lists as ready.
    /// The demo seed's Push A session fills the routine. Its workout is
    /// discarded first: its running clock keeps the app from idling, and
    /// Today offers Start a block only with no workout in progress.
    @MainActor
    func testBottomActionNamesEachMissingPieceThenSavesAsReady() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        discardWorkoutInProgress(in: app)
        let emptyRoutine = makeRoutine(adding: [], in: app)
        let routine = makeRoutine(adding: ["Push A", "Push A"], in: app)

        openStartABlock(in: app)
        type("", into: nameField(in: app))
        expectBottomAction("NAME FIRST", enabled: false, in: app)
        XCTAssertFalse(app.buttons.labeled("SAVE DRAFT").isEnabled, "SAVE DRAFT must wait for a name")
        UITestNavigation.saveScreenshot("T11", "new-block-name-first")

        type("Walk Block", into: nameField(in: app))
        expectBottomAction("ADD A PHASE", enabled: false, in: app)

        hittable(app.buttons, "+ ADD PHASE").tap()
        hittable(app.buttons, "Accumulation").tap()
        expectBottomAction("PICK A ROUTINE", enabled: false, in: app)
        UITestNavigation.saveScreenshot("T11", "new-block-pick-a-routine")

        pickRoutine(emptyRoutine, from: "+ ATTACH ▸", in: app)
        expectBottomAction("ROUTINE IS EMPTY", enabled: false, in: app)

        pickRoutine(routine, from: "SWAP ▸", in: app)
        expectBottomAction("SAVE AS READY", enabled: true, in: app)

        let fixedWeekly = app.buttons.labeled("FIXED WEEKLY scheduling")
        revealAboveBottomBar(fixedWeekly, in: app)
        fixedWeekly.tap()
        expectBottomAction("PICK 2 DAYS", enabled: false, in: app)
        UITestNavigation.saveScreenshot("T11", "new-block-pick-2-days")
        toggleDay("Monday", in: app)
        expectBottomAction("PICK 2 DAYS", enabled: false, in: app)
        toggleDay("Thursday", in: app)
        expectBottomAction("SAVE AS READY", enabled: true, in: app)
        UITestNavigation.saveScreenshot("T11", "new-block-save-as-ready")

        app.buttons.labeled("SAVE AS READY").tap()
        XCTAssertTrue(newBlockTitle(in: app).waitForNonExistence(timeout: 5), "SAVE AS READY must close New Block")
        UITestNavigation.selectTab("Program", in: app)
        XCTAssertTrue(app.buttons.labeled("READY block: Walk Block").waitForExistence(timeout: 10),
                      "Program must list the block as ready")
        UITestNavigation.saveScreenshot("T11", "program-ready-block")
    }

    /// EDIT BLOCK keeps one save: the bottom SAVE CHANGES.
    @MainActor
    func testEditBlockShowsOnlySaveChanges() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Program", in: app)
        // A template row opens a named block with phases.
        let template = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Hypertrophy Meso")).firstMatch
        UITestNavigation.reveal(template, in: app)
        template.tap()
        XCTAssertTrue(newBlockTitle(in: app).waitForExistence(timeout: 10), "New Block never opened")
        hittable(app.buttons, "SAVE DRAFT").tap()
        XCTAssertTrue(newBlockTitle(in: app).waitForNonExistence(timeout: 5), "SAVE DRAFT must close New Block")

        let card = app.buttons.labeled("DRAFT block: Hypertrophy Meso")
        UITestNavigation.reveal(card, in: app)
        card.tap()
        hittable(app.buttons, "EDIT").tap()
        XCTAssertTrue(editBlockTitle(in: app).waitForExistence(timeout: 10), "EDIT must open EDIT BLOCK")
        expectBottomAction("SAVE CHANGES", enabled: true, in: app)
        let saves = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "SAVE"))
            .allElementsBoundByIndex.filter(\.isHittable).map(\.label)
        XCTAssertEqual(saves, ["SAVE CHANGES"], "EDIT BLOCK must show only SAVE CHANGES")
        XCTAssertFalse(app.staticTexts.labeled("SAVE DRAFT").exists, "EDIT BLOCK must not show SAVE DRAFT")
        UITestNavigation.saveScreenshot("T11", "edit-block-save-changes")

        app.buttons.labeled("SAVE CHANGES").tap()
        XCTAssertTrue(editBlockTitle(in: app).waitForNonExistence(timeout: 5), "SAVE CHANGES must close EDIT BLOCK")
    }

    // MARK: - New Block

    /// Program → + NEW → + New block → Blank Block: three phases, no name.
    @MainActor
    private func openBlankNewBlock() -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Program", in: app)
        hittable(app.buttons, "+ NEW").tap()
        hittable(app.buttons, "+ New block").tap()
        hittable(app.buttons, "Blank Block").tap()
        XCTAssertTrue(newBlockTitle(in: app).waitForExistence(timeout: 10), "New Block never opened")
        return app
    }

    /// Today's resume slab discards the seeded workout; with no set logged
    /// it may not ask first.
    @MainActor
    private func discardWorkoutInProgress(in app: XCUIApplication) {
        UITestNavigation.selectTab("Today", in: app)
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10), "The demo seed must leave a workout in progress")
        app.buttons["resumeSlab.discard"].tap()
        let alert = app.alerts["Discard workout?"]
        if alert.waitForExistence(timeout: 2) {
            alert.buttons["Discard"].tap()
        }
        XCTAssertTrue(resume.waitForNonExistence(timeout: 5), "Discard must remove the workout in progress")
    }

    @MainActor
    private func newBlockTitle(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.labeled("NEW BLOCK")
    }

    @MainActor
    private func editBlockTitle(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.labeled("EDIT BLOCK")
    }

    /// Today's Start a block: New Block on the blank template, named
    /// "Blank Block" with no phases.
    @MainActor
    private func openStartABlock(in app: XCUIApplication) {
        UITestNavigation.selectTab("Today", in: app)
        let start = app.buttons.labeled("Start a block")
        UITestNavigation.reveal(start, in: app)
        start.tap()
        XCTAssertTrue(newBlockTitle(in: app).waitForExistence(timeout: 10), "Start a block must open New Block")
    }

    /// Waits until the bottom action reads `label`, then checks that it is
    /// the action beside CANCEL and whether it can be tapped.
    @MainActor
    private func expectBottomAction(
        _ label: String, enabled: Bool, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let action = app.buttons.labeled(label)
        XCTAssertTrue(action.waitForExistence(timeout: 5),
                      "The bottom action must read \(label), not \"\(bottomAction(in: app).label)\"",
                      file: file, line: line)
        let cancel = hittable(app.buttons, "Cancel", file: file, line: line).frame
        let frame = action.frame
        XCTAssertTrue(frame.minY < cancel.midY && frame.maxY > cancel.midY && frame.minX > cancel.maxX,
                      "\(label) must be the action beside CANCEL, at \(frame) with CANCEL at \(cancel)",
                      file: file, line: line)
        XCTAssertEqual(action.isEnabled, enabled,
                       "\(label) must be \(enabled ? "enabled" : "disabled")", file: file, line: line)
    }

    /// Opens the routine picker with `control` and picks `routine`.
    @MainActor
    private func pickRoutine(
        _ routine: String, from control: String, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let open = app.buttons.labeled(control)
        revealAboveBottomBar(open, in: app, file: file, line: line)
        open.tap()
        let picker = app.staticTexts.labeled("Choose Routine")
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "\(control) must open the routine picker", file: file, line: line)
        hittable(app.buttons, routine, file: file, line: line).tap()
        XCTAssertTrue(picker.waitForNonExistence(timeout: 5), "Picking \(routine) must close the routine picker",
                      file: file, line: line)
    }

    /// A fixed weekly day chip reads its weekday and reports "on" or "off".
    @MainActor
    private func toggleDay(_ weekday: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let day = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ AND (value == 'on' OR value == 'off')", weekday)).firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 5), "Missing the \(weekday) chip", file: file, line: line)
        revealAboveBottomBar(day, in: app, file: file, line: line)
        day.tap()
        let on = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'on'"), object: day)
        XCTAssertEqual(XCTWaiter().wait(for: [on], timeout: 3), .completed, "\(weekday) must turn on", file: file, line: line)
    }

    /// Scrolls New Block until `element` sits above its bottom bar. The bar
    /// covers the end of the scroll view, where a tap reaches the bar.
    @MainActor
    private func revealAboveBottomBar(
        _ element: XCUIElement, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        // The bar's 52pt buttons sit 24pt below its top edge; CANCEL's frame is its text.
        let barTop = hittable(app.buttons, "Cancel", file: file, line: line).frame.midY - 50
        for _ in 0..<8 {
            if element.exists && element.isHittable && element.frame.maxY < barTop { return }
            if let scroll = app.scrollViews.allElementsBoundByIndex.last(where: { $0.isHittable }) {
                scroll.swipeUp(velocity: .slow)
            } else {
                app.swipeUp(velocity: .slow)
            }
        }
        XCTAssertLessThan(element.frame.maxY, barTop, "\(element) must scroll above the bottom bar", file: file, line: line)
    }

    /// The builder's only text field. Its placeholder "NAME YOUR BLOCK" is
    /// a separate text.
    @MainActor
    private func nameField(in app: XCUIApplication) -> XCUIElement {
        app.textFields.firstMatch
    }

    /// The top-right save, whatever it reads. While the name is empty, no
    /// bottom label starts with SAVE.
    @MainActor
    private func topSaveControl(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let saves = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "SAVE"))
        XCTAssertTrue(saves.firstMatch.waitForExistence(timeout: 5), "New Block has no top save", file: file, line: line)
        return saves.allElementsBoundByIndex.min { $0.frame.minY < $1.frame.minY } ?? saves.firstMatch
    }

    /// The bottom bar's primary action: the tappable button to the right of
    /// CANCEL whose frame spans CANCEL's middle. Its frame is taller than
    /// CANCEL's, and the tab bar under New Block shares the band.
    @MainActor
    private func bottomAction(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let cancel = hittable(app.buttons, "Cancel", file: file, line: line).frame
        let action = app.buttons.allElementsBoundByIndex
            .filter { $0.frame.minY < cancel.midY && $0.frame.maxY > cancel.midY && $0.frame.minX > cancel.maxX }
            .filter(\.isHittable)
            .min { $0.frame.minX < $1.frame.minX }
        XCTAssertNotNil(action, "New Block has no action beside CANCEL", file: file, line: line)
        return action ?? app.buttons.labeled("Cancel")
    }

    // MARK: - Program

    /// Program's block cards, read as "DRAFT block: Spring Base".
    @MainActor
    private func blockCards(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH %@ OR label BEGINSWITH %@ OR label BEGINSWITH %@",
            "DRAFT block:", "READY block:", "ACTIVE block:"
        ))
    }

    /// Makes a routine on Program the way a user does, adds the named
    /// existing sessions in order, and returns the name "+ New routine"
    /// gives it, such as "Untitled routine 2".
    @MainActor
    private func makeRoutine(adding sessions: [String], in app: XCUIApplication) -> String {
        UITestNavigation.selectTab("Program", in: app)
        hittable(app.buttons, "+ NEW").tap()
        hittable(app.buttons, "+ New routine").tap()
        let field = app.descendants(matching: .any).matching(NSPredicate(
            format: "label ==[c] %@ AND value BEGINSWITH %@", "Routine name", "Untitled routine"
        )).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "+ New routine must open the new routine")
        let name = field.value as? String ?? ""

        let picker = app.staticTexts.labeled("Existing sessions")
        for session in sessions {
            hittable(app.buttons, "+ Add session").tap()
            XCTAssertTrue(picker.waitForExistence(timeout: 10), "+ Add session must list the existing sessions")
            hittable(app.buttons, session).tap()
            XCTAssertTrue(picker.waitForNonExistence(timeout: 5), "Adding \(session) must close the session picker")
        }
        hittable(app.buttons, "Back").tap()
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name + ",")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Program must list \(name)")
        XCTAssertTrue(row.label.contains("\(sessions.count) sessions"),
                      "\(name) must hold \(sessions.count) sessions: \(row.label)")
        return name
    }

    // MARK: - Input

    /// Replaces the field's text once it has keyboard focus, because
    /// `typeText` can drop the first character, then presses return to put
    /// the keyboard away.
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
        let value = field.value as? String ?? ""
        XCTAssertEqual(value == field.placeholderValue ? "" : value, text,
                       "The field must hold the typed text", file: file, line: line)
    }

    /// The match a user can tap: a sheet leaves same-named controls under it.
    @MainActor
    @discardableResult
    private func hittable(
        _ query: XCUIElementQuery, _ label: String,
        file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement {
        let matches = query.matching(NSPredicate(format: "label ==[c] %@ OR label BEGINSWITH[c] %@", label, label + ","))
        XCTAssertTrue(matches.firstMatch.waitForExistence(timeout: 10), "Missing \(label)", file: file, line: line)
        for _ in 0..<10 {
            if let match = matches.allElementsBoundByIndex.first(where: { $0.isHittable }) { return match }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTFail("No tappable \(label)", file: file, line: line)
        return matches.firstMatch
    }

    /// Keeps a note in the result bundle, even when the test passes.
    @MainActor
    private func record(_ note: String) {
        let attachment = XCTAttachment(string: note)
        attachment.name = "T11-note"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
