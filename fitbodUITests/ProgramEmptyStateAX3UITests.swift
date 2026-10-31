//
//  ProgramEmptyStateAX3UITests.swift
//  fitbodUITests
//
//  T15, review item 8. At AX3 on the 390pt iPhone 17e, Program's empty
//  state drew text on top of itself: the heading read "NO PROGR…", the
//  description ran under "+ DEFINE BLOCK ▶", the feature chips printed
//  over each other, the template rows ran over their own phase lines, and
//  the Resume banner broke its pill into "RESU" over "ME ▸".
//
//  XCUI reports each text at the size it draws, even when a fixed frame
//  around it is smaller, so text spilling out of its frame shows up here
//  as two frames that intersect.
//

import XCTest

final class ProgramEmptyStateAX3UITests: XCTestCase {
    override func setUpWithError() throws {
        // Every pair gets checked, so one overlap does not hide the rest.
        continueAfterFailure = true
    }

    // MARK: - Repro at AX3

    /// The caption, "NO PROGRAM", the description and "+ DEFINE BLOCK ▶"
    /// stack without touching.
    @MainActor
    func testHeroTextStaysClearOfDefineBlockAtAX3() throws {
        let app = openEmptyProgram(textSize: .ax3)
        let hero = heroElements(in: app)
        UITestNavigation.saveScreenshot("T15", "program-empty-hero", textSize: .ax3)

        assertNoTwoOverlap([hero.caption, hero.heading, hero.description, hero.define])
        XCTAssertGreaterThanOrEqual(hero.define.frame.minY, hero.description.frame.maxY - 0.5,
                                    "The description must sit above + DEFINE BLOCK, not under it")

        UITestNavigation.reveal(hero.define, in: app)
        UITestNavigation.saveScreenshot("T15", "program-empty-define", textSize: .ax3)
    }

    /// WEEKS, PHASES, DELOAD OPTIONAL and CUSTOM wrap instead of printing
    /// over each other or the button above them.
    @MainActor
    func testFeatureChipsDoNotOverlapAtAX3() throws {
        let app = openEmptyProgram(textSize: .ax3)
        let chips = featureChips(in: app)
        let define = heroElements(in: app).define
        UITestNavigation.reveal(chips[chips.count - 1], in: app)
        UITestNavigation.saveScreenshot("T15", "program-empty-chips", textSize: .ax3)

        assertNoTwoOverlap(chips + [define])
    }

    /// Each template row keeps its weeks, name, phases and chevron apart,
    /// and inside the row; the section header stays clear of the rows.
    @MainActor
    func testTemplateRowTextsDoNotOverlapAtAX3() throws {
        let app = openEmptyProgram(textSize: .ax3)
        let header = app.staticTexts.labeled("Or start from a template")
        let count = app.staticTexts.labeled("4 presets")
        let rows = templateRows(in: app)
        let firstRow = try XCTUnwrap(rows.first, "Program shows no template rows")
        UITestNavigation.reveal(firstRow, in: app)
        assertNoTwoOverlap([header, count, firstRow])

        for (index, row) in rows.enumerated() {
            UITestNavigation.reveal(row, in: app)
            if index == 0 || index == rows.count - 1 {
                UITestNavigation.saveScreenshot("T15", "program-empty-rows-\(index + 1)", textSize: .ax3)
            }
            let texts = row.staticTexts.allElementsBoundByIndex
            XCTAssertGreaterThanOrEqual(texts.count, 3, "Row \(row.label) must show its weeks, name and phases")
            assertNoTwoOverlap(texts)
            for text in texts {
                UITestNavigation.assertInside(text, row)
            }
            // A stack that cuts a wrapped line short with "…" still keeps
            // the height of that line, as blank space under the last text.
            let lastText = texts.map(\.frame.maxY).max() ?? row.frame.maxY
            XCTAssertLessThanOrEqual(row.frame.maxY - lastText, 24,
                                     "Row \(row.label) keeps blank height under its text, so a line was cut short")
        }
    }

    /// With a workout left unfinished, the banner's RESUME pill drops under
    /// its text instead of squeezing beside it.
    @MainActor
    func testResumePillSitsUnderTheBannerTextAtAX3() throws {
        let app = openProgramWithUnfinishedWorkout(textSize: .ax3)
        let banner = bannerElements(in: app)
        UITestNavigation.saveScreenshot("T15", "program-resume-banner", textSize: .ax3)

        let textBottom = banner.texts.map(\.frame.maxY).max() ?? 0
        XCTAssertGreaterThanOrEqual(
            banner.pill.frame.minY, textBottom - 0.5,
            "The pill's top edge (\(banner.pill.frame.minY)) must be at or below the banner text's bottom edge (\(textBottom))"
        )
        assertNoTwoOverlap(banner.texts + [banner.pill])
        UITestNavigation.assertTapTarget(banner.pill)

        XCTAssertFalse(app.staticTexts["Workout"].exists, "Program shows no workout before the pill opens it")
        banner.pill.tap()
        XCTAssertTrue(app.staticTexts["Workout"].waitForExistence(timeout: 10),
                      "The Resume pill under the text must still open the workout")
    }

    // MARK: - Default text keeps the layout from T10

    /// At default text the hero, chips and rows keep their measured sizes:
    /// a 71pt button, the chip lines the phone draws, and 77pt rows. On the
    /// small phone WEEKS, PHASES and DELOAD OPTIONAL share the first chip
    /// line and CUSTOM wraps to a second; on the large phone all four chips
    /// share one line.
    @MainActor
    func testEmptyProgramKeepsItsLayoutAtDefaultText() throws {
        let app = openEmptyProgram(textSize: .default)
        let hero = heroElements(in: app)
        UITestNavigation.saveScreenshot("T15", "program-empty", textSize: .default)

        XCTAssertEqual(hero.define.frame.height, 71, accuracy: 0.5, "+ DEFINE BLOCK keeps its measured 71pt height")
        assertNoTwoOverlap([hero.heading, hero.description, hero.define])
        let chips = featureChips(in: app)
        let firstLine = chips[0].frame.minY
        XCTAssertEqual(chips.prefix(3).map { $0.frame.minY.rounded() }, Array(repeating: firstLine.rounded(), count: 3),
                       "WEEKS, PHASES and DELOAD OPTIONAL share the first chip line")
        switch UITestNavigation.phone {
        case "small":
            XCTAssertGreaterThan(chips[3].frame.minY, firstLine, "CUSTOM wraps to the second chip line on the small phone")
        case "large":
            XCTAssertEqual(chips[3].frame.minY.rounded(), firstLine.rounded(),
                           "CUSTOM shares the one chip line with the other three on the large phone")
        case let phone:
            XCTFail("No chip lines are measured for a \(phone) wide phone")
        }
        // Chips on one line sit side by side, not over each other.
        assertNoTwoOverlap(chips)

        let rows = templateRows(in: app)
        // Scrolled to the end, the last row and the section's closing rule show.
        for _ in 0..<3 {
            app.swipeUp(velocity: .slow)
        }
        UITestNavigation.saveScreenshot("T15", "program-empty-rows", textSize: .default)
        for row in rows {
            XCTAssertEqual(row.frame.height, 77, accuracy: 0.5, "Row \(row.label) keeps its measured 77pt height")
            let parts = row.label.components(separatedBy: ", ")
            let weeks = row.staticTexts[parts[0]]
            let title = row.staticTexts[parts.count > 1 ? parts[1] : ""]
            XCTAssertGreaterThan(title.frame.minX, weeks.frame.maxX, "Row \(row.label) keeps its weeks beside its name")
        }
    }

    /// At default text the pill stays beside the banner text.
    @MainActor
    func testResumePillStaysBesideTheBannerTextAtDefaultText() throws {
        let app = openProgramWithUnfinishedWorkout(textSize: .default)
        let banner = bannerElements(in: app)
        UITestNavigation.saveScreenshot("T15", "program-resume-banner", textSize: .default)

        let textTrailing = banner.texts.map(\.frame.maxX).max() ?? 0
        XCTAssertGreaterThan(banner.pill.frame.minX, textTrailing, "The pill stays beside the banner text at default size")
        XCTAssertEqual(banner.pill.frame.height, 52, accuracy: 0.5, "The pill keeps BRU's 52pt primary action height")
    }

    // MARK: - Program

    /// Program on a fresh store, which has no block and no routine, so it
    /// shows the empty state.
    @MainActor
    private func openEmptyProgram(textSize: UITestNavigation.TextSize) -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.freshStore, textSize: textSize)
        UITestNavigation.selectTab("Program", in: app)
        XCTAssertTrue(app.staticTexts["NO PROGRAM"].waitForExistence(timeout: 10), "Program must show its empty state")
        return app
    }

    /// Program with today's demo Push A started and not finished. The seed
    /// adds a session but no block or routine, so Program stays empty.
    @MainActor
    private func openProgramWithUnfinishedWorkout(textSize: UITestNavigation.TextSize) -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout, textSize: textSize)
        UITestNavigation.selectTab("Program", in: app)
        XCTAssertTrue(app.staticTexts["NO PROGRAM"].waitForExistence(timeout: 10), "Program must show its empty state")
        return app
    }

    @MainActor
    private func heroElements(in app: XCUIApplication) -> (
        caption: XCUIElement, heading: XCUIElement, description: XCUIElement, define: XCUIElement
    ) {
        let caption = app.staticTexts.labeled("Active block · None")
        let heading = app.staticTexts["NO PROGRAM"]
        let description = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "A block schedules routines")
        ).firstMatch
        let define = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "+ DEFINE BLOCK")).firstMatch
        for element in [caption, heading, description, define] {
            XCTAssertTrue(element.waitForExistence(timeout: 10), "Missing hero element: \(element)")
        }
        return (caption, heading, description, define)
    }

    @MainActor
    private func featureChips(in app: XCUIApplication) -> [XCUIElement] {
        let chips = ["WEEKS · 4-12", "PHASES · 1-4", "DELOAD OPTIONAL", "CUSTOM"].map { app.staticTexts[$0] }
        for chip in chips {
            XCTAssertTrue(chip.waitForExistence(timeout: 10), "Missing feature chip: \(chip)")
        }
        return chips
    }

    /// The four template rows, top to bottom. A row's label starts with
    /// its weeks: "8W, Hypertrophy Meso, ACCUM 5 · INTNS 2 · DELOAD 1, ›".
    @MainActor
    private func templateRows(in app: XCUIApplication) -> [XCUIElement] {
        let query = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]+W, .*"))
        XCTAssertTrue(query.firstMatch.waitForExistence(timeout: 10), "Program shows no template rows")
        let rows = query.allElementsBoundByIndex.sorted { $0.frame.minY < $1.frame.minY }
        XCTAssertEqual(rows.count, 4, "Program lists the catalog's 4 templates")
        return rows
    }

    // MARK: - Resume banner

    /// The banner's RESUME label, routine name and "12:00 · 0 sets" meta
    /// line, and its Resume pill.
    @MainActor
    private func bannerElements(in app: XCUIApplication) -> (texts: [XCUIElement], pill: XCUIElement) {
        let texts = [
            app.staticTexts["RESUME"],
            app.staticTexts["Push A"],
            app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", ".* · [0-9]+ sets?")).firstMatch,
        ]
        let pill = app.buttons.labeled("Resume ▸")
        for element in texts + [pill] {
            XCTAssertTrue(element.waitForExistence(timeout: 10), "Missing banner element: \(element)")
        }
        return (texts, pill)
    }

    // MARK: - Frames

    @MainActor
    private func assertNoTwoOverlap(_ elements: [XCUIElement], file: StaticString = #filePath, line: UInt = #line) {
        for (index, first) in elements.enumerated() {
            for second in elements.dropFirst(index + 1) {
                UITestNavigation.assertNoOverlap(first, second, file: file, line: line)
            }
        }
    }
}
