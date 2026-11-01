//
//  BlockWeekCountsUITests.swift
//  fitbodUITests
//
//  Ticket T78, T12 findings F69, F71 and F75: the active block's week
//  strip and its counts leave out empty workouts (decision 6), and a block
//  past its last planned week reads PLAN COMPLETE instead of week 1
//  (tradeoffs.md "A block past its plan"). BlockStatesSeed supplies Spring
//  Block, whose Upper A was logged two days ago and whose Upper B was
//  finished yesterday with nothing logged.
//

import XCTest

final class BlockWeekCountsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Empty workouts

    /// The empty Upper B showed as a done day, and the strip read "2 / 2
    /// SESSIONS DONE · 0 LEFT".
    @MainActor
    func testWeekStripLeavesOutTheEmptyWorkout() throws {
        let app = UITestNavigation.launch(UITestNavigation.blockStates)
        openSpringBlockFromToday(in: app)
        let count = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH 'SESSIONS DONE'")).firstMatch
        XCTAssertTrue(UITestNavigation.appears(count), "The week strip must count its sessions")
        UITestNavigation.reveal(count, in: app)

        let days = dayCells(in: app).mapValues(\.label)
        XCTAssertEqual(days.count, 7, "The week strip must show seven days: \(days)")
        // The strip shows this Monday-first week, which holds Upper A's day
        // unless today is Monday.
        let logged = Self.isInThisWeek(daysAgo: 2) ? [Self.weekday(daysAgo: 2)] : []
        let done = days.filter { $0.value.hasSuffix(", done") }.keys.sorted()
        XCTAssertEqual(done, logged, "Only Upper A's day may show as done, not the empty Upper B's: \(days)")
        XCTAssertFalse(days.values.contains { $0.contains("Upper B") },
                       "The strip must not name the empty Upper B: \(days)")

        XCTAssertEqual(count.label, "\(logged.count) / 2 SESSIONS DONE", "The count must leave out the empty workout")
        XCTAssertTrue(app.staticTexts["\(2 - logged.count) LEFT"].exists,
                      "The strip must leave \(2 - logged.count) of its two sessions")

        let progress = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'In progress'")).firstMatch
        XCTAssertTrue(progress.exists, "The NOW phase must show its progress")
        let sessions = logged.count == 1 ? "1 session" : "\(logged.count) sessions"
        XCTAssertEqual(progress.label, "In progress · \(sessions)", "The NOW phase's count must leave out the empty workout")
    }

    // MARK: - Past the plan

    /// A block past its last planned week fell back to week 1: "W1 / 4" on
    /// the overview hero with phase 1 marked NOW, "WEEK 1 OF 4" on the week
    /// strip, "Week 1 of 4 · Accumulation" on Program and an Accumulation
    /// chip on Today with week 1 current.
    @MainActor
    func testBlockPastItsPlanReadsPlanComplete() throws {
        let app = UITestNavigation.launch(UITestNavigation.blockStatesPastPlan)
        var problems: [String] = []

        // Today's band.
        UITestNavigation.selectTab("Today", in: app)
        let band = app.staticTexts.labeled("SPRING BLOCK")
        XCTAssertTrue(UITestNavigation.appears(band), "Today must show Spring Block's band")
        UITestNavigation.reveal(band, in: app)
        // The ticker's pixels are read once the screen stops moving.
        UITestNavigation.waitUntilStill(band)
        let ticker = (1...4).map { app.staticTexts["W\($0)"] }
        let todayShot = XCUIScreen.main.screenshot()
        if !app.staticTexts["PLAN COMPLETE"].exists {
            problems.append("Today's band has no PLAN COMPLETE chip")
        }
        for phase in Self.phaseNames where app.staticTexts[phase].exists {
            problems.append("Today's band shows the \(phase) chip")
        }
        // A past week is faint, the current week ink and a later week paper.
        for (index, cell) in ticker.enumerated() {
            guard cell.exists else {
                problems.append("Today's ticker has no W\(index + 1)")
                continue
            }
            let fill = CGPoint(x: cell.frame.minX + 4, y: cell.frame.midY)
            if let problem = UITestNavigation.colorProblem(at: fill, in: todayShot, is: Self.faint, tolerance: 12) {
                problems.append("W\(index + 1) on Today's ticker is not past: \(problem)")
            }
        }

        // Program's block row.
        UITestNavigation.selectTab("Program", in: app)
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'ACTIVE block: Spring Block'")).firstMatch
        XCTAssertTrue(UITestNavigation.appears(row), "Program must list Spring Block")
        UITestNavigation.reveal(row, in: app)
        UITestNavigation.waitUntilStill(row)
        let programShot = XCUIScreen.main.screenshot()
        if row.label != "ACTIVE block: Spring Block. Plan complete." {
            problems.append("Program's row reads \"\(row.label)\"")
        }
        let rowText = Self.letters(try UITestNavigation.readText(in: row.frame, of: programShot))
        if !rowText.contains("PLANCOMPLETE") || rowText.contains("WEEK") || rowText.contains("ACCUMULATION") {
            problems.append("Program's row shows \"\(rowText)\"")
        }

        // The block overview.
        row.tap()
        let hero = hero(in: app)
        XCTAssertTrue(UITestNavigation.appears(hero), "Program's row must open the block overview")
        UITestNavigation.waitUntilStill(hero)
        let overviewShot = XCUIScreen.main.screenshot()
        if !hero.label.hasPrefix("Active block #1: Spring Block, plan complete, ")
            || hero.label.localizedCaseInsensitiveContains("week") {
            problems.append("The hero reads \"\(hero.label)\"")
        }
        let heroText = Self.letters(try UITestNavigation.readText(in: hero.frame, of: overviewShot))
        if !heroText.contains("PLANCOMPLETE") || heroText.contains("VOL") || heroText.contains("INT") {
            problems.append("The hero shows \"\(heroText)\"")
        }
        let stripHeader = app.staticTexts.matching(NSPredicate(format: "label == 'PLAN COMPLETE'"))
            .allElementsBoundByIndex.first { $0.frame.minY >= hero.frame.maxY - 1 }
        if stripHeader == nil {
            problems.append("The week strip header does not read PLAN COMPLETE")
        }
        let weekText = app.staticTexts.matching(NSPredicate(
            format: "label MATCHES %@ OR label MATCHES %@ OR label MATCHES %@",
            "WEEK [0-9]+ OF [0-9]+", "‹ W[0-9]+", "W[0-9]+ ›"
        )).allElementsBoundByIndex.map(\.label)
        if !weekText.isEmpty {
            problems.append("The week strip shows \(weekText)")
        }
        let days = dayCells(in: app).mapValues(\.label)
        if days.count != 7 {
            problems.append("The week strip shows \(days.count) days, not seven")
        }
        for (day, label) in days where Self.phaseNames.contains(where: { label.contains($0) }) {
            problems.append("\(day) speaks a phase: \"\(label)\"")
        }

        if app.staticTexts["NOW"].exists {
            problems.append("A phase shows NOW")
        }
        let doneChips = app.staticTexts.matching(NSPredicate(format: "label == 'DONE'")).count
        if doneChips != Self.phaseNames.count {
            problems.append("\(doneChips) of \(Self.phaseNames.count) phases show DONE")
        }
        XCTAssertTrue(problems.isEmpty, "Spring Block is past its four-week plan: " + problems.joined(separator: "; "))
    }

    // MARK: - Helpers

    /// Spring Block's three phases.
    private static let phaseNames = ["Accumulation", "Intensification", "Deload"]

    /// bruFaint in light mode, a past week's fill.
    private static let faint = UITestNavigation.RGB(hex: 0xE8E5DD)

    /// Opens Spring Block's overview from Today's block band.
    @MainActor
    private func openSpringBlockFromToday(in app: XCUIApplication) {
        UITestNavigation.selectTab("Today", in: app)
        let band = app.staticTexts.labeled("SPRING BLOCK")
        XCTAssertTrue(UITestNavigation.appears(band), "Today must show Spring Block's band")
        UITestNavigation.reveal(band, in: app)
        band.tap()
        XCTAssertTrue(UITestNavigation.appears(hero(in: app)), "The band must open Spring Block's overview")
    }

    /// The overview's hero, one element VoiceOver reads as "Active block #1:
    /// Spring Block, …".
    @MainActor
    private func hero(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(
            format: "label MATCHES[c] %@", "(active|ready|draft|completed) block .*"
        )).firstMatch
    }

    /// The week strip's cells, each read as "Wednesday, Upper A, done",
    /// keyed by weekday.
    @MainActor
    private func dayCells(in app: XCUIApplication) -> [String: XCUIElement] {
        let cells = app.descendants(matching: .any).matching(NSPredicate(format: "label MATCHES %@", Self.dayPattern))
        var days: [String: XCUIElement] = [:]
        for cell in cells.allElementsBoundByIndex {
            days[String(cell.label.prefix { $0 != "," })] = cell
        }
        return days
    }

    /// How VoiceOver reads a day cell: its weekday, then what the day holds,
    /// if anything. Past the plan a later day is its weekday alone.
    private static let dayPattern = "(\(Calendar.current.weekdaySymbols.joined(separator: "|")))(, .*)?"

    /// Uppercased letters and digits only, with Vision's 0 for the mono O.
    private static func letters(_ text: String) -> String {
        String(text.uppercased().filter { $0.isLetter || $0.isNumber }.map { $0 == "0" ? "O" : $0 })
    }

    /// The weekday `days` before now, as the strip's cells name it.
    private static func weekday(daysAgo days: Int) -> String {
        let date = Date.now.addingTimeInterval(-Double(days) * 24 * 3600)
        return Calendar.current.weekdaySymbols[Calendar.current.component(.weekday, from: date) - 1]
    }

    /// Whether the day `days` before now is in the strip's Monday-first week.
    private static func isInThisWeek(daysAgo days: Int) -> Bool {
        let date = Date.now.addingTimeInterval(-Double(days) * 24 * 3600)
        return Calendar(identifier: .iso8601).dateInterval(of: .weekOfYear, for: .now)?.contains(date) ?? false
    }
}

extension UITestNavigation {
    /// BlockStatesSeed's blocks with Spring Block started five weeks ago,
    /// past its four-week plan.
    static let blockStatesPastPlan = [resetFlag, "-fitbod-seed-block-states-past-plan"]
}
