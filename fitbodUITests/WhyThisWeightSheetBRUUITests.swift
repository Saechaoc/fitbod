// Long-press a real prescribed weight to verify its explanation sheet.
import XCTest

final class WhyThisWeightSheetBRUUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }


    @MainActor
    private func waitForSeedComplete(_ app: XCUIApplication, timeout: TimeInterval = 60) {
        let splash = app.staticTexts["Preparing library…"]
        if splash.exists {
            let pred = NSPredicate(format: "exists == false")
            let exp = XCTNSPredicateExpectation(predicate: pred, object: splash)
            _ = XCTWaiter().wait(for: [exp], timeout: timeout)
        }
    }

    @MainActor
    private func selectTodayTab(_ app: XCUIApplication) {
        let today = app.buttons["Today"]
        if today.waitForExistence(timeout: 10) {
            today.tap()
        }
    }


    @MainActor
    func testWhyThisWeightHeroSlabAppearsAfterLongPress() throws {
        let app = UITestNavigation.openSeededWorkout()
        UITestNavigation.openWeightExplanation(in: app)
    }

    @MainActor
    func testWhyThisWeightSectionHeadVisible() throws {
        let app = UITestNavigation.openSeededWorkout()
        UITestNavigation.openWeightExplanation(in: app)
        let heading = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Why this weight")).firstMatch
        UITestNavigation.reveal(heading, in: app)
    }

    @MainActor
    func testSessionSurfaceRendersWithoutCrash() throws {
        let app = UITestNavigation.openSeededWorkout()
        XCTAssertTrue(app.buttons["set.complete.1.S1"].exists)
        XCTAssertTrue(app.buttons["More"].exists)
    }
}
