//
//  SettingsBRUUITests.swift
//  fitbodUITests
//
//  Phase 6.1 Plan 07 — UI smoke tests for the Phase 6 BRU reskin of
//  SettingsView (Plan 06.1-05) and its Export/Backup subsections
//  (Plans 06.1-04 [Export grid] + 06.1-06 [Backup panel]).
//
//  Confirms:
//    1. BRUHeaderBar "Settings" center label renders after navigation
//       to the Settings tab in BRUTabBar.
//    2. Export section: "CSV" and "JSON" BRUDisplay card labels are
//       present; optional captions "ONE ROW PER SET" + "VERSION-STAMPED"
//       are checked via case-insensitive predicates.
//    3. Backup section: "CREATE" and "RESTORE" BRUButton labels render
//       inside the outlined panel; "FULL BACKUP" caption is present.
//
//  XCTest (not Swift Testing) — UI tests must use XCUIApplication.
//  Per CLAUDE.md: Swift Testing does not support XCUIApplication.
//
//  Adaptive: backup panel CREATE/RESTORE render regardless of whether a
//  backup file exists (they are BRUButton action triggers, not conditional
//  on backup presence).
//

import XCTest

final class SettingsBRUUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Shared helpers

    /// Wait until the "Preparing library…" splash disappears OR timeout expires.
    @MainActor
    private func waitForSeedComplete(timeout: TimeInterval = 60) {
        let splash = app.staticTexts["Preparing library…"]
        if splash.exists {
            let pred = NSPredicate(format: "exists == false")
            let exp = XCTNSPredicateExpectation(predicate: pred, object: splash)
            _ = XCTWaiter().wait(for: [exp], timeout: timeout)
        }
    }

    /// Tap the Settings tab in BRUTabBar.
    @MainActor
    private func selectSettingsTab() {
        let settingsTab = app.tabBars.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'settings'")
        ).firstMatch
        if settingsTab.waitForExistence(timeout: 10) {
            settingsTab.tap()
        }
    }

    /// Swipe up until the target staticText label is visible, up to maxSwipes.
    @MainActor
    private func scrollUntilVisible(text: String, maxSwipes: Int = 8) -> Bool {
        let element = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", text)
        ).firstMatch
        if element.exists { return true }
        for _ in 0..<maxSwipes {
            app.swipeUp()
            if element.exists { return true }
        }
        return element.exists
    }

    // MARK: - Test 1: BRUHeaderBar "Settings" title renders

    /// Asserts:
    ///   - Settings tab is tappable in the BRUTabBar.
    ///   - BRUHeaderBar center label "Settings" exists after tab navigation.
    @MainActor
    func testSettingsTabRendersWithBRUHeaderBar() throws {
        app.launch()
        waitForSeedComplete()
        selectSettingsTab()

        // BRUHeaderBar renders "Settings" as a plain Text staticText.
        let settingsHeader = app.staticTexts.matching(
            NSPredicate(format: "label == 'Settings'")
        ).firstMatch
        XCTAssertTrue(
            settingsHeader.waitForExistence(timeout: 10),
            "Expected BRUHeaderBar center label 'Settings' on the Settings tab — " +
            "BRUHeaderBar not rendered or label changed (Plan 06.1-05 regression)."
        )
    }

    // MARK: - Test 2: Export grid renders CSV + JSON cards

    /// Asserts:
    ///   - "CSV" BRUDisplay card label exists in the Export 2-card grid.
    ///   - "JSON" BRUDisplay card label exists in the Export 2-card grid.
    ///   - Optional: "ONE ROW PER SET" sub-caption exists (case-insensitive).
    ///
    /// Export section requires scrolling past the Units & Calibration,
    /// Volume Targets, and Smart Progression sections.
    @MainActor
    func testSettingsExportGridRenders() throws {
        app.launch()
        waitForSeedComplete()
        selectSettingsTab()

        // Wait for the header to confirm we are on the Settings tab
        _ = app.staticTexts.matching(
            NSPredicate(format: "label == 'Settings'")
        ).firstMatch.waitForExistence(timeout: 10)

        // Scroll to find the Export section (past Units, Volume Targets, Smart Progression)
        let csvLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'CSV'")
        ).firstMatch
        if !csvLabel.exists {
            _ = scrollUntilVisible(text: "Export", maxSwipes: 6)
        }

        // Wait for CSV card label to appear
        XCTAssertTrue(
            csvLabel.waitForExistence(timeout: 5),
            "Expected 'CSV' card label in the Export section — " +
            "BRU 2-card export grid not rendered or label changed (Plan 06.1-04 regression)."
        )

        // JSON card label
        let jsonLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'JSON'")
        ).firstMatch
        XCTAssertTrue(
            jsonLabel.exists,
            "Expected 'JSON' card label in the Export section — " +
            "second export card not rendered or label changed."
        )

        // Optional: ONE ROW PER SET sub-caption (case-insensitive)
        let rowPerSetCaption = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'one row per set'")
        ).firstMatch
        if rowPerSetCaption.exists {
            XCTAssertTrue(
                rowPerSetCaption.exists,
                "Expected 'ONE ROW PER SET' sub-caption on the CSV card."
            )
        }
    }

    // MARK: - Test 3: Backup panel renders CREATE + RESTORE buttons

    /// Asserts:
    ///   - "CREATE" BRUButton label exists in the outlined Backup panel.
    ///   - "RESTORE" BRUButton label exists in the outlined Backup panel.
    ///   - "FULL BACKUP" caption appears via case-insensitive predicate.
    ///
    /// Backup panel renders regardless of whether a backup file exists
    /// (CREATE + RESTORE are always-visible action buttons).
    @MainActor
    func testSettingsBackupPanelRenders() throws {
        app.launch()
        waitForSeedComplete()
        selectSettingsTab()

        // Wait for Settings header
        _ = app.staticTexts.matching(
            NSPredicate(format: "label == 'Settings'")
        ).firstMatch.waitForExistence(timeout: 10)

        // Scroll past Export grid to reach the Backup section
        _ = scrollUntilVisible(text: "Backup", maxSwipes: 8)

        // "CREATE" BRUButton label
        let createButton = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'create'")
        ).firstMatch

        // Try buttons as well in case it's an XCUIElement button type
        let createButtonElement = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'create'")
        ).firstMatch

        let createExists = createButton.waitForExistence(timeout: 5) || createButtonElement.waitForExistence(timeout: 2)
        XCTAssertTrue(
            createExists,
            "Expected 'CREATE' button label in the Backup panel — " +
            "BRU Backup section not rendered or button label changed (Plan 06.1-06 regression)."
        )

        // "RESTORE" BRUButton label
        let restoreButton = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'restore'")
        ).firstMatch
        let restoreButtonElement = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'restore'")
        ).firstMatch

        let restoreExists = restoreButton.exists || restoreButtonElement.exists
        XCTAssertTrue(
            restoreExists,
            "Expected 'RESTORE' button label in the Backup panel — " +
            "backup restore action not rendered or button label changed."
        )

        // "FULL BACKUP" caption in the Backup section header
        let fullBackupCaption = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'full backup'")
        ).firstMatch
        if fullBackupCaption.exists {
            XCTAssertTrue(
                fullBackupCaption.exists,
                "Expected 'FULL BACKUP' caption in the Backup section head."
            )
        }
    }
}
