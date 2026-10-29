// The seeded logger exposes weight entry without an info-circle control.
import XCTest

final class PrescriptionWeightCellBRUUITests: XCTestCase {

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
    func testNoInfoCircleIconOnPrescribedWeightCell() throws {
        let app = UITestNavigation.openSeededWorkout()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "set.weight.1.S1").firstMatch.exists)
        XCTAssertFalse(app.images["info.circle"].exists)
    }
}
