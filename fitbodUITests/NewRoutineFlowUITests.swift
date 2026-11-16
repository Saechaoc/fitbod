import XCTest

/// Ticket T21, review item 15. "+ New routine" opens a name step, and no
/// routine exists until SAVE, so leaving the step keeps Program's first-run
/// screen. SAVE puts the routine's editor in the step's place, so Back from
/// the editor returns to where the user started. From New block's empty
/// routine picker, SAVE attaches the routine instead (RM-018).
final class NewRoutineFlowUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Repro

    /// Program → + NEW → + New routine → Back leaves no routine, and Program
    /// keeps its first-run screen.
    @MainActor
    func testBackFromProgramsNewRoutineLeavesNoRoutine() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Program", in: app)
        XCTAssertTrue(app.staticTexts.labeled("Start with a routine").waitForExistence(timeout: 10),
                      "Program must start on its first-run screen")
        UITestNavigation.hittable(app.buttons, "+ NEW", exactLabel: true).tap()
        UITestNavigation.hittable(app.buttons, "+ New routine", exactLabel: true).tap()
        UITestNavigation.hittable(app.buttons, "Back", exactLabel: true).tap()
        assertProgramHasNoRoutine(in: app)
    }

    // MARK: - Name step

    /// A typed name and SAVE open the routine's editor with that name in the
    /// name step's place, so Back from the editor goes straight to Program,
    /// which lists the routine instead of its first-run screen.
    @MainActor
    func testSaveOpensTheRoutineEditorAndProgramListsIt() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        openNameStepOnProgram(in: app)
        UITestNavigation.type("Upper Lower", into: nameField(in: app))
        saveButton(in: app).tap()
        assertEditorReplacedNameStep(named: "Upper Lower", in: app)

        UITestNavigation.hittable(app.buttons, "Back", exactLabel: true).tap()
        XCTAssertTrue(programRow("Upper Lower", in: app).waitForExistence(timeout: 10),
                      "Program must list the saved routine")
        XCTAssertFalse(nameStepTitle(in: app).exists, "Back from the editor must skip the name step")
        XCTAssertFalse(app.staticTexts.labeled("Start with a routine").exists,
                       "A saved routine must take the first-run screen's place")
    }

    // MARK: - From New block

    /// RM-018: with no routine, New block's picker offers + New routine.
    /// ‹ BACK from the name step makes nothing. SAVE returns to New block
    /// with its name and FIXED WEEKLY kept and the new routine attached,
    /// and SAVE DRAFT saves the block on that routine.
    @MainActor
    func testNewBlocksEmptyPickerMakesARoutineAndKeepsTheDraft() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.hittable(app.buttons, "+ NEW", exactLabel: true).tap()
        UITestNavigation.hittable(app.buttons, "+ New block", exactLabel: true).tap()
        UITestNavigation.hittable(app.buttons, "Blank Block").tap()
        let newBlock = app.staticTexts.labeled("NEW BLOCK")
        XCTAssertTrue(UITestNavigation.appears(newBlock), "New Block never opened")
        UITestNavigation.type("Spring Base", into: app.textFields.firstMatch)
        let fixedWeekly = app.buttons.labeled("FIXED WEEKLY scheduling")
        UITestNavigation.reveal(fixedWeekly, in: app)
        fixedWeekly.tap()

        UITestNavigation.revealAboveBottomBar(app.buttons, "+ ATTACH ▸", in: app).tap()
        let picker = app.staticTexts.labeled("Choose Routine")
        let noRoutines = app.staticTexts.labeled("No routines yet.")
        XCTAssertTrue(UITestNavigation.appears(noRoutines), "With no routine, the picker must say so")
        UITestNavigation.hittable(app.buttons, "+ New routine", exactLabel: true).tap()
        XCTAssertTrue(nameField(in: app).waitForExistence(timeout: 10), "+ New routine must open the name step")
        UITestNavigation.hittable(app.buttons, "Back", exactLabel: true).tap()
        XCTAssertTrue(UITestNavigation.appears(noRoutines), "‹ BACK must return to the picker with no routine made")

        UITestNavigation.hittable(app.buttons, "+ New routine", exactLabel: true).tap()
        UITestNavigation.type("Upper Lower", into: nameField(in: app))
        saveButton(in: app).tap()
        XCTAssertTrue(UITestNavigation.disappears(nameField(in: app)), "SAVE must close the name step")
        XCTAssertFalse(picker.exists, "SAVE must close the picker, not return to it")
        XCTAssertTrue(newBlock.exists, "SAVE must return to New block")
        XCTAssertEqual(app.textFields.firstMatch.value as? String, "Spring Base", "New block must keep its name")
        XCTAssertTrue(fixedWeekly.isSelected, "New block must keep FIXED WEEKLY")
        XCTAssertTrue(app.staticTexts.labeled("Upper Lower").exists, "New block must take the new routine")
        XCTAssertTrue(app.buttons.labeled("ROUTINE IS EMPTY").exists, "The bottom action must ask for the routine's sessions")

        UITestNavigation.hittable(app.buttons, "SAVE DRAFT", exactLabel: true).tap()
        XCTAssertTrue(UITestNavigation.disappears(newBlock), "SAVE DRAFT must close New Block")
        let row = programRow("Upper Lower", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Program must list the new routine")
        XCTAssertTrue(row.label.hasSuffix("used by Spring Base"), "The saved block must run the new routine, not \"\(row.label)\"")
    }

    // MARK: - Helpers

    /// Program → + NEW → + New routine, then saves `screenshot`, if named,
    /// and checks the name step.
    @MainActor
    private func openNameStepOnProgram(
        in app: XCUIApplication, textSize: UITestNavigation.TextSize = .default, screenshot: String? = nil,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.hittable(app.buttons, "+ NEW", exactLabel: true, file: file, line: line).tap()
        UITestNavigation.hittable(app.buttons, "+ New routine", exactLabel: true, file: file, line: line).tap()
        saveNameStepScreenshot(screenshot, textSize: textSize, in: app)
        assertNameStep(in: app, textSize: textSize, file: file, line: line)
    }

    /// Saves the name step once it has stopped moving in.
    @MainActor
    private func saveNameStepScreenshot(_ screen: String?, textSize: UITestNavigation.TextSize, in app: XCUIApplication) {
        guard let screen else { return }
        let field = nameField(in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 10), "+ New routine must open the name step")
        UITestNavigation.waitUntilStill(field)
        UITestNavigation.saveScreenshot("T21", screen, textSize: textSize)
    }

    /// The name step: ‹ BACK, New routine and SAVE in the header above a
    /// field that asks "Name your routine". At default text they share one
    /// row, left to right. At AX3 the title sits over ‹ BACK and SAVE, whose
    /// 44pt hit areas reach up beside it.
    @MainActor
    private func assertNameStep(
        in app: XCUIApplication, textSize: UITestNavigation.TextSize,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let title = nameStepTitle(in: app)
        XCTAssertTrue(title.waitForExistence(timeout: 10), "+ New routine must open the name step", file: file, line: line)
        let back = UITestNavigation.hittable(app.buttons, "Back", exactLabel: true, file: file, line: line)
        let save = saveButton(in: app)
        let field = nameField(in: app)
        XCTAssertTrue(save.exists, "The name step must offer SAVE", file: file, line: line)
        XCTAssertTrue(field.exists, "The name step must offer a name field", file: file, line: line)
        UITestNavigation.waitUntilStill(field)
        XCTAssertEqual(field.placeholderValue, "Name your routine", file: file, line: line)

        let window = app.windows.firstMatch
        for control in [back, title, save, field] {
            UITestNavigation.assertInside(control, window, file: file, line: line)
        }
        UITestNavigation.assertTapTarget(back, file: file, line: line)
        UITestNavigation.assertTapTarget(save, file: file, line: line)
        UITestNavigation.assertNoOverlap(back, save, file: file, line: line)
        UITestNavigation.assertNoOverlap(title, field, file: file, line: line)
        XCTAssertLessThan(back.frame.midX, save.frame.midX, "‹ BACK must sit left of SAVE", file: file, line: line)
        XCTAssertLessThanOrEqual(max(back.frame.midY, title.frame.maxY, save.frame.midY), field.frame.minY,
                                 "The header must sit above the name field", file: file, line: line)
        if textSize == .default {
            UITestNavigation.assertNoOverlap(back, title, file: file, line: line)
            UITestNavigation.assertNoOverlap(title, save, file: file, line: line)
            XCTAssertLessThan(back.frame.midX, title.frame.minX, "‹ BACK must sit left of the title", file: file, line: line)
            XCTAssertGreaterThan(save.frame.midX, title.frame.maxX, "SAVE must sit right of the title", file: file, line: line)
        } else {
            XCTAssertLessThanOrEqual(title.frame.maxY, min(back.frame.midY, save.frame.midY),
                                     "At AX3 the title must sit over ‹ BACK and SAVE", file: file, line: line)
        }
    }

    /// SAVE opened the routine's editor, which shows the saved name, and the
    /// name step is gone from under it.
    @MainActor
    private func assertEditorReplacedNameStep(
        named name: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) {
        let editorName = app.textFields.matching(NSPredicate(
            format: "label ==[c] %@ AND value == %@ AND identifier != %@", "Routine name", name, "newRoutine.name"
        )).firstMatch
        XCTAssertTrue(editorName.waitForExistence(timeout: 10), "SAVE must open the routine's editor named \(name)",
                      file: file, line: line)
        XCTAssertTrue(app.staticTexts.labeled("Routine").exists, "The routine's editor must show its header",
                      file: file, line: line)
        XCTAssertTrue(nameStepTitle(in: app).waitForNonExistence(timeout: 5),
                      "The routine's editor must take the name step's place", file: file, line: line)
        XCTAssertFalse(nameField(in: app).exists, "The name step's field must be gone", file: file, line: line)
    }

    /// Program shows its first-run screen and lists no routine, untitled or
    /// not. Every problem reports, so the repro names them all.
    @MainActor
    private func assertProgramHasNoRoutine(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        UITestNavigation.selectTab("Program", in: app)
        var problems: [String] = []
        if !app.staticTexts.labeled("Start with a routine").waitForExistence(timeout: 10) {
            problems.append("the first-run screen (Start with a routine and + NEW ROUTINE) is gone")
        }
        let untitled = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Untitled routine")).firstMatch
        if untitled.exists {
            problems.append("ROUTINES lists \"\(untitled.label)\"")
        }
        if app.staticTexts.labeled("Routines").exists {
            problems.append("Program shows a ROUTINES section")
        }
        XCTAssertEqual(problems, [], "Leaving + New routine without SAVE must create no routine", file: file, line: line)
    }

    @MainActor
    private func nameStepTitle(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.labeled("New routine")
    }

    @MainActor
    private func nameField(in app: XCUIApplication) -> XCUIElement {
        app.textFields["newRoutine.name"]
    }

    @MainActor
    private func saveButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.labeled("Save")
    }

    /// Program's ROUTINES row, read as "Upper Lower, 0 sessions".
    @MainActor
    private func programRow(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name + ",")).firstMatch
    }
}
