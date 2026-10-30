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
        hittable(app.buttons, "EDIT BLOCK ▸").tap()
        let title = app.staticTexts.labeled("EDIT BLOCK")
        XCTAssertTrue(title.waitForExistence(timeout: 10), "EDIT BLOCK ▸ must open EDIT BLOCK")
        saveBuilderScreenshot("edit-block-from-today", in: app)
        assertBackControl(reads: "< TODAY", not: "< PROGRAM", in: app)

        let fixedWeekly = revealAboveBottomBar(app.buttons, "FIXED WEEKLY scheduling", in: app)
        fixedWeekly.tap()
        XCTAssertTrue(fixedWeekly.isSelected, "FIXED WEEKLY must take the edit")
        let dialog = app.staticTexts.labeled("Discard changes?")
        hittable(app.buttons, "< TODAY").tap()
        XCTAssertTrue(dialog.waitForExistence(timeout: 5), "< TODAY must ask before it throws an edit away")
        hittable(app.buttons, "Keep editing").tap()
        XCTAssertTrue(dialog.waitForNonExistence(timeout: 5), "Keep editing must close the dialog")
        XCTAssertTrue(title.isHittable, "Keep editing must leave EDIT BLOCK open")
        XCTAssertTrue(fixedWeekly.isSelected, "Keep editing must keep the edit")

        hittable(app.buttons, "< TODAY").tap()
        XCTAssertTrue(dialog.waitForExistence(timeout: 5), "< TODAY must still ask before it discards")
        hittable(app.buttons, "Discard").tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 5), "Discard must close EDIT BLOCK")
        XCTAssertTrue(hittable(app.buttons, "END BLOCK").exists, "< TODAY must go back to the block's overview")
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
        hittable(app.buttons, "+ NEW").tap()
        hittable(app.buttons, "+ New block").tap()
        hittable(app.buttons, "Blank Block").tap()
        XCTAssertTrue(app.staticTexts.labeled("NEW BLOCK").waitForExistence(timeout: 10), "New Block never opened")
        saveBuilderScreenshot("new-block-from-program", in: app)
        assertBackControl(reads: "< PROGRAM", not: "< TODAY", in: app)
    }

    // MARK: - Helpers

    /// Saves a screenshot once the builder's CANCEL can be tapped, so the
    /// builder has finished sliding up.
    @MainActor
    private func saveBuilderScreenshot(_ screen: String, in app: XCUIApplication) {
        hittable(app.buttons, "Cancel")
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

    /// Scrolls the builder until a tappable `label` sits above its bottom
    /// bar, which covers the end of the scroll view. A sheet leaves the
    /// screen under it in the tree, so only a tappable match counts.
    @MainActor
    private func revealAboveBottomBar(
        _ query: XCUIElementQuery, _ label: String, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement {
        // The bar's 52pt buttons sit 24pt below its top edge; CANCEL's frame is its text.
        let barTop = hittable(app.buttons, "Cancel", file: file, line: line).frame.midY - 50
        let matches = query.matching(NSPredicate(format: "label ==[c] %@", label))
        for _ in 0..<8 {
            if let match = matches.allElementsBoundByIndex.first(where: { $0.isHittable && $0.frame.maxY < barTop }) {
                return match
            }
            if let scroll = app.scrollViews.allElementsBoundByIndex.last(where: { $0.isHittable }) {
                scroll.swipeUp(velocity: .slow)
            } else {
                app.swipeUp(velocity: .slow)
            }
        }
        XCTFail("\(label) must scroll above the bottom bar", file: file, line: line)
        return matches.firstMatch
    }

    /// The match a user can tap: a sheet leaves same-named controls under it.
    @MainActor
    @discardableResult
    private func hittable(
        _ query: XCUIElementQuery, _ label: String,
        file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement {
        let matches = query.matching(NSPredicate(format: "label ==[c] %@ OR label BEGINSWITH[c] %@", label, label + ","))
        XCTAssertTrue(matches.firstMatch.waitForExistence(timeout: 10), "Missing \(label)", file: file, line: line)
        for _ in 0..<10 {
            if let match = matches.allElementsBoundByIndex.first(where: { $0.isHittable }) { return match }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTFail("No tappable \(label)", file: file, line: line)
        return matches.firstMatch
    }
}
