import XCTest

/// Ticket T70, finding F53. After END BLOCK, Today opens the ended block's
/// review the next time it shows. Plan custom puts the review off, so it
/// opens again on later visits until Start next acknowledges it.
final class BlockReviewAfterEndUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// Ending the seeded block from its overview on Today opens its review
    /// when the lifter goes back to Today.
    @MainActor
    func testEndingTheBlockOpensItsReviewOnToday() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        endBlockFromTodaysBand(in: app)
        XCTAssertFalse(reviewTitle(in: app).exists, "The review waits until Today shows")
        hittable(app.buttons, "Back").tap()

        assertReviewOpens(in: app, "Going back to Today after END BLOCK must open the block's review")
        XCTAssertTrue(UITestNavigation.tab("Today", in: app).isSelected, "The review must open on Today")
        UITestNavigation.saveScreenshot("T70", "review-after-end")
    }

    /// Plan custom closes the review without acknowledging it, so a later
    /// visit to Today and a relaunch open it again. Start next acknowledges
    /// it and opens New Block from Today; after that it never opens again,
    /// and the block stays completed.
    @MainActor
    func testReviewKeepsOpeningUntilStartNextAcknowledgesIt() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        endBlockFromTodaysBand(in: app)
        hittable(app.buttons, "Back").tap()
        assertReviewOpens(in: app, "Going back to Today after END BLOCK must open the block's review")

        closeReview(with: "Plan custom", in: app)
        XCTAssertTrue(app.staticTexts.labeled("No active block.").waitForExistence(timeout: 10),
                      "Plan custom must leave the lifter on Today")
        XCTAssertFalse(reviewTitle(in: app).waitForExistence(timeout: 3), "Plan custom must not reopen the review at once")

        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.selectTab("Today", in: app)
        assertReviewOpens(in: app, "The review must open again on the next visit to Today")
        closeReview(with: "Plan custom", in: app)

        UITestNavigation.relaunch(app)
        assertReviewOpens(in: app, "The review must open again after a relaunch")
        hittable(app.buttons, "Start next ▸").tap()
        let newBlock = app.staticTexts.labeled("NEW BLOCK")
        XCTAssertTrue(newBlock.waitForExistence(timeout: 10), "Start next must open New Block")
        // T69: the review shows only on Today, so its builder goes back to Today.
        let back = app.buttons.labeled("< TODAY")
        XCTAssertTrue(back.waitForExistence(timeout: 5), "Start next's builder must read < TODAY")
        XCTAssertFalse(app.buttons.labeled("< PROGRAM").exists, "Start next's builder must not read < PROGRAM")
        UITestNavigation.assertTapTarget(back)
        hittable(app.buttons, "Cancel")
        UITestNavigation.saveScreenshot("T70", "start-next-builder")
        hittable(app.buttons, "Cancel").tap()
        XCTAssertTrue(newBlock.waitForNonExistence(timeout: 5), "CANCEL must close an untouched New Block")
        closeReview(with: "Plan custom", in: app)

        UITestNavigation.selectTab("Program", in: app)
        XCTAssertTrue(app.buttons.labeled("DONE block: Live Block").waitForExistence(timeout: 10),
                      "Acknowledging the review must leave the block completed")
        UITestNavigation.selectTab("Today", in: app)
        XCTAssertTrue(app.staticTexts.labeled("No active block.").waitForExistence(timeout: 10),
                      "Today must still have no active block")
        XCTAssertFalse(reviewTitle(in: app).waitForExistence(timeout: 3), "An acknowledged review must not open again")

        UITestNavigation.relaunch(app)
        XCTAssertTrue(app.staticTexts.labeled("No active block.").waitForExistence(timeout: 10),
                      "Today must still have no active block after a relaunch")
        XCTAssertFalse(reviewTitle(in: app).waitForExistence(timeout: 3),
                       "An acknowledged review must not open after a relaunch")
    }

    // MARK: - Helpers

    /// Today's band opens the seeded active block's overview, whose END
    /// BLOCK ends the block after it asks.
    @MainActor
    private func endBlockFromTodaysBand(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        UITestNavigation.selectTab("Today", in: app)
        let band = app.staticTexts.labeled("LIVE BLOCK")
        XCTAssertTrue(band.waitForExistence(timeout: 10), "Today must show the active block's band", file: file, line: line)
        band.tap()
        hittable(app.buttons, "END BLOCK", file: file, line: line).tap()
        let alert = app.alerts["End block?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "END BLOCK must ask before it ends the block",
                      file: file, line: line)
        alert.buttons["End Block"].tap()
        XCTAssertTrue(app.buttons.labeled("END BLOCK").waitForNonExistence(timeout: 5),
                      "An ended block offers no END BLOCK", file: file, line: line)
    }

    /// The review's header title.
    @MainActor
    private func reviewTitle(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.labeled("Block review")
    }

    /// The review of the seeded block, numbered 1 and complete, is up and
    /// its actions can be tapped.
    @MainActor
    private func assertReviewOpens(
        in app: XCUIApplication, _ message: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(reviewTitle(in: app).waitForExistence(timeout: 10), message, file: file, line: line)
        let complete = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "BLOCK 1 · COMPLETE"))
        XCTAssertTrue(complete.firstMatch.exists, "The review must be the ended block's", file: file, line: line)
        XCTAssertTrue(app.staticTexts.labeled("Live Block").exists, "The review must name the ended block",
                      file: file, line: line)
        hittable(app.buttons, "Plan custom", file: file, line: line)
        hittable(app.buttons, "Start next ▸", file: file, line: line)
    }

    /// Closes the review with `action` and waits until it is gone.
    @MainActor
    private func closeReview(with action: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        hittable(app.buttons, action, file: file, line: line).tap()
        XCTAssertTrue(reviewTitle(in: app).waitForNonExistence(timeout: 5), "\(action) must close the review",
                      file: file, line: line)
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
