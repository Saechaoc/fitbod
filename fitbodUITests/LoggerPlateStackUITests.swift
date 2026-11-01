import XCTest

/// Ticket T125, finding F286, which T107's worker found. The logger never
/// showed a set's plates: SetRow toggled them from a tap on the weight
/// cell, but the weight field took every tap first. A set's plates now
/// show under it while its weight field has focus, for the weight in the
/// field, and hide when the field loses focus. Only barbell and dumbbell
/// exercises load plates, so a cable set shows none.
final class LoggerPlateStackUITests: XCTestCase {

    // XCUIApplication and its elements are main-actor isolated.
    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Set 1 of the seeded bench press. A tap on its weight focuses the
    /// field and shows the set's plates under it, above set 2 and clear of
    /// the keyboard. They follow the weight as it is typed: the empty field
    /// shows what the plates show for no weight, and 185 lb loads a 45 and
    /// a 25 on each side of the 45 lb bar. DONE ends the entry and hides
    /// them, and the typed weight stays.
    @MainActor
    func testSetPlatesShowWhileItsWeightIsEntered() throws {
        let app = UITestNavigation.openSeededWorkout()
        let weight = app.textFields.matching(identifier: "set.weight.1.S1").firstMatch
        let plates = Self.plates(of: "1.S1", in: app)
        UITestNavigation.revealInLogger(weight, in: app)
        XCTAssertFalse(plates.exists, "Set 1 must show no plates before its weight is entered")

        // The caret lands after the weight, as for a lifter about to retype it.
        weight.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(Self.wait(for: "hasKeyboardFocus == true", on: weight), "A tap on the weight must still focus it for entry")
        XCTAssertTrue(plates.exists || plates.waitForExistence(timeout: 5), "Set 1's plates must show while its weight is entered")
        XCTAssertTrue(plates.label.contains("Plates each side"), "VoiceOver must read set 1's plates: \(plates.label)")

        weight.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6))
        XCTAssertTrue(Self.wait(for: "label CONTAINS 'below bar weight'", on: plates),
                      "The empty field must show what the plates show for no weight: \(plates.label)")
        weight.typeText("185")
        XCTAssertTrue(Self.wait(for: "label == 'Bar: 45 lb. Plates each side: one 45, one 25. Total: 140.'", on: plates),
                      "The plates must follow the typed weight: \(plates.label)")
        UITestNavigation.waitUntilStill(plates)
        UITestNavigation.saveScreenshot("T125", "logger-plates-entry")
        let span = UITestNavigation.loggerSpan(in: app)
        XCTAssertGreaterThanOrEqual(plates.frame.minY, weight.frame.maxY, "The plates must show under set 1")
        XCTAssertLessThanOrEqual(plates.frame.maxY, app.textFields["set.reps.1.S2"].frame.minY, "The plates must show above set 2")
        XCTAssertLessThanOrEqual(plates.frame.maxY, span.bottom, "The plates must show above the keyboard's DONE bar")

        app.toolbars.buttons["DONE"].firstMatch.tap()
        XCTAssertTrue(plates.waitForNonExistence(timeout: 5), "The plates must hide when the weight field loses focus")
        XCTAssertEqual(weight.value as? String, "185 lb", "The typed weight must stay entered")
    }

    /// The seeded Push A's fourth exercise is the cable seated lateral
    /// raise, which loads no plates: its weight takes focus and a typed
    /// weight, and no plates show anywhere.
    @MainActor
    func testCableSetShowsNoPlates() throws {
        let app = UITestNavigation.openSeededWorkout()
        let weight = app.textFields.matching(identifier: "set.weight.4.S1").firstMatch
        scrollDown(to: weight, in: app)

        weight.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(Self.wait(for: "hasKeyboardFocus == true", on: weight), "A tap on the weight must focus it for entry")
        // 50 lb would load a 2.5 on each side of a barbell.
        weight.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "50")
        XCTAssertTrue(Self.wait(for: "value == '50 lb'", on: weight), "The field must take the typed weight")
        let anyPlates = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "set.plates.")).firstMatch
        XCTAssertFalse(anyPlates.exists, "A cable set must show no plates: \(anyPlates)")
    }

    // MARK: - Helpers

    /// A set's plate stack, such as "1.S1"'s: one element that reads its
    /// plates, or what shows in their place.
    @MainActor
    private static func plates(of set: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "set.plates.\(set)").firstMatch
    }

    /// Waits up to 5 seconds for `element` to match `format`.
    @MainActor
    private static func wait(for format: String, on element: XCUIElement) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: format), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
    }

    /// Drags the logger up a screen at a time until `element`'s row is
    /// built, then scrolls it into view.
    @MainActor
    private func scrollDown(to element: XCUIElement, in app: XCUIApplication) {
        let span = UITestNavigation.loggerSpan(in: app)
        for _ in 0..<10 where !element.exists {
            UITestNavigation.dragLogger(from: span.bottom - 20, to: span.top + 20, in: app)
        }
        UITestNavigation.revealInLogger(element, in: app)
    }
}
