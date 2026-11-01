import XCTest

extension UITestNavigation {
    /// A fresh store plus a routine whose session sits on an active block
    /// (ActiveBlockSeed).
    static let activeBlock = [resetFlag, "-fitbod-seed-active-block"]
}

/// Ticket T67, findings F48 and F49. Ending a block and changing its
/// routine go through BlockLifecycleService. END BLOCK, reached from
/// Today's block band, completes the block: Program lists it as done and
/// Today has no active block. (BlockCard's own End Block is not in the
/// app, so F48 was not reproduced.) A draft block still takes a routine in
/// EDIT BLOCK.
final class BlockLifecycleEntryPointsUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - END BLOCK

    /// Today's band opens the active block's overview, whose END BLOCK asks
    /// first and then ends the block.
    @MainActor
    func testEndBlockFromTodaysBandCompletesTheBlock() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        openActiveBlockOverview(in: app)
        UITestNavigation.hittable(app.buttons, "END BLOCK").tap()
        let alert = app.alerts["End block?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "END BLOCK must ask before it ends the block")
        alert.buttons["End Block"].tap()
        XCTAssertTrue(app.buttons.labeled("END BLOCK").waitForNonExistence(timeout: 5),
                      "An ended block offers no END BLOCK")
        UITestNavigation.hittable(app.buttons, "Back").tap()
        // T70: Today opens the ended block's review; Plan custom puts it off.
        let review = app.staticTexts.labeled("Block review")
        UITestNavigation.hittable(app.buttons, "Plan custom").tap()
        XCTAssertTrue(review.waitForNonExistence(timeout: 5), "Plan custom must close the review")
        assertNoActiveBlockOnToday(in: app)

        UITestNavigation.selectTab("Program", in: app)
        XCTAssertTrue(app.buttons.labeled("DONE block: Live Block").waitForExistence(timeout: 10),
                      "Program must list the ended block as completed")
        XCTAssertFalse(app.buttons.labeled("READY block: Live Block").exists,
                       "An ended block must not drop back to ready")
        XCTAssertFalse(activeBlockCards(in: app).firstMatch.exists, "Program must list no active block")
        UITestNavigation.saveScreenshot("T67", "program-ended-block")

        // Reopened, the app reads the block back as ended, and the review
        // the lifter put off opens again.
        UITestNavigation.relaunch(app)
        UITestNavigation.hittable(app.buttons, "Plan custom").tap()
        XCTAssertTrue(review.waitForNonExistence(timeout: 5), "Plan custom must close the review")
        assertNoActiveBlockOnToday(in: app)
        UITestNavigation.selectTab("Program", in: app)
        XCTAssertTrue(app.buttons.labeled("DONE block: Live Block").waitForExistence(timeout: 10),
                      "The ended block must stay completed after a relaunch")
    }

    // MARK: - EDIT BLOCK routine

    /// A draft block still takes a routine in EDIT BLOCK, which then offers
    /// SWAP, and SAVE CHANGES leaves the block ready.
    @MainActor
    func testEditBlockStillGivesADraftBlockARoutine() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.hittable(app.buttons, "+ NEW").tap()
        UITestNavigation.hittable(app.buttons, "+ New block").tap()
        UITestNavigation.hittable(app.buttons, "Blank Block").tap()
        let newBlock = app.staticTexts.labeled("NEW BLOCK")
        XCTAssertTrue(newBlock.waitForExistence(timeout: 10), "New Block never opened")
        UITestNavigation.type("Next Block", into: app.textFields.firstMatch)
        UITestNavigation.hittable(app.buttons, "SAVE DRAFT").tap()
        XCTAssertTrue(newBlock.waitForNonExistence(timeout: 5), "SAVE DRAFT must close New Block")

        let draft = app.buttons.labeled("DRAFT block: Next Block")
        XCTAssertTrue(draft.waitForExistence(timeout: 10), "Program must list the new block as a draft")
        UITestNavigation.reveal(draft, in: app)
        draft.tap()
        UITestNavigation.hittable(app.buttons, "EDIT").tap()
        XCTAssertTrue(editBlockTitle(in: app).waitForExistence(timeout: 10), "EDIT must open EDIT BLOCK")
        pickRoutine("Live Routine", from: "+ ATTACH ▸", in: app)
        UITestNavigation.revealAboveBottomBar(app.buttons, "SWAP ▸", in: app)
        UITestNavigation.saveScreenshot("T67", "edit-draft-block-routine")
        UITestNavigation.hittable(app.buttons, "SAVE CHANGES").tap()
        XCTAssertTrue(editBlockTitle(in: app).waitForNonExistence(timeout: 5), "SAVE CHANGES must close EDIT BLOCK")

        UITestNavigation.hittable(app.buttons, "Back").tap()
        XCTAssertTrue(app.buttons.labeled("READY block: Next Block").waitForExistence(timeout: 10),
                      "With a routine, Program must list the block as ready")
    }

    // MARK: - Helpers

    /// Today's band for the seeded active block opens its overview.
    @MainActor
    private func openActiveBlockOverview(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        UITestNavigation.selectTab("Today", in: app)
        let band = app.staticTexts.labeled("LIVE BLOCK")
        XCTAssertTrue(band.waitForExistence(timeout: 10), "Today must show the active block's band", file: file, line: line)
        band.tap()
        XCTAssertTrue(app.buttons.labeled("END BLOCK").waitForExistence(timeout: 10),
                      "The band must open the active block's overview", file: file, line: line)
    }

    /// Today drops the block band and says it has no active block.
    @MainActor
    private func assertNoActiveBlockOnToday(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        UITestNavigation.selectTab("Today", in: app)
        XCTAssertTrue(app.staticTexts.labeled("No active block.").waitForExistence(timeout: 10),
                      "Today must say it has no active block", file: file, line: line)
        XCTAssertFalse(app.staticTexts.labeled("LIVE BLOCK").exists,
                       "Today must drop the ended block's band", file: file, line: line)
    }

    /// Program's block cards for active blocks, read as "ACTIVE block: …".
    @MainActor
    private func activeBlockCards(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "ACTIVE block:"))
    }

    @MainActor
    private func editBlockTitle(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.labeled("EDIT BLOCK")
    }

    /// Opens the routine picker with `control` and picks `routine`.
    @MainActor
    private func pickRoutine(
        _ routine: String, from control: String, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        UITestNavigation.revealAboveBottomBar(app.buttons, control, in: app, file: file, line: line).tap()
        let picker = app.staticTexts.labeled("Choose Routine")
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "\(control) must open the routine picker", file: file, line: line)
        UITestNavigation.hittable(app.buttons, routine, file: file, line: line).tap()
        XCTAssertTrue(picker.waitForNonExistence(timeout: 5), "Picking \(routine) must close the routine picker",
                      file: file, line: line)
    }
}
