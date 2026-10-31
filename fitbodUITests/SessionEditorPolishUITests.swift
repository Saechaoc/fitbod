import XCTest

/// Ticket T29, review items 12, 13, 17 and 25, and T20's findings F145 and
/// F147. In the session editor each exercise row's number showed "•••",
/// its "⋮⋮" control looked like a drag handle but opened a menu, and the
/// row merged its children, so the menu's identifier repeated. Rest read
/// "180S", "3 min rest" and "180s". The three switches were the system's
/// green ones. At AX3 the set labels stayed tiny, "WORK" and
/// "+ ADD EXERCISE" broke mid-word, "Track partial reps" was cut and the
/// overrides count was clipped. "Archive this session?" had only a hidden
/// Cancel, and archiving skipped a routine that was archived itself.
///
/// Each test opens the progress-history seed's "Bench & Squat", which
/// holds the barbell bench press and the barbell squat, each resting 180
/// seconds, the way a user does: Today's + New routine, + Add session,
/// the routine's session, then Edit.
final class SessionEditorPolishUITests: XCTestCase {

    private static let session = "Bench & Squat"
    private static let routine = "Upper Lower"
    private static let bench = "Barbell Bench Press - Medium Grip"
    private static let squat = "Barbell Squat"

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Exercise rows

    /// The first row's number is drawn whole: its text is wider than the
    /// 28pt column that cut "01" to "•••".
    @MainActor
    func testExerciseNumberShowsInFull() throws {
        let app = openEditor()
        let number = editor(in: app).staticTexts.matching(NSPredicate(format: "label == %@", "01")).firstMatch
        XCTAssertTrue(number.waitForExistence(timeout: 10), "The first row must show its number")
        UITestNavigation.saveScreenshot("T29", "editor-rows")
        XCTAssertGreaterThan(number.frame.width, 28,
                             "The number at \(number.frame) must be wider than the 28pt column that cuts \"01\" to •••")
    }

    /// Each row has a MOVE control, a 44pt target that opens the reorder
    /// menu, whose Move up and Move down still reorder the rows.
    @MainActor
    func testMoveOpensTheReorderMenu() throws {
        let app = openEditor()
        for row in 1...2 {
            let move = moveControl(row: row, in: app)
            UITestNavigation.assertTapTarget(move)
            let shown = try drawnText(of: move)
            XCTAssertTrue(shown.contains("MOVE"), "Row \(row)'s control must read MOVE, but shows \"\(shown)\"")
        }
        UITestNavigation.saveScreenshot("T29", "move-controls")

        moveControl(row: 1, in: app).tap()
        let up = UITestNavigation.hittable(app.buttons, "Move up", exactLabel: true)
        XCTAssertFalse(up.isEnabled, "The first row cannot move up")
        UITestNavigation.saveScreenshot("T29", "move-menu")
        UITestNavigation.hittable(app.buttons, "Move down", exactLabel: true).tap()
        XCTAssertTrue(app.buttons.labeled("Move down").waitForNonExistence(timeout: 5), "Move down must close the menu")
        assertOrder([Self.squat, Self.bench], in: app)

        moveControl(row: 2, in: app).tap()
        UITestNavigation.hittable(app.buttons, "Move up", exactLabel: true).tap()
        XCTAssertTrue(app.buttons.labeled("Move up").waitForNonExistence(timeout: 5), "Move up must close the menu")
        assertOrder([Self.bench, Self.squat], in: app)
    }

    /// Each row's number, name, summary and MOVE control has its own
    /// identifier, which exactly one element matches, with the rows closed
    /// and with the first row open.
    @MainActor
    func testRowIdentifiersAreUnique() throws {
        let app = openEditor()
        let closed = identifierCounts(in: app)
        XCTAssertEqual(closed, closed.mapValues { _ in 1 }, "Each row identifier must match one element with the rows closed")
        expand(Self.bench, in: app)
        let open = identifierCounts(in: app)
        XCTAssertEqual(open, open.mapValues { _ in 1 }, "Each row identifier must match one element with the first row open")
    }

    // MARK: - Prescription details

    /// A 180-second rest reads "3:00" in the row's summary, the rest chip
    /// and the Rest stepper.
    @MainActor
    func testRestReadsAsMinutesAndSeconds() throws {
        let app = openEditor()
        let sheet = editor(in: app)
        var shown: [String: String] = [:]
        shown["summary"] = rowSummary(in: sheet)?.label
        expand(Self.bench, in: app)
        shown["chip"] = sheet.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", " rest"))
            .allElementsBoundByIndex.first(where: \.isHittable)?.label
        openDetails(in: app)
        let stepper = sheet.otherElements.matching(NSPredicate(format: "label == %@", "Rest")).firstMatch
        showInEditor(stepper, in: app)
        shown["stepper"] = stepper.value as? String
        UITestNavigation.saveScreenshot("T29", "rest-stepper")
        XCTAssertEqual(shown, ["summary": "barbell · 3×5–8 · 3:00", "chip": "3:00 rest", "stepper": "3:00"],
                       "A 180-second rest must read 3:00 everywhere")
    }

    /// Track tempo, Track partial reps and Auto warm-up, all on, draw the
    /// BRU signal track and never the system switch's green.
    @MainActor
    func testTogglesUseTheBRUStyle() throws {
        let app = openEditor()
        expand(Self.bench, in: app)
        openDetails(in: app)
        var problems: [String] = []
        for name in ["Track tempo", "Track partial reps", "Auto warm-up"] {
            let control = toggle(name, in: app)
            turnOn(control)
            let colors = trackColors(of: control)
            if let green = colors.first(where: Self.isSystemGreen) {
                problems.append("\(name) draws the system switch's green \(green)")
            }
            if !colors.contains(where: Self.isSignal) {
                problems.append("\(name) draws no BRU signal track, only \(Set(colors.map(\.description)).sorted())")
            }
            if name == "Track tempo" { UITestNavigation.saveScreenshot("T29", "track-tempo-on") }
        }
        UITestNavigation.saveScreenshot("T29", "toggles-on")
        XCTAssertEqual(problems, [], "Every switch must use the BRU toggle style")
    }

    // MARK: - Text sizes

    /// At the default text size every part of the editor is whole.
    @MainActor
    func testEditorAtDefaultText() throws {
        let app = openEditor()
        let problems = try tourEditor(in: app, textSize: .default)
        XCTAssertEqual(problems, [], "Every label in the editor must be whole at the default text size")
    }

    /// At AX3 the number, set labels, WORK, Track partial reps and
    /// + ADD EXERCISE are drawn whole, inside the
    /// screen, and the set labels grow with the text. The routine is made
    /// at the default size, then the app reopens at AX3.
    @MainActor
    func testEditorAtAX3() throws {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory)
        makeRoutineOnToday(in: app)
        UITestNavigation.relaunch(app, textSize: .ax3)
        UITestNavigation.selectTab("Today", in: app)
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", Self.session + ",")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Today must offer \(Self.session)")
        bringIntoView(row, between: 100, and: UITestNavigation.tab("Today", in: app).frame.minY - 8, in: app)
        row.tap()
        XCTAssertTrue(app.staticTexts.labeled("Session").waitForExistence(timeout: 10), "Today's row must open the session")
        openEditorFromSession(in: app)
        let problems = try tourEditor(in: app, textSize: .ax3)
        XCTAssertEqual(problems, [], "Every label in the editor must be whole at AX3")
    }

    // MARK: - Archive session

    /// "Archive this session?" offers a visible Keep session, which closes
    /// it and keeps the session: the editor stays open, and the routine's
    /// session picker, which leaves archived sessions out, still offers it.
    /// The session is first taken out of its routine, so nothing holds it.
    @MainActor
    func testKeepSessionClosesTheArchiveDialog() throws {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory)
        makeRoutineOnToday(in: app)
        openSessionDetail(in: app)

        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.hittable(app.buttons, Self.routine).tap()
        UITestNavigation.hittable(app.buttons, "Edit", exactLabel: true).tap()
        UITestNavigation.hittable(app.buttons, "Remove \(Self.session)", exactLabel: true).tap()
        UITestNavigation.hittable(app.buttons, "Remove Session", exactLabel: true).tap()
        XCTAssertTrue(app.buttons.labeled("Remove \(Self.session)").waitForNonExistence(timeout: 5),
                      "The routine must let go of \(Self.session)")

        UITestNavigation.selectTab("Today", in: app)
        openEditorFromSession(in: app)
        tapArchiveSession(in: app)
        let title = app.staticTexts.labeled("Archive this session?")
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Archive session must ask first")
        UITestNavigation.hittable(app.buttons, "Archive session", exactLabel: true)
        let keep = UITestNavigation.hittable(app.buttons, "Keep session", exactLabel: true)
        UITestNavigation.saveScreenshot("T29", "archive-dialog")
        keep.tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 5), "Keep session must close the dialog")
        XCTAssertEqual(app.textFields["Session name"].value as? String, Self.session,
                       "Keep session must leave the session open in the editor")

        UITestNavigation.hittable(app.buttons, "Back").tap()
        XCTAssertTrue(app.textFields["Session name"].waitForNonExistence(timeout: 5), "Back must close the unchanged editor")
        UITestNavigation.selectTab("Program", in: app)
        let picker = app.staticTexts.labeled("Existing sessions")
        UITestNavigation.hittable(app.buttons, "+ Add session").tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "+ Add session must list the existing sessions")
        UITestNavigation.hittable(app.buttons, Self.session)
    }

    /// A session whose routine is archived stays held by it: Archive session
    /// shows "Session is in use", naming the routine with "(archived)",
    /// instead of archiving the session into a routine that a restore
    /// would bring back with it.
    @MainActor
    func testAnArchivedRoutineStillHoldsTheSession() throws {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory)
        makeRoutineOnToday(in: app)
        openSessionDetail(in: app)

        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.hittable(app.buttons, Self.routine).tap()
        let archiveRoutine = app.buttons.labeled("Archive routine")
        UITestNavigation.reveal(archiveRoutine, in: app)
        archiveRoutine.tap()
        UITestNavigation.hittable(app.buttons, "Archive", exactLabel: true).tap()
        XCTAssertTrue(app.staticTexts.labeled("NO PROGRAM").waitForExistence(timeout: 10),
                      "Program must drop \(Self.routine), its only routine")

        UITestNavigation.selectTab("Today", in: app)
        openEditorFromSession(in: app)
        tapArchiveSession(in: app)
        let alert = app.alerts["Session is in use"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "An archived routine must still block archiving its session")
        XCTAssertFalse(app.staticTexts.labeled("Archive this session?").exists, "The block must come before the confirmation")
        let named = alert.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "\(Self.routine) (archived)")).firstMatch
        XCTAssertTrue(named.exists, "The alert must name \(Self.routine) as archived")
        UITestNavigation.saveScreenshot("T29", "archive-blocked")
        alert.buttons["OK"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5), "OK must close the alert")
        XCTAssertEqual(app.textFields["Session name"].value as? String, Self.session,
                       "A blocked archive must leave the session open")
    }

    // MARK: - Editor tour

    /// Walks the open editor from its rows to + ADD EXERCISE, saving a
    /// screenshot of each part, and returns every label it finds cut,
    /// clipped or broken mid-word.
    @MainActor
    private func tourEditor(in app: XCUIApplication, textSize: UITestNavigation.TextSize) throws -> [String] {
        var problems: [String] = []
        let window = app.windows.firstMatch
        let sheet = editor(in: app)
        let appearance = appearance(in: app)
        func shot(_ screen: String) {
            UITestNavigation.saveScreenshot("T29", screen, textSize: textSize, appearance: appearance)
        }
        func check(_ problem: String?) {
            if let problem { problems.append(problem) }
        }
        func expectDrawn(_ text: String, in element: XCUIElement) {
            do {
                let shown = try drawnText(of: element)
                if !shown.contains(text) { problems.append("\"\(text)\" is drawn as \"\(shown)\"") }
            } catch {
                problems.append("\"\(text)\" cannot be read: \(error)")
            }
        }

        // The rows: the number, the summary and the MOVE control.
        let number = sheet.staticTexts.matching(NSPredicate(format: "label == %@", "01")).firstMatch
        showInEditor(number, in: app)
        shot("editor-rows")
        let numberFrame = number.frame
        if numberFrame.width <= 28 || numberFrame.width < numberFrame.height * 0.75 {
            problems.append("The number 01 is cut to \(numberFrame.width) x \(numberFrame.height)pt, so it shows •••")
        }
        if let summary = rowSummary(in: sheet) {
            check(UITestNavigation.insideProblem(summary, window))
            expectDrawn("3:00", in: summary)
        } else {
            problems.append("The first row shows no summary")
        }
        let move = sheet.buttons.matching(NSPredicate(
            format: "identifier == %@ AND label BEGINSWITH %@", "routine.exercise.reorder.1", "Move"
        )).firstMatch
        if move.exists {
            showInEditor(move, in: app)
            check(UITestNavigation.insideProblem(move, window))
            check(UITestNavigation.tapTargetProblem(move))
        } else {
            problems.append("The first row has no MOVE control")
        }

        // The prescription: chips, then the set rows.
        expand(Self.bench, in: app)
        let restChip = sheet.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", " rest")).firstMatch
        showInEditor(restChip, in: app)
        for chip in [sheet.staticTexts.labeled("5–8 reps"), sheet.staticTexts.labeled("RPE —"), restChip] {
            check(UITestNavigation.insideProblem(chip, window))
        }
        let setLabel = sheet.staticTexts.labeled("S1")
        let work = sheet.staticTexts.labeled("WORK")
        showInEditor(work, in: app)
        shot("editor-sets")
        checkSetRow(setLabel, work, in: window, into: &problems)

        // The details: steppers, then the three switches with tempo on.
        openDetails(in: app)
        showInEditor(sheet.otherElements["prescription.sets"], in: app)
        shot("editor-steppers")
        let rest = sheet.otherElements.matching(NSPredicate(format: "label == %@", "Rest")).firstMatch
        showInEditor(rest, in: app)
        shot("editor-rest")
        check(UITestNavigation.insideProblem(rest, window))
        let tempo = toggle("Track tempo", in: app)
        turnOn(tempo)
        check(UITestNavigation.insideProblem(tempo, window))
        for placeholder in ["Ecc", "Bot", "Con", "Top"] {
            let field = sheet.textFields.matching(NSPredicate(format: "placeholderValue == %@", placeholder)).firstMatch
            showInEditor(field, in: app)
            check(UITestNavigation.insideProblem(field, window))
        }
        let partial = toggle("Track partial reps", in: app)
        check(UITestNavigation.insideProblem(partial, window))
        expectDrawn("TRACK PARTIAL REPS", in: partial)
        let warmup = toggle("Auto warm-up", in: app)
        shot("editor-toggles")
        check(UITestNavigation.insideProblem(warmup, window))

        // + ADD EXERCISE.
        let addExercise = sheet.buttons.labeled("Add exercise")
        showInEditor(addExercise, in: app)
        shot("editor-add-exercise")
        check(UITestNavigation.insideProblem(addExercise, window))
        check(UITestNavigation.tallerThanWideProblem(addExercise.staticTexts.labeled("Add exercise")))
        expectDrawn("ADD EXERCISE", in: addExercise)
        return problems
    }

    /// A set row's label and kind: inside the screen, WORK on one line,
    /// and the set label grown with the text like WORK beside it.
    @MainActor
    private func checkSetRow(_ setLabel: XCUIElement, _ kind: XCUIElement, in window: XCUIElement, into problems: inout [String]) {
        for element in [setLabel, kind] {
            if let problem = UITestNavigation.insideProblem(element, window) { problems.append(problem) }
        }
        if let problem = UITestNavigation.tallerThanWideProblem(kind) {
            problems.append(problem + ": WORK breaks mid-word")
        }
        if setLabel.frame.height < kind.frame.height * 0.8 {
            problems.append("\(setLabel.label) is \(setLabel.frame.height)pt tall beside WORK's \(kind.frame.height)pt: it must grow with the text")
        }
    }

    // MARK: - Navigation

    /// The session editor on "Bench & Squat", opened from its routine.
    @MainActor
    private func openEditor() -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory)
        makeRoutineOnToday(in: app)
        openSessionDetail(in: app)
        openEditorFromSession(in: app)
        return app
    }

    /// Today's + New routine makes "Upper Lower" holding the seeded
    /// session, and leaves the routine open on Today.
    @MainActor
    private func makeRoutineOnToday(in app: XCUIApplication) {
        UITestNavigation.selectTab("Today", in: app)
        UITestNavigation.hittable(app.buttons, "+ New routine").tap()
        UITestNavigation.type(Self.routine, into: app.textFields["newRoutine.name"])
        UITestNavigation.hittable(app.buttons, "Save", exactLabel: true).tap()
        XCTAssertTrue(app.textFields["newRoutine.name"].waitForNonExistence(timeout: 10), "SAVE must leave the name step")
        let picker = app.staticTexts.labeled("Existing sessions")
        UITestNavigation.hittable(app.buttons, "+ Add session").tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "+ Add session must list the existing sessions")
        UITestNavigation.hittable(app.buttons, Self.session).tap()
        XCTAssertTrue(picker.waitForNonExistence(timeout: 5), "Adding \(Self.session) must close the session picker")
    }

    /// Opens the session from its routine's screen.
    @MainActor
    private func openSessionDetail(in app: XCUIApplication) {
        UITestNavigation.hittable(app.buttons, "Session 1: \(Self.session)", exactLabel: true).tap()
        XCTAssertTrue(app.staticTexts.labeled("Session").waitForExistence(timeout: 10), "The routine's row must open the session")
    }

    /// From the session's screen, Edit opens the session editor.
    @MainActor
    private func openEditorFromSession(in app: XCUIApplication) {
        UITestNavigation.hittable(app.buttons, "Edit", exactLabel: true).tap()
        XCTAssertTrue(app.textFields["Session name"].waitForExistence(timeout: 10), "Edit must open the session editor")
    }

    /// The editor's sheet, so a query skips the session's screen under it,
    /// which lists the same exercises.
    @MainActor
    private func editor(in app: XCUIApplication) -> XCUIElement {
        var sheet = UITestNavigation.topSheet(in: app)
        // A menu or dialog that is closing still holds the top layer.
        for _ in 0..<8 where sheet == nil {
            Thread.sleep(forTimeInterval: 0.25)
            sheet = UITestNavigation.topSheet(in: app)
        }
        XCTAssertNotNil(sheet, "The session editor must be up as a sheet")
        return sheet ?? app
    }

    /// Opens an exercise's row with a tap on its name.
    @MainActor
    private func expand(_ name: String, in app: XCUIApplication) {
        let title = editor(in: app).staticTexts.matching(NSPredicate(format: "label == %@", name)).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10), "Missing \(name)")
        showInEditor(title, in: app)
        title.tap()
        XCTAssertTrue(app.buttons["prescription.details"].waitForExistence(timeout: 10), "\(name)'s row must open")
    }

    /// Opens EDIT PRESCRIPTION under the open row.
    @MainActor
    private func openDetails(in app: XCUIApplication) {
        let details = app.buttons["prescription.details"]
        showInEditor(details, in: app)
        details.tap()
        XCTAssertTrue(app.otherElements["prescription.sets"].waitForExistence(timeout: 10), "EDIT PRESCRIPTION must open")
    }

    /// Scrolls the editor until `element` sits in its list, below the
    /// header and above the bottom bar, where XCUITest would otherwise
    /// call it hittable and a tap would land on DISCARD or SAVE SESSION.
    @MainActor
    private func showInEditor(_ element: XCUIElement, in app: XCUIApplication) {
        let list = editor(in: app).scrollViews.firstMatch.frame
        let bar = app.buttons.labeled("Save session ▸").frame
        bringIntoView(element, between: list.minY + 4, and: min(list.maxY, bar.minY) - 4, in: app)
    }

    /// Drags the screen in its leading margin, clear of the rows' controls,
    /// until `element` sits between `top` and `bottom`, for at most 14
    /// drags. It does not fail: a label that never shows whole is a
    /// finding, and the check after it says so.
    @MainActor
    private func bringIntoView(_ element: XCUIElement, between top: CGFloat, and bottom: CGFloat, in app: XCUIApplication) {
        let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
        let middle = (top + bottom) / 2
        for _ in 0..<14 {
            // A lazy row appears once it nears the screen.
            var distance: CGFloat = -300
            if element.exists {
                let frame = element.frame
                if frame.minY >= top && frame.maxY <= bottom { return }
                if frame.height > bottom - top && frame.minY >= top && frame.minY <= top + 60 { return }
                distance = max(-300, min(300, middle - frame.midY))
                if abs(distance) < 8 { return }
            }
            let start = origin.withOffset(CGVector(dx: 8, dy: middle))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)),
                        withVelocity: .slow, thenHoldForDuration: 0.3)
        }
    }

    /// The editor's ••• menu, then Archive session.
    @MainActor
    private func tapArchiveSession(in app: XCUIApplication) {
        UITestNavigation.hittable(app.buttons, "More", exactLabel: true).tap()
        UITestNavigation.hittable(app.buttons, "Archive session", exactLabel: true).tap()
    }

    // MARK: - Rows

    /// Row `row`'s MOVE control, which VoiceOver reads as "Move exercise N".
    @MainActor
    private func moveControl(row: Int, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let move = app.buttons.matching(NSPredicate(
            format: "identifier == %@ AND label == %@", "routine.exercise.reorder.\(row)", "Move exercise \(row)"
        )).firstMatch
        XCTAssertTrue(move.waitForExistence(timeout: 10), "Row \(row) must have a MOVE control", file: file, line: line)
        showInEditor(move, in: app)
        return move
    }

    /// The first row's summary, such as "BARBELL · 3×5–8 · 3:00".
    @MainActor
    private func rowSummary(in sheet: XCUIElement) -> XCUIElement? {
        sheet.staticTexts.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "barbell ·"))
            .allElementsBoundByIndex.min { $0.frame.minY < $1.frame.minY }
    }

    @MainActor
    private func assertOrder(_ names: [String], in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        for (index, name) in names.enumerated() {
            let title = app.staticTexts["routine.exercise.name.\(index + 1)"]
            XCTAssertTrue(title.waitForExistence(timeout: 5), "Row \(index + 1) must show its name", file: file, line: line)
            for _ in 0..<10 where title.label != name {
                Thread.sleep(forTimeInterval: 0.25)
            }
            XCTAssertEqual(title.label, name, "Row \(index + 1) must be \(name)", file: file, line: line)
        }
    }

    /// How many elements carry each row identifier.
    @MainActor
    private func identifierCounts(in app: XCUIApplication) -> [String: Int] {
        var counts: [String: Int] = [:]
        for row in 1...2 {
            for part in ["number", "name", "summary", "reorder"] {
                let identifier = "routine.exercise.\(part).\(row)"
                counts[identifier] = app.descendants(matching: .any).matching(identifier: identifier).count
            }
        }
        return counts
    }

    // MARK: - Switches

    @MainActor
    private func toggle(_ name: String, in app: XCUIApplication) -> XCUIElement {
        let toggle = app.switches.matching(NSPredicate(format: "label == %@", name)).firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "Missing \(name)")
        showInEditor(toggle, in: app)
        return toggle
    }

    /// Turns a switch on with a tap near its row's trailing edge, where the
    /// system switch sits; the BRU style takes a tap anywhere on its row.
    @MainActor
    private func turnOn(_ toggle: XCUIElement) {
        guard toggle.value as? String != "1" else { return }
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)).withOffset(CGVector(dx: -24, dy: 0)).tap()
        for _ in 0..<10 where toggle.value as? String != "1" {
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTAssertEqual(toggle.value as? String, "1", "\(toggle.label) must turn on")
        // Let the track finish sliding.
        Thread.sleep(forTimeInterval: 0.5)
    }

    /// The colors across the trailing 60pt of a switch's row, at its middle,
    /// where the system switch and the BRU track both draw.
    @MainActor
    private func trackColors(of toggle: XCUIElement) -> [UITestNavigation.RGB] {
        let screenshot = XCUIScreen.main.screenshot()
        let frame = toggle.frame
        return stride(from: frame.maxX - 60, through: frame.maxX - 2, by: 2).compactMap {
            UITestNavigation.color(at: CGPoint(x: $0, y: frame.midY), in: screenshot)
        }
    }

    /// The system switch's green, #34C759, or #30D158 in dark mode: green
    /// leads red and blue by far.
    private static func isSystemGreen(_ color: UITestNavigation.RGB) -> Bool {
        color.green > 150 && color.green - color.red > 60 && color.green - color.blue > 50
    }

    /// bruSignal, #FF5C1A, or #FF7A3D in dark mode.
    private static func isSignal(_ color: UITestNavigation.RGB) -> Bool {
        [UITestNavigation.RGB(hex: 0xFF5C1A), UITestNavigation.RGB(hex: 0xFF7A3D)].contains { $0.distance(to: color) <= 24 }
    }

    // MARK: - Screenshots

    /// The text drawn in `element`'s frame, uppercased, with each run of
    /// spaces and line breaks as one space.
    @MainActor
    private func drawnText(of element: XCUIElement) throws -> String {
        let shown = try UITestNavigation.readText(in: element.frame.insetBy(dx: -2, dy: -2), of: XCUIScreen.main.screenshot())
        return shown.uppercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Light or dark, read from the editor's paper at the screen's left edge.
    @MainActor
    private func appearance(in app: XCUIApplication) -> UITestNavigation.Appearance {
        let paper = UITestNavigation.color(at: CGPoint(x: 3, y: app.frame.midY), in: XCUIScreen.main.screenshot())
        return paper.map { $0.distance(to: UITestNavigation.RGB(hex: 0x0A0A0A)) <= 24 } == true ? .dark : .light
    }
}
