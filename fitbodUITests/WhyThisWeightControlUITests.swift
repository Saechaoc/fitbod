import XCTest

/// Review item 4 (decision 8): a visible WHY control opens Why-this-weight
/// and dismisses the keyboard. Use writes the suggested weight into the set;
/// Override closes the sheet and focuses the weight field.
final class WhyThisWeightControlUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// Mid-entry, with the reps keyboard up, one tap on WHY shows the
    /// sheet's section head and no keyboard.
    @MainActor
    func testWhyOpensSheetWithKeyboardDismissed() throws {
        let app = UITestNavigation.openSeededWorkout()
        attachScreenshot(of: app, named: "logger-set-rows-with-why")
        let reps = app.textFields["set.reps.1.S1"]
        UITestNavigation.reveal(reps, in: app)
        reps.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

        tapWhy(in: app)
        let heading = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Why this weight")).firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 5), "One tap on WHY must open Why-this-weight")
        XCTAssertTrue(waitUntilGone(app.keyboards.firstMatch), "Opening Why-this-weight must dismiss the keyboard")
        XCTAssertTrue(heading.isHittable, "The section head must be visible, not under the keyboard")
        attachScreenshot(of: app, named: "why-sheet-without-keyboard")
    }

    /// Use writes the suggested weight into the set, replacing a typed one.
    @MainActor
    func testUseWritesSuggestedWeight() throws {
        let app = UITestNavigation.openSeededWorkout()
        let weight = weightField(in: app)
        revealInLogger(weight, in: app)
        // Put the caret after the prescribed weight, then type a different one.
        weight.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        weight.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "90")
        XCTAssertEqual(numericWeight(weight), 90)

        tapWhy(in: app)
        let use = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Use ")).firstMatch
        XCTAssertTrue(use.waitForExistence(timeout: 5))
        let suggested = use.label.split(separator: " ").dropFirst().first.flatMap { Double($0) }
        XCTAssertNotNil(suggested, "Use must name the suggested weight: \(use.label)")
        XCTAssertNotEqual(suggested, 90)
        use.tap()
        XCTAssertTrue(waitUntilGone(use), "Use must close the sheet")
        XCTAssertEqual(numericWeight(weight), suggested, "Use must write the suggested weight into the set")
    }

    /// Override closes the sheet and puts the cursor in the weight field.
    @MainActor
    func testOverrideFocusesWeightField() throws {
        let app = UITestNavigation.openSeededWorkout()
        tapWhy(in: app)
        let override = app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Override")).firstMatch
        XCTAssertTrue(override.waitForExistence(timeout: 5))
        override.tap()
        XCTAssertTrue(waitUntilGone(override), "Override must close the sheet")
        let weight = weightField(in: app)
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: weight)
        XCTAssertEqual(XCTWaiter().wait(for: [focused], timeout: 5), .completed, "Override must focus the weight field")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
    }

    @MainActor
    private func tapWhy(in app: XCUIApplication) {
        let why = app.buttons["set.why.1.S1"]
        XCTAssertTrue(why.waitForExistence(timeout: 5), "Set 1 must show a visible WHY control")
        XCTAssertGreaterThanOrEqual(why.frame.width, 44)
        XCTAssertGreaterThanOrEqual(why.frame.height, 44)
        revealInLogger(why, in: app)
        why.tap()
    }

    /// Scrolls the logger until `element` sits between the fixed workout
    /// header and the keyboard's DONE bar, where a user can see and tap it.
    /// XCUITest calls rows under the header hittable, so a tap there would
    /// land on the header.
    @MainActor
    private func revealInLogger(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            let header = app.otherElements["workout.header"].firstMatch
            let top = (header.exists ? header.frame.maxY : 0) + 8
            let keyboard = app.keyboards.firstMatch
            // The DONE bar sits on top of the number pad.
            let bottom = keyboard.exists ? keyboard.frame.minY - 66 : app.frame.maxY - 24
            if element.frame.minY >= top && element.frame.maxY <= bottom { return }
            let delta = (top + bottom) / 2 - element.frame.midY
            let x = app.frame.width - 24
            let startY = delta > 0 ? top + 20 : bottom - 20
            let endY = min(bottom - 20, max(top + 20, startY + delta))
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: x, dy: startY)).press(
                forDuration: 0.1,
                thenDragTo: origin.withOffset(CGVector(dx: x, dy: endY)),
                withVelocity: .slow,
                thenHoldForDuration: 0.2
            )
        }
        XCTFail("Could not scroll \(element) into view")
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    private func weightField(in app: XCUIApplication) -> XCUIElement {
        app.textFields.matching(identifier: "set.weight.1.S1").firstMatch
    }

    /// The accessible weight reads "100 lb"; keep the number.
    @MainActor
    private func numericWeight(_ field: XCUIElement) -> Double? {
        ((field.value as? String) ?? "").split(separator: " ").first.flatMap { Double($0) }
    }

    @MainActor
    private func waitUntilGone(_ element: XCUIElement) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: 5) == .completed
    }
}
