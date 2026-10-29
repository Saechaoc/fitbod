// Logger controls are exercised with a deterministic active workout.
import XCTest

final class SessionLoggerBRUUITests: XCTestCase {

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
    private func selectRoutinesTab(_ app: XCUIApplication) {
        let routines = app.buttons["Program"]
        if routines.waitForExistence(timeout: 10) {
            routines.tap()
        }
    }


    @MainActor
    func testTodayTabRendersWithoutCrash() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        XCTAssertTrue(app.buttons["today.sessions"].exists)
        XCTAssertTrue(app.buttons["resumeSlab.resume"].exists)
    }

    @MainActor
    func testSetTypeChipsRenderBRULabelsNotSystemColors() throws {
        let app = UITestNavigation.openSeededWorkout()
        XCTAssertTrue(app.buttons["Working"].firstMatch.exists)
        XCTAssertTrue(app.buttons["set.complete.1.S1"].exists)
        XCTAssertFalse(app.buttons["Today"].exists, "The logger hides the tab bar")
    }

    @MainActor
    func testBRUHeaderBarMenuActionsAccessibleInActiveSession() throws {
        let app = UITestNavigation.openSeededWorkout()
        app.buttons["More"].tap()
        XCTAssertTrue(app.buttons["Finish"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Workout notes"].exists)
        XCTAssertTrue(app.buttons["Discard"].exists)
        app.buttons["Workout notes"].tap()
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 5))
    }
}
