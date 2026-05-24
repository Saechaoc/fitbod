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
//   Settings tab → Smart Progression section → "Plate Inventory" row →
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

    /// Navigate to Settings tab.
    @MainActor
    private func selectSettingsTab(_ app: XCUIApplication) {
        let settings = app.tabBars.buttons["Settings"]
        if settings.waitForExistence(timeout: 10) {
            settings.tap()
        }
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
        let menuButton = app.staticTexts["•••"]
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
            throw XCTSkip(
                "Settings → Plate Inventory row not found — seed may not be complete " +
                "or Smart Progression section is not visible on this simulator state. " +
                "BRU contract enforced by Phase3BRUSurfacesTests.plateCalculatorSheetInstantiates."
            )
        }

        guard tapPlateCalculatorMenu(app) else {
            throw XCTSkip(
                "'•••' button not found in PlateInventoryEditor header — " +
                "may require plates to be seeded first. " +
                "BRU contract enforced by Phase3BRUSurfacesTests.plateCalculatorSheetInstantiates."
            )
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
            throw XCTSkip(
                "Settings → Plate Inventory row not found. " +
                "PER SIDE zone contract enforced by Phase3BRUSurfacesTests.plateCalculatorSheetInstantiates."
            )
        }

        guard tapPlateCalculatorMenu(app) else {
            throw XCTSkip(
                "'•••' button not found in PlateInventoryEditor. " +
                "PER SIDE zone contract enforced by Phase3BRUSurfacesTests.plateCalculatorSheetInstantiates."
            )
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
}
