// PlateCalculatorSheetBRUUITests.swift
// fitbodUITests
//
// Phase 3.2 Plan 10 — BRU surface smoke tests for PlateCalculatorSheet.
// UI-REVIEW Phase 3.2 / UI-SPEC § PlateCalculatorSheet (lines 240–256).
//
// PURPOSE: Verify that PlateCalculatorSheet is reachable from Settings and
// renders the BRU target display band ("TARGET") and plate stack zone
// ("PER SIDE") via accessibility. These are compile-and-launch smoke checks.
//
// NAVIGATION PATH:
//   Settings sheet → Smart Progression section → "Plate Inventory" row →
//   PlateInventoryEditor → "•••" header button → PlateCalculatorSheet
//
// CONTRACT ENFORCER: The actual view-instantiation contract (init signature,
// BRU token compile-time resolution) is enforced by
// Phase3BRUSurfacesTests.plateCalculatorSheetInstantiates in fitbodTests/.
// These UI tests are smoke tests proving end-to-end navigation wiring only.
//
// Mirrors SessionLoggerBRUUITests.swift helpers (waitForSeedComplete).
//

import XCTest

final class PlateCalculatorSheetBRUUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    /// Wait for the seed splash to disappear before interacting with tabs.
    @MainActor
    private func waitForSeedComplete(_ app: XCUIApplication, timeout: TimeInterval = 60) {
        let splash = app.staticTexts["Preparing library…"]
        if splash.exists {
            let pred = NSPredicate(format: "exists == false")
            let exp = XCTNSPredicateExpectation(predicate: pred, object: splash)
            _ = XCTWaiter().wait(for: [exp], timeout: timeout)
        }
    }

    /// Navigate to Settings sheet.
    @MainActor
    private func selectSettingsTab(_ app: XCUIApplication) {
        UITestNavigation.openSettings(in: app)
    }

    /// Navigate into PlateInventoryEditor from Settings → "Plate Inventory" row.
    /// Returns true if navigation succeeded.
    @MainActor
    @discardableResult
    private func navigateToPlateInventory(_ app: XCUIApplication) -> Bool {
        let plateInventoryRow = app.staticTexts["Plate Inventory"]
        guard plateInventoryRow.waitForExistence(timeout: 10) else {
            return false
        }
        UITestNavigation.reveal(plateInventoryRow, in: app)
        plateInventoryRow.tap()
        return true
    }

    /// Tap the "•••" BRUHeaderBar button in PlateInventoryEditor to open
    /// PlateCalculatorSheet.
    @MainActor
    @discardableResult
    private func tapPlateCalculatorMenu(_ app: XCUIApplication) -> Bool {
        // PlateInventoryEditor BRUHeaderBar right action is "•••"
        // (PlateInventoryEditor.swift line 60: HeaderAction("•••") { showCalculatorSheet = true })
        let menuButton = app.buttons["More"]
        guard menuButton.waitForExistence(timeout: 8) else {
            return false
        }
        menuButton.tap()
        return true
    }

    // MARK: - Tests

    /// Smoke test 1: Settings → Plate Inventory → "•••" opens PlateCalculatorSheet
    /// and the "TARGET" label (target display band) is visible.
    ///
    /// The "Target" label in PlateCalculatorSheet is rendered via
    /// `.textCase(.uppercase)` on "Target" (PlateCalculatorSheet.swift line 181).
    /// NSPredicate matches both "Target" and "TARGET" (accessibility layer may
    /// vary casing on .textCase-modified labels).
    @MainActor
    func testPlateCalculatorReachableFromSettings() throws {
        let app = XCUIApplication()
        app.launch()
        waitForSeedComplete(app)
        selectSettingsTab(app)

        guard navigateToPlateInventory(app) else {
            XCTFail(
                "Settings → Plate Inventory row not found — seed may not be complete " +
                "or Smart Progression section is not visible on this simulator state. " +
                "BRU contract enforced by Phase3BRUSurfacesTests.plateCalculatorSheetInstantiates."
            )
            return
        }

        guard tapPlateCalculatorMenu(app) else {
            XCTFail(
                "'•••' button not found in PlateInventoryEditor header — " +
                "may require plates to be seeded first. " +
                "BRU contract enforced by Phase3BRUSurfacesTests.plateCalculatorSheetInstantiates."
            )
            return
        }

        // Assert that the TARGET display band is visible in the calculator sheet.
        // PlateCalculatorSheet.targetBand renders Text("Target").textCase(.uppercase)
        // so accessibility label may be "Target" or "TARGET" depending on iOS rendering.
        let targetPredicate = NSPredicate(format: "label CONTAINS[c] 'target'")
        let targetLabel = app.staticTexts.element(matching: targetPredicate)
        let targetVisible = targetLabel.waitForExistence(timeout: 10)
        XCTAssertTrue(targetVisible,
            "PlateCalculatorSheet 'TARGET' display band not visible — " +
            "BRU targetBand section may have regressed")
    }

    /// Smoke test 2: Settings → Plate Inventory → "•••" opens PlateCalculatorSheet
    /// and the "PER SIDE" label (plate stack zone) is visible.
    ///
    /// The "PER SIDE" label is rendered in PlateCalculatorSheet.plateStackZone
    /// (PlateCalculatorSheet.swift line 271: 03-UI-SPEC line 245 / plate-calc.jsx lines 48-49).
    @MainActor
    func testPlateCalculatorPerSideZoneVisible() throws {
        let app = XCUIApplication()
        app.launch()
        waitForSeedComplete(app)
        selectSettingsTab(app)

        guard navigateToPlateInventory(app) else {
            XCTFail(
                "Settings → Plate Inventory row not found. " +
                "PER SIDE zone contract enforced by Phase3BRUSurfacesTests.plateCalculatorSheetInstantiates."
            )
            return
        }

        guard tapPlateCalculatorMenu(app) else {
            XCTFail(
                "'•••' button not found in PlateInventoryEditor. " +
                "PER SIDE zone contract enforced by Phase3BRUSurfacesTests.plateCalculatorSheetInstantiates."
            )
            return
        }

        // Assert that the PER SIDE plate stack zone label is visible.
        // PlateCalculatorSheet.plateStackZone renders Text("PER SIDE")
        // (PlateCalculatorSheet.swift line ~271).
        let perSidePredicate = NSPredicate(format: "label CONTAINS[c] 'per side'")
        let perSideLabel = app.staticTexts.element(matching: perSidePredicate)
        let perSideVisible = perSideLabel.waitForExistence(timeout: 10)
        XCTAssertTrue(perSideVisible,
            "PlateCalculatorSheet 'PER SIDE' plate stack zone not visible — " +
            "BRU plateStackZone section may have regressed")
    }

    // MARK: - Header (T19)

    /// Ticket T19. Review items 43, 37 and 25. The calculator is a sheet
    /// that only shows information, so "Plate calculator" sits in the
    /// center of its header and DONE on the right, and DONE closes it. The
    /// bare "‹", "•••", footer Save and footer Done are gone.
    @MainActor
    func testDoneClosesTheCalculator() throws {
        try assertDoneClosesTheCalculator(textSize: .default)
    }

    /// At AX3 the header stacks "Plate calculator" over DONE, and DONE
    /// still closes the sheet.
    @MainActor
    func testDoneClosesTheCalculatorAtAX3() throws {
        try assertDoneClosesTheCalculator(textSize: .ax3)
    }

    // MARK: - Values (T19)

    /// On the small phone at default text the −2.5 chip read "−2." over
    /// "5". Each quick-adjust chip stays one line tall, and no value on the
    /// sheet splits a number across lines.
    @MainActor
    func testValuesStayWhole() throws {
        try assertValuesStayWhole(textSize: .default)
    }

    /// The same at AX3.
    @MainActor
    func testValuesStayWholeAtAX3() throws {
        try assertValuesStayWhole(textSize: .ax3)
    }

    // MARK: - T19 helpers

    /// Settings → Plate Inventory → ••• on a fresh store at `textSize`,
    /// once the sheet has stopped moving. Returns the sheet's title.
    @MainActor
    private func openCalculator(
        textSize: UITestNavigation.TextSize, file: StaticString = #filePath, line: UInt = #line
    ) -> (app: XCUIApplication, title: XCUIElement) {
        let app = UITestNavigation.launch(UITestNavigation.freshStore, textSize: textSize, file: file, line: line)
        UITestNavigation.openSettings(in: app)
        let inventory = app.buttons.labeled("Plate Inventory")
        _ = inventory.waitForExistence(timeout: 10)
        UITestNavigation.reveal(inventory, in: app)
        inventory.tap()
        XCTAssertTrue(app.otherElements["plateInventory.tabStrip"].waitForExistence(timeout: 10),
                      "Plate Inventory must open", file: file, line: line)
        UITestNavigation.hittable(app.buttons, "More", exactLabel: true, file: file, line: line).tap()
        let title = app.staticTexts.labeled("Plate calculator")
        XCTAssertTrue(title.waitForExistence(timeout: 10), "••• must open the plate calculator", file: file, line: line)
        UITestNavigation.waitUntilStill(title, interval: 0.3)
        return (app, title)
    }

    /// The tappable `label` button on the sheet whose title is `title`:
    /// the sheet leaves Plate Inventory's controls above and under it.
    @MainActor
    private func sheetButton(_ label: String, under title: XCUIElement, in app: XCUIApplication) -> XCUIElement? {
        app.buttons.matching(NSPredicate(format: "label ==[c] %@", label)).allElementsBoundByIndex
            .first { $0.isHittable && $0.frame.midY >= title.frame.minY - 10 }
    }

    @MainActor
    private func assertDoneClosesTheCalculator(
        textSize: UITestNavigation.TextSize, file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let (app, title) = openCalculator(textSize: textSize, file: file, line: line)
        UITestNavigation.saveScreenshot("T19", "calculator-header", textSize: textSize)

        let leftovers = ["Back", "More", "Save inventory", "Done ▸"].filter { sheetButton($0, under: title, in: app) != nil }
        XCTAssertEqual(leftovers, [], "The calculator must show no ‹, •••, Save or footer Done", file: file, line: line)
        XCTAssertFalse(app.buttons.labeled("Save inventory").exists, "No Save inventory may be left", file: file, line: line)
        let done = try XCTUnwrap(sheetButton("Done", under: title, in: app), "The calculator's header must show DONE",
                                 file: file, line: line)
        let shown = UITestNavigation.latin(try UITestNavigation.readText(in: done.frame, of: XCUIScreen.main.screenshot()))
        XCTAssertTrue(shown.contains("DONE"), "DONE must read DONE, but reads \"\(shown)\"", file: file, line: line)
        let window = app.windows.firstMatch
        UITestNavigation.assertInside(title, window, file: file, line: line)
        UITestNavigation.assertInside(done, window, file: file, line: line)
        // A medium sheet lays out at the window's width and draws inset, so
        // on screen its 44pt target shrinks by the sheet's width over the
        // window's: 374 over 390 on the small phone.
        let sheet = try XCTUnwrap(app.scrollViews.allElementsBoundByIndex.last { $0.isHittable },
                                  "The calculator must scroll", file: file, line: line)
        UITestNavigation.assertTapTarget(done, minimum: 44 * sheet.frame.width / window.frame.width, file: file, line: line)
        if textSize == .default {
            UITestNavigation.assertNoOverlap(title, done, file: file, line: line)
            XCTAssertEqual(title.frame.midX, window.frame.midX, accuracy: 1,
                           "Plate calculator must sit in the center of the header", file: file, line: line)
            XCTAssertGreaterThan(done.frame.midX, title.frame.maxX, "DONE must sit right of the title", file: file, line: line)
            XCTAssertEqual(done.frame.midY, title.frame.midY, accuracy: 2, "DONE must share the title's row", file: file, line: line)
        } else {
            XCTAssertLessThanOrEqual(title.frame.maxY, done.frame.midY, "At AX3 the title must sit over DONE", file: file, line: line)
            XCTAssertGreaterThan(done.frame.midX, window.frame.midX, "DONE must sit on the right", file: file, line: line)
        }

        done.tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 10), "DONE must close the plate calculator", file: file, line: line)
        let strip = app.otherElements["plateInventory.tabStrip"]
        let back = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: strip)
        XCTAssertEqual(XCTWaiter().wait(for: [back], timeout: 10), .completed,
                       "DONE must return to Plate Inventory", file: file, line: line)
    }

    /// Scrolls the sheet to each value from the top down and checks it
    /// whole on screen. A chip is one line of TARGET's font inside 3pt of
    /// padding above and below, and the weight's font is three times its
    /// unit's. XCUI reads a whole label however its text wraps, so the
    /// numbers of the other values are read off a screenshot.
    @MainActor
    private func assertValuesStayWhole(
        textSize: UITestNavigation.TextSize, file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let (app, title) = openCalculator(textSize: textSize, file: file, line: line)
        let done = try XCTUnwrap(sheetButton("Done", under: title, in: app), "The calculator's header must show DONE",
                                 file: file, line: line)
        let top = max(title.frame.maxY, done.frame.maxY) + 4
        let bottom = app.windows.firstMatch.frame.maxY - 34
        UITestNavigation.saveScreenshot("T19", "calculator-values", textSize: textSize)

        let target = app.staticTexts.labeled("Target")
        let unit = app.staticTexts.labeled("LB")
        XCTAssertTrue(target.exists && unit.exists, "The calculator must show TARGET and its unit", file: file, line: line)
        let startsWith = { (prefix: String) in
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH[c] %@", prefix)).firstMatch
        }
        enum Check { case numbers, weight, chip }
        let chips = ["Subtract 5 lb", "Subtract 2.5 lb", "Add 2.5 lb", "Add 5 lb"].map { (app.buttons.labeled($0), Check.chip) }
        let values = [(startsWith("Bar "), Check.numbers), (app.staticTexts.labeled("60"), .weight)] + chips
            + [(startsWith("Olympic"), .numbers)]
        var problems: [String] = []
        for (index, (value, check)) in values.enumerated() {
            guard revealWhole(value, between: top, and: bottom, in: app) else {
                problems.append("\(value) never shows whole on the sheet")
                continue
            }
            switch check {
            case .weight:
                if let tall = UITestNavigation.heightProblem(value, atMost: unit.frame.height * 3 * 1.25) {
                    problems.append(tall + ", more than one line")
                }
            case .chip:
                if index == 3 {
                    UITestNavigation.saveScreenshot("T19", "calculator-chips", textSize: textSize)
                }
                if let tall = UITestNavigation.heightProblem(value, atMost: target.frame.height * 1.5 + 6) {
                    problems.append(tall + ", more than one line")
                }
                problems += try UITestNavigation.numberProblems(in: value)
            case .numbers:
                problems += try UITestNavigation.numberProblems(in: value)
            }
        }

        // The plate list ends the sheet, and its longest weights end it.
        for _ in 0..<6 {
            dragSheet(by: -(bottom - top - 40), from: bottom - 10, in: app)
        }
        UITestNavigation.saveScreenshot("T19", "calculator-plates", textSize: textSize)
        for weight in ["2.5", "1.25"] {
            // Plate Inventory's own row sits under the sheet, where no tap reaches it.
            let row = app.otherElements.matching(NSPredicate(format: "label == %@", "\(weight) lb plate"))
                .allElementsBoundByIndex.first { $0.isHittable && $0.frame.minY >= top && $0.frame.maxY <= bottom }
            guard let row else {
                problems.append("The \(weight) lb plate never shows whole at the end of the sheet")
                continue
            }
            problems += try UITestNavigation.numberProblems(in: row)
        }
        XCTAssertEqual(problems, [], "No calculator value may break inside a number", file: file, line: line)
    }

    /// Drags the sheet's content until `element` sits whole between `top`
    /// and `bottom`. False when it never does.
    @MainActor
    private func revealWhole(_ element: XCUIElement, between top: CGFloat, and bottom: CGFloat, in app: XCUIApplication) -> Bool {
        for _ in 0..<10 {
            guard element.exists else { return false }
            let frame = element.frame
            if frame.minY >= top && frame.maxY <= bottom { return true }
            if frame.maxY > bottom {
                dragSheet(by: -min(frame.maxY - bottom + 40, bottom - top - 40), from: bottom - 10, in: app)
            } else {
                dragSheet(by: min(top - frame.minY + 40, bottom - top - 40), from: top + 10, in: app)
            }
            UITestNavigation.waitUntilStill(element)
        }
        let frame = element.frame
        return frame.minY >= top && frame.maxY <= bottom
    }

    /// Drags the sheet's content `distance` points down, or up when it is
    /// negative, from `y` across the middle of the screen, and holds before
    /// it lets go so the content does not fling on.
    @MainActor
    private func dragSheet(by distance: CGFloat, from y: CGFloat, in app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 0, dy: y))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)),
                    withVelocity: .slow, thenHoldForDuration: 0.3)
    }
}
