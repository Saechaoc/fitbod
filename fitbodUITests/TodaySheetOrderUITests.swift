import XCTest

/// Ticket T87, finding F95. On the first Today visit of a week after a
/// workout last week, with a block review also due, Today asked for the
/// weekly recap and the review on the same appearance. SwiftUI shows one
/// sheet at a time, so one could be dropped, and the recap was marked seen
/// whether or not it showed. Today shows the review first and the recap
/// once the review closes, and marks the recap seen only once it shows.
final class TodaySheetOrderUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// With both due, the review shows first and the recap follows when the
    /// review closes. Plan custom puts the review off, so the next visit
    /// shows it again, but the recap has shown and does not follow it.
    /// Before the fix this order already held on iOS 27, which queued the
    /// recap behind the review; Today sequences them itself instead.
    @MainActor
    func testReviewShowsFirstAndTheRecapFollowsWhenItCloses() throws {
        let app = openTodayWithReviewAndRecapDue()
        let reviewShown = reviewTitle(in: app).waitForExistence(timeout: 10)
        if reviewShown {
            UITestNavigation.waitUntilStill(reviewTitle(in: app))
            UITestNavigation.saveScreenshot("T87", "review")
        } else {
            UITestNavigation.saveScreenshot("T87", "first-visit")
        }
        XCTAssertTrue(
            reviewShown,
            recapTitle(in: app).exists
                ? "With both due, Today must show the block review first, but it shows the recap"
                : "With both due, Today must show the block review first"
        )
        assertReviewShows(in: app, "With both due, Today must show the block review first")
        XCTAssertFalse(recapTitle(in: app).exists, "The recap must wait until the review closes")

        closeReview(in: app)
        XCTAssertTrue(recapTitle(in: app).waitForExistence(timeout: 10), "The recap must show once the review closes")
        UITestNavigation.waitUntilStill(recapTitle(in: app))
        UITestNavigation.saveScreenshot("T87", "recap")
        closeRecap(in: app)

        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.selectTab("Today", in: app)
        assertReviewShows(in: app, "Plan custom puts the review off, so the next visit to Today must show it again")
        closeReview(in: app)
        XCTAssertFalse(recapTitle(in: app).waitForExistence(timeout: 3), "A recap that has shown must not show again")
    }

    /// A recap waiting behind the review has not shown, so it stays due.
    /// Start next acknowledges the review; after a relaunch only the recap
    /// is due, and Today shows it at once. Once shown, it does not return.
    @MainActor
    func testRecapWaitingBehindTheReviewStaysDueUntilItShows() throws {
        let app = openTodayWithReviewAndRecapDue()
        assertReviewShows(in: app, "With both due, Today must show the block review first")
        UITestNavigation.hittable(app.buttons, "Start next ▸").tap()
        let newBlock = app.staticTexts.labeled("NEW BLOCK")
        XCTAssertTrue(newBlock.waitForExistence(timeout: 10), "Start next must open New Block")
        UITestNavigation.hittable(app.buttons, "Cancel").tap()
        XCTAssertTrue(newBlock.waitForNonExistence(timeout: 5), "CANCEL must close an untouched New Block")
        XCTAssertFalse(recapTitle(in: app).exists, "The recap must wait while the review shows")

        UITestNavigation.relaunch(app)
        XCTAssertTrue(recapTitle(in: app).waitForExistence(timeout: 10),
                      "The recap never showed, so it must still be due after a relaunch")
        XCTAssertFalse(reviewTitle(in: app).exists, "Start next acknowledged the review, so only the recap is due")
        closeRecap(in: app)

        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.selectTab("Today", in: app)
        XCTAssertFalse(recapTitle(in: app).waitForExistence(timeout: 3), "A recap that has shown must not show again")
        XCTAssertFalse(reviewTitle(in: app).exists, "An acknowledged review must not show again")
    }

    // MARK: - Helpers

    /// Launches on Program with Live Block ended and a workout last week,
    /// waits until the seed has ended the block, then makes the first visit
    /// to Today, with the review and the recap both due.
    @MainActor
    private func openTodayWithReviewAndRecapDue(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.endedBlockWithRecap, file: file, line: line)
        XCTAssertTrue(app.buttons.labeled("DONE block: Live Block").waitForExistence(timeout: 30),
                      "The seed must end Live Block before Today's first visit", file: file, line: line)
        UITestNavigation.selectTab("Today", in: app)
        return app
    }

    /// The review's header title.
    @MainActor
    private func reviewTitle(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.labeled("Block review")
    }

    /// The recap's header title, such as "Week 44 · recap", whose spaces do
    /// not break.
    @MainActor
    private func recapTitle(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label MATCHES[c] %@", #"Week\s\d+\s·\srecap"#)).firstMatch
    }

    /// The review of Live Block is up and its actions can be tapped.
    @MainActor
    private func assertReviewShows(
        in app: XCUIApplication, _ message: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(reviewTitle(in: app).waitForExistence(timeout: 10), message, file: file, line: line)
        XCTAssertTrue(app.staticTexts.labeled("Live Block").exists, "The review must name the ended block",
                      file: file, line: line)
        UITestNavigation.hittable(app.buttons, "Plan custom", file: file, line: line)
        UITestNavigation.hittable(app.buttons, "Start next ▸", file: file, line: line)
    }

    /// Closes the review with Plan custom and waits until it is gone.
    @MainActor
    private func closeReview(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        UITestNavigation.hittable(app.buttons, "Plan custom", file: file, line: line).tap()
        XCTAssertTrue(reviewTitle(in: app).waitForNonExistence(timeout: 5), "Plan custom must close the review",
                      file: file, line: line)
    }

    /// Closes the recap with its Start button, such as "Start W44 ▸", and
    /// waits until it is gone.
    @MainActor
    private func closeRecap(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let start = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Start W")).firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 5), "The recap must offer its Start button", file: file, line: line)
        start.tap()
        XCTAssertTrue(recapTitle(in: app).waitForNonExistence(timeout: 5), "Start must close the recap",
                      file: file, line: line)
    }
}

extension UITestNavigation {
    /// A fresh store with Live Block ended, its review due, and one workout
    /// last week, so this week's recap is due too (ActiveBlockSeed). Program
    /// opens first, because on a fresh store Today can show before the seed.
    static let endedBlockWithRecap = [resetFlag, "-fitbod-seed-ended-block-recap", "-fitbod-start-program"]
}
