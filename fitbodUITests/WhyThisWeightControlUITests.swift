import XCTest

/// The exercise explains the frozen weight. A set can restore it through its actions.
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
        UITestNavigation.keyboardDone(in: app).tap()

        let use = UITestNavigation.suggestedWeightAction(for: "1.S1", in: app)
        let suggested = use.label.split(separator: " ").dropFirst().first.flatMap { Double($0) }
        XCTAssertNotNil(suggested, "Use must name the suggested weight: \(use.label)")
        XCTAssertNotEqual(suggested, 90)
        use.tap()
        XCTAssertTrue(waitUntilGone(use), "Use must close the set menu")
        XCTAssertEqual(numericWeight(weight), suggested, "Use must write the suggested weight into the set")
    }

    /// Ticket T09, under the frozen-WHY decision (ROADMAP "Decided"):
    /// without the barbell's 2.5 and 1.25 lb plates the live steps round the
    /// bench's 100 lb down to 95 lb, but WHY keeps the 100 lb frozen when the
    /// workout started and names the 95 in a note. Use writes the frozen 100
    /// over a typed weight and clears the "changed from prescription" mark,
    /// which stays clear after a relaunch.
    @MainActor
    func testUseRestoresFrozenWeightWhenLiveSuggestionDiffers() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        removeSmallBarbellPlates(in: app)
        resumeWorkout(in: app)
        let weight = weightField(in: app)
        XCTAssertEqual(numericWeight(weight), 100, "The set starts at the prescription stored at the start")
        UITestNavigation.revealInLogger(weight, in: app)
        UITestNavigation.enter("90", into: weight)
        UITestNavigation.keyboardDone(in: app).tap()
        XCTAssertTrue(UITestNavigation.appears(overrideMark(in: app), within: 5), "A typed weight is marked")

        let why = app.buttons["card.why.1"]
        XCTAssertTrue(UITestNavigation.appears(why))
        XCTAssertTrue(why.label.contains("Suggested 100 lb"), "The exercise still shows the frozen 100 lb")
        UITestNavigation.openWeightExplanation(in: app)
        let note = app.staticTexts["why.changedSinceStart"]
        XCTAssertTrue(note.exists && note.label.contains("95 lb"), "The note names the live 95 lb")
        let close = app.buttons.labeled("Close")
        UITestNavigation.reveal(close, in: app)
        close.tap()
        XCTAssertTrue(waitUntilGone(note), "Close must return to the logger")

        let use = UITestNavigation.suggestedWeightAction(for: "1.S1", in: app)
        XCTAssertTrue(use.label.hasPrefix("Use 100 "), "Use offers the weight frozen at the start")
        use.tap()
        XCTAssertTrue(waitUntilGone(use), "Use must close the set menu")
        XCTAssertEqual(numericWeight(weight), 100, "Use must write the frozen weight into the set")
        // Waits the whole 2 s: a mark that comes back shows within it.
        XCTAssertFalse(overrideMark(in: app).waitForExistence(timeout: 2),
                       "Use must clear the set's \"changed from prescription\" mark")

        UITestNavigation.relaunch(app)
        resumeWorkout(in: app)
        XCTAssertEqual(numericWeight(weightField(in: app)), 100)
        // The same 2 s watch for the mark, on the reopened workout.
        XCTAssertFalse(overrideMark(in: app).waitForExistence(timeout: 2),
                       "The cleared mark must stay cleared after a relaunch")
    }

    @MainActor
    private func weightField(in app: XCUIApplication) -> XCUIElement {
        app.textFields.matching(identifier: "set.weight.1.S1").firstMatch
    }

    /// The typed set is the only override in the seeded workout.
    @MainActor
    private func overrideMark(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.labeled("changed from prescription")
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
