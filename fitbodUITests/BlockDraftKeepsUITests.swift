import XCTest

/// F300: New Block and EDIT BLOCK lost the lifter's draft when the screen
/// behind them redrew. Their presenters build a fresh draft each time they
/// redraw, and Program redraws when a field starts editing and the keyboard
/// comes up, so focusing the name field emptied a preset's name and phases
/// and dropped edits made to a saved block. The builder keeps the draft it
/// opened with until it closes.
final class BlockDraftKeepsUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Use Preset, then Generic Strength Meso: the name field taking focus
    /// emptied the name, turned SAVE DRAFT off and put back the blank
    /// block's phases, so TOTAL WEEKS went from 8 to 5.
    @MainActor
    func testPresetKeepsItsNameAndWeeksWhenTheNameFieldTakesFocus() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.hittable(app.buttons, "+ NEW").tap()
        UITestNavigation.hittable(app.buttons, "+ New block").tap()
        UITestNavigation.hittable(app.buttons, "Use Preset").tap()
        let preset = "GENERIC STRENGTH MESO"
        let row = app.buttons.matching(NSPredicate(
            format: "label ==[c] %@ OR label BEGINSWITH[c] %@", preset, preset + ","
        )).firstMatch
        XCTAssertTrue(row.exists || row.waitForExistence(timeout: 10), "CHOOSE PRESET must list \(preset)")
        UITestNavigation.reveal(row, in: app)
        row.tap()
        let title = app.staticTexts.labeled("NEW BLOCK")
        XCTAssertTrue(title.exists || title.waitForExistence(timeout: 10), "New Block never opened")

        let opened = ShownDraft(name: "Generic Strength Meso", totalWeeks: "8")
        // New Block applies the preset once it is up.
        waitUntil { self.shownDraft(in: app) == opened }
        XCTAssertEqual(shownDraft(in: app), opened, "Use Preset must open the preset's name and its 8 weeks")

        focusName(in: app)
        UITestNavigation.saveScreenshot("T130", "preset-name-focused")
        XCTAssertEqual(shownDraft(in: app), opened, "The name field taking focus must keep the preset's name and phases")
        XCTAssertTrue(app.buttons.labeled("SAVE DRAFT").isEnabled, "SAVE DRAFT must stay on while the block has its name")
    }

    /// EDIT BLOCK on a draft block: a phase's weeks, changed in the duration
    /// sheet, stay after the name field takes focus.
    @MainActor
    func testEditBlockKeepsAPhaseEditWhenTheNameFieldTakesFocus() throws {
        let app = UITestNavigation.launch(UITestNavigation.blockStates)
        UITestNavigation.selectTab("Program", in: app)
        // The seed's draft block, with one 4-week phase.
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "DRAFT block: Autumn Block")).firstMatch
        XCTAssertTrue(card.exists || card.waitForExistence(timeout: 10), "Program must list the draft Autumn Block")
        UITestNavigation.reveal(card, in: app)
        card.tap()
        UITestNavigation.hittable(app.buttons, "EDIT", exactLabel: true).tap()
        let title = app.staticTexts.labeled("EDIT BLOCK")
        XCTAssertTrue(title.exists || title.waitForExistence(timeout: 10), "EDIT must open EDIT BLOCK")
        XCTAssertEqual(shownDraft(in: app), ShownDraft(name: "Autumn Block", totalWeeks: "4"), "EDIT BLOCK must open the saved block")

        totalWeeksButton(in: app).tap()
        let duration = app.staticTexts.labeled("Edit Block Duration")
        XCTAssertTrue(duration.exists || duration.waitForExistence(timeout: 5), "TOTAL WEEKS must open the duration sheet")
        // The sheet's one phase row is its only + stepper.
        UITestNavigation.hittable(app.buttons, "+", exactLabel: true).tap()
        UITestNavigation.hittable(app.buttons, "Done", exactLabel: true).tap()
        XCTAssertTrue(!duration.exists || duration.waitForNonExistence(timeout: 5), "Done must close the duration sheet")
        let edited = ShownDraft(name: "Autumn Block", totalWeeks: "5")
        XCTAssertEqual(shownDraft(in: app), edited, "The duration sheet's + must add a week to the phase")

        focusName(in: app)
        UITestNavigation.saveScreenshot("T130", "edit-block-name-focused")
        XCTAssertEqual(shownDraft(in: app), edited, "The name field taking focus must keep the phase's added week")
    }

    // MARK: - Reading the builder

    /// The draft as the builder shows it: its name and its TOTAL WEEKS.
    private struct ShownDraft: Equatable, CustomStringConvertible {
        let name: String
        let totalWeeks: String

        var description: String { "name \"\(name)\", TOTAL WEEKS \(totalWeeks)" }
    }

    @MainActor
    private func shownDraft(in app: XCUIApplication) -> ShownDraft {
        let weeks = totalWeeksButton(in: app)
        // The button reads "Total weeks, 8, edit phase durations".
        let parts = weeks.exists ? weeks.label.components(separatedBy: ", ") : []
        return ShownDraft(
            name: nameField(in: app).value as? String ?? "",
            totalWeeks: parts.count > 1 ? parts[1] : "missing"
        )
    }

    /// The builder's only text field. It has no label; its placeholder
    /// "NAME YOUR BLOCK" is a separate text.
    @MainActor
    private func nameField(in app: XCUIApplication) -> XCUIElement {
        app.textFields.firstMatch
    }

    @MainActor
    private func totalWeeksButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Total weeks, ")).firstMatch
    }

    /// Taps the name field near its trailing edge, the way a lifter starts
    /// editing the name, and waits until the keyboard is up: by then the
    /// editing has redrawn the screen behind the builder.
    @MainActor
    private func focusName(in app: XCUIApplication) {
        let field = nameField(in: app)
        XCTAssertTrue(field.exists || field.waitForExistence(timeout: 10), "The builder must show its name field")
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        // XCUI reads keyboard focus only through a predicate.
        let editing = NSPredicate(format: "hasKeyboardFocus == true")
        XCTAssertTrue(waitUntil { editing.evaluate(with: field) }, "A tap must start editing the name")
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.exists || keyboard.waitForExistence(timeout: 5), "Editing the name must bring up the keyboard")
        UITestNavigation.waitUntilStill(keyboard)
    }

    /// Polls `condition` every 100 ms until it holds or `timeout`, a
    /// ceiling, runs out, and returns whether it held.
    @MainActor
    @discardableResult
    private func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while !condition() {
            guard Date.now < deadline else { return false }
            // The poll step the test guide asks for.
            Thread.sleep(forTimeInterval: 0.1)
        }
        return true
    }
}
