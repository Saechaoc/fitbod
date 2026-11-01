//
//  SmallFixesUITests.swift
//  fitbodUITests
//
//  Ticket T38, review item 25 and findings F149, F182, F190, F192 and F193.
//  Small fixes on Program, New Block and Settings, read off the running app
//  on the 390pt phone:
//
//    - CHOOSE ROUTINE closes with a visible CANCEL in its header.
//    - New Block's CANCEL reads at 4.5:1 and its outline at 3:1, in the
//      run's appearance; run the suite in light and in dark mode.
//    - Volume Targets goes back with ‹ BACK, its rows say whether they are
//      open, and its rows leave the accessibility tree once it closes.
//    - The session editor's left header action reads CANCEL and still asks
//      before it discards an edit.
//    - ARCHIVED ROUTINES is one line in its header at default text.
//    - New Block's mode chips, day chips and sheet steppers are 44pt tap
//      targets, and neighbors' targets do not overlap.
//    - At AX3 a named block's name field shows the whole name, and the
//      chart's HIGH and LOW stay clear of its plotted lines.
//
//  Findings F100 and F102, routed to T38 from T73: New Block's UNDO read at
//  4.40:1 on the toast's faint fill, and the fixed-weekly mismatch hint at
//  2.14:1, amber on paper, in light mode. Both read at 4.5:1 in light mode,
//  and dark mode keeps its colors.
//

import XCTest

final class SmallFixesUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - CHOOSE ROUTINE

    /// + ATTACH opened CHOOSE ROUTINE with no close button, so a swipe was
    /// its only way out. Its header shows CANCEL, which closes it without
    /// choosing a routine.
    @MainActor
    func testChooseRoutineClosesWithCancel() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        openBlankNewBlock(in: app)
        UITestNavigation.revealAboveBottomBar(app.buttons, "+ ATTACH ▸", in: app).tap()
        let title = app.staticTexts.labeled("Choose Routine")
        XCTAssertTrue(title.waitForExistence(timeout: 10), "+ ATTACH must open CHOOSE ROUTINE")
        let routine = UITestNavigation.hittable(app.buttons, "Live Routine")
        UITestNavigation.waitUntilStill(routine)
        UITestNavigation.saveScreenshot("T38", "choose-routine", appearance: appearance)

        // New Block's own CANCEL waits under the sheet, at the bottom of the
        // screen; the sheet's sits in its header, above the routines.
        let cancels = app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Cancel")).allElementsBoundByIndex
        let cancel = try XCTUnwrap(
            cancels.first { $0.isHittable && $0.frame.midY < routine.frame.minY },
            "CHOOSE ROUTINE must show CANCEL in its header, above its routines"
        )
        let shown = UITestNavigation.latin(try UITestNavigation.readText(in: cancel.frame, of: XCUIScreen.main.screenshot()))
        XCTAssertTrue(shown.contains("CANCEL"), "The sheet's close control must read CANCEL, but reads \"\(shown)\"")

        cancel.tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 5), "CANCEL must close CHOOSE ROUTINE")
        XCTAssertTrue(app.staticTexts.labeled("None — saves as draft").exists, "CANCEL must choose no routine")
        XCTAssertTrue(app.staticTexts.labeled("NEW BLOCK").exists, "CANCEL must leave New Block open")
    }

    // MARK: - Contrast

    /// New Block's CANCEL read as a faint, low-contrast button: muted text
    /// and a hairline outline. In the run's appearance its text reads at
    /// 4.5:1 against the bar, and its outline at 3:1.
    @MainActor
    func testNewBlockCancelReadsAgainstItsBar() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        openBlankNewBlock(in: app)
        let cancel = UITestNavigation.hittable(app.buttons, "CANCEL", exactLabel: true)
        UITestNavigation.waitUntilStill(cancel)
        UITestNavigation.saveScreenshot("T38", "new-block-bar", appearance: appearance)
        let screenshot = XCUIScreen.main.screenshot()

        // The text sits in the middle of the pill, clear of its outline.
        let pill = cancel.frame
        let text = Contrast(in: pill.insetBy(dx: 12, dy: 14), of: screenshot)
        // The outline crosses a short strip over the pill's leading edge, at
        // its middle, where the edge runs straight up and down.
        let outline = Contrast(
            foregroundIn: CGRect(x: pill.minX - 2, y: pill.midY - 3, width: 4, height: 6),
            backgroundIn: CGRect(x: pill.minX - 10, y: pill.midY - 3, width: 20, height: 6),
            of: screenshot
        )
        XCTAssertEqual([
            contrastProblem(text, "CANCEL's text", atLeast: 4.5),
            contrastProblem(outline, "CANCEL's outline", atLeast: 3),
        ].compactMap { $0 }, [])
    }

    /// F100 and F102: in light mode New Block's UNDO read at 4.40:1 on the
    /// toast's faint fill, and the fixed-weekly mismatch hint, "0 days /
    /// 1 session", at 2.14:1, amber on paper. Both read at 4.5:1 in light
    /// mode. In dark mode, which already read, each keeps its colors.
    @MainActor
    func testUndoAndDayHintRead() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        openBlankNewBlock(in: app)
        let dark = appearance == .dark

        // The mismatch hint: FIXED WEEKLY with no day picked, then Live
        // Routine, whose one session the picked days do not match.
        UITestNavigation.revealAboveBottomBar(app.buttons, "FIXED WEEKLY scheduling", in: app).tap()
        UITestNavigation.revealAboveBottomBar(app.buttons, "+ ATTACH ▸", in: app).tap()
        let picker = app.staticTexts.labeled("Choose Routine")
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "+ ATTACH must open CHOOSE ROUTINE")
        UITestNavigation.hittable(app.buttons, "Live Routine").tap()
        XCTAssertTrue(picker.waitForNonExistence(timeout: 5), "Picking Live Routine must close CHOOSE ROUTINE")
        let hint = app.staticTexts.labeled("0 days / 1 session")
        XCTAssertTrue(hint.waitForExistence(timeout: 5), "No day for a one-session routine must show the mismatch hint")
        UITestNavigation.revealAboveBottomBar(hint, in: app, scroll: .dragInMargin)
        UITestNavigation.waitUntilStill(hint)
        UITestNavigation.saveScreenshot("T38", "day-hint", appearance: appearance)
        let hintContrast = Contrast(in: hint.frame, of: XCUIScreen.main.screenshot())

        // The undo toast: phase 1's revealed Delete deletes it.
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Phase 1:")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "New Block must show phase 1")
        UITestNavigation.revealAboveBottomBar(card, in: app, scroll: .dragInMargin)
        let start = card.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: card.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5)),
                    withVelocity: .slow, thenHoldForDuration: 0.1)
        UITestNavigation.hittable(app.buttons, "Delete", exactLabel: true).tap()
        // The toast leaves after four seconds, so it is read at once.
        let undo = UITestNavigation.hittable(app.buttons, "UNDO", exactLabel: true)
        UITestNavigation.waitUntilStill(undo, interval: 0.1, timeout: 1)
        UITestNavigation.saveScreenshot("T38", "undo-toast", appearance: appearance)
        let undoContrast = Contrast(in: undo.frame.insetBy(dx: 4, dy: 6), of: XCUIScreen.main.screenshot())

        if dark {
            XCTAssertEqual([
                colorProblem(undoContrast?.background, is: 0x222220, "The toast's fill, bruFaint"),
                colorProblem(undoContrast?.foreground, is: 0xFF7A3D, "UNDO, bruSignalText"),
                colorProblem(hintContrast?.background, is: 0x0A0A0A, "The hint's background, bruPaper"),
                colorProblem(hintContrast?.foreground, is: 0xFFB54D, "The hint, bruAmber"),
                contrastProblem(undoContrast, "UNDO", atLeast: 4.5),
                contrastProblem(hintContrast, "The mismatch hint", atLeast: 4.5),
            ].compactMap { $0 }, [], "In dark mode UNDO and the hint keep their colors")
        } else {
            XCTAssertEqual([
                contrastProblem(undoContrast, "UNDO", atLeast: 4.5),
                contrastProblem(hintContrast, "The mismatch hint", atLeast: 4.5),
            ].compactMap { $0 }, [])
        }
    }

    // MARK: - Volume Targets

    /// Volume Targets went back with a bare "‹", its rows gave no sign that
    /// a tap opens them, and after it closed, its muscle rows stayed in the
    /// accessibility tree for more than 12 seconds (F182). It goes back with
    /// ‹ BACK, each row says whether it is open, and the rows leave the tree
    /// within 2 seconds of ‹ BACK.
    @MainActor
    func testVolumeTargetsGoBackWithBackAndMarkTheirRows() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.openSettings(in: app)
        let entry = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Volume Targets")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "Settings must offer Volume Targets")
        UITestNavigation.reveal(entry, in: app)
        entry.tap()

        let row = firstMuscleRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Volume Targets must list the muscles")
        let back = UITestNavigation.hittable(app.buttons, "Back", exactLabel: true)
        UITestNavigation.waitUntilStill(back)
        UITestNavigation.saveScreenshot("T38", "volume-targets", appearance: appearance)
        let shown = UITestNavigation.latin(try UITestNavigation.readText(in: back.frame, of: XCUIScreen.main.screenshot()))
        var problems: [String] = []
        if !shown.contains("BACK") {
            problems.append("Volume Targets' back control must read ‹ BACK, but reads \"\(shown)\"")
        }
        if row.value as? String != "Collapsed" {
            problems.append("A closed row's value must be \"Collapsed\", but is \"\(row.value ?? "nil")\"")
        }
        row.tap()
        let expanded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Expanded"), object: row)
        if XCTWaiter().wait(for: [expanded], timeout: 3) != .completed {
            problems.append("An open row's value must be \"Expanded\", but is \"\(row.value ?? "nil")\"")
        }
        UITestNavigation.saveScreenshot("T38", "volume-targets-open", appearance: appearance)

        let muscle = row.label
        back.tap()
        if !row.waitForNonExistence(timeout: 2) {
            problems.append("\"\(muscle)\" must leave the accessibility tree within 2 seconds of ‹ BACK")
        }
        XCTAssertEqual(problems, [])
    }

    // MARK: - Session editor

    /// The session editor, a sheet, went back with ‹ BACK, a pushed
    /// screen's label. Opened from a routine's session, its left header
    /// action reads CANCEL, which still asks before it discards an edit.
    @MainActor
    func testSessionEditorClosesWithCancel() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.hittable(app.buttons, "Live Routine").tap()
        UITestNavigation.hittable(app.buttons, "Session 1: Live Push", exactLabel: true).tap()
        UITestNavigation.hittable(app.buttons, "Edit", exactLabel: true).tap()
        let title = app.staticTexts.labeled("Edit session")
        XCTAssertTrue(title.waitForExistence(timeout: 10), "Edit must open the session editor")
        UITestNavigation.waitUntilStill(title)
        UITestNavigation.saveScreenshot("T38", "session-editor", appearance: appearance)

        // The header's left action: the control left of the title, in its row.
        let left = app.buttons.allElementsBoundByIndex.filter {
            $0.isHittable && $0.frame.maxX <= title.frame.minX && abs($0.frame.midY - title.frame.midY) < 22
        }
        let action = try XCTUnwrap(left.first, "The session editor's header must have a left action")
        XCTAssertEqual(action.label.uppercased(), "CANCEL", "The session editor's left header action must read CANCEL")
        let shown = UITestNavigation.latin(try UITestNavigation.readText(in: action.frame, of: XCUIScreen.main.screenshot()))
        XCTAssertTrue(shown.contains("CANCEL"), "The left header action must show CANCEL, but shows \"\(shown)\"")

        // An edit: CANCEL asks first, and Discard closes the editor.
        let name = app.textFields["Session name"]
        UITestNavigation.type("Live Push B", into: name)
        action.tap()
        let dialog = app.staticTexts.labeled("Discard changes?")
        XCTAssertTrue(dialog.waitForExistence(timeout: 5), "CANCEL must ask before it discards an edit")
        UITestNavigation.hittable(app.buttons, "Discard", exactLabel: true).tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 5), "Discard must close the session editor")
    }

    // MARK: - Archived routines

    /// On the small phone at default text, ARCHIVED ROUTINES wrapped onto two
    /// lines in its header (F149). It shows whole on one line.
    @MainActor
    func testArchivedRoutinesTitleFitsOneLine() throws {
        // Live Block has ended, so Live Routine can be archived.
        let app = UITestNavigation.launch(UITestNavigation.endedBlockWithRecap)
        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.hittable(app.buttons, "Live Routine").tap()
        let archive = app.buttons.labeled("Archive routine")
        UITestNavigation.reveal(archive, in: app)
        archive.tap()
        UITestNavigation.hittable(app.buttons, "Archive", exactLabel: true).tap()

        let entry = app.buttons.labeled("Archived routines")
        UITestNavigation.reveal(entry, in: app)
        entry.tap()
        // Matches the title with a space or a no-break space between its words.
        let title = app.staticTexts.matching(NSPredicate(format: "label MATCHES[c] %@", "Archived.routines")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10), "The entry must open ARCHIVED ROUTINES")
        UITestNavigation.hittable(app.buttons, "Restore Live Routine", exactLabel: true)
        UITestNavigation.waitUntilStill(title)
        UITestNavigation.saveScreenshot("T38", "archived-routines", appearance: appearance)
        let screenshot = XCUIScreen.main.screenshot()

        let lines = try UITestNavigation.textLines(in: title.frame.insetBy(dx: -4, dy: -4), of: screenshot)
        XCTAssertEqual(inkedLines(in: title.frame, of: screenshot), 1,
                       "ARCHIVED ROUTINES must draw one line of text, and the screen reads \(lines.map(\.text))")
        XCTAssertEqual(lines.map { Self.letters($0.text) }.joined(), "ARCHIVEDROUTINES",
                       "ARCHIVED ROUTINES must show whole, and the screen reads \(lines.map(\.text))")
    }

    // MARK: - Tap targets

    /// At default text New Block's mode chips were about 22pt tall, its day
    /// chips 42 by 28pt and its sheet steppers 32 by 30pt (F193). Each is a
    /// 44pt tap target, and no two neighbors' targets overlap. A half-height
    /// sheet draws its content scaled down to its inset width, so a sheet's
    /// steppers are measured in the sheet's own points.
    @MainActor
    func testNewBlockChipsAndSheetSteppersAreTapTargets() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        openBlankNewBlock(in: app)

        // The sheets open from the top of the page, so they come first.
        let total = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Total weeks, ")).firstMatch
        XCTAssertTrue(total.waitForExistence(timeout: 5), "New Block must show TOTAL WEEKS")
        total.tap()
        let duration = app.staticTexts.labeled("Edit Block Duration")
        XCTAssertTrue(duration.waitForExistence(timeout: 5), "TOTAL WEEKS must open the duration sheet")
        var problems = sheetStepperProblems("The duration sheet", screenshot: "duration-sheet", in: app)
        UITestNavigation.hittable(app.buttons, "Done", exactLabel: true).tap()
        XCTAssertTrue(duration.waitForNonExistence(timeout: 5), "Done must close the duration sheet")

        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Phase 1:")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "New Block must show phase 1")
        UITestNavigation.revealAboveBottomBar(card, in: app, scroll: .dragInMargin)
        card.tap()
        let editor = app.staticTexts.labeled("% of training max")
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "A phase card must open its editor")
        problems += sheetStepperProblems("The phase editor", screenshot: "phase-editor", in: app)
        UITestNavigation.hittable(app.buttons, "Done", exactLabel: true).tap()
        XCTAssertTrue(editor.waitForNonExistence(timeout: 5), "Done must close the phase editor")

        let rotation = app.buttons.labeled("ROTATION scheduling")
        let fixedWeekly = UITestNavigation.revealAboveBottomBar(app.buttons, "FIXED WEEKLY scheduling", in: app)
        fixedWeekly.tap()
        // A day reads as a toggle, so it is found by its label alone.
        let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            .map { app.descendants(matching: .any).labeled($0) }
        UITestNavigation.revealAboveBottomBar(days[6], in: app, scroll: .dragInMargin)
        UITestNavigation.saveScreenshot("T38", "new-block-chips", appearance: appearance)

        problems += ([rotation, fixedWeekly] + days).map { UITestNavigation.tapTargetProblem($0) }
        problems.append(UITestNavigation.overlapProblem(rotation, fixedWeekly))
        problems += zip(days, days.dropFirst()).map { UITestNavigation.overlapProblem($0, $1) }
        XCTAssertEqual(problems.compactMap { $0 }, [])
    }

    // MARK: - AX3

    /// At AX3 Generic Strength Meso's name field cut the name off at
    /// "GENERIC STREN…" (F192). It shows each word of the name whole,
    /// wrapping between words.
    @MainActor
    func testNamedBlockShowsItsWholeNameAtAX3() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore, textSize: .ax3)
        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.hittable(app.buttons, "+ NEW").tap()
        UITestNavigation.hittable(app.buttons, "+ New block").tap()
        UITestNavigation.hittable(app.buttons, "Use Preset").tap()
        let preset = "GENERIC STRENGTH MESO"
        let row = app.buttons.matching(NSPredicate(
            format: "label ==[c] %@ OR label BEGINSWITH[c] %@", preset, preset + ","
        )).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "CHOOSE PRESET must list \(preset)")
        UITestNavigation.reveal(row, in: app)
        row.tap()
        XCTAssertTrue(app.staticTexts.labeled("NEW BLOCK").waitForExistence(timeout: 10), "New Block never opened")

        let name = "Generic Strength Meso"
        let field = app.descendants(matching: .any).matching(NSPredicate(format: "value == %@", name)).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "The preset must name the block \(name)")
        UITestNavigation.waitUntilStill(field)
        UITestNavigation.saveScreenshot("T38", "block-name", textSize: .ax3, appearance: appearance)

        // XCUI reads the whole value however the field cuts it off, so the
        // screen is read instead.
        let lines = try UITestNavigation.textLines(in: field.frame.insetBy(dx: -4, dy: -8), of: XCUIScreen.main.screenshot())
        let shown = lines.map { Self.letters($0.text) }
        // A word cut off or broken across lines shows whole on no line.
        let cut = name.uppercased().split(separator: " ").map(String.init).filter { word in !shown.contains { $0.contains(word) } }
        XCTAssertEqual(cut, [], "The name field must show each word of \(name) whole, and the screen reads \(lines.map(\.text))")
    }

    /// At AX3 the chart's LOW anchor sat under the intensity line's first
    /// point, and HIGH could sit on the volume line (F190). Both stay clear
    /// of every plotted line: they lie outside the plot, where the lines are
    /// drawn, and no line's ink falls inside either one.
    @MainActor
    func testChartAnchorsStayClearOfThePlottedLinesAtAX3() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore, textSize: .ax3)
        openBlankNewBlock(in: app)
        let matches = app.descendants(matching: .any).matching(identifier: "newBlock.progression.plot")
        XCTAssertTrue(matches.firstMatch.waitForExistence(timeout: 10), "New Block must show the progression chart")
        let plot = matches.firstMatch
        let anchors = ["HIGH", "LOW"].map { app.staticTexts.labeled($0) }
        UITestNavigation.revealAboveBottomBar(plot, in: app, scroll: .dragInMargin)
        UITestNavigation.waitUntilStill(plot)
        UITestNavigation.saveScreenshot("T38", "new-block-chart", textSize: .ax3, appearance: appearance)
        let screenshot = XCUIScreen.main.screenshot()

        var problems: [String] = []
        // HIGH's gridline lies 18% of the plot's height down from its top,
        // and LOW's 82%.
        for (anchor, fraction) in zip(anchors, [0.18, 0.82]) where anchor.exists {
            let lineY = plot.frame.minY + plot.frame.height * fraction
            if abs(anchor.frame.midY - lineY) > 2 {
                problems.append("\(anchor.label)'s middle is at y \(anchor.frame.midY), not level with its gridline at y \(lineY)")
            }
        }
        for anchor in anchors {
            guard anchor.exists else {
                problems.append("The chart must show its \(anchor) anchor")
                continue
            }
            let shared = anchor.frame.intersection(plot.frame)
            if !shared.isNull, shared.width > 0.5, shared.height > 0.5 {
                problems.append("\(anchor.label) at \(anchor.frame) lies on the plot at \(plot.frame), where the lines are drawn")
            }
            let ink = inkPixels(in: anchor.frame, of: screenshot)
            if ink > 0 {
                problems.append("\(ink) pixels of the intensity line's ink fall inside \(anchor.label) at \(anchor.frame)")
            }
        }
        XCTAssertEqual(problems, [])
    }

    // MARK: - Navigation

    /// Program → + NEW → + New block → Blank Block, once New Block has
    /// finished sliding up.
    @MainActor
    private func openBlankNewBlock(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.hittable(app.buttons, "+ NEW", file: file, line: line).tap()
        UITestNavigation.hittable(app.buttons, "+ New block", file: file, line: line).tap()
        UITestNavigation.hittable(app.buttons, "Blank Block", file: file, line: line).tap()
        let title = app.staticTexts.labeled("NEW BLOCK")
        XCTAssertTrue(title.waitForExistence(timeout: 10), "New Block never opened", file: file, line: line)
        UITestNavigation.waitUntilStill(UITestNavigation.hittable(app.buttons, "CANCEL", exactLabel: true, file: file, line: line))
    }

    /// Volume Targets' top row, read as its muscle and its MEV, MAV and MRV,
    /// such as "ABDOMINALS, 0 / 6 / 20".
    @MainActor
    private func firstMuscleRow(in app: XCUIApplication) -> XCUIElement {
        let rows = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "^[A-Z][A-Z ]*, [0-9]+ / [0-9]+ / [0-9]+$"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "Volume Targets must list its muscles")
        let label = rows.allElementsBoundByIndex.min { $0.frame.minY < $1.frame.minY }?.label ?? ""
        return app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    // MARK: - Sheets

    /// Each − and + stepper in the half-height sheet on top that is not a
    /// 44pt tap target in the sheet's own points. Saves a screenshot.
    @MainActor
    private func sheetStepperProblems(_ sheet: String, screenshot: String, in app: XCUIApplication) -> [String?] {
        let done = UITestNavigation.hittable(app.buttons, "Done", exactLabel: true)
        UITestNavigation.waitUntilStill(done)
        UITestNavigation.saveScreenshot("T38", screenshot, appearance: appearance)
        // A half-height sheet lays out at the window's width and draws inset,
        // so its width over the window's is the scale it draws at: 374 over
        // 390 on the small phone (T74).
        guard let container = UITestNavigation.topSheet(in: app) else { return ["\(sheet) must be the sheet on top"] }
        let scale = container.frame.width / app.windows.firstMatch.frame.width
        // New Block's own DAYS PER WEEK steppers may show above the sheet.
        let steppers = app.buttons.matching(NSPredicate(
            format: "(label IN %@ OR label BEGINSWITH %@ OR label BEGINSWITH %@) AND NOT (label ENDSWITH %@)",
            ["\u{2212}", "+"], "Decrease ", "Increase ", "days per week"
        )).allElementsBoundByIndex.filter(\.isHittable)
        guard !steppers.isEmpty else { return ["\(sheet) must show its steppers"] }
        return steppers.map { stepper in
            let size = CGSize(width: stepper.frame.width / scale, height: stepper.frame.height / scale)
            let measured = "\(sheet)'s \"\(stepper.label)\" is \(String(format: "%.1f x %.1f", size.width, size.height))pt "
                + "in the sheet's points (\(String(format: "%.1f x %.1f", stepper.frame.width, stepper.frame.height))pt on screen, "
                + "scale \(String(format: "%.3f", scale)))"
            XCTContext.runActivity(named: "Tap target: \(measured)") { _ in }
            guard size.width < 43.5 || size.height < 43.5 else { return nil }
            return "\(measured), under a 44pt tap target"
        }
    }

    // MARK: - Pixels

    /// The phone's appearance, which the run sets with `xcrun simctl ui`.
    @MainActor
    private var appearance: UITestNavigation.Appearance {
        XCUIDevice.shared.appearance == .dark ? .dark : .light
    }

    /// The number of text lines drawn in `rect`: runs of pixel rows that
    /// differ from the rect's commonest color, where a gap under 2pt stays
    /// inside one line.
    @MainActor
    private func inkedLines(in rect: CGRect, of screenshot: XCUIScreenshot) -> Int {
        guard let (pixels, bytes) = UITestNavigation.pixels(in: rect, of: screenshot) else { return 0 }
        let width = Int(pixels.width)
        let background = Self.commonest(in: bytes)
        let scale = screenshot.image.scale
        var lines = 0
        var gap = Int.max
        for y in 0..<Int(pixels.height) {
            let inked = (0..<width).contains { x in
                Self.rgb(bytes, at: (y * width + x) * 4).distance(to: background) > 60
            }
            if inked {
                if CGFloat(gap) >= 2 * scale { lines += 1 }
                gap = 0
            } else if gap != Int.max {
                gap += 1
            }
        }
        return lines
    }

    /// The pixels in `rect` that are the chart's ink, the intensity line's
    /// color, rather than an anchor's muted letters.
    @MainActor
    private func inkPixels(in rect: CGRect, of screenshot: XCUIScreenshot) -> Int {
        guard let bytes = UITestNavigation.pixels(in: rect, of: screenshot)?.bytes else { return 0 }
        let ink = appearance == .dark ? UITestNavigation.RGB(hex: 0xFAFAF7) : UITestNavigation.RGB(hex: 0x0A0A0A)
        return stride(from: 0, to: bytes.count, by: 4).filter { Self.rgb(bytes, at: $0).distance(to: ink) <= 40 }.count
    }

    @MainActor
    private func contrastProblem(_ contrast: Contrast?, _ text: String, atLeast minimum: Double) -> String? {
        guard let contrast else { return "\(text) is not on screen" }
        let measured = "\(text) is \(contrast.foreground) on \(contrast.background) in \(appearance) mode: "
            + "\(String(format: "%.2f", contrast.ratio)):1"
        XCTContext.runActivity(named: "Contrast: \(measured), needs \(String(format: "%.1f", minimum)):1") { _ in }
        return contrast.ratio >= minimum ? nil : "\(measured), below \(String(format: "%.1f", minimum)):1"
    }

    private func colorProblem(_ color: UITestNavigation.RGB?, is hex: UInt32, _ name: String) -> String? {
        let expected = UITestNavigation.RGB(hex: hex)
        guard let color else { return "\(name) is not on screen" }
        return color.distance(to: expected) <= 8 ? nil : "\(name) is \(color), not \(expected)"
    }

    fileprivate static func rgb(_ bytes: [UInt8], at offset: Int) -> UITestNavigation.RGB {
        UITestNavigation.RGB(red: Int(bytes[offset]), green: Int(bytes[offset + 1]), blue: Int(bytes[offset + 2]))
    }

    /// The commonest color in `bytes`, four to a pixel.
    fileprivate static func commonest(in bytes: [UInt8]) -> UITestNavigation.RGB {
        var counts: [UInt32: Int] = [:]
        for offset in stride(from: 0, to: bytes.count, by: 4) {
            counts[UInt32(bytes[offset]) << 16 | UInt32(bytes[offset + 1]) << 8 | UInt32(bytes[offset + 2]), default: 0] += 1
        }
        return UITestNavigation.RGB(hex: counts.max { $0.value < $1.value }?.key ?? 0)
    }

    /// Uppercased letters and digits only, with a "0" read as an "O".
    private static func letters(_ text: String) -> String {
        String(text.uppercased().filter { $0.isLetter || $0.isNumber }.map { $0 == "0" ? "O" : $0 })
    }
}

// MARK: - Contrast

/// A foreground color and the background behind it, read from a
/// screenshot, and their WCAG 2 contrast ratio.
private struct Contrast {
    let foreground: UITestNavigation.RGB
    let background: UITestNavigation.RGB

    /// From 1 to 21.
    var ratio: Double {
        let lighter = max(foreground.relativeLuminance, background.relativeLuminance)
        let darker = min(foreground.relativeLuminance, background.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Text in `region`, in screen points: the commonest color is the
    /// background between the glyphs, and the color whose luminance is
    /// farthest from it is the glyphs'. Nil when `region` is off the
    /// screenshot.
    @MainActor
    init?(in region: CGRect, of screenshot: XCUIScreenshot) {
        self.init(foregroundIn: region, backgroundIn: region, of: screenshot)
    }

    /// The commonest color in `backgroundRegion`, and the color in
    /// `foregroundRegion` whose luminance is farthest from it, such as a
    /// thin outline's.
    @MainActor
    init?(foregroundIn foregroundRegion: CGRect, backgroundIn backgroundRegion: CGRect, of screenshot: XCUIScreenshot) {
        guard let backgroundBytes = UITestNavigation.pixels(in: backgroundRegion, of: screenshot)?.bytes,
              let foregroundBytes = UITestNavigation.pixels(in: foregroundRegion, of: screenshot)?.bytes else { return nil }
        let background = SmallFixesUITests.commonest(in: backgroundBytes)
        let candidates = stride(from: 0, to: foregroundBytes.count, by: 4).map { SmallFixesUITests.rgb(foregroundBytes, at: $0) }
        self.background = background
        self.foreground = candidates.max {
            abs($0.relativeLuminance - background.relativeLuminance) < abs($1.relativeLuminance - background.relativeLuminance)
        } ?? background
    }
}

private extension UITestNavigation.RGB {
    /// WCAG 2 relative luminance, from 0 for black to 1 for white.
    var relativeLuminance: Double {
        func linear(_ channel: Int) -> Double {
            let value = Double(channel) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}
