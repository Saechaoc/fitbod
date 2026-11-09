import XCTest

/// T49 in the workout logger: holding an RPE chip opens the decimal picker.
/// Set 1's controls come first in the logger, so `firstMatch` finds them.
final class RPEDecimalHoldUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Logging a set allows a blank effort. Holding 8 then saves 8.5 to that set.
    @MainActor
    func testHoldingAnRPEChipInTheLoggerSetsAHalfStep() throws {
        let app = UITestNavigation.openSeededWorkout()
        let reps = app.textFields["set.reps.1.S1"]
        UITestNavigation.revealInLogger(reps, in: app)
        UITestNavigation.enter("5", into: reps)
        UITestNavigation.keyboardDone(in: app).tap()
        let complete = app.buttons["set.complete.1.S1"]
        UITestNavigation.revealInLogger(complete, in: app)
        complete.tap()
        XCTAssertTrue(UITestNavigation.waitUntil(timeout: 5) { complete.label == "Set 1 complete" })

        let effort = app.buttons["set.effort.1.S1"]
        UITestNavigation.revealInLogger(effort, in: app)
        effort.tap()
        let eight = chip("RPE 8", in: app)
        UITestNavigation.revealInLogger(eight, in: app)
        eight.press(forDuration: 1.0)
        let wheel = app.pickerWheels.firstMatch
        XCTAssertTrue(wheel.waitForExistence(timeout: 5), "Holding an RPE chip in the logger must open the decimal picker")
        XCTAssertEqual(wheel.value as? String, "8.0", "The picker must start at the held number")
        attachScreenshot(of: app, named: "logger-picker")

        wheel.adjust(toPickerWheelValue: "8.5")
        UITestNavigation.tapPickerButton("Done", in: app)
        XCTAssertEqual(effort.value as? String, "8.5")
        XCTAssertEqual(complete.label, "Set 1 complete")
        attachScreenshot(of: app, named: "logger-half-step")

        UITestNavigation.revealInLogger(effort, in: app)
        effort.tap()
        let half = chip("RPE 8.5", in: app)
        XCTAssertTrue(half.waitForExistence(timeout: 5), "Set 1 must show 8.5")
        XCTAssertTrue(half.isSelected, "8.5 must read as selected")
        XCTAssertFalse(chip("RPE 8", in: app).isSelected, "Chip 8 must not look selected")
    }

    @MainActor
    private func chip(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
