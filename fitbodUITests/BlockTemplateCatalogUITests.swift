//
//  BlockTemplateCatalogUITests.swift
//  fitbodUITests
//
//  Ticket T10: Program's template rows and New Block's preset pickers
//  share one catalog, so each opens the block it describes. A row reads
//  "8W", "Hypertrophy Meso" and "ACCUM 5 · INTNS 2 · DELOAD 1", and New
//  Block's duration sheet lists the same phases.
//

import XCTest

final class BlockTemplateCatalogUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The catalog in its order, written the way Program's rows write it.
    private static let catalog: [(name: String, weeks: Int, phases: String)] = [
        ("Hypertrophy Meso", 8, "ACCUM 5 · INTNS 2 · DELOAD 1"),
        ("Generic Strength Meso", 8, "ACCUM 4 · INTNS 2 · REAL 1 · DELOAD 1"),
        ("Powerlifting Peak", 8, "ACCUM 3 · INTNS 3 · REAL 1 · DELOAD 1"),
        ("5/3/1 Cycle", 4, "ACCUM 1 · INTNS 1 · REAL 1 · DELOAD 1"),
    ]

    /// The short label Program's rows give each phase title.
    private static let shortLabels = [
        "Accumulation": "ACCUM",
        "Intensification": "INTNS",
        "Peak": "PEAK",
        "Realization": "REAL",
        "Deload": "DELOAD",
    ]

    // MARK: - Repro

    /// The row promised 5 weeks (ACCUM 3 · INTNS 1 · DELOAD 1), and New
    /// Block opened the 8-week template.
    @MainActor
    func testHypertrophyRowOpensThePhasesItPromises() throws {
        let app = openProgram()
        let row = templateRow(containing: "Hypertrophy", in: app)
        UITestNavigation.reveal(row, in: app)
        let promised = promise(of: row)
        row.tap()
        assertNewBlockOpen(in: app)
        assertShows(promised, in: app, row: row.label)
    }

    /// The 5/3/1 row promised 4 weeks and opened a blank block with none.
    @MainActor
    func testFiveThreeOneRowOpensFourWeeks() throws {
        let app = openProgram()
        let row = templateRow(containing: "5/3/1", or: "5 / 3 / 1", in: app)
        UITestNavigation.reveal(row, in: app)
        row.tap()
        assertNewBlockOpen(in: app)
        XCTAssertEqual(totalWeeks(in: app), 4, "The 5/3/1 row must open a 4-week block")
    }

    /// Picking a preset forced 4 days per week.
    @MainActor
    func testPickingAPresetKeepsDaysPerWeek() throws {
        let app = openBlankNewBlock()
        UITestNavigation.hittable(app.buttons, "Decrease days per week").tap()
        XCTAssertEqual(daysPerWeek(in: app), "3 days per week")
        pickPreset("HYPERTROPHY MESO", in: app)
        XCTAssertEqual(daysPerWeek(in: app), "3 days per week", "Picking a preset must leave days per week alone")
        XCTAssertEqual(builderPhases(in: app), Self.catalog[0].phases)
    }

    // MARK: - Acceptance

    /// Each of Program's four rows shows only its template's facts and
    /// opens New Block with that template's name and phases.
    @MainActor
    func testEveryProgramRowOpensItsPhases() throws {
        let app = openProgram()
        XCTAssertTrue(app.staticTexts.labeled("4 presets").waitForExistence(timeout: 10),
                      "The template header must count the catalog's 4 presets")
        for (index, template) in Self.catalog.enumerated() {
            let row = templateRow(containing: template.name, in: app)
            UITestNavigation.reveal(row, in: app)
            if index == Self.catalog.count - 1 {
                UITestNavigation.saveScreenshot("T10", "program-template-rows")
            }
            let promised = promise(of: row)
            XCTAssertEqual(promised.weeks, template.weeks, "Row label: \(row.label)")
            XCTAssertEqual(promised.phases, template.phases, "Row label: \(row.label)")
            for stale in ["POPULAR", "/ WK", "BEGINNER", "INTERMEDIATE", "ADVANCED"] {
                XCTAssertFalse(row.label.localizedCaseInsensitiveContains(stale),
                               "Rows show only the template's facts, not \(stale): \(row.label)")
            }
            row.tap()
            assertNewBlockOpen(in: app)
            assertShows(promised, in: app, row: row.label)
            XCTAssertEqual(blockName(in: app), template.name)
            XCTAssertEqual(daysPerWeek(in: app), "4 days per week")
            UITestNavigation.hittable(app.buttons, "Cancel").tap()
            XCTAssertTrue(app.staticTexts.labeled("NEW BLOCK").waitForNonExistence(timeout: 5),
                          "CANCEL must close an untouched New Block at once")
        }
    }

    /// New Block's picker lists BLANK, then the catalog in its order. Each
    /// preset sets its phases and, while the name is still a preset's,
    /// its name; none of them touches days per week.
    @MainActor
    func testEveryPresetSetsItsPhases() throws {
        let app = openBlankNewBlock()
        UITestNavigation.hittable(app.buttons, "Decrease days per week").tap()

        openPresetPicker(in: app)
        let labels = ["BLANK"] + Self.catalog.map { $0.name.uppercased() }
        assertListed(labels, in: app)
        for removed in ["LINEAR STRENGTH", "POWERBUILDING", "OFF-SEASON", "PRE-MEET"] {
            XCTAssertFalse(row(removed, in: app).exists, "\(removed) is not in the catalog")
        }
        XCTAssertTrue(row("BLANK", in: app).isSelected, "A blank New Block starts on BLANK")
        UITestNavigation.saveScreenshot("T10", "new-block-preset-picker")
        let sheet = UITestNavigation.topSheet(in: app) ?? app
        UITestNavigation.hittable(sheet.buttons, "Cancel").tap()
        XCTAssertTrue(row("BLANK", in: app).waitForNonExistence(timeout: 5),
                      "CANCEL must close the picker without picking")
        XCTAssertEqual(builderPhases(in: app), "ACCUM 2 · INTNS 2 · DELOAD 1")

        for template in Self.catalog {
            pickPreset(template.name.uppercased(), in: app)
            XCTAssertEqual(builderPhases(in: app), template.phases)
            XCTAssertEqual(totalWeeks(in: app), template.weeks)
            XCTAssertEqual(blockName(in: app), template.name)
            XCTAssertEqual(daysPerWeek(in: app), "3 days per week")
        }

        pickPreset("BLANK", in: app)
        XCTAssertEqual(totalWeeks(in: app), 0, "BLANK starts with no phases")
        XCTAssertTrue(app.staticTexts.labeled("PHASES · 0").exists)
        XCTAssertEqual(blockName(in: app), "Blank Block")
        XCTAssertEqual(daysPerWeek(in: app), "3 days per week")
    }

    /// Edited phases survive "Keep my phases", and "Replace phases" swaps
    /// in the preset's.
    @MainActor
    func testKeepMyPhasesKeepsTheEdit() throws {
        let app = openBlankNewBlock()
        addWeekToFirstPhase(in: app)
        XCTAssertEqual(builderPhases(in: app), "ACCUM 3 · INTNS 2 · DELOAD 1")

        pickPreset("POWERLIFTING PEAK", in: app)
        let dialog = app.staticTexts.labeled("Replace your phases?")
        XCTAssertTrue(dialog.waitForExistence(timeout: 5), "Picking a preset over edited phases must ask first")
        UITestNavigation.saveScreenshot("T10", "replace-phases-dialog")
        UITestNavigation.hittable(app.buttons, "Keep my phases").tap()
        XCTAssertTrue(dialog.waitForNonExistence(timeout: 5))
        XCTAssertEqual(builderPhases(in: app), "ACCUM 3 · INTNS 2 · DELOAD 1", "Keep my phases must keep the edit")
        XCTAssertEqual(blockName(in: app), "", "Keep my phases cancels the whole pick")

        pickPreset("POWERLIFTING PEAK", in: app)
        XCTAssertTrue(dialog.waitForExistence(timeout: 5))
        UITestNavigation.hittable(app.buttons, "Replace phases").tap()
        XCTAssertTrue(dialog.waitForNonExistence(timeout: 5))
        XCTAssertEqual(builderPhases(in: app), Self.catalog[2].phases)
        XCTAssertEqual(blockName(in: app), "Powerlifting Peak")
    }

    /// Program's own CHOOSE PRESET sheet lists the same catalog, and its
    /// pick opens New Block on that template.
    @MainActor
    func testProgramPresetSheetOpensTheTemplate() throws {
        let app = openProgram()
        UITestNavigation.hittable(app.buttons, "+ NEW").tap()
        UITestNavigation.hittable(app.buttons, "+ New block").tap()
        UITestNavigation.hittable(app.buttons, "Use Preset").tap()
        XCTAssertTrue(app.staticTexts.labeled("CHOOSE PRESET").waitForExistence(timeout: 5))
        assertListed(["FROM SCRATCH"] + Self.catalog.map { $0.name.uppercased() }, in: app)
        UITestNavigation.saveScreenshot("T10", "program-choose-preset")

        UITestNavigation.hittable(app.buttons, "5/3/1 CYCLE").tap()
        assertNewBlockOpen(in: app)
        XCTAssertEqual(builderPhases(in: app), Self.catalog[3].phases)
        XCTAssertEqual(blockName(in: app), "5/3/1 Cycle")
        XCTAssertEqual(daysPerWeek(in: app), "4 days per week")
    }

    /// Today's Start a block still opens New Block, on the blank template;
    /// a preset replaces its "Blank Block" name. EDIT BLOCK has no PRESET.
    @MainActor
    func testTodayBlankBlockTakesAPresetAndEditBlockHasNone() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        let start = app.buttons.labeled("Start a block")
        UITestNavigation.reveal(start, in: app)
        start.tap()
        assertNewBlockOpen(in: app)
        XCTAssertEqual(blockName(in: app), "Blank Block")
        XCTAssertEqual(totalWeeks(in: app), 0)

        pickPreset("HYPERTROPHY MESO", in: app)
        XCTAssertEqual(builderPhases(in: app), Self.catalog[0].phases)
        XCTAssertEqual(blockName(in: app), "Hypertrophy Meso")
        UITestNavigation.hittable(app.buttons, "SAVE DRAFT").tap()
        XCTAssertTrue(app.staticTexts.labeled("NEW BLOCK").waitForNonExistence(timeout: 5), "SAVE DRAFT must close New Block")

        UITestNavigation.selectTab("Program", in: app)
        let card = app.buttons.labeled("DRAFT block: Hypertrophy Meso")
        UITestNavigation.reveal(card, in: app)
        card.tap()
        UITestNavigation.hittable(app.buttons, "EDIT").tap()
        XCTAssertTrue(app.staticTexts.labeled("EDIT BLOCK").waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons.labeled("+ ADD PHASE").exists)
        XCTAssertFalse(app.buttons.labeled("Preset").exists, "EDIT BLOCK must not offer presets")
    }

    // MARK: - Program

    @MainActor
    private func openProgram() -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Program", in: app)
        return app
    }

    /// Program → + NEW → + New block → Blank Block: today's default draft,
    /// ACCUM 2 · INTNS 2 · DELOAD 1 with no name.
    @MainActor
    private func openBlankNewBlock() -> XCUIApplication {
        let app = openProgram()
        UITestNavigation.hittable(app.buttons, "+ NEW").tap()
        UITestNavigation.hittable(app.buttons, "+ New block").tap()
        UITestNavigation.hittable(app.buttons, "Blank Block").tap()
        assertNewBlockOpen(in: app)
        return app
    }

    /// A template row: a button whose label starts with its weeks, such as
    /// "8W, Hypertrophy Meso, ACCUM 5 · INTNS 2 · DELOAD 1".
    @MainActor
    private func templateRow(containing text: String, or other: String? = nil, in app: XCUIApplication) -> XCUIElement {
        let format = "label MATCHES %@ AND (label CONTAINS[c] %@ OR label CONTAINS[c] %@)"
        let row = app.buttons.matching(NSPredicate(format: format, "^[0-9]+W.*", text, other ?? text)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Missing Program's \(text) row")
        return row
    }

    /// The weeks and phases a row's label promises.
    private func promise(of row: XCUIElement) -> (weeks: Int?, phases: String?) {
        let parts = row.label.components(separatedBy: ", ")
        let weeks = parts.first.flatMap { $0.hasSuffix("W") ? Int($0.dropLast()) : nil }
        let phases = parts.first {
            $0.range(of: #"^[A-Z]+ [0-9]+( · [A-Z]+ [0-9]+)*$"#, options: .regularExpression) != nil
        }
        return (weeks, phases)
    }

    // MARK: - New Block

    @MainActor
    private func assertNewBlockOpen(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.staticTexts.labeled("NEW BLOCK").waitForExistence(timeout: 10),
                      "New Block never opened", file: file, line: line)
    }

    @MainActor
    private func assertShows(
        _ promised: (weeks: Int?, phases: String?), in app: XCUIApplication, row: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let weeks = totalWeeks(in: app)
        let phases = builderPhases(in: app)
        XCTAssertTrue(
            weeks == promised.weeks && phases == promised.phases,
            "The row \"\(row)\" promised \(promised.weeks.map { "\($0)W" } ?? "no weeks") "
                + "\(promised.phases ?? "and no phases"), and New Block shows \(weeks.map { "\($0)W" } ?? "no weeks") \(phases)",
            file: file, line: line
        )
    }

    /// TOTAL WEEKS reads "Total weeks, 8, edit phase durations".
    @MainActor
    private func totalWeeksCell(in app: XCUIApplication) -> XCUIElement {
        let cell = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Total weeks, ")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "Missing TOTAL WEEKS")
        return cell
    }

    @MainActor
    private func totalWeeks(in app: XCUIApplication) -> Int? {
        let parts = totalWeeksCell(in: app).label.components(separatedBy: ", ")
        return parts.count > 1 ? Int(parts[1]) : nil
    }

    /// DAYS PER WEEK reports its count as its value: "3 days per week".
    @MainActor
    private func daysPerWeek(in app: XCUIApplication) -> String? {
        let cell = app.descendants(matching: .any)
            .matching(NSPredicate(format: "value ENDSWITH %@", "days per week")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "Missing DAYS PER WEEK")
        return cell.value as? String
    }

    /// The name field's text; an empty field reports its placeholder.
    @MainActor
    private func blockName(in app: XCUIApplication) -> String {
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Missing the block name field")
        let value = field.value as? String ?? ""
        return value == field.placeholderValue ? "" : value
    }

    /// New Block's phases written the way Program's rows write them, such as
    /// "ACCUM 5 · INTNS 2 · DELOAD 1", read from the duration sheet that
    /// TOTAL WEEKS opens. Each sheet row is "01", the phase title, − weeks +.
    /// The screens under the sheet put other texts on the same lines, so a
    /// row's weeks are the bare number between its − and +. Every lookup
    /// stays in the sheet: New Block's phase cards under it list their own
    /// "01", title and weeks to XCUITest (T24).
    @MainActor
    private func builderPhases(in app: XCUIApplication) -> String {
        let sheet = openDurationSheet(in: app)
        let titles = sheet.staticTexts.matching(NSPredicate(format: "label IN %@", Array(Self.shortLabels.keys)))
        let numbers = sheet.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]+$"))
        var phases: [String] = []
        for index in 1...12 {
            let number = sheet.staticTexts.labeled(String(format: "%02d", index))
            guard number.exists else { break }
            let title = sameRow(as: number, in: titles).first?.label ?? "?"
            let minus = sameRow(as: number, in: steppers("\u{2212}", in: sheet)).first
            let plus = sameRow(as: number, in: steppers("+", in: sheet)).first
            let weeks = sameRow(as: number, in: numbers).first { text in
                guard let minus, let plus else { return false }
                return text.frame.midX > minus.frame.maxX && text.frame.midX < plus.frame.minX
            }?.label ?? "?"
            phases.append("\(Self.shortLabels[title] ?? title) \(weeks)")
        }
        closeDurationSheet(in: app)
        return phases.joined(separator: " · ")
    }

    /// One more week for the first phase, through the duration sheet's +.
    @MainActor
    private func addWeekToFirstPhase(in app: XCUIApplication) {
        let sheet = openDurationSheet(in: app)
        let number = sheet.staticTexts.labeled("01")
        XCTAssertTrue(number.exists, "The duration sheet lists no phases")
        let plus = sameRow(as: number, in: steppers("+", in: sheet)).first
        XCTAssertNotNil(plus, "The first phase has no + in the duration sheet")
        plus?.tap()
        closeDurationSheet(in: app)
    }

    /// The duration sheet's − or + buttons.
    @MainActor
    private func steppers(_ glyph: String, in sheet: XCUIElement) -> XCUIElementQuery {
        sheet.buttons.matching(NSPredicate(format: "label == %@", glyph))
    }

    /// Taps TOTAL WEEKS and returns the duration sheet it opens, the last
    /// layer's view that starts below the top of the screen, once it stops
    /// sliding up; the whole app if none shows. The half-height sheet floats
    /// 8pt above the bottom of the screen, so UITestNavigation.topSheet(in:),
    /// which looks for a sheet that reaches the bottom, does not find it.
    @MainActor
    private func openDurationSheet(in app: XCUIApplication) -> XCUIElement {
        totalWeeksCell(in: app).tap()
        XCTAssertTrue(app.staticTexts.labeled("Edit Block Duration").waitForExistence(timeout: 5),
                      "TOTAL WEEKS must open the duration sheet")
        let layer = app.windows.firstMatch.children(matching: .other).allElementsBoundByIndex.last
        guard let sheet = layer?.children(matching: .other).allElementsBoundByIndex.first(where: { $0.frame.minY > 0.5 })
        else { return app }
        UITestNavigation.waitUntilStill(sheet)
        return sheet
    }

    @MainActor
    private func closeDurationSheet(in app: XCUIApplication) {
        UITestNavigation.hittable(app.buttons, "Done").tap()
        XCTAssertTrue(app.staticTexts.labeled("Edit Block Duration").waitForNonExistence(timeout: 5))
    }

    /// The elements of `query` level with `anchor`, left to right.
    @MainActor
    private func sameRow(as anchor: XCUIElement, in query: XCUIElementQuery) -> [XCUIElement] {
        let midY = anchor.frame.midY
        return query.allElementsBoundByIndex
            .filter { abs($0.frame.midY - midY) < 12 }
            .sorted { $0.frame.minX < $1.frame.minX }
    }

    // MARK: - Preset picker

    @MainActor
    private func openPresetPicker(in app: XCUIApplication) {
        let control = app.buttons.labeled("Preset")
        XCTAssertTrue(control.waitForExistence(timeout: 5), "New Block has no Preset control to pick a preset with")
        UITestNavigation.reveal(control, in: app)
        UITestNavigation.assertTapTarget(control)
        control.tap()
        XCTAssertTrue(row("BLANK", in: app).waitForExistence(timeout: 5), "The preset picker never opened")
    }

    @MainActor
    private func pickPreset(_ label: String, in app: XCUIApplication) {
        openPresetPicker(in: app)
        UITestNavigation.hittable(app.buttons, label).tap()
        XCTAssertTrue(row("BLANK", in: app).waitForNonExistence(timeout: 5), "Picking \(label) must close the picker")
    }

    /// A picker row. Program's rows end in "›", which joins the label.
    @MainActor
    private func row(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ==[c] %@ OR label BEGINSWITH[c] %@", label, label + ",")).firstMatch
    }

    /// Every label is a button, top to bottom in this order.
    @MainActor
    private func assertListed(_ labels: [String], in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        var lastY = -CGFloat.infinity
        for label in labels {
            let element = row(label, in: app)
            XCTAssertTrue(element.waitForExistence(timeout: 5), "The picker must list \(label)", file: file, line: line)
            XCTAssertGreaterThan(element.frame.minY, lastY, "\(label) is out of catalog order", file: file, line: line)
            lastY = element.frame.minY
        }
    }
}
