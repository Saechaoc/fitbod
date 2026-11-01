import XCTest

/// Ticket T99, finding F142. The block review's hero counts the sets that
/// set a PR during the block.
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
    /// the block, then makes the first visit to Today, which opens the
    /// block's review.
    @MainActor
    private func openEndedBlocksReview(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.endedBlockWithRecap, file: file, line: line)
        XCTAssertTrue(UITestNavigation.appears(app.buttons.labeled("DONE block: Live Block"), within: 30),
                      "The seed must end Live Block before Today's first visit", file: file, line: line)
        UITestNavigation.selectTab("Today", in: app)
        assertReviewOpens(in: app, "Today's first visit after the block ended must open its review", file: file, line: line)
        return app
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
