// Create an empty session through Today and verify its chrome and validation.
import XCTest

final class RoutineBuilderBRUUITests: XCTestCase {

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
    private func selectRoutinesTab(_ app: XCUIApplication) {
        let routines = app.buttons["Program"]
        if routines.waitForExistence(timeout: 10) {
            routines.tap()
        }
    }


    @MainActor
    func testRoutineBuilderLaunchesWithBRUHeader() throws {
        let app = UITestNavigation.openEmptySessionBuilder()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "New session")).firstMatch.exists)
        XCTAssertTrue(app.buttons["Add exercise"].exists)
    }

    @MainActor
    func testSaveRoutineButtonLabelMatchesBRU() throws {
        let app = UITestNavigation.openEmptySessionBuilder()
        let save = app.buttons["Save session ▸"]
        XCTAssertTrue(save.exists)
        save.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS[c] %@", "ADD AT LEAST ONE EXERCISE"
        )).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add exercise"].exists, "Validation keeps the draft open")
    }
}
