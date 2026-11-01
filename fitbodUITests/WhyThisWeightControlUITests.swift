import XCTest

/// Review item 4 (decision 8): a visible WHY control opens Why-this-weight,
/// and Use writes the suggested weight into the set.
final class WhyThisWeightControlUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// Use writes the suggested weight into the set, replacing a typed one.
    @MainActor
    func testUseWritesSuggestedWeight() throws {
        let app = UITestNavigation.openSeededWorkout()
        let weight = weightField(in: app)
        UITestNavigation.revealInLogger(weight, in: app)
        UITestNavigation.enter("90", into: weight)
        XCTAssertEqual(numericWeight(weight), 90)

        tapWhy(in: app)
        let use = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Use ")).firstMatch
        XCTAssertTrue(UITestNavigation.appears(use, within: 5))
        let suggested = use.label.split(separator: " ").dropFirst().first.flatMap { Double($0) }
        XCTAssertNotNil(suggested, "Use must name the suggested weight: \(use.label)")
        XCTAssertNotEqual(suggested, 90)
        use.tap()
        XCTAssertTrue(waitUntilGone(use), "Use must close the sheet")
        XCTAssertEqual(numericWeight(weight), suggested, "Use must write the suggested weight into the set")
    }

    /// Ticket T09: Use clears "changed from prescription" even when the
    /// suggestion differs from the prescription stored when the workout
    /// started. Without the barbell's 2.5 and 1.25 lb plates the bench's
    /// 100 lb rounds down to 95 lb, so Use writes 95 against a stored 100.
    /// The mark stays clear after a relaunch.
    @MainActor
    func testUseClearsOverrideMarkWhenSuggestionDiffersFromPrescription() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        removeSmallBarbellPlates(in: app)
        resumeWorkout(in: app)
        let weight = weightField(in: app)
        XCTAssertEqual(numericWeight(weight), 100, "The set starts at the prescription stored at the start")
        XCTAssertFalse(overrideMark(in: app).exists)

        tapWhy(in: app)
        let use = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Use ")).firstMatch
        XCTAssertTrue(UITestNavigation.appears(use, within: 5))
        XCTAssertTrue(use.label.hasPrefix("Use 95 "), "Without small plates the suggestion is 95 lb: \(use.label)")
        use.tap()
        XCTAssertTrue(waitUntilGone(use), "Use must close the sheet")
        XCTAssertEqual(numericWeight(weight), 95, "Use must write the suggested weight into the set")
        // Waits the whole 2 s: a mark that comes back shows within it.
        XCTAssertFalse(overrideMark(in: app).waitForExistence(timeout: 2),
                       "Use must clear the set's \"changed from prescription\" mark")

        UITestNavigation.relaunch(app)
        resumeWorkout(in: app)
        XCTAssertEqual(numericWeight(weightField(in: app)), 95)
        // The same 2 s watch for the mark, on the reopened workout.
        XCTAssertFalse(overrideMark(in: app).waitForExistence(timeout: 2),
                       "The cleared mark must stay cleared after a relaunch")
    }

    @MainActor
    private func tapWhy(in app: XCUIApplication) {
        let why = app.buttons["set.why.1.S1"]
        XCTAssertTrue(UITestNavigation.appears(why, within: 5), "Set 1 must show a visible WHY control")
        UITestNavigation.revealInLogger(why, in: app)
        why.tap()
    }

    @MainActor
    private func weightField(in app: XCUIApplication) -> XCUIElement {
        app.textFields.matching(identifier: "set.weight.1.S1").firstMatch
    }

    /// Set 1's "M" mark. It shares the weight cell's identifier, and the
    /// cell's only static text is that mark.
    @MainActor
    private func overrideMark(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(identifier: "set.weight.1.S1").firstMatch
    }

    /// Opens today's workout from Today's resume slab.
    @MainActor
    private func resumeWorkout(in app: XCUIApplication) {
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(UITestNavigation.appears(resume))
        resume.tap()
        XCTAssertTrue(UITestNavigation.appears(app.textFields["set.reps.1.S1"]))
    }

    /// Settings > Plate Inventory: takes every 2.5 and 1.25 lb plate off the
    /// barbell, the way a lifter records plates they do not have.
    @MainActor
    private func removeSmallBarbellPlates(in app: XCUIApplication) {
        UITestNavigation.openSettings(in: app)
        let inventory = app.buttons.labeled("Plate Inventory")
        UITestNavigation.reveal(inventory, in: app)
        inventory.tap()
        let done = app.buttons.labeled("Done ▸")
        XCTAssertTrue(UITestNavigation.appears(done))
        for plate in ["2.5 lb plate", "1.25 lb plate"] {
            // Plate rows load as they scroll in; a tap must clear the footer bar.
            let row = app.descendants(matching: .any).labeled(plate)
            for _ in 0..<6 {
                if row.exists && row.frame.maxY < done.frame.minY { break }
                app.swipeUp(velocity: .slow)
            }
            XCTAssertTrue(row.exists && row.frame.maxY < done.frame.minY, "The \(plate) row must be on screen")
            // Tapping the last filled tally box takes one plate off.
            for _ in 0..<4 {
                guard let count = (row.value as? String)?.split(separator: " ").first.flatMap({ Int($0) }),
                      count > 0 else { break }
                tallyBox(count - 1, of: row).tap()
            }
            XCTAssertEqual(row.value as? String, "0 per side", "The \(plate) must be off the barbell")
        }
        done.tap()
        let close = app.buttons["Close"]
        XCTAssertTrue(UITestNavigation.appears(close))
        close.tap()
    }

    /// The center of a plate row's tally box. The row is laid out as
    /// [16 | 90 plate | 10 | four boxes 3pt apart | 10 | 80 count | 16].
    @MainActor
    private func tallyBox(_ index: Int, of row: XCUIElement) -> XCUICoordinate {
        let box = (row.frame.width - 222 - 9) / 4
        let x = 116 + CGFloat(index) * (box + 3) + box / 2
        return row.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: row.frame.height / 2))
    }

    /// The accessible weight reads "100 lb"; keep the number.
    @MainActor
    private func numericWeight(_ field: XCUIElement) -> Double? {
        ((field.value as? String) ?? "").split(separator: " ").first.flatMap { Double($0) }
    }

    @MainActor
    private func waitUntilGone(_ element: XCUIElement) -> Bool {
        UITestNavigation.disappears(element, within: 5)
    }
}
