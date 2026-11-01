import XCTest

/// T49 in the workout logger: holding an RPE chip opens the decimal picker.
/// Set 1's controls come first in the logger, so `firstMatch` finds them.
final class RPEDecimalHoldUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Set 1 has no RPE yet. Holding its 8 opens the picker at 8.0, and Done
    /// saves 8.5, which shows as its own chip, never as chip 8.
    @MainActor
    func testHoldingAnRPEChipInTheLoggerSetsAHalfStep() throws {
        let app = UITestNavigation.openSeededWorkout()
        let eight = chip("RPE 8", in: app)
        UITestNavigation.reveal(eight, in: app)
        eight.press(forDuration: 1.0)
        let wheel = app.pickerWheels.firstMatch
        XCTAssertTrue(wheel.waitForExistence(timeout: 5), "Holding an RPE chip in the logger must open the decimal picker")
        XCTAssertEqual(wheel.value as? String, "8.0", "The picker must start at the held number")
        attachScreenshot(of: app, named: "logger-picker")

        wheel.adjust(toPickerWheelValue: "8.5")
        UITestNavigation.tapPickerButton("Done", in: app)
        let half = chip("RPE 8.5", in: app)
        XCTAssertTrue(half.waitForExistence(timeout: 5), "Set 1 must show 8.5")
        XCTAssertTrue(half.isSelected, "8.5 must read as selected")
        XCTAssertFalse(chip("RPE 8", in: app).isSelected, "Chip 8 must not look selected")
        attachScreenshot(of: app, named: "logger-half-step")
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
