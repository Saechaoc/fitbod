import XCTest

/// Ticket T67, findings F48 and F49. Ending a block and changing its
/// routine go through BlockLifecycleService. END BLOCK, reached from
/// Today's block band, completes the block: Program lists it as done and
/// Today has no active block. (BlockCard's own End Block is not in the
/// app, so F48 was not reproduced.) EDIT BLOCK offers no routine change for
/// the active block, and a draft block still takes a routine there.
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
        hittable(app.buttons, "END BLOCK").tap()
        let alert = app.alerts["End block?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "END BLOCK must ask before it ends the block")
        alert.buttons["End Block"].tap()
        XCTAssertTrue(app.buttons.labeled("END BLOCK").waitForNonExistence(timeout: 5),
                      "An ended block offers no END BLOCK")
        hittable(app.buttons, "Back").tap()
        // T70: Today opens the ended block's review; Plan custom puts it off.
        let review = app.staticTexts.labeled("Block review")
        hittable(app.buttons, "Plan custom").tap()
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
        hittable(app.buttons, "Plan custom").tap()
        XCTAssertTrue(review.waitForNonExistence(timeout: 5), "Plan custom must close the review")
        assertNoActiveBlockOnToday(in: app)
        UITestNavigation.selectTab("Program", in: app)
        XCTAssertTrue(app.buttons.labeled("DONE block: Live Block").waitForExistence(timeout: 10),
                      "The ended block must stay completed after a relaunch")
    }

    // MARK: - EDIT BLOCK routine

    /// EDIT BLOCK on the active block shows its routine with no SWAP or
    /// + ATTACH: the lifecycle service refuses an active block a new routine.
    @MainActor
    func testEditBlockOffersNoRoutineChangeForTheActiveBlock() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        openActiveBlockOverview(in: app)
        hittable(app.buttons, "EDIT BLOCK ▸").tap()
        XCTAssertTrue(editBlockTitle(in: app).waitForExistence(timeout: 10), "EDIT BLOCK ▸ must open EDIT BLOCK")
        revealAboveBottomBar(app.staticTexts, "Live Routine", in: app)
        UITestNavigation.saveScreenshot("T67", "edit-active-block-routine")
        XCTAssertFalse(app.buttons.labeled("SWAP ▸").exists, "EDIT BLOCK must not offer SWAP for the active block")
        XCTAssertFalse(app.buttons.labeled("+ ATTACH ▸").exists,
                       "EDIT BLOCK must not offer + ATTACH for the active block")
    }

    /// A draft block still takes a routine in EDIT BLOCK, which then offers
    /// SWAP, and SAVE CHANGES leaves the block ready.
    @MainActor
    func testEditBlockStillGivesADraftBlockARoutine() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        UITestNavigation.selectTab("Program", in: app)
        hittable(app.buttons, "+ NEW").tap()
        hittable(app.buttons, "+ New block").tap()
        hittable(app.buttons, "Blank Block").tap()
        let newBlock = app.staticTexts.labeled("NEW BLOCK")
        XCTAssertTrue(newBlock.waitForExistence(timeout: 10), "New Block never opened")
        type("Next Block", into: app.textFields.firstMatch)
        hittable(app.buttons, "SAVE DRAFT").tap()
        XCTAssertTrue(newBlock.waitForNonExistence(timeout: 5), "SAVE DRAFT must close New Block")

        let draft = app.buttons.labeled("DRAFT block: Next Block")
        XCTAssertTrue(draft.waitForExistence(timeout: 10), "Program must list the new block as a draft")
        UITestNavigation.reveal(draft, in: app)
        draft.tap()
        hittable(app.buttons, "EDIT").tap()
        XCTAssertTrue(editBlockTitle(in: app).waitForExistence(timeout: 10), "EDIT must open EDIT BLOCK")
        pickRoutine("Live Routine", from: "+ ATTACH ▸", in: app)
        revealAboveBottomBar(app.buttons, "SWAP ▸", in: app)
        UITestNavigation.saveScreenshot("T67", "edit-draft-block-routine")
        hittable(app.buttons, "SAVE CHANGES").tap()
        XCTAssertTrue(editBlockTitle(in: app).waitForNonExistence(timeout: 5), "SAVE CHANGES must close EDIT BLOCK")

        hittable(app.buttons, "Back").tap()
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
        revealAboveBottomBar(app.buttons, control, in: app, file: file, line: line).tap()
        let picker = app.staticTexts.labeled("Choose Routine")
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "\(control) must open the routine picker", file: file, line: line)
        hittable(app.buttons, routine, file: file, line: line).tap()
        XCTAssertTrue(picker.waitForNonExistence(timeout: 5), "Picking \(routine) must close the routine picker",
                      file: file, line: line)
    }

    /// Scrolls the builder until a tappable `label` sits above its bottom
    /// bar, which covers the end of the scroll view. A sheet leaves the
    /// screen under it in the tree, so only a tappable match counts.
    @MainActor
    @discardableResult
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

    /// Replaces the field's text once it has keyboard focus, because
    /// `typeText` can drop the first character, then presses return to put
    /// the keyboard away.
    @MainActor
    private func type(
        _ text: String, into field: XCUIElement,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Missing \(field)", file: file, line: line)
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)
        XCTAssertEqual(XCTWaiter().wait(for: [focused], timeout: 5), .completed,
                       "The field never took keyboard focus", file: file, line: line)
        // An empty field reports its placeholder as its value.
        if let current = field.value as? String, !current.isEmpty, current != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(text + "\n")
        let value = field.value as? String ?? ""
        XCTAssertEqual(value == field.placeholderValue ? "" : value, text,
                       "The field must hold the typed text", file: file, line: line)
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
