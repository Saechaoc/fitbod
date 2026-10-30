import XCTest

/// T49 in the workout logger: holding an RPE chip opens the decimal picker,
/// and the set-type menus no longer take that hold. The session editor's
/// side is in `PrescriptionEditorUITests`. Set 1's controls come first in
/// the logger, so `firstMatch` finds them.
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

    /// A working set shows no set-type chip, so its set label opens the
    /// set-type menu. A typed set's chip still cycles on a tap and opens the
    /// menu on a hold, and the RPE chips' hold still opens the picker.
    @MainActor
    func testSetTypeMenusLeaveTheRPEChipHoldFree() throws {
        let app = UITestNavigation.openSeededWorkout()
        let label = app.buttons["set.type.1.S1"]
        UITestNavigation.reveal(label, in: app)
        XCTAssertGreaterThanOrEqual(label.frame.width, 44)
        XCTAssertGreaterThanOrEqual(label.frame.height, 44)
        label.tap()
        chooseFromMenu("Drop Set", in: app)
        XCTAssertTrue(app.buttons["Drop Set"].waitForExistence(timeout: 5), "Set 1 must show its DROP chip")
        XCTAssertEqual(label.value as? String, "Drop Set")

        app.buttons["Drop Set"].tap()
        let fail = app.buttons["To Failure"]
        XCTAssertTrue(fail.waitForExistence(timeout: 5), "A tap on the chip must still cycle the set type")

        chip("RPE 9", in: app).press(forDuration: 1.0)
        XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 5),
                      "The set-type menu must not take the RPE chip's hold")
        UITestNavigation.tapPickerButton("Cancel", in: app)

        fail.press(forDuration: 1.0)
        chooseFromMenu("Warm-up", in: app)
        XCTAssertTrue(app.buttons["Warm-up"].waitForExistence(timeout: 5), "The chip's hold must open its menu")
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

    /// Picks a set-type menu item. "Rest-Pause" exists only while the menu
    /// is open, so it shows when the menu opens and closes.
    @MainActor
    private func chooseFromMenu(_ item: String, in app: XCUIApplication) {
        let marker = app.buttons["Rest-Pause"]
        XCTAssertTrue(marker.waitForExistence(timeout: 5), "The set-type menu must open")
        app.buttons.matching(NSPredicate(format: "label == %@", item)).allElementsBoundByIndex
            .last(where: { $0.isHittable })?.tap()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: marker)
        XCTAssertEqual(XCTWaiter().wait(for: [closed], timeout: 5), .completed, "The set-type menu must close")
    }
}
