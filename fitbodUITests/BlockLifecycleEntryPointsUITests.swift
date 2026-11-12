import XCTest

extension UITestNavigation {
    /// A fresh store plus a routine whose session sits on an active block
    /// (ActiveBlockSeed).
    static let activeBlock = [resetFlag, "-fitbod-seed-active-block"]
}

/// Ticket T67, findings F48 and F49. Ending a block and changing its
/// routine go through BlockLifecycleService. END BLOCK, reached from
/// Today's block band, completes the block and opens its review: Program
/// lists it under Past blocks and Today has no active block. (BlockCard's own End Block is not in the
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
        XCTAssertTrue(UITestNavigation.appears(alert, within: 5), "END BLOCK must ask before it ends the block")
        alert.buttons["End Block"].tap()
        // The review opens on the overview as soon as the block ends (B9),
        // and counts as seen once it has opened.
        let review = app.staticTexts.labeled("Block review")
        XCTAssertTrue(UITestNavigation.appears(review, within: 5), "Ending a block must open its review")
        // Start next opens New block on the first tap, with the ended
        // block's routine; CANCEL comes back to the review.
        UITestNavigation.hittable(app.buttons, "Start next ▸").tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts.labeled("NEW BLOCK"), within: 5),
                      "Start next must open New block on the first tap, not an empty sheet")
        XCTAssertTrue(app.staticTexts.labeled("Live Routine").exists, "Start next must keep the ended block's routine")
        UITestNavigation.hittable(app.buttons, "CANCEL", exactLabel: true).tap()
        XCTAssertTrue(UITestNavigation.appears(review, within: 5), "CANCEL must return to the review")
        UITestNavigation.hittable(app.buttons, "Back").tap()
        XCTAssertTrue(UITestNavigation.disappears(review, within: 5), "‹ BACK must close the review")
        XCTAssertFalse(app.buttons.labeled("END BLOCK").exists, "An ended block offers no END BLOCK")
        XCTAssertTrue(UITestNavigation.appears(app.buttons.labeled("REVIEW ▸")),
                      "A finished block's overview must reopen its review (B12)")
        UITestNavigation.hittable(app.buttons, "Back").tap()
        XCTAssertFalse(UITestNavigation.appears(review, within: 3), "A review already seen must not reopen on Today")
        assertNoActiveBlockOnToday(in: app)

        UITestNavigation.selectTab("Program", in: app)
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts.labeled("No block planned.")),
                      "With its one block ended, Program must say no block is planned")
        XCTAssertFalse(app.buttons.labeled("READY block: Live Block").exists,
                       "An ended block must not drop back to ready")
        XCTAssertFalse(activeBlockCards(in: app).firstMatch.exists, "Program must list no active block")
        UITestNavigation.openPastBlocks(in: app)
        XCTAssertTrue(UITestNavigation.appears(app.buttons.labeled("DONE block: Live Block")),
                      "Past blocks must list the ended block")

        // Reopened, the app reads the block back as ended, and the review,
        // already seen, stays closed.
        UITestNavigation.relaunch(app)
        XCTAssertFalse(UITestNavigation.appears(review, within: 3), "A seen review must not reopen after a relaunch")
        assertNoActiveBlockOnToday(in: app)
        UITestNavigation.openPastBlocks(in: app)
        XCTAssertTrue(UITestNavigation.appears(app.buttons.labeled("DONE block: Live Block")),
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
        XCTAssertTrue(UITestNavigation.appears(newBlock), "New Block never opened")
        UITestNavigation.type("Next Block", into: app.textFields.firstMatch)
        UITestNavigation.hittable(app.buttons, "SAVE DRAFT").tap()
        XCTAssertTrue(UITestNavigation.disappears(newBlock, within: 5), "SAVE DRAFT must close New Block")

        let draft = app.buttons.labeled("DRAFT block: Next Block")
        XCTAssertTrue(UITestNavigation.appears(draft), "Program must list the new block as a draft")
        UITestNavigation.reveal(draft, in: app)
        draft.tap()
        UITestNavigation.hittable(app.buttons, "EDIT").tap()
        XCTAssertTrue(UITestNavigation.appears(editBlockTitle(in: app)), "EDIT must open EDIT BLOCK")
        pickRoutine("Live Routine", from: "+ ATTACH ▸", in: app)
        UITestNavigation.revealAboveBottomBar(app.buttons, "SWAP ▸", in: app)
        UITestNavigation.hittable(app.buttons, "SAVE CHANGES").tap()
        XCTAssertTrue(UITestNavigation.disappears(editBlockTitle(in: app), within: 5), "SAVE CHANGES must close EDIT BLOCK")

        UITestNavigation.hittable(app.buttons, "Back").tap()
        XCTAssertTrue(UITestNavigation.appears(app.buttons.labeled("READY block: Next Block")),
                      "With a routine, Program must list the block as ready")
    }

    // MARK: - START BLOCK ▸ on Program

    /// Program's ready slab starts the block through the lifecycle service,
    /// as Today's T-READY does. A failed start shows "Couldn't start block"
    /// and saves nothing: read back after a relaunch, the block is still
    /// ready and none is active. Try again then starts it.
    @MainActor
    func testProgramStartFailureLeavesTheBlockReadyAndTryAgainStartsIt() throws {
        let failOnce = "-fitbod-fail-block-start-once"
        let app = UITestNavigation.launch(UITestNavigation.freshStore + ["-fitbod-seed-today-ready", failOnce])
        let start = app.buttons["today.startBlock"]
        let alert = app.alerts["Couldn't start block"]
        UITestNavigation.selectTab("Program", in: app)
        XCTAssertTrue(UITestNavigation.appears(start), "Program must lead with the ready block's START BLOCK ▸")
        start.tap()
        XCTAssertTrue(UITestNavigation.appears(alert), "A failed start must show the retry alert")

        // Reopened with the failure armed again, the store must still hold the block as ready.
        app.terminate()
        app.launchArguments = [UITestNavigation.resetSignalFlag, failOnce]
        app.launch()
        UITestNavigation.selectTab("Program", in: app)
        XCTAssertTrue(UITestNavigation.appears(start), "A failed start must leave the block ready")
        XCTAssertFalse(activeBlockCards(in: app).firstMatch.exists, "A failed start must start no block")
        start.tap()
        XCTAssertTrue(UITestNavigation.appears(alert), "A failed start must show the retry alert")
        alert.buttons["Try again"].tap()
        let started = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "ACTIVE block: Spring Block"))
        XCTAssertTrue(UITestNavigation.appears(started.firstMatch), "Try again must start Spring Block")
        XCTAssertTrue(UITestNavigation.disappears(start), "A started block offers no START BLOCK ▸")
    }

    // MARK: - Helpers

    /// Today's band for the seeded active block opens its overview.
    @MainActor
    private func openActiveBlockOverview(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        UITestNavigation.selectTab("Today", in: app)
        let band = app.buttons["today.planLine"]
        XCTAssertTrue(UITestNavigation.appears(band), "Today must show the active block's plan line", file: file, line: line)
        band.tap()
        XCTAssertTrue(UITestNavigation.appears(app.buttons.labeled("END BLOCK")),
                      "The band must open the active block's overview", file: file, line: line)
    }

    /// Today drops the ended block's plan line and returns to the routine suggestion.
    @MainActor
    private func assertNoActiveBlockOnToday(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        UITestNavigation.selectTab("Today", in: app)
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts.labeled("NEXT UP · LIVE ROUTINE")),
                      "Today must suggest a routine session after the block ends", file: file, line: line)
        XCTAssertFalse(app.buttons["today.planLine"].exists,
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
        XCTAssertTrue(UITestNavigation.appears(picker, within: 5), "\(control) must open the routine picker", file: file, line: line)
        UITestNavigation.hittable(app.buttons, routine, file: file, line: line).tap()
        XCTAssertTrue(UITestNavigation.disappears(picker, within: 5), "Picking \(routine) must close the routine picker",
                      file: file, line: line)
    }
}
