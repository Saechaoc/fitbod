//
//  MuscleVolumeTargetEditorUITests.swift
//  fitbodUITests
//
//  Phase 5 SET-05 — smoke test that the Settings sheet's "Volume
//  Targets" surface is reachable, expanding a muscle reveals the
//  Stepper editor, and the global "Reset All to RP Defaults" button
//  is present.
//
//  Full round-trip (edit MEV → back out → re-enter → assert
//  persistence) is hard to drive reliably across simulator runs
//  because Stepper button accessibility identifiers vary. The
//  algorithmic round-trip is pinned at the data layer via
//  MuscleVolumeTargetSeederTests (5 GREEN tests).
//
//  T109: each test launches on a reset store through
//  UITestNavigation.launch (finding F304), and Chest's targets open on
//  BRU steppers.
//

import XCTest

final class MuscleVolumeTargetEditorUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testVolumeTargetsSectionReachable() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.openSettings(in: app)

        // Two static texts read "Volume Targets" (the Section header AND
        // the NavigationLink label). Use the predicate to pick the first
        // visible one.
        let header = app.staticTexts.matching(
            NSPredicate(format: "label ==[c] 'Volume Targets'")
        ).firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 10))
    }

    @MainActor
    func testNavigateToEditorAndExpandChest() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.openSettings(in: app)

        // Tap the row labeled "Volume Targets" to navigate.
        let row = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Volume Targets' AND label CONTAINS[c] '17 muscles'")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        UITestNavigation.reveal(row, in: app)
        row.tap()

        // BRU header bar replaces system navigation bar — assert the BRUHeaderBar
        // center Text element "Volume Targets" is present rather than a nav bar title.
        let headerText = app.staticTexts.matching(
            NSPredicate(format: "label ==[c] 'Volume Targets'")
        ).firstMatch
        XCTAssertTrue(headerText.waitForExistence(timeout: 5),
                      "BRUHeaderBar center 'Volume Targets' must be visible")

        // T109: Chest opens its four targets on BRU steppers, with no
        // stock iOS stepper. Its MRV stepper is the last of them; before
        // T109 the stock stepper and its two lines of text all carried
        // its VoiceOver label. The row reads whether it is open, unlike
        // Chest's volume bar under the sheet.
        let chest = app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH[c] %@ AND value == %@", "Chest", "Collapsed"
        )).firstMatch
        UITestNavigation.reveal(chest, in: app)
        chest.tap()
        let mrv = app.descendants(matching: .any).matching(NSPredicate(
            format: "label == %@", "Maximum recoverable volume for Chest"
        )).firstMatch
        XCTAssertTrue(mrv.waitForExistence(timeout: 5), "Chest must open its targets")
        UITestNavigation.reveal(mrv, in: app)
        UITestNavigation.saveScreenshot("T109", "volume-targets-chest")
        XCTAssertEqual(app.steppers.count, 0, "Chest's targets must use BRU steppers, not the stock iOS stepper")
        XCTAssertTrue(app.otherElements["Maintenance volume for Chest"].exists, "Missing Chest's BRU MV stepper")

        // Reset All destructive button should be present at the bottom.
        let resetAll = app.buttons["Reset All to RP Defaults"]
        // Scroll until visible.
        for _ in 0..<8 where !resetAll.exists {
            app.swipeUp()
        }
        XCTAssertTrue(resetAll.waitForExistence(timeout: 5))
    }
}
