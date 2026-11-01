//
//  TodayPolishUITests.swift
//  fitbodUITests
//
//  T35, review items 22, 24 and 25, and findings F9, F81, F106, F107, F134,
//  F176, F178 and F179. On Today:
//
//  - VOLUME THIS WEEK's MEV, MAV and MRV tick labels sat right against the
//    muscle name, and MRV landed under "SETS". The review also saw a stepped
//    divider under a row on the small phone in light mode; it no longer
//    reproduces, and the test keeps every divider straight.
//  - At AX3 the legend wrapped its labels, and the header cut the date.
//    The name step's header actions reached up over its stacked title.
//  - At xxLarge and xxxLarge on the small phone the stat strip broke
//    "SESSIONS" mid-word and the header cut the date; the start slab split
//    "1" from "EXERCISE", and the block band split ACCUMULATION.
//  - With an active block, the third stat showed a dash under "W1 / 4".
//    Past the plan it read W1 / 4, and the NEXT slab a wrapped DAY 08 / 28.
//  - The "No active block." card was inset 32pt, in sentence case, with a
//    link in bruSignal.
//
//  A volume row is one VoiceOver element, so the tests find its tick labels
//  in the screenshot's pixels. XCUI reads a whole label even when the screen
//  cuts it, so every check that a word shows whole reads the screenshot.
//

import XCTest

final class TodayPolishUITests: XCTestCase {
    /// How far the tick labels' letters must stay below the muscle name's
    /// and the set count's: they sat 1.7pt below them, right against them.
    private static let tickLabelClearance: CGFloat = 4

    override func setUpWithError() throws {
        // Every check runs, so one broken part does not hide the rest.
        continueAfterFailure = true
    }

    // MARK: - Volume rows

    /// Every row's tick labels sit in their own row above the bar, clear of
    /// the muscle name and the set count, and inside the bar's width. On the
    /// small phone in light mode, the divider under each row, the first one
    /// included, is one straight line.
    @MainActor
    func testTickLabelsSitInTheirOwnRowInsideTheBar() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        let appearance = currentAppearance
        scrollToTop(app.staticTexts.labeled("UNDER MEV"), in: app)
        let screenshot = XCUIScreen.main.screenshot()
        UITestNavigation.saveScreenshot("T35", "legend-volume-rows", appearance: appearance)

        let rows = volumeRowsOnScreen(in: app)
        XCTAssertGreaterThanOrEqual(rows.count, 2, "Today must show whole volume rows under the legend")
        for row in rows {
            assertTickLabelsClear(row, in: screenshot, appearance: appearance)
        }
        if appearance == .light, UITestNavigation.phone == "small" {
            for row in rows {
                assertDividerIsStraight(under: row, in: screenshot)
            }
        }
    }

    // MARK: - AX3

    /// At AX3 the header keeps SETTINGS at least 8pt from the date and shows
    /// the date whole, and the legend's three items stay apart, each on one
    /// line.
    @MainActor
    func testHeaderAndLegendFitAtAX3() throws {
        try skipUnlessSmallPhone()
        let app = UITestNavigation.launch(UITestNavigation.freshStore, textSize: .ax3)
        let appearance = currentAppearance
        assertHeaderItemsApartAndDateWhole(in: app, at: .ax3)
        UITestNavigation.saveScreenshot("T35", "today-top", textSize: .ax3, appearance: appearance)

        scrollToTop(app.staticTexts.labeled("No active block."), in: app)
        UITestNavigation.saveScreenshot("T35", "empty-card", textSize: .ax3, appearance: appearance)

        let legend = ["UNDER MEV", "MEV → MAV", "MRV"].map { app.staticTexts.labeled($0) }
        scrollToTop(legend[0], in: app)
        UITestNavigation.saveScreenshot("T35", "legend-volume-rows", textSize: .ax3, appearance: appearance)
        let screenshot = XCUIScreen.main.screenshot()
        for item in legend {
            XCTAssertTrue(item.exists, "Missing legend item \(item)")
        }
        for (index, item) in legend.enumerated() {
            for other in legend.dropFirst(index + 1) {
                UITestNavigation.assertNoOverlap(item, other)
            }
            UITestNavigation.assertInside(item, app.windows.firstMatch)
        }
        // "MRV" is one short word, so its height is one line of the legend.
        let lineHeight = legend[2].frame.height
        for item in legend {
            UITestNavigation.assertHeight(item, atMost: lineHeight + 1)
            let lines = visualLines(in: item.frame.insetBy(dx: -2, dy: -2), of: screenshot)
            XCTAssertEqual(lines.count, 1, "\(item.label) must draw on one line at AX3, but reads \(lines)")
        }
    }

    /// At AX3 the name step stacks its title over ‹ BACK and SAVE, and
    /// neither action's touch area reaches over the title.
    @MainActor
    func testNameStepActionsClearTheTitleAtAX3() throws {
        try skipUnlessSmallPhone()
        let app = UITestNavigation.launch(UITestNavigation.freshStore, textSize: .ax3)
        let newRoutine = app.buttons.labeled("+ New routine")
        UITestNavigation.reveal(newRoutine, in: app)
        newRoutine.tap()
        let title = app.staticTexts.labeled("New routine")
        XCTAssertTrue(title.waitForExistence(timeout: 10), "+ New routine must open the name step")
        let back = UITestNavigation.hittable(app.buttons, "Back", exactLabel: true)
        let save = app.buttons.labeled("Save")
        UITestNavigation.waitUntilStill(title)
        UITestNavigation.saveScreenshot("T35", "name-step", textSize: .ax3, appearance: currentAppearance)

        XCTAssertLessThanOrEqual(title.frame.maxY, min(back.frame.midY, save.frame.midY),
                                 "At AX3 the title must sit over ‹ BACK and SAVE")
        UITestNavigation.assertNoOverlap(back, title)
        UITestNavigation.assertNoOverlap(save, title)
        UITestNavigation.assertTapTarget(back)
        UITestNavigation.assertTapTarget(save)
    }

    // MARK: - xxLarge and xxxLarge

    /// At xxLarge and xxxLarge on the small phone the header keeps its items
    /// apart and the date whole, DAY STREAK and SESSIONS each show whole on
    /// one line, PLAN COMPLETE breaks only between its words, and so does the
    /// block band's name.
    @MainActor
    func testHeaderAndStatStripStayWholeAtXXLAndXXXL() throws {
        try skipUnlessSmallPhone()
        let app = UITestNavigation.launch(UITestNavigation.blockStatesPastPlan, textSize: .xxl)
        let appearance = currentAppearance
        for size in [UITestNavigation.TextSize.xxl, .xxxl] {
            if size != .xxl {
                UITestNavigation.relaunch(app, textSize: size)
            }
            let cells = statCells(in: app)
            UITestNavigation.saveScreenshot("T35", "today-top-past-plan", textSize: size, appearance: appearance)
            assertHeaderItemsApartAndDateWhole(in: app, at: size)

            let screenshot = XCUIScreen.main.screenshot()
            for (cell, label) in [(cells.dayStreak, "DAY STREAK"), (cells.sessions, "SESSIONS")] {
                let lines = visualLines(in: cell.frame.insetBy(dx: -2, dy: -2), of: screenshot)
                XCTAssertEqual(lines.first.map(letters), letters(label),
                               "At \(size) \(label) must show whole on one line, but the cell reads \(lines)")
            }
            let lines = visualLines(in: cells.third.frame.insetBy(dx: -2, dy: -2), of: screenshot)
            let words = Set(lines.flatMap(Self.words))
            XCTAssertTrue(words.isSuperset(of: ["PLAN", "COMPLETE"]),
                          "At \(size) PLAN COMPLETE may wrap only between its words, but the cell reads \(lines)")
            assertBandKeepsWordsWhole(["SPRING", "BLOCK"], in: app, at: size)
        }
    }

    /// At xxxLarge on the small phone the start slab keeps each number with
    /// its noun, and the block band shows ACCUMULATION whole on one line and
    /// its name's words whole.
    @MainActor
    func testStartSlabAndBlockBandKeepWordsWholeAtXXXL() throws {
        try skipUnlessSmallPhone()
        let app = UITestNavigation.launch(UITestNavigation.activeBlock, textSize: .xxxl)
        let next = app.staticTexts.labeled("NEXT")
        XCTAssertTrue(next.exists || next.waitForExistence(timeout: 10), "Today must show the start slab")
        let blockChip = app.staticTexts.labeled("Block")
        let phase = app.staticTexts.labeled("Accumulation")
        XCTAssertTrue(blockChip.exists && phase.exists, "Today must show the block band with its phase")
        scrollToTop(blockChip, in: app)
        UITestNavigation.saveScreenshot("T35", "band-start-slab", textSize: .xxxl, appearance: currentAppearance)

        // NEXT is one line of the meta line's font.
        let lineHeight = next.frame.height
        let meta = [
            "(?i)[0-9]+ exercises?", "(?i)[0-9]+ sets?", "(?i)~[0-9]+ min",
        ].map { app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", $0)).firstMatch }
        for part in meta {
            XCTAssertTrue(part.exists, "Missing meta line part: \(part)")
            UITestNavigation.assertHeight(part, atMost: lineHeight + 1)
        }

        UITestNavigation.assertHeight(phase, atMost: blockChip.frame.height + 0.5)
        let lines = visualLines(in: phase.frame.insetBy(dx: -2, dy: -2), of: XCUIScreen.main.screenshot())
        XCTAssertEqual(lines, ["ACCUMULATION"], "The block band must show ACCUMULATION whole on one line")
        assertBandKeepsWordsWhole(["LIVE", "BLOCK"], in: app, at: .xxxl)
    }

    // MARK: - Third stat

    /// With an active block in week 1 and no workouts, the third stat shows
    /// the phase's short label under W1 / 4, and VoiceOver reads its full
    /// name.
    @MainActor
    func testThirdStatShowsThePhaseShortLabel() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        let third = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label ==[c] %@", "Block week 1 of 4")).firstMatch
        XCTAssertTrue(third.exists || third.waitForExistence(timeout: 10),
                      "With its block in week 1 the third stat must read W1 / 4")
        UITestNavigation.saveScreenshot("T35", "today-top-block", appearance: currentAppearance)

        let lines = visualLines(in: third.frame.insetBy(dx: -2, dy: -2), of: XCUIScreen.main.screenshot())
        XCTAssertEqual(lines.map(letters), ["W14", "ACCUM"], "The third stat must show ACCUM under W1 / 4, but reads \(lines)")
        XCTAssertEqual(third.value as? String, "Accumulation", "VoiceOver must read the phase's full name")
    }

    /// Past its plan, the third stat reads PLAN COMPLETE, not week 1, and
    /// shows no phase; the NEXT slab shows no wrapped DAY counter.
    @MainActor
    func testPastPlanReadsPlanCompleteWithNoDayCounter() throws {
        let app = UITestNavigation.launch(UITestNavigation.blockStatesPastPlan)
        let next = app.staticTexts.labeled("NEXT")
        XCTAssertTrue(next.exists || next.waitForExistence(timeout: 10), "Past the plan Today must still offer the NEXT slab")
        let cells = statCells(in: app)
        UITestNavigation.saveScreenshot("T35", "today-top-past-plan", appearance: currentAppearance)

        XCTAssertEqual(cells.third.label, "Block plan complete", "VoiceOver must say the plan is complete, not a week")
        let screenshot = XCUIScreen.main.screenshot()
        let lines = visualLines(in: cells.third.frame.insetBy(dx: -2, dy: -2), of: screenshot)
        XCTAssertTrue(Set(lines.flatMap(Self.words)).isSuperset(of: ["PLAN", "COMPLETE"]),
                      "The third stat must read PLAN COMPLETE, but reads \(lines)")
        XCTAssertFalse(lines.contains { letters($0).contains("W1") }, "The third stat must not read week 1: \(lines)")

        let strip = cells.dayStreak.frame.union(cells.third.frame).union(cells.sessions.frame)
        let stripWords = Set(visualLines(in: strip.insetBy(dx: -2, dy: -2), of: screenshot).flatMap(Self.words))
        XCTAssertTrue(stripWords.isDisjoint(with: ["ACCUM", "INTNS", "PEAK", "REAL", "DELOAD"]),
                      "Past the plan the stat strip must show no phase, but reads \(stripWords.sorted())")

        let day = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "(?i)day [0-9]+ / [0-9]+")).firstMatch
        XCTAssertFalse(day.exists, "Past the plan the NEXT slab must show no DAY counter, but reads \(day.label)")
    }

    // MARK: - No active block

    /// With no active block, the card's heading and copy start at the 16pt
    /// edge the card above uses, its heading wears that card's uppercase
    /// display style, and its link reads in bruSignalText.
    @MainActor
    func testNoActiveBlockCardLinesUpWithTheCardAbove() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        let appearance = currentAppearance
        UITestNavigation.saveScreenshot("T35", "today-top", appearance: appearance)
        let above = app.staticTexts.labeled("Build your first routine")
        let heading = app.staticTexts.labeled("No active block.")
        let copy = app.staticTexts.labeled("Define a training block to see your phase, week, and deloads here.")
        let link = app.buttons.labeled("Start a block")
        scrollToTop(above, in: app)
        UITestNavigation.saveScreenshot("T35", "empty-card", appearance: appearance)
        for element in [above, heading, copy, link] {
            XCTAssertTrue(element.exists, "Missing \(element)")
        }

        XCTAssertEqual(heading.frame.minX, above.frame.minX, accuracy: 0.5,
                       "No active block. must start at the card above's 16pt edge")
        XCTAssertEqual(copy.frame.minX, above.frame.minX, accuracy: 0.5,
                       "The card's copy must start at the card above's 16pt edge")
        XCTAssertEqual(heading.frame.height, above.frame.height, accuracy: 1,
                       "No active block. must wear the card above's display style")

        // bruSignal and bruSignalText are one orange in dark mode.
        guard appearance == .light else { return }
        let screenshot = XCUIScreen.main.screenshot()
        XCTAssertGreaterThan(pixelCount(of: UITestNavigation.RGB(hex: 0xC03700), in: link.frame, of: screenshot), 0,
                             "START A BLOCK must read in bruSignalText")
        XCTAssertEqual(pixelCount(of: UITestNavigation.RGB(hex: 0xFF5C1A), in: link.frame, of: screenshot), 0,
                       "START A BLOCK must not read in bruSignal")
    }

    // MARK: - Checks

    /// SETTINGS ends at least 8pt before the date starts, and the date shows
    /// whole: XCUI reads its whole label even when the screen cuts it, so
    /// the drawn text comes from the screenshot.
    @MainActor
    private func assertHeaderItemsApartAndDateWhole(
        in app: XCUIApplication, at size: UITestNavigation.TextSize,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let settings = app.buttons["Settings"]
        let date = app.staticTexts.matching(NSPredicate(
            format: "label MATCHES %@", "(?i)[a-z]{3} · [a-z]{3} [0-9]{1,2}"
        )).firstMatch
        guard settings.exists || settings.waitForExistence(timeout: 10), date.exists else {
            return XCTFail("Today's header must show SETTINGS and the date", file: file, line: line)
        }
        let screenshot = XCUIScreen.main.screenshot()
        let settingsLine = textLines(in: settings.frame, of: screenshot)
            .first { letters($0.text).contains("SETTINGS") }
        let dateLines = textLines(in: date.frame.insetBy(dx: -2, dy: -2), of: screenshot)
        let shown = dateLines.map(\.text).joined(separator: " ")
        XCTAssertTrue(letters(shown) == letters(date.label) && !shown.contains("…") && !shown.contains("..."),
                      "At \(size) the header must show the date \"\(date.label)\" whole, but it reads \"\(shown)\"",
                      file: file, line: line)
        guard let settingsLine, let dateStart = dateLines.map(\.box.minX).min() else {
            return XCTFail("At \(size) the header's SETTINGS and date must be readable", file: file, line: line)
        }
        XCTAssertGreaterThanOrEqual(dateStart - settingsLine.box.maxX, 8,
                                    "At \(size) SETTINGS must end at least 8pt before the date: SETTINGS ends at \(settingsLine.box.maxX), the date starts at \(dateStart)",
                                    file: file, line: line)
    }

    /// The block band shows the block's name with each of `words` whole,
    /// whichever line each lands on.
    @MainActor
    private func assertBandKeepsWordsWhole(
        _ words: [String], in app: XCUIApplication, at size: UITestNavigation.TextSize,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let name = app.staticTexts.labeled(words.joined(separator: " "))
        guard name.exists else {
            return XCTFail("The block band must show \(words.joined(separator: " "))", file: file, line: line)
        }
        let lines = visualLines(in: name.frame.insetBy(dx: -2, dy: -2), of: XCUIScreen.main.screenshot())
        XCTAssertTrue(Set(lines.flatMap(Self.words)).isSuperset(of: words),
                      "At \(size) the block band must keep each word of its name whole, but it reads \(lines)",
                      file: file, line: line)
    }

    /// The row's tick labels sit in a row of their own. Above the bar and
    /// its ticks, the lowest band of drawn pixel rows, the labels, lies at
    /// least `tickLabelClearance` below the band over it, the muscle name
    /// and the set count, and inside the bar's width; and MRV's label keeps
    /// its signal color there.
    @MainActor
    private func assertTickLabelsClear(
        _ row: VolumeRow, in screenshot: XCUIScreenshot, appearance: UITestNavigation.Appearance,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        guard let bar = barTrack(in: row.frame, of: screenshot, ink: Self.ink(appearance)) else {
            return XCTFail("\(row.name): no bar in its row at \(row.frame)", file: file, line: line)
        }
        // Clear of the ticks, which run 3pt above the bar, and of the scroll
        // indicator past the bar's right end.
        let above = CGRect(
            x: row.frame.minX, y: row.frame.minY,
            width: bar.maxX + 4 - row.frame.minX, height: bar.minY - 3.5 - row.frame.minY
        )
        let bands = drawnBands(in: above, of: screenshot, paper: Self.paper(appearance))
        guard bands.count >= 2, let labels = bands.last else {
            return XCTFail("\(row.name): its tick labels must sit in a row of their own under the header, but above the bar it draws \(bands.map(\.box).map(describe))",
                           file: file, line: line)
        }
        let header = bands[bands.count - 2]
        let clearance = Self.tickLabelClearance
        XCTAssertGreaterThanOrEqual(labels.box.minY - header.box.maxY, clearance,
                                    "\(row.name): the tick labels at \(describe(labels.box)) must sit at least \(clearance)pt under the muscle name and set count at \(describe(header.box))",
                                    file: file, line: line)
        XCTAssertTrue(labels.box.minX >= bar.minX - 0.5 && labels.box.maxX <= bar.maxX + 0.5,
                      "\(row.name): the tick labels at \(describe(labels.box)) must lie inside the bar, \(describe(bar))",
                      file: file, line: line)
        XCTAssertTrue(labels.hasSignal, "\(row.name): MRV must keep its tick label, in bruSignalText", file: file, line: line)
    }

    /// The divider under `row` sits at one height across the row: sampled at
    /// twelve points, its top edge is the same device pixel row at each.
    @MainActor
    private func assertDividerIsStraight(
        under row: VolumeRow, in screenshot: XCUIScreenshot,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let hair = UITestNavigation.RGB(hex: 0xD4D0C5)
        let paper = UITestNavigation.RGB(hex: 0xFAFAF7)
        let band = CGRect(x: row.frame.minX, y: row.frame.maxY - 4, width: row.frame.width, height: 8)
        guard let cut = UITestNavigation.pixels(in: band, of: screenshot) else {
            return XCTFail("\(row.name): its divider is not on the screenshot", file: file, line: line)
        }
        let width = Int(cut.frame.width)
        let height = Int(cut.frame.height)
        let scale = screenshot.image.scale
        var tops: [String] = []
        var rows = Set<Int>()
        for sample in 0..<12 {
            let column = Int((Double(sample) + 0.5) * Double(width) / 12)
            let top = (0..<height).first { y in
                let color = rgb(at: column, y, in: cut.bytes, width: width)
                return color.distance(to: hair) < color.distance(to: paper)
            }
            let x = (cut.frame.minX + CGFloat(column)) / scale
            tops.append("x \(Int(x)): \(top.map { "y \(String(format: "%.2f", (cut.frame.minY + CGFloat($0)) / scale))" } ?? "none")")
            rows.insert(top ?? -1)
        }
        XCTAssertFalse(rows.contains(-1), "\(row.name): its divider must span the row: \(tops)", file: file, line: line)
        XCTAssertEqual(rows.count, 1, "\(row.name): its divider must be one straight line, but its top edge is at \(tops)",
                       file: file, line: line)
    }

    // MARK: - Elements

    private struct VolumeRow {
        let name: String
        let frame: CGRect
    }

    private struct StatCells {
        let dayStreak: XCUIElement
        let sessions: XCUIElement
        let third: XCUIElement
    }

    /// The volume rows whole on screen, top to bottom. Each reads "Chest: 4
    /// sets this week, …", or "1 set" for one.
    @MainActor
    private func volumeRowsOnScreen(in app: XCUIApplication) -> [VolumeRow] {
        let top = headerBottom(in: app)
        let bottom = tabBarTop(in: app)
        var rows: [VolumeRow] = []
        let query = app.descendants(matching: .any).matching(NSPredicate(
            format: "label MATCHES %@", ".+: [0-9]+ sets? this week, .*"
        ))
        for element in query.allElementsBoundByIndex {
            let frame = element.frame
            guard frame.minY >= top, frame.maxY <= bottom, !rows.contains(where: { $0.frame == frame }) else { continue }
            rows.append(VolumeRow(name: String(element.label.prefix { $0 != ":" }), frame: frame))
        }
        return rows.sorted { $0.frame.minY < $1.frame.minY }
    }

    /// The stat strip's three cells: Day streak, Sessions, and the block's
    /// week or this week's count.
    @MainActor
    private func statCells(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> StatCells {
        let cells = StatCells(
            dayStreak: app.descendants(matching: .any).matching(NSPredicate(format: "label ==[c] %@", "Day streak")).firstMatch,
            sessions: app.buttons["today.sessions"],
            third: app.descendants(matching: .any).matching(NSPredicate(
                format: "label BEGINSWITH[c] %@ OR label ==[c] %@", "Block ", "Sessions this week"
            )).firstMatch
        )
        XCTAssertTrue(cells.sessions.exists || cells.sessions.waitForExistence(timeout: 10),
                      "Today must show its stat strip", file: file, line: line)
        XCTAssertTrue(cells.dayStreak.exists && cells.third.exists, "Today must show all three stats", file: file, line: line)
        return cells
    }

    // MARK: - Page

    @MainActor
    private var currentAppearance: UITestNavigation.Appearance {
        XCUIDevice.shared.appearance == .dark ? .dark : .light
    }

    @MainActor
    private func skipUnlessSmallPhone() throws {
        try XCTSkipUnless(UITestNavigation.phone == "small", "T35 checks this on the 390pt phone only")
    }

    /// The bottom of Today's header: SETTINGS' touch area reaches its rule.
    @MainActor
    private func headerBottom(in app: XCUIApplication) -> CGFloat {
        app.buttons["Settings"].frame.maxY
    }

    @MainActor
    private func tabBarTop(in app: XCUIApplication) -> CGFloat {
        UITestNavigation.tab("Today", in: app).frame.minY
    }

    /// Drags Today's page, in its trailing margin, until `element`'s top
    /// sits just under the header, or the page stops moving.
    @MainActor
    private func scrollToTop(_ element: XCUIElement, in app: XCUIApplication) {
        if !element.exists {
            UITestNavigation.reveal(element, in: app)
        }
        let top = headerBottom(in: app) + 8
        let bottom = tabBarTop(in: app) - 24
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let x = app.frame.width - 6
        for _ in 0..<8 {
            let distance = element.frame.minY - top
            if distance >= 0 && distance <= 24 { return }
            let start = distance > 0 ? bottom : top + 16
            let end = min(bottom, max(top + 16, start - distance))
            let before = element.frame
            origin.withOffset(CGVector(dx: x, dy: start)).press(
                forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: x, dy: end)),
                withVelocity: .slow, thenHoldForDuration: 0.2
            )
            UITestNavigation.waitUntilStill(element)
            if element.frame == before { return }
        }
    }

    // MARK: - Screenshot readers

    /// bruInk in `appearance`.
    private static func ink(_ appearance: UITestNavigation.Appearance) -> UITestNavigation.RGB {
        UITestNavigation.RGB(hex: appearance == .dark ? 0xFAFAF7 : 0x0A0A0A)
    }

    /// bruPaper in `appearance`.
    private static func paper(_ appearance: UITestNavigation.Appearance) -> UITestNavigation.RGB {
        UITestNavigation.RGB(hex: appearance == .dark ? 0x0A0A0A : 0xFAFAF7)
    }

    private func rgb(at x: Int, _ y: Int, in bytes: [UInt8], width: Int) -> UITestNavigation.RGB {
        let index = (y * width + x) * 4
        return UITestNavigation.RGB(red: Int(bytes[index]), green: Int(bytes[index + 1]), blue: Int(bytes[index + 2]))
    }

    /// A volume bar's track inside `row`: the span of its 1.5pt outline. Its
    /// top is the first pixel row in which ink covers most of the row's
    /// width; its ends are where that pixel row's ink starts and stops.
    @MainActor
    private func barTrack(in row: CGRect, of screenshot: XCUIScreenshot, ink: UITestNavigation.RGB) -> CGRect? {
        guard let cut = UITestNavigation.pixels(in: row, of: screenshot) else { return nil }
        let width = Int(cut.frame.width)
        let height = Int(cut.frame.height)
        let isInk = { (x: Int, y: Int) in self.rgb(at: x, y, in: cut.bytes, width: width).distance(to: ink) <= 64 }
        let outline = (0..<height).filter { y in (0..<width).count { isInk($0, y) } * 10 >= width * 7 }
        guard let top = outline.first, let bottom = outline.last,
              let left = (0..<width).first(where: { isInk($0, top) }),
              let right = (0..<width).last(where: { isInk($0, top) }) else { return nil }
        let scale = screenshot.image.scale
        return CGRect(
            x: (cut.frame.minX + CGFloat(left)) / scale, y: (cut.frame.minY + CGFloat(top)) / scale,
            width: CGFloat(right - left + 1) / scale, height: CGFloat(bottom - top + 1) / scale
        )
    }

    /// The text lines drawn inside `rect`, or none when it is off the
    /// screenshot.
    @MainActor
    private func textLines(in rect: CGRect, of screenshot: XCUIScreenshot) -> [(text: String, box: CGRect)] {
        (try? UITestNavigation.textLines(in: rect, of: screenshot)) ?? []
    }

    /// The lines of text drawn inside `rect`, top to bottom: Vision's pieces
    /// that share a line, joined left to right.
    @MainActor
    private func visualLines(in rect: CGRect, of screenshot: XCUIScreenshot) -> [String] {
        var lines: [[(text: String, box: CGRect)]] = []
        for piece in textLines(in: rect, of: screenshot).sorted(by: { $0.box.midY < $1.box.midY }) {
            if let last = lines.last?.last, piece.box.midY < last.box.maxY {
                lines[lines.count - 1].append(piece)
            } else {
                lines.append([piece])
            }
        }
        return lines.map { $0.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ") }
    }

    /// The bands of drawn pixel rows inside `rect`, top to bottom: rows
    /// with a pixel unlike `paper`, and each band's box around its drawn
    /// pixels, in screen points. A band also says whether it draws in
    /// bruSignalText.
    @MainActor
    private func drawnBands(
        in rect: CGRect, of screenshot: XCUIScreenshot, paper: UITestNavigation.RGB
    ) -> [(box: CGRect, hasSignal: Bool)] {
        guard let cut = UITestNavigation.pixels(in: rect, of: screenshot) else { return [] }
        let width = Int(cut.frame.width)
        let height = Int(cut.frame.height)
        let signals = [UITestNavigation.RGB(hex: 0xC03700), UITestNavigation.RGB(hex: 0xFF7A3D)]
        var bands: [(box: CGRect, hasSignal: Bool)] = []
        var band: (top: Int, left: Int, right: Int, hasSignal: Bool)?
        let scale = screenshot.image.scale
        func close(at bottom: Int) {
            guard let open = band else { return }
            bands.append((CGRect(
                x: (cut.frame.minX + CGFloat(open.left)) / scale, y: (cut.frame.minY + CGFloat(open.top)) / scale,
                width: CGFloat(open.right - open.left + 1) / scale, height: CGFloat(bottom - open.top) / scale
            ), open.hasSignal))
            band = nil
        }
        for y in 0..<height {
            let drawn = (0..<width).filter { rgb(at: $0, y, in: cut.bytes, width: width).distance(to: paper) > 32 }
            guard let left = drawn.first, let right = drawn.last else {
                close(at: y)
                continue
            }
            let hasSignal = drawn.contains { x in
                signals.contains { rgb(at: x, y, in: cut.bytes, width: width).distance(to: $0) <= 40 }
            }
            if let open = band {
                band = (open.top, min(open.left, left), max(open.right, right), open.hasSignal || hasSignal)
            } else {
                band = (y, left, right, hasSignal)
            }
        }
        close(at: height)
        return bands
    }

    /// The pixels inside `rect` within 24 of `color` on every channel.
    @MainActor
    private func pixelCount(of color: UITestNavigation.RGB, in rect: CGRect, of screenshot: XCUIScreenshot) -> Int {
        guard let cut = UITestNavigation.pixels(in: rect, of: screenshot) else { return 0 }
        return stride(from: 0, to: cut.bytes.count, by: 4).count { index in
            UITestNavigation.RGB(red: Int(cut.bytes[index]), green: Int(cut.bytes[index + 1]), blue: Int(cut.bytes[index + 2]))
                .distance(to: color) <= 24
        }
    }

    /// `text`'s letters and digits, uppercased.
    private func letters(_ text: String) -> String {
        String(text.uppercased().filter { $0.isLetter || $0.isNumber })
    }

    /// `text`'s words, uppercased.
    private static func words(_ text: String) -> [String] {
        text.uppercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    private func describe(_ box: CGRect) -> String {
        String(format: "(%.1f, %.1f) %.1f x %.1f", box.minX, box.minY, box.width, box.height)
    }
}
