import XCTest

/// Ticket T99, finding F142. The block review's hero counts the sets that
/// set a PR during the block.
///
/// RM-013. Nothing opens by itself on Today: this week's recap shows on its
/// own (O-4), and the ended block's review waits behind Today's notice,
/// whose close records it for good.
final class BlockReviewAfterEndUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - T99

    /// F142: PRS showed a dash over "COMING IN PHASE 6". The seeded block's
    /// one workout logged the lifter's first bench sets, all 100 x 5, so
    /// only the first set a PR.
    @MainActor
    func testHeroCountsTheBlocksPRs() throws {
        let app = openEndedBlocksReview()
        let prs = heroStat("prs", in: app)
        XCTAssertTrue(UITestNavigation.appears(prs), "The review's hero must show its PRS stat")
        let shown = prs.staticTexts.allElementsBoundByIndex.map(\.label)
        XCTAssertEqual(shown, ["PRS", "1", "THIS BLOCK"], "The PRS stat must count the block's one PR")
    }

    // MARK: - RM-013

    /// ‹ BACK closes the review and records it: the notice clears, and
    /// neither comes back after a relaunch.
    @MainActor
    func testClosingTheReviewRecordsIt() throws {
        let app = openEndedBlocksReview()
        UITestNavigation.hittable(app.buttons, "Back").tap()
        XCTAssertTrue(UITestNavigation.disappears(reviewTitle(in: app)), "‹ BACK must close the review")
        XCTAssertTrue(UITestNavigation.disappears(reviewNotice(in: app)), "Closing the review must clear its notice")

        UITestNavigation.relaunch(app)
        XCTAssertFalse(UITestNavigation.appears(reviewNotice(in: app), within: 3),
                       "A closed review's notice must not come back after a relaunch")
        XCTAssertFalse(reviewTitle(in: app).exists, "A closed review must not open again by itself")
    }

    /// Start next ▸ records the review before New block opens, so the notice
    /// stays gone when the app closes with the builder open.
    @MainActor
    func testStartNextRecordsTheReviewBeforeItsBuilder() throws {
        let app = openEndedBlocksReview()
        UITestNavigation.hittable(app.buttons, "Start next ▸").tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts.labeled("NEW BLOCK")), "Start next must open New block")

        UITestNavigation.relaunch(app)
        XCTAssertFalse(UITestNavigation.appears(reviewNotice(in: app), within: 3),
                       "Start next must record the review before New block opens")
    }

    // MARK: - Helpers

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
        XCTAssertTrue(UITestNavigation.appears(reviewTitle(in: app)), message, file: file, line: line)
        let complete = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "BLOCK 1 · COMPLETE"))
        XCTAssertTrue(complete.firstMatch.exists, "The review must be the ended block's", file: file, line: line)
        XCTAssertTrue(app.staticTexts.labeled("Live Block").exists, "The review must name the ended block",
                      file: file, line: line)
        UITestNavigation.hittable(app.buttons, "Plan custom", file: file, line: line)
        UITestNavigation.hittable(app.buttons, "Start next ▸", file: file, line: line)
    }

    // MARK: - T99 helpers

    /// Launches on Program with Live Block ended after one finished Live
    /// Push workout last week (T87's seed), waits until the seed has ended
    /// the block, then makes the first visit to Today. This week's recap
    /// shows on its own; once it closes, the notice opens the review.
    @MainActor
    private func openEndedBlocksReview(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.endedBlockWithRecap, file: file, line: line)
        XCTAssertTrue(UITestNavigation.appears(app.buttons.labeled("Past blocks"), within: 30),
                      "The seed must end Live Block before Today's first visit", file: file, line: line)
        UITestNavigation.selectTab("Today", in: app)
        let recap = app.staticTexts.matching(NSPredicate(format: "label MATCHES[c] %@", #"Week\s\d+\s·\srecap"#)).firstMatch
        XCTAssertTrue(UITestNavigation.appears(recap), "This week's recap must show on its own, with a review pending (O-4)",
                      file: file, line: line)
        XCTAssertFalse(reviewTitle(in: app).exists, "The review must not open by itself", file: file, line: line)
        UITestNavigation.hittable(app.buttons, "Done", file: file, line: line).tap()

        let notice = reviewNotice(in: app)
        XCTAssertTrue(UITestNavigation.appears(notice), "Today must offer the ended block's review", file: file, line: line)
        XCTAssertEqual(notice.label, "Live Block finished", file: file, line: line)
        notice.tap()
        assertReviewOpens(in: app, "The notice must open the ended block's review", file: file, line: line)
        return app
    }

    /// Today's "LIVE BLOCK FINISHED · REVIEW ›".
    @MainActor
    private func reviewNotice(in app: XCUIApplication) -> XCUIElement {
        app.buttons["today.reviewNotice"]
    }

    /// One of the hero's stats: its label, value and sub-label.
    @MainActor
    private func heroStat(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.otherElements["blockReview.stat.\(name)"]
    }
}

extension UITestNavigation {
    /// A fresh store with Live Block ended, its review due, and one workout
    /// last week, so this week's recap is due too (ActiveBlockSeed). Program
    /// opens first, because on a fresh store Today can show before the seed.
    static let endedBlockWithRecap = [resetFlag, "-fitbod-seed-ended-block-recap", "-fitbod-start-program"]
}
