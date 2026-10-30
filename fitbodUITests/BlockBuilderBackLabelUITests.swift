import XCTest

/// Ticket T69, finding F52. The block builder's back control names the tab
/// it opened from. Today opens the builder for EDIT BLOCK on its block
/// overview and for Start a block, so there it reads "< TODAY"; Program's
/// New Block keeps the mock's "< PROGRAM". The back control still asks
/// before it throws edits away.
final class BlockBuilderBackLabelUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// EDIT BLOCK from Today's block overview reads "< TODAY", asks before
    /// it drops an edit, and goes back to the overview on Today.
    @MainActor
    func testEditBlockFromTodayNamesToday() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        UITestNavigation.selectTab("Today", in: app)
        let band = app.staticTexts.labeled("LIVE BLOCK")
        XCTAssertTrue(band.waitForExistence(timeout: 10), "Today must show the active block's band")
        band.tap()
        UITestNavigation.hittable(app.buttons, "EDIT BLOCK ▸").tap()
        let title = app.staticTexts.labeled("EDIT BLOCK")
        XCTAssertTrue(title.waitForExistence(timeout: 10), "EDIT BLOCK ▸ must open EDIT BLOCK")
        saveBuilderScreenshot("edit-block-from-today", in: app)
        assertBackControl(reads: "< TODAY", not: "< PROGRAM", in: app)

        let fixedWeekly = UITestNavigation.revealAboveBottomBar(app.buttons, "FIXED WEEKLY scheduling", in: app)
        fixedWeekly.tap()
        XCTAssertTrue(fixedWeekly.isSelected, "FIXED WEEKLY must take the edit")
        let dialog = app.staticTexts.labeled("Discard changes?")
        UITestNavigation.hittable(app.buttons, "< TODAY").tap()
        XCTAssertTrue(dialog.waitForExistence(timeout: 5), "< TODAY must ask before it throws an edit away")
        UITestNavigation.hittable(app.buttons, "Keep editing").tap()
        XCTAssertTrue(dialog.waitForNonExistence(timeout: 5), "Keep editing must close the dialog")
        XCTAssertTrue(title.isHittable, "Keep editing must leave EDIT BLOCK open")
        XCTAssertTrue(fixedWeekly.isSelected, "Keep editing must keep the edit")

        UITestNavigation.hittable(app.buttons, "< TODAY").tap()
        XCTAssertTrue(dialog.waitForExistence(timeout: 5), "< TODAY must still ask before it discards")
        UITestNavigation.hittable(app.buttons, "Discard").tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 5), "Discard must close EDIT BLOCK")
        XCTAssertTrue(UITestNavigation.hittable(app.buttons, "END BLOCK").exists, "< TODAY must go back to the block's overview")
        XCTAssertTrue(UITestNavigation.tab("Today", in: app).isSelected, "< TODAY must leave the lifter on Today")
    }

    /// Today's Start a block opens New Block with "< TODAY".
    @MainActor
    func testNewBlockFromTodayNamesToday() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Today", in: app)
        let start = app.buttons.labeled("Start a block")
        UITestNavigation.reveal(start, in: app)
        start.tap()
        XCTAssertTrue(app.staticTexts.labeled("NEW BLOCK").waitForExistence(timeout: 10),
                      "Start a block must open New Block")
        saveBuilderScreenshot("new-block-from-today", in: app)
        assertBackControl(reads: "< TODAY", not: "< PROGRAM", in: app)
    }

    /// Program's New Block keeps the mock's "< PROGRAM".
    @MainActor
    func testNewBlockFromProgramNamesProgram() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.hittable(app.buttons, "+ NEW").tap()
        UITestNavigation.hittable(app.buttons, "+ New block").tap()
        UITestNavigation.hittable(app.buttons, "Blank Block").tap()
        XCTAssertTrue(app.staticTexts.labeled("NEW BLOCK").waitForExistence(timeout: 10), "New Block never opened")
        saveBuilderScreenshot("new-block-from-program", in: app)
        assertBackControl(reads: "< PROGRAM", not: "< TODAY", in: app)
    }

    // MARK: - Helpers

    /// Saves a screenshot once the builder's CANCEL can be tapped, so the
    /// builder has finished sliding up.
    @MainActor
    private func saveBuilderScreenshot(_ screen: String, in app: XCUIApplication) {
        UITestNavigation.hittable(app.buttons, "Cancel")
        UITestNavigation.saveScreenshot("T69", screen)
    }

    /// The builder's back control reads `label`, never `other`, and stays a
    /// 44pt tap target.
    @MainActor
    private func assertBackControl(
        reads label: String, not other: String, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let back = app.buttons.labeled(label)
        XCTAssertTrue(back.waitForExistence(timeout: 5), "The back control must read \(label)", file: file, line: line)
        XCTAssertFalse(app.buttons.labeled(other).exists, "The back control must not read \(other)",
                       file: file, line: line)
        UITestNavigation.assertTapTarget(back, file: file, line: line)
    }
}
