//
//  BlockAndRoutineTextFitUITests.swift
//  fitbodUITests
//
//  Ticket T26, review items 37, 46 and 25, and findings F147, F148 and
//  F156. On the small phone, at default text and at AX3, no word breaks
//  inside itself on the block overview's hero, Program's block and routine
//  rows or the routine screen. Program's block row shows its phase once,
//  in "Week 1 of 5 · Accumulation", and its routine row keeps the block's
//  name tag on the screen. The routine screen keeps "01" and REMOVE on one
//  line, its Remove Session? dialog has a visible Keep session, a quick
//  swipe that starts on a session row scrolls the screen, a tap that opens
//  a session leaves its row full size, and a long press then a drag still
//  reorders.
//
//  XCUI reads a label whole even where the screen breaks it, so the words
//  are read from screenshots.
//

import XCTest

extension UITestNavigation {
    /// A fresh store plus the Powerbuilding seed (`PowerbuildingSeed`):
    /// "Upper Lower", three sessions of one exercise each, Upper A, Lower A
    /// and Upper B, on an active "Powerbuilding" block in week 1 of 5,
    /// accumulation, and a draft "Powerbuilding" with no routine.
    static let powerbuilding = [resetFlag, "-fitbod-seed-powerbuilding"]
}

final class BlockAndRoutineTextFitUITests: XCTestCase {

    /// The seeded routine's sessions, in order, each "1 exercise · 3 sets
    /// · ~11 min".
    private static let sessions = ["Upper A", "Lower A", "Upper B"]

    @MainActor
    override func setUpWithError() throws {
        // Every label gets checked, so one failure does not hide the rest.
        continueAfterFailure = true
    }

    // MARK: - Block overview hero

    /// The active block's hero reads "Accumulation week", and the draft's
    /// reads "Powerbuilding", each word whole: "Accumulatio" over "n week"
    /// and "Powerbuildin" over "g" before.
    @MainActor
    func testBlockHeroesKeepEachWordWhole() throws {
        try checkHeroes(textSize: .default)
    }

    /// At AX3 the heroes broke "Accumul" over "ation" and "Powerbu" over
    /// "ilding".
    @MainActor
    func testBlockHeroesKeepEachWordWholeAtAX3() throws {
        try checkHeroes(textSize: .ax3)
    }

    // MARK: - Program rows

    /// The block row shows its phase once, in "Week 1 of 5 · Accumulation",
    /// not also in a "W1 · ACCUMULATION" badge, and the routine row's
    /// POWERBUILDING tag stays whole on the screen.
    @MainActor
    func testProgramRowsShowThePhaseOnceAndKeepTheTag() throws {
        try checkProgramRows(textSize: .default)
    }

    /// At AX3 the badge broke "ACCUMULATI" over "ON", and the tag ran off
    /// the screen.
    @MainActor
    func testProgramRowsShowThePhaseOnceAndKeepTheTagAtAX3() throws {
        try checkProgramRows(textSize: .ax3)
    }

    // MARK: - Routine screen

    /// The meta line under the routine's name and each session row's
    /// number, name, summary and REMOVE stay whole.
    @MainActor
    func testRoutineScreenKeepsEachWordWhole() throws {
        try checkRoutineScreen(textSize: .default)
    }

    /// At AX3 the session rows broke "1 EXERCI" over "SE" and "REM" over
    /// "OVE", and wrapped "0" above "1".
    @MainActor
    func testRoutineScreenKeepsEachWordWholeAtAX3() throws {
        try checkRoutineScreen(textSize: .ax3)
    }

    // MARK: - Remove Session?

    /// Remove Session? offered only a cancel-role Cancel, which iOS 26
    /// hides. Its visible Keep session closes it and keeps the session.
    @MainActor
    func testKeepSessionClosesRemoveSessionAndKeepsTheSession() throws {
        let app = UITestNavigation.launch(UITestNavigation.powerbuilding)
        openRoutine(in: app)
        UITestNavigation.hittable(app.buttons, "Edit", exactLabel: true).tap()
        UITestNavigation.hittable(app.buttons, "Remove Upper A", exactLabel: true).tap()

        let title = app.staticTexts.labeled("Remove Session?")
        XCTAssertTrue(title.waitForExistence(timeout: 5), "REMOVE must ask first")
        UITestNavigation.hittable(app.buttons, "Remove Session", exactLabel: true)
        let keep = app.buttons.labeled("Keep session")
        let shown = keep.waitForExistence(timeout: 5) && keep.isHittable
        UITestNavigation.saveScreenshot("T26", "remove-session-dialog")
        XCTAssertTrue(shown, "Remove Session? must offer a visible Keep session")
        guard shown else { return }

        keep.tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 5), "Keep session must close the dialog")
        UITestNavigation.hittable(app.buttons, "Done", exactLabel: true).tap()
        for (index, name) in Self.sessions.enumerated() {
            XCTAssertTrue(app.buttons["Session \(index + 1): \(name)"].waitForExistence(timeout: 5),
                          "Keep session must keep \(name) in place \(index + 1)")
        }
        XCTAssertTrue(routineMeta(in: app).label.lowercased().hasPrefix("3 sessions"),
                      "The routine must still hold three sessions, but it reads \"\(routineMeta(in: app).label)\"")
    }

    // MARK: - Session rows

    /// At AX3 a press of under 0.1 s on a session row, then a drag up,
    /// scrolls the routine screen and starts no reorder: the row neither
    /// shrinks nor moves to another place.
    @MainActor
    func testQuickSwipeOnASessionRowScrollsAtAX3() throws {
        let app = UITestNavigation.launch(UITestNavigation.powerbuilding, textSize: .ax3)
        openRoutine(in: app)
        let window = app.windows.firstMatch
        let rows = Self.sessions.enumerated().map { app.buttons["Session \($0.offset + 1): \($0.element)"] }
        let top = routineScrollTop(in: app)
        let bottom = tabBarTop(in: app)

        // At AX3 the first row ends under the tab bar. A slow drag on the
        // routine's name label, clear of the rows' gesture, lifts it whole
        // above the tab bar; the extra 10pt covers the drag the page takes
        // before it starts to scroll.
        let lift = rows[0].frame.maxY - (bottom - 40)
        if lift > 0 {
            let from = app.staticTexts.labeled("Routine name").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            from.press(forDuration: 0.05, thenDragTo: from.withOffset(CGVector(dx: 0, dy: -(lift + 10))),
                       withVelocity: .slow, thenHoldForDuration: 0.3)
            UITestNavigation.waitUntilStill(rows[0])
        }

        // The lowest session row that sits whole on the screen, so the
        // swipe has room above it.
        guard let row = rows.last(where: { $0.exists && $0.frame.minY >= top && $0.frame.maxY <= bottom }) else {
            return XCTFail("No session row sits whole on the screen at AX3: \(rows.map(\.frame))")
        }
        let label = row.label
        let before = row.frame
        UITestNavigation.saveScreenshot("T26", "routine-before-swipe", textSize: .ax3)

        let start = row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let distance = min(250, before.midY - top - 20)
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -distance)),
                    withVelocity: .fast, thenHoldForDuration: 0.1)
        UITestNavigation.waitUntilStill(row)
        UITestNavigation.saveScreenshot("T26", "routine-after-swipe", textSize: .ax3)

        XCTAssertTrue(row.exists, "The swipe must leave \(label) in its place")
        let after = row.frame
        XCTAssertLessThan(after.minY, before.minY - 50,
                          "The swipe must scroll the routine screen: \(label) went from \(before) to \(after)")
        XCTAssertEqual(after.width, window.frame.width, accuracy: 0.5,
                       "No reorder may start: \(label) must stay full width, not \(after.width)pt")
    }

    /// A tap that opens a session, then ‹ BACK, leaves the session's row at
    /// the frame it had before the tap, not scaled to 97%.
    @MainActor
    func testOpeningASessionLeavesItsRowFullSize() throws {
        let app = UITestNavigation.launch(UITestNavigation.powerbuilding)
        openRoutine(in: app)
        let row = app.buttons["Session 1: Upper A"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The routine must list Upper A first")
        UITestNavigation.waitUntilStill(row)
        let before = row.frame

        row.tap()
        let sessionTitle = app.staticTexts.labeled("Session")
        XCTAssertTrue(sessionTitle.waitForExistence(timeout: 10), "The row must open Upper A")
        UITestNavigation.hittable(app.buttons, "Back").tap()
        XCTAssertTrue(sessionTitle.waitForNonExistence(timeout: 10), "‹ BACK must close the session")
        UITestNavigation.waitUntilStill(row)
        UITestNavigation.saveScreenshot("T26", "routine-after-back")

        let after = row.frame
        for (part, was, now) in [
            ("x", before.minX, after.minX), ("y", before.minY, after.minY),
            ("width", before.width, after.width), ("height", before.height, after.height),
        ] {
            XCTAssertEqual(now, was, accuracy: 0.5, "Upper A's row \(part) must match its frame before the tap, \(before), not \(after)")
        }
    }

    /// A long press, then a drag down one row, still reorders: Upper A
    /// moves to the second place without opening, and its row is full size
    /// again once dropped. A second drag on the moved row, now second, takes
    /// it to the third place, so the row reorders from its new place.
    @MainActor
    func testLongPressThenDragStillReordersASession() throws {
        let app = UITestNavigation.launch(UITestNavigation.powerbuilding)
        openRoutine(in: app)
        let window = app.windows.firstMatch
        let row = app.buttons["Session 1: Upper A"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The routine must list Upper A first")
        UITestNavigation.waitUntilStill(row)

        let start = row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.8, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 75)),
                    withVelocity: .slow, thenHoldForDuration: 0.3)

        let moved = app.buttons["Session 2: Upper A"]
        XCTAssertTrue(moved.waitForExistence(timeout: 5), "A long press and a drag must move Upper A down one place")
        XCTAssertTrue(app.buttons["Session 1: Lower A"].exists, "Lower A must move up to the first place")
        XCTAssertFalse(app.staticTexts.labeled("Session").exists, "A reorder must not open the session")
        UITestNavigation.waitUntilStill(moved)
        UITestNavigation.saveScreenshot("T26", "routine-after-reorder")
        XCTAssertEqual(moved.frame.width, window.frame.width, accuracy: 0.5,
                       "The dropped row must be full size again, not \(moved.frame.width)pt")

        let again = moved.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        again.press(forDuration: 0.8, thenDragTo: again.withOffset(CGVector(dx: 0, dy: 75)),
                    withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertTrue(app.buttons["Session 3: Upper A"].waitForExistence(timeout: 5),
                      "A second drag must move Upper A from the second place to the third")
        XCTAssertTrue(app.buttons["Session 2: Upper B"].exists, "Upper B must move up to the second place")
    }

    // MARK: - Checks

    @MainActor
    private func checkHeroes(textSize: UITestNavigation.TextSize) throws {
        let app = UITestNavigation.launch(UITestNavigation.powerbuilding, textSize: textSize)

        openBlock("ACTIVE block: Powerbuilding", in: app)
        UITestNavigation.saveScreenshot("T26", "hero-active", textSize: textSize)
        try assertWordsWhole(["ACCUMULATION"], drawnIn: hero(in: app), "The active block's hero")

        // The hero's last row, "W1 / 5 · VOL HOLD · INT 100%", keeps its
        // words too. At AX3 it starts under the bottom bar, so a slow drag
        // inside the hero brings it up first.
        let barTop = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Edit block")).firstMatch.frame.minY
        let activeHero = hero(in: app)
        let overflow = activeHero.frame.maxY - (barTop - 8)
        if overflow > 0 {
            let from = app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: app.frame.width - 8, dy: min(activeHero.frame.maxY, barTop) - 30))
            from.press(forDuration: 0.05, thenDragTo: from.withOffset(CGVector(dx: 0, dy: -overflow)),
                       withVelocity: .slow, thenHoldForDuration: 0.3)
            UITestNavigation.waitUntilStill(activeHero)
        }
        UITestNavigation.saveScreenshot("T26", "hero-active-stats", textSize: textSize)
        try assertWordsWhole(["W1", "VOL", "HOLD", "INT", "1OO"], drawnIn: activeHero, "The active block's hero stats",
                             above: barTop)
        UITestNavigation.hittable(app.buttons, "Back").tap()

        openBlock("DRAFT block: Powerbuilding", in: app)
        UITestNavigation.saveScreenshot("T26", "hero-draft", textSize: textSize)
        try assertWordsWhole(["POWERBUILDING"], drawnIn: hero(in: app), "The draft block's hero")
    }

    @MainActor
    private func checkProgramRows(textSize: UITestNavigation.TextSize) throws {
        let app = UITestNavigation.launch(UITestNavigation.powerbuilding, textSize: textSize)
        UITestNavigation.selectTab("Program", in: app)
        let window = app.windows.firstMatch
        let top = app.buttons.labeled("+ NEW").frame.maxY

        let block = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "ACTIVE block: Powerbuilding")).firstMatch
        XCTAssertTrue(block.waitForExistence(timeout: 10), "Program must list the active Powerbuilding")
        bringIntoView(block, below: top, in: app)
        UITestNavigation.saveScreenshot("T26", "program-blocks", textSize: textSize)
        let blockLines = try drawnLines(in: block, "the block row")
        let phaseLines = blockLines.filter { $0.contains("ACCUM") }
        XCTAssertEqual(phaseLines.count, 1, "The block row must show its phase in one place, but it reads \(blockLines)")
        XCTAssertTrue(phaseLines.allSatisfy { $0.contains("ACCUMULATION") },
                      "The block row must draw ACCUMULATION whole, but it reads \(blockLines)")
        XCTAssertTrue(blockLines.contains { $0.contains("WEEK1OF5") },
                      "The block row must read \"Week 1 of 5\", but it reads \(blockLines)")
        UITestNavigation.assertInside(block, window)

        let routine = routineRow(in: app)
        XCTAssertTrue(routine.waitForExistence(timeout: 10), "Program must list Upper Lower")
        bringIntoView(routine, below: top, in: app)
        UITestNavigation.saveScreenshot("T26", "program-routines", textSize: textSize)
        let lines = try UITestNavigation.textLines(in: routine.frame, of: XCUIScreen.main.screenshot())
        record("T26-program-routine-lines-\(textSize.rawValue)", lines.map(\.text).joined(separator: " | "))
        guard let tag = lines.first(where: { Self.letters($0.text).contains("POWERBUIL") }) else {
            return XCTFail("The routine row must show its POWERBUILDING tag, but it reads \(lines.map(\.text))")
        }
        XCTAssertTrue(Self.letters(tag.text).contains("POWERBUILDING"),
                      "The routine row must draw its POWERBUILDING tag whole, but it reads \(lines.map(\.text))")
        // The chip's border and padding sit around its text, inside the screen.
        XCTAssertTrue(window.frame.insetBy(dx: 6, dy: 0).contains(tag.box),
                      "The POWERBUILDING tag at \(tag.box) must lie inside the screen, \(window.frame)")
    }

    @MainActor
    private func checkRoutineScreen(textSize: UITestNavigation.TextSize) throws {
        let app = UITestNavigation.launch(UITestNavigation.powerbuilding, textSize: textSize)
        openRoutine(in: app)
        let window = app.windows.firstMatch
        UITestNavigation.saveScreenshot("T26", "routine", textSize: textSize)

        try assertWordsWhole(["SESSIONS", "ROTATES", "ORDER"], drawnIn: routineMeta(in: app), "The routine's meta line")
        // At default text every session row is on the screen.
        if textSize == .default {
            for (index, name) in Self.sessions.enumerated() {
                let row = app.buttons["Session \(index + 1): \(name)"]
                try assertWordsWhole(["EXERCISE", "SETS"], drawnIn: row, "\(name)'s row")
            }
        }

        // Edit shows each row's number, name, summary and controls, and
        // turns off the reorder drag, so the page scrolls freely.
        UITestNavigation.hittable(app.buttons, "Edit", exactLabel: true).tap()
        let top = routineScrollTop(in: app)
        // One line of the label font REMOVE uses.
        let lineHeight = app.staticTexts.labeled("Routine name").frame.height
        let summaries = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "1 exercise"))
        var savedEditScreenshot = false
        for (index, name) in Self.sessions.enumerated() {
            let number = app.staticTexts[String(format: "%02d", index + 1)]
            let remove = app.buttons.labeled("Remove \(name)")
            let row = app.descendants(matching: .any).matching(NSPredicate(
                format: "label ==[c] %@", "Session \(index + 1): \(name)"
            )).firstMatch
            XCTAssertTrue(remove.waitForExistence(timeout: 10), "Edit must show REMOVE on \(name)")
            bringIntoView(row, below: top, in: app)
            if !savedEditScreenshot {
                UITestNavigation.saveScreenshot("T26", "routine-edit", textSize: textSize)
                savedEditScreenshot = true
            }

            // On one line "01" is about as wide as it is tall; wrapped, it
            // is one digit wide and two lines tall.
            XCTAssertTrue(number.exists, "Edit must show \(name)'s number")
            XCTAssertGreaterThan(number.frame.width, number.frame.height / 2,
                                 "\"\(number.label)\" at \(number.frame) must be one line, not one digit over the other")
            UITestNavigation.assertInside(number, window)
            UITestNavigation.assertHeight(remove, atMost: max(44, lineHeight) + 1)
            UITestNavigation.assertTapTarget(remove)
            UITestNavigation.assertInside(remove, window)
            try assertWordsWhole(["REMOVE"], drawnIn: remove, "\(name)'s REMOVE")
            let title = app.staticTexts[name]
            try assertWordsWhole(name.split(separator: " ").map { Self.letters(String($0)) }, drawnIn: title, "\(name)'s name")
            // The summary is the first one under the session's name.
            let summary = summaries.allElementsBoundByIndex
                .filter { $0.frame.minY >= title.frame.maxY - 1 }
                .min { $0.frame.minY < $1.frame.minY }
            guard let summary else {
                XCTFail("Edit must show \(name)'s summary under its name")
                continue
            }
            try assertWordsWhole(["EXERCISE", "SETS"], drawnIn: summary, "\(name)'s summary")
        }
        UITestNavigation.saveScreenshot("T26", "routine-edit-end", textSize: textSize)

        // Used in names the active block beside its status chip.
        let usedIn = app.staticTexts["Powerbuilding"]
        XCTAssertTrue(usedIn.waitForExistence(timeout: 10), "Used in must list Powerbuilding")
        bringIntoView(usedIn, below: top, in: app)
        UITestNavigation.saveScreenshot("T26", "routine-used-in", textSize: textSize)
        try assertWordsWhole(["POWERBUILDING"], drawnIn: usedIn, "Used in's Powerbuilding")
    }

    // MARK: - Helpers

    /// Fails unless each of `words`, in capitals without spaces or marks,
    /// is drawn whole on one line inside `element`, above `limit` when given.
    @MainActor
    private func assertWordsWhole(
        _ words: [String], drawnIn element: XCUIElement, _ place: String, above limit: CGFloat? = nil,
        file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let lines = try drawnLines(in: element, place, above: limit, file: file, line: line)
        for word in words where !lines.contains(where: { $0.contains(word) }) {
            XCTFail("\(place) must draw \(word) whole on one line, but it reads \(lines)", file: file, line: line)
        }
    }

    /// The lines of text drawn inside `element`, above `limit` when given,
    /// top first, each in capitals without spaces or marks. Each reading is
    /// kept in the result bundle.
    @MainActor
    private func drawnLines(
        in element: XCUIElement, _ place: String, above limit: CGFloat? = nil,
        file: StaticString = #filePath, line: UInt = #line
    ) throws -> [String] {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "Missing \(place)", file: file, line: line)
        UITestNavigation.waitUntilStill(element)
        var frame = element.frame
        if let limit {
            frame = frame.intersection(CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: max(0, limit - frame.minY)))
        }
        let lines = try UITestNavigation.textLines(in: frame, of: XCUIScreen.main.screenshot()).map(\.text)
        record("T26-reading", "\(place): \(lines.joined(separator: " | "))")
        return lines.map(Self.letters)
    }

    /// Opens a block from its Program row, read as "DRAFT block: Powerbuilding".
    @MainActor
    private func openBlock(_ row: String, in app: XCUIApplication) {
        UITestNavigation.selectTab("Program", in: app)
        let button = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", row)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 10), "Program must list \(row)")
        UITestNavigation.reveal(button, in: app)
        button.tap()
        let hero = hero(in: app)
        XCTAssertTrue(hero.waitForExistence(timeout: 10), "\(row) must open the block overview")
        UITestNavigation.waitUntilStill(hero)
    }

    /// The block overview's hero, read as "Active block #1: Powerbuilding, …".
    @MainActor
    private func hero(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(
            format: "label MATCHES[c] %@", "(active|ready|draft|completed) block .*"
        )).firstMatch
    }

    /// Program's row for Upper Lower, read as "Upper Lower, 3 sessions, …".
    @MainActor
    private func routineRow(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Upper Lower,")).firstMatch
    }

    /// Opens Upper Lower from its Program row.
    @MainActor
    private func openRoutine(in app: XCUIApplication) {
        UITestNavigation.selectTab("Program", in: app)
        let row = routineRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Program must list Upper Lower")
        UITestNavigation.reveal(row, in: app)
        row.tap()
        let name = app.descendants(matching: .any).matching(NSPredicate(
            format: "label ==[c] %@ AND value BEGINSWITH %@", "Routine name", "Upper Lower"
        )).firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 10), "Program's row must open Upper Lower")
        UITestNavigation.waitUntilStill(name)
    }

    /// The routine's meta line, "3 sessions · rotates in order".
    @MainActor
    private func routineMeta(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "rotates in order")).firstMatch
    }

    /// The top of the routine screen's scroll view, under its header and
    /// the live-edit banner: rows scrolled above it are hidden.
    @MainActor
    private func routineScrollTop(in app: XCUIApplication) -> CGFloat {
        app.scrollViews.containing(NSPredicate(format: "label ==[c] %@", "Routine name"))
            .allElementsBoundByIndex.map(\.frame.minY).max() ?? 0
    }

    /// The top of the tab bar: its highest cell's top edge.
    @MainActor
    private func tabBarTop(in app: XCUIApplication) -> CGFloat {
        ["Today", "Program", "Progress", "Library"]
            .map { UITestNavigation.tab($0, in: app).frame.minY }
            .min() ?? app.frame.maxY
    }

    /// Drags the page slowly in its trailing margin, clear of any row's
    /// gesture, until `element` sits whole between `top` and the tab bar.
    @MainActor
    private func bringIntoView(
        _ element: XCUIElement, below top: CGFloat, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let bottom = tabBarTop(in: app) - 8
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let x = app.frame.width - 8
        for _ in 0..<10 {
            let frame = element.frame
            if element.exists && frame.minY >= top && frame.maxY <= bottom { return }
            let delta = (top + bottom) / 2 - frame.midY
            let startY = delta > 0 ? top + 20 : bottom - 20
            let endY = min(bottom - 20, max(top + 20, startY + delta))
            origin.withOffset(CGVector(dx: x, dy: startY)).press(
                forDuration: 0.05,
                thenDragTo: origin.withOffset(CGVector(dx: x, dy: endY)),
                withVelocity: .slow,
                thenHoldForDuration: 0.3
            )
            UITestNavigation.waitUntilStill(element)
        }
        XCTFail("\(element) must scroll whole between \(top) and the tab bar at \(bottom)", file: file, line: line)
    }

    /// `text` in capitals with only its letters and digits, a zero read as
    /// the letter O, the way Vision reads the display fonts.
    private static func letters(_ text: String) -> String {
        String(text.uppercased().filter { $0.isLetter || $0.isNumber }.map { $0 == "0" ? "O" : $0 })
    }

    /// Keeps a note in the result bundle, even when the test passes.
    @MainActor
    private func record(_ name: String, _ note: String) {
        let attachment = XCTAttachment(string: note)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
