import XCTest

/// Ticket T21, review item 15. "+ New routine" on Program and on Today
/// opens one name step: ‹ BACK, New routine and SAVE over a field that asks
/// "Name your routine". SAVE stays muted and off until the trimmed name is
/// not empty, and no routine exists until SAVE, so leaving the step keeps
/// Program's first-run screen. SAVE puts the routine's editor in the step's
/// place, so Back from the editor returns to where the user started. With a
/// routine but no block, BLOCKS says "No blocks yet." and offers
/// + DEFINE BLOCK ▶, which opens New Block the way the first-run screen does.
final class NewRoutineFlowUITests: XCTestCase {

    /// bruMuted and bruSignalText in light mode: SAVE's label off and on.
    private static let muted = UITestNavigation.RGB(hex: 0x6E6A60)
    private static let signal = UITestNavigation.RGB(hex: 0xC03700)

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
        XCTAssertTrue(app.staticTexts.labeled("NO PROGRAM").waitForExistence(timeout: 10),
                      "Program must start on its first-run screen")
        UITestNavigation.hittable(app.buttons, "+ NEW", exactLabel: true).tap()
        UITestNavigation.hittable(app.buttons, "+ New routine", exactLabel: true).tap()
        UITestNavigation.hittable(app.buttons, "Back", exactLabel: true).tap()
        assertProgramHasNoRoutine(in: app)
    }

    /// Today → + New routine → Back leaves no routine either.
    @MainActor
    func testBackFromTodaysNewRoutineLeavesNoRoutine() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        let newRoutine = app.buttons.labeled("+ New routine")
        UITestNavigation.reveal(newRoutine, in: app)
        newRoutine.tap()
        UITestNavigation.hittable(app.buttons, "Back", exactLabel: true).tap()
        XCTAssertTrue(app.staticTexts.labeled("Build your first routine").waitForExistence(timeout: 10),
                      "Back must return to Today's Start a workout")
        assertProgramHasNoRoutine(in: app)
    }

    // MARK: - Name step

    /// SAVE stays muted and off for an empty name and for a name of only a
    /// space. A name turns it on in signal orange, and clearing the name
    /// turns it off again. Back then leaves no routine.
    @MainActor
    func testSaveStaysOffForAnEmptyOrBlankName() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        openNameStepOnProgram(in: app, screenshot: "name-step")
        let field = nameField(in: app)
        assertSave(isOn: false, "an empty name", in: app)

        UITestNavigation.type(" ", into: field, pressingReturn: false)
        assertSave(isOn: false, "a name of only a space", in: app)

        UITestNavigation.type("Upper Lower", into: field, pressingReturn: false)
        assertSave(isOn: true, "a name", in: app)
        UITestNavigation.saveScreenshot("T21", "name-step-named")

        UITestNavigation.type("", into: field, pressingReturn: false)
        assertSave(isOn: false, "a cleared name", in: app)

        UITestNavigation.hittable(app.buttons, "Back", exactLabel: true).tap()
        assertProgramHasNoRoutine(in: app)
    }

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
        XCTAssertFalse(app.staticTexts.labeled("NO PROGRAM").exists,
                       "A saved routine must take the first-run screen's place")
    }

    /// Today's + New routine opens the same name step, and Back from the
    /// editor SAVE opens returns to Today. Program lists the routine.
    @MainActor
    func testTodayOpensTheSameNameStep() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        openNameStepOnToday(in: app, screenshot: "name-step-from-today")
        assertSave(isOn: false, "an empty name", in: app)
        UITestNavigation.type("Full Body", into: nameField(in: app))
        saveButton(in: app).tap()
        assertEditorReplacedNameStep(named: "Full Body", in: app)

        UITestNavigation.hittable(app.buttons, "Back", exactLabel: true).tap()
        XCTAssertTrue(app.staticTexts.labeled("Start a workout").waitForExistence(timeout: 10),
                      "Back from the editor must return to Today")
        XCTAssertFalse(nameStepTitle(in: app).exists, "Back from the editor must skip the name step")
        UITestNavigation.selectTab("Program", in: app)
        XCTAssertTrue(programRow("Full Body", in: app).waitForExistence(timeout: 10),
                      "Program must list the routine saved on Today")
    }

    /// The edge swipe leaves no routine either, even with a name typed.
    /// Where the swipe does not go back yet, Back leaves instead and the
    /// test says so.
    @MainActor
    func testEdgeSwipeLeavesNoRoutine() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        openNameStepOnProgram(in: app)
        UITestNavigation.type("Upper Lower", into: nameField(in: app))
        UITestNavigation.swipeBack(in: app)
        if nameStepTitle(in: app).waitForNonExistence(timeout: 3) {
            record("The edge swipe left the name step")
        } else {
            record("The edge swipe did not leave the name step, so Back left it")
            UITestNavigation.hittable(app.buttons, "Back", exactLabel: true).tap()
        }
        assertProgramHasNoRoutine(in: app)
    }

    /// At AX3 the header stacks New routine over ‹ BACK and SAVE, each a
    /// whole tap target on screen, and the placeholder and a long name wrap
    /// inside the screen instead of ending in "…".
    @MainActor
    func testNameStepFitsAtAX3() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore, textSize: .ax3)
        openNameStepOnProgram(in: app, textSize: .ax3, screenshot: "name-step")
        assertSave(isOn: false, "an empty name", in: app)
        let field = nameField(in: app)
        assertShowsWhole("Name your routine", in: field, app: app)

        UITestNavigation.type("Upper Lower Twice a Week", into: field, pressingReturn: false)
        UITestNavigation.waitUntilStill(field)
        UITestNavigation.saveScreenshot("T21", "name-step-named", textSize: .ax3)
        assertSave(isOn: true, "a name", in: app)
        assertShowsWhole("Upper Lower Twice a Week", in: field, app: app)
    }

    // MARK: - BLOCKS before the first block

    /// With one routine and no block, BLOCKS says "No blocks yet." above
    /// + DEFINE BLOCK ▶, between its heading and ROUTINES. After a relaunch,
    /// at AX3, both stay whole on screen, and the action opens New Block the
    /// way the first-run screen's does: CREATE BLOCK, then Blank Block.
    @MainActor
    func testRoutineWithoutABlockOffersDefineBlock() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        openNameStepOnProgram(in: app)
        UITestNavigation.type("Upper Lower", into: nameField(in: app))
        saveButton(in: app).tap()
        assertEditorReplacedNameStep(named: "Upper Lower", in: app)
        UITestNavigation.hittable(app.buttons, "Back", exactLabel: true).tap()
        assertNoBlocksYet(in: app)
        UITestNavigation.saveScreenshot("T21", "blocks-empty")

        UITestNavigation.relaunch(app, textSize: .ax3)
        UITestNavigation.selectTab("Program", in: app)
        assertNoBlocksYet(in: app)
        UITestNavigation.saveScreenshot("T21", "blocks-empty", textSize: .ax3)

        defineBlock(in: app).tap()
        XCTAssertTrue(app.staticTexts.labeled("CREATE BLOCK").waitForExistence(timeout: 5),
                      "+ DEFINE BLOCK ▶ must open CREATE BLOCK, as the first-run screen's does")
        UITestNavigation.hittable(app.buttons, "Blank Block").tap()
        XCTAssertTrue(app.staticTexts.labeled("NEW BLOCK").waitForExistence(timeout: 10),
                      "+ DEFINE BLOCK ▶ must open New Block")
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

    /// Today → + New routine, then saves `screenshot`, if named, and checks
    /// the name step.
    @MainActor
    private func openNameStepOnToday(
        in app: XCUIApplication, screenshot: String? = nil, file: StaticString = #filePath, line: UInt = #line
    ) {
        UITestNavigation.selectTab("Today", in: app)
        let newRoutine = app.buttons.labeled("+ New routine")
        UITestNavigation.reveal(newRoutine, in: app)
        newRoutine.tap()
        saveNameStepScreenshot(screenshot, textSize: .default, in: app)
        assertNameStep(in: app, textSize: .default, file: file, line: line)
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

    /// The field shows `text` whole, read off a screenshot of its frame:
    /// XCUI reads a field's whole text even when the screen cuts it short.
    @MainActor
    private func assertShowsWhole(
        _ text: String, in field: XCUIElement, app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let screenshot = XCUIScreen.main.screenshot()
        let shown = (try? UITestNavigation.readText(in: field.frame.insetBy(dx: -2, dy: -2), of: screenshot)) ?? ""
        let letters = { (value: String) in String(value.uppercased().filter { $0.isLetter }) }
        XCTAssertTrue(letters(shown).contains(letters(text)) && !shown.contains("…") && !shown.contains("..."),
                      "The name field must show \"\(text)\" whole inside its frame \(field.frame), but it reads \"\(shown)\"",
                      file: file, line: line)
    }

    /// SAVE is on and reads in signal orange, or off, which VoiceOver reads
    /// as dimmed, and muted, with no orange.
    @MainActor
    private func assertSave(
        isOn: Bool, _ name: String, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let save = saveButton(in: app)
        XCTAssertTrue(save.waitForExistence(timeout: 5), "The name step must offer SAVE", file: file, line: line)
        XCTAssertEqual(save.isEnabled, isOn, "SAVE must be \(isOn ? "on" : "off") for \(name)", file: file, line: line)
        let screenshot = XCUIScreen.main.screenshot()
        let orange = pixelCount(of: Self.signal, in: save.frame, of: screenshot)
        if isOn {
            XCTAssertGreaterThan(orange, 0, "SAVE must read in signal orange for \(name)", file: file, line: line)
        } else {
            XCTAssertEqual(orange, 0, "SAVE must show no signal orange for \(name)", file: file, line: line)
            XCTAssertGreaterThan(pixelCount(of: Self.muted, in: save.frame, of: screenshot), 0,
                                 "SAVE must read muted for \(name)", file: file, line: line)
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
        if !app.staticTexts.labeled("NO PROGRAM").waitForExistence(timeout: 10) {
            problems.append("the first-run screen (NO PROGRAM, + DEFINE BLOCK ▶ and the templates) is gone")
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

    /// BLOCKS says "No blocks yet." above + DEFINE BLOCK ▶, both between its
    /// heading and ROUTINES, whole on screen, with no first-run screen.
    @MainActor
    private func assertNoBlocksYet(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let noBlocks = app.staticTexts.labeled("No blocks yet.")
        XCTAssertTrue(noBlocks.waitForExistence(timeout: 10), "BLOCKS must say No blocks yet.", file: file, line: line)
        let define = defineBlock(in: app)
        XCTAssertTrue(define.exists, "BLOCKS must offer + DEFINE BLOCK ▶", file: file, line: line)
        XCTAssertFalse(app.staticTexts.labeled("NO PROGRAM").exists,
                       "A routine must take the first-run screen's place", file: file, line: line)

        let blocksHead = app.staticTexts.labeled("Blocks")
        let routinesHead = app.staticTexts.labeled("Routines")
        XCTAssertTrue(blocksHead.exists && routinesHead.exists, "Program must show BLOCKS and ROUTINES", file: file, line: line)
        XCTAssertLessThanOrEqual(blocksHead.frame.maxY, noBlocks.frame.minY,
                                 "No blocks yet. must sit under BLOCKS", file: file, line: line)
        XCTAssertLessThanOrEqual(max(noBlocks.frame.maxY, define.frame.maxY), routinesHead.frame.minY,
                                 "BLOCKS' empty state must sit above ROUTINES", file: file, line: line)
        let window = app.windows.firstMatch
        UITestNavigation.assertInside(noBlocks, window, file: file, line: line)
        UITestNavigation.assertInside(define, window, file: file, line: line)
        UITestNavigation.assertNoOverlap(noBlocks, define, file: file, line: line)
        UITestNavigation.assertTapTarget(define, file: file, line: line)
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

    @MainActor
    private func defineBlock(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "+ DEFINE BLOCK")).firstMatch
    }

    /// The pixels inside `rect`, in screen points, within 24 of `color` on
    /// every channel.
    @MainActor
    private func pixelCount(of color: UITestNavigation.RGB, in rect: CGRect, of screenshot: XCUIScreenshot) -> Int {
        guard let crop = UITestNavigation.pixels(in: rect, of: screenshot) else { return 0 }
        return stride(from: 0, to: crop.bytes.count, by: 4).count(where: { byte in
            UITestNavigation.RGB(
                red: Int(crop.bytes[byte]), green: Int(crop.bytes[byte + 1]), blue: Int(crop.bytes[byte + 2])
            ).distance(to: color) <= 24
        })
    }

    /// Keeps a note in the result bundle, even when the test passes.
    @MainActor
    private func record(_ note: String) {
        let attachment = XCTAttachment(string: note)
        attachment.name = "T21-note"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
