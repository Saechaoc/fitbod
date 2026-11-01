//
//  BlockOverviewAndRoutineAX3UITests.swift
//  fitbodUITests
//
//  Ticket T108, findings F203 to F205. On the small phone at AX3, with T26's
//  Powerbuilding seed:
//
//  - The routine screen's live-edit banner stayed under the header, about
//    140pt of the roughly 390pt above the tab bar, so the first session row
//    started under the tab bar. The banner now scrolls with the page, after
//    the sessions.
//  - The active block hero's stat row wrapped each part over two lines, "W1 /"
//    over "5", "VOL" over "HOLD" and "INT" over "100%". Each part now has a
//    line of its own, without the dots between them.
//  - A draft block's "+ ATTACH ROUTINE ▸" put its "▸" on a line of its own.
//
//  At default text the banner stays under the header, and the stat row and
//  the attach button each read on one line, as before.
//
//  XCUI reads a label whole even where the screen breaks it, so the lines
//  are read from screenshots.
//

import XCTest

final class BlockOverviewAndRoutineAX3UITests: XCTestCase {
    // The tests and helpers are @MainActor because XCUIApplication and
    // XCUIElement are main-actor isolated.

    /// The active hero's stat parts, as the screen writes them.
    private static let statParts = ["W1 / 5", "VOL HOLD", "INT 100%"]

    @MainActor
    override func setUpWithError() throws {
        // Every check runs, so one failure does not hide the rest.
        continueAfterFailure = true
    }

    // MARK: - Routine screen

    /// The first session row sits whole above the tab bar when the routine
    /// opens, and the banner moves with the page.
    @MainActor
    func testFirstSessionRowShowsWhenTheRoutineOpensAtAX3() throws {
        try checkRoutine(textSize: .ax3)
    }

    /// At default text the banner stays under the header, above the page.
    @MainActor
    func testRoutineKeepsItsBannerAboveThePageAtDefaultText() throws {
        try checkRoutine(textSize: .default)
    }

    // MARK: - Active block hero

    /// "W1 / 5", "VOL HOLD" and "INT 100%" each read on a line of their own.
    @MainActor
    func testActiveHeroStatsEachReadOnOneLineAtAX3() throws {
        try checkActiveHeroStats(textSize: .ax3)
    }

    /// At default text the three parts share one line.
    @MainActor
    func testActiveHeroStatsShareOneLineAtDefaultText() throws {
        try checkActiveHeroStats(textSize: .default)
    }

    // MARK: - Draft block's routine band

    /// "▸" reads on ROUTINE's line.
    @MainActor
    func testAttachRoutineKeepsItsArrowOnRoutinesLineAtAX3() throws {
        try checkAttachRoutine(textSize: .ax3)
    }

    /// At default text the whole label reads on one line.
    @MainActor
    func testAttachRoutineReadsOnOneLineAtDefaultText() throws {
        try checkAttachRoutine(textSize: .default)
    }

    // MARK: - Checks

    @MainActor
    private func checkRoutine(textSize: UITestNavigation.TextSize) throws {
        let app = UITestNavigation.launch(UITestNavigation.powerbuilding, textSize: textSize)
        openRoutine(in: app)
        let row = app.buttons["Session 1: Upper A"]
        XCTAssertTrue(row.exists || row.waitForExistence(timeout: 10), "The routine must list Upper A first")
        UITestNavigation.waitUntilStill(row)
        UITestNavigation.saveScreenshot("T108", "routine", textSize: textSize)

        let top = routinePageTop(in: app)
        let bottom = tabBarTop(in: app)
        let banner = app.descendants(matching: .any).matching(identifier: "liveEditBanner").firstMatch
        let opened = row.frame
        XCTAssertGreaterThanOrEqual(opened.minY, top - 0.5, "Upper A's row at \(opened) must start on the page, below \(top)")
        XCTAssertLessThanOrEqual(opened.maxY, bottom + 0.5,
                                 "Upper A's row at \(opened) must sit whole above the tab bar at \(bottom) when the routine opens")

        guard textSize == .ax3 else {
            // The page starts under the banner, which sits outside it.
            XCTAssertTrue(banner.exists || banner.waitForExistence(timeout: 5), "A routine on an active block must show the live-edit banner")
            XCTAssertEqual(banner.frame.maxY, top, accuracy: 1,
                           "At default text the page must start under the banner at \(banner.frame), not at \(top)")
            return
        }

        // The banner is on the page, after the sessions, so drags bring it
        // up. The page lays it out only once it comes near the screen.
        XCTAssertTrue(!banner.exists || banner.frame.minY >= opened.maxY - 0.5,
                      "The banner at \(banner.frame) must come after Upper A's row at \(opened), not above it")
        for _ in 0..<6 {
            if banner.exists && banner.frame.minY >= top && banner.frame.maxY <= bottom { break }
            let distance = banner.exists ? (top + bottom) / 2 - banner.frame.midY : -(bottom - top) / 2
            dragPage(by: distance, between: top, and: bottom, in: app)
            UITestNavigation.waitUntilStill(banner.exists ? banner : row)
        }
        UITestNavigation.saveScreenshot("T108", "routine-banner", textSize: textSize)
        let shown = banner.frame
        XCTAssertTrue(banner.exists && shown.minY >= top - 0.5 && shown.maxY <= bottom + 0.5,
                      "Drags must bring the live-edit banner whole onto the page, between \(top) and \(bottom), but it is at \(shown)")

        // A drag down moves it down with the page.
        dragPage(by: 120, between: top, and: bottom, in: app)
        UITestNavigation.waitUntilStill(banner)
        XCTAssertGreaterThan(banner.frame.minY - shown.minY, 60,
                             "The banner must scroll with the page: a 120pt drag moved it from \(shown) to \(banner.frame)")
    }

    @MainActor
    private func checkActiveHeroStats(textSize: UITestNavigation.TextSize) throws {
        let app = UITestNavigation.launch(UITestNavigation.powerbuilding, textSize: textSize)
        openBlock("ACTIVE block: Powerbuilding", in: app)
        let hero = hero(in: app)

        // At AX3 the stat row starts under the bottom bar, so a slow drag in
        // the trailing margin brings it up first; the extra 10pt covers the
        // drag the page takes before it starts to scroll.
        let barTop = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Edit block")).firstMatch.frame.minY
        let overflow = hero.frame.maxY - (barTop - 8)
        if overflow > 0 {
            dragPage(from: min(hero.frame.maxY, barTop) - 30, by: -(overflow + 10), in: app)
            UITestNavigation.waitUntilStill(hero)
        }
        UITestNavigation.saveScreenshot("T108", "hero-active", textSize: textSize)

        let visible = hero.frame.intersection(CGRect(x: hero.frame.minX, y: 0, width: hero.frame.width, height: barTop))
        let screenshot = XCUIScreen.main.screenshot()
        let lines = try UITestNavigation.textLines(in: visible, of: screenshot)
        record("T108-hero-active-lines-\(textSize.rawValue)", lines.map { "\($0.text) \($0.box)" }.joined(separator: " | "))
        let found = Self.statParts.map { part in lines.first { Self.letters($0.text).contains(Self.letters(part)) } }
        for (part, line) in zip(Self.statParts, found) where line == nil {
            XCTFail("The active hero must read \"\(part)\" on one line, but it reads \(lines.map(\.text))")
        }
        let boxes = found.compactMap { $0?.box }
        guard boxes.count == Self.statParts.count else { return }

        if textSize == .ax3 {
            // Each part on a line of its own, in order, with nothing drawn
            // between two parts, where a dot's line would sit. The 6pt
            // margins clear the "/" and "%" that reach past Vision's boxes,
            // and the 12pt insets the scroll bar a drag leaves showing.
            for (upper, lower) in zip(boxes, boxes.dropFirst()) {
                XCTAssertLessThanOrEqual(upper.midY, lower.minY,
                                         "At AX3 each stat part must have a line of its own, but the hero reads \(lines.map(\.text))")
                let gap = CGRect(x: visible.minX + 12, y: upper.maxY + 6, width: visible.width - 24, height: lower.minY - upper.maxY - 12)
                XCTAssertFalse(Self.anyPixel(in: gap, of: screenshot) { max($0, $1, $2) > 60 },
                               "Nothing may be drawn between two stat parts at AX3, but \(gap) holds a mark")
            }
        } else {
            for box in boxes.dropFirst() {
                XCTAssertTrue(box.minY < boxes[0].midY && boxes[0].midY < box.maxY,
                              "At default text the stat parts must share one line, but the hero reads \(lines.map(\.text))")
            }
        }
    }

    @MainActor
    private func checkAttachRoutine(textSize: UITestNavigation.TextSize) throws {
        let app = UITestNavigation.launch(UITestNavigation.powerbuilding, textSize: textSize)
        openBlock("DRAFT block: Powerbuilding", in: app)
        let attach = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "+ ATTACH ROUTINE")).firstMatch
        XCTAssertTrue(attach.exists || attach.waitForExistence(timeout: 10), "A draft block without a routine must offer + ATTACH ROUTINE ▸")
        bringIntoView(attach, between: blockPageTop(in: app), and: tabBarTop(in: app), in: app)
        UITestNavigation.saveScreenshot("T108", "draft-attach", textSize: textSize)

        // Inside the button's 1.5pt outline.
        let inside = attach.frame.insetBy(dx: 3, dy: 3)
        let screenshot = XCUIScreen.main.screenshot()
        let lines = try UITestNavigation.textLines(in: inside, of: screenshot)
        record("T108-attach-lines-\(textSize.rawValue)", "\(inside): " + lines.map(\.text).joined(separator: " | "))
        guard let routine = lines.first(where: { Self.letters($0.text).contains("ROUTINE") }) else {
            return XCTFail("+ ATTACH ROUTINE ▸ must draw ROUTINE whole, but it reads \(lines.map(\.text))")
        }
        XCTAssertTrue(Self.hasArrow(routine.text),
                      "\"▸\" must read on ROUTINE's line, but the button reads \(lines.map(\.text))")
        // "▸" comes after ROUTINE, so nothing may be drawn under ROUTINE's
        // line. Vision does not read a "▸" alone on a line.
        let below = CGRect(x: inside.minX, y: routine.box.maxY + 4, width: inside.width, height: inside.maxY - routine.box.maxY - 4)
        XCTAssertFalse(Self.anyPixel(in: below, of: screenshot) { ($0 + $1 + $2) / 3 < 128 },
                       "Nothing may be drawn under ROUTINE's line at \(routine.box), but \(below) holds a glyph")
        if textSize == .default {
            XCTAssertEqual(lines.count, 1, "At default text + ATTACH ROUTINE ▸ must read on one line, but it reads \(lines.map(\.text))")
        }
    }

    // MARK: - Helpers

    /// Opens Upper Lower from its Program row.
    @MainActor
    private func openRoutine(in app: XCUIApplication) {
        UITestNavigation.selectTab("Program", in: app)
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Upper Lower,")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Program must list Upper Lower")
        UITestNavigation.reveal(row, in: app)
        row.tap()
        let name = app.textFields.matching(NSPredicate(
            format: "label ==[c] %@ AND value BEGINSWITH %@", "Routine name", "Upper Lower"
        )).firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 10), "Program's row must open Upper Lower")
        UITestNavigation.waitUntilStill(name)
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
        app.staticTexts.matching(Self.heroLabel).firstMatch
    }

    private static let heroLabel = NSPredicate(format: "label MATCHES[c] %@", "(active|ready|draft|completed) block .*")

    /// The top of the routine screen's page, the innermost scroll view that
    /// holds the routine's name: rows scrolled above it are hidden.
    @MainActor
    private func routinePageTop(in app: XCUIApplication) -> CGFloat {
        app.scrollViews.containing(NSPredicate(format: "label ==[c] %@", "Routine name"))
            .allElementsBoundByIndex.map(\.frame.minY).max() ?? 0
    }

    /// The top of the block overview's page, under its header.
    @MainActor
    private func blockPageTop(in app: XCUIApplication) -> CGFloat {
        app.scrollViews.containing(Self.heroLabel).allElementsBoundByIndex.map(\.frame.minY).max() ?? 0
    }

    /// The top of the tab bar: the 2pt rule above its highest cell.
    @MainActor
    private func tabBarTop(in app: XCUIApplication) -> CGFloat {
        let cells = ["Today", "Program", "Progress", "Library"].map { UITestNavigation.tab($0, in: app).frame.minY }
        return (cells.min() ?? app.frame.maxY) - 2
    }

    /// Drags the page slowly in its trailing margin, where no row's press
    /// begins, from `startY` by `distance` points: up when negative.
    @MainActor
    private func dragPage(from startY: CGFloat, by distance: CGFloat, in app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.width - 8, dy: startY))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)),
                    withVelocity: .slow, thenHoldForDuration: 0.3)
    }

    /// Drags the page by about `distance` points, starting 20pt inside
    /// the span between `top` and `bottom` and staying in it.
    @MainActor
    private func dragPage(by distance: CGFloat, between top: CGFloat, and bottom: CGFloat, in app: XCUIApplication) {
        let startY = distance < 0 ? bottom - 20 : top + 20
        let endY = min(bottom - 20, max(top + 20, startY + distance))
        dragPage(from: startY, by: endY - startY, in: app)
    }

    /// Drags the page until `element` sits whole between `top` and `bottom`.
    @MainActor
    private func bringIntoView(
        _ element: XCUIElement, between top: CGFloat, and bottom: CGFloat, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        for _ in 0..<8 {
            let frame = element.frame
            if element.exists && frame.minY >= top && frame.maxY <= bottom { return }
            dragPage(by: (top + bottom) / 2 - frame.midY, between: top, and: bottom, in: app)
            UITestNavigation.waitUntilStill(element)
        }
        XCTFail("\(element) must scroll whole between \(top) and \(bottom)", file: file, line: line)
    }

    /// `text` in capitals with only its letters and digits, a zero read as
    /// the letter O, the way Vision reads the display fonts.
    private static func letters(_ text: String) -> String {
        String(text.uppercased().filter { $0.isLetter || $0.isNumber }.map { $0 == "0" ? "O" : $0 })
    }

    /// True when `text` holds "▸" or a glyph Vision reads it as, such as
    /// "•" at default text.
    private static func hasArrow(_ text: String) -> Bool {
        text.contains { "▸►▶>›»•".contains($0) }
    }

    /// True when a pixel in `rect` passes `test` on its sRGB channels: a
    /// dark one where the page's light fill should show, or a light one on
    /// the hero's ink. False for an empty `rect`.
    @MainActor
    private static func anyPixel(in rect: CGRect, of screenshot: XCUIScreenshot, _ test: (Int, Int, Int) -> Bool) -> Bool {
        guard rect.width > 0, rect.height > 0, let bytes = UITestNavigation.pixels(in: rect, of: screenshot)?.bytes else { return false }
        return stride(from: 0, to: bytes.count, by: 4).contains { test(Int(bytes[$0]), Int(bytes[$0 + 1]), Int(bytes[$0 + 2])) }
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
