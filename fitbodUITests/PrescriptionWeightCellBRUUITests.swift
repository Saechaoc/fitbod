// The seeded logger exposes weight entry without an info-circle control, and
// the weight cell keeps its "M" mark and its empty placeholder in place.
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

    /// Review item 18: a weight changed by hand shows its "M" inside the
    /// weight cell, clear of the reps value, so the row never reads
    /// "185 M5". VoiceOver reads the mark as "changed from prescription".
    @MainActor
    func testOverrideMarkStaysInsideWeightCell() throws {
        let app = UITestNavigation.openSeededWorkout()
        let weight = app.textFields.matching(identifier: "set.weight.1.S1").firstMatch
        UITestNavigation.reveal(weight, in: app)
        // Put the caret after the prescribed weight, then type a new one.
        weight.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        weight.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "185")

        // The cell's only static text is the mark.
        let mark = app.staticTexts.matching(identifier: "set.weight.1.S1").firstMatch
        XCTAssertTrue(mark.waitForExistence(timeout: 5), "A weight changed by hand must show the M mark")
        UITestNavigation.saveScreenshot("T09", "override-mark")
        UITestNavigation.assertInside(mark, weight)
        UITestNavigation.assertNoOverlap(mark, app.textFields["set.reps.1.S1"])
        XCTAssertEqual(mark.label, "changed from prescription")
    }

    /// Review item 18: a bench press with no history has no prescription,
    /// so its weight field shows the "—" placeholder, not a target of 0.
    @MainActor
    func testWeightWithoutPrescriptionShowsPlaceholder() throws {
        let app = UITestNavigation.openEmptySessionBuilder()
        let name = app.textFields["Session name"]
        name.tap()
        name.typeText("T09 First Bench\n")
        app.buttons["Add exercise"].tap()
        let search = app.textFields["library.search.picker"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Barbell Bench Press - Medium Grip")
        let pick = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH[c] %@",
            "exercise.pick.", "Barbell Bench Press - Medium Grip"
        )).firstMatch
        XCTAssertTrue(pick.waitForExistence(timeout: 10))
        pick.tap()
        let save = app.buttons["Save session ▸"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()
        let session = app.staticTexts["T09 First Bench"].firstMatch
        XCTAssertTrue(session.waitForExistence(timeout: 15))
        session.tap()
        let start = app.buttons.labeled("Start workout ▸")
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        UITestNavigation.reveal(start, in: app)
        start.tap()

        let weight = app.textFields.matching(identifier: "set.weight.1.S1").firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 15))
        UITestNavigation.reveal(weight, in: app)
        UITestNavigation.saveScreenshot("T09", "weight-placeholder")
        XCTAssertEqual(weight.value as? String, "none",
                       "With no prescription the field must show its placeholder, not a weight of 0")
    }
}
