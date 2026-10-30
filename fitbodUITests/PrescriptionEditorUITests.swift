import XCTest

/// Review items 5 and 6: target reps and target RPE in the session editor's
/// prescription details.
final class PrescriptionEditorUITests: XCTestCase {

    private let exerciseName = "Barbell Bench Press - Medium Grip"

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// Item 5: a barbell bench press starts at 4–6 reps. Raising the top of
    /// the range to 8 must read 8 (typing into the old field gave 68 or 86),
    /// and neither end can step past the other.
    @MainActor
    func testHighRepsChangesFromSixToEight() throws {
        let app = UITestNavigation.openEmptySessionBuilder()
        addExercise(in: app)
        openDetails(in: app)
        let high = control("prescription.reps.high", in: app)
        XCTAssertEqual(high.value as? String, "6")
        UITestNavigation.step(high, to: 8)
        XCTAssertTrue(app.staticTexts["4–8 reps"].exists, "The prescription chip must read the new range")

        let low = control("prescription.reps.low", in: app)
        XCTAssertGreaterThanOrEqual(low.frame.height, 44)
        UITestNavigation.step(low, to: 8)
        UITestNavigation.tapStepper(low, increment: true)
        XCTAssertEqual(low.value as? String, "8", "Low reps must not step above high reps")
        UITestNavigation.tapStepper(high, increment: false)
        XCTAssertEqual(high.value as? String, "8", "High reps must not step below low reps")
    }

    /// Item 6: target RPE is one control. A chosen value and an explicit
    /// "no target" both survive saving and reopening the session.
    @MainActor
    func testTargetRPEIsOneControlThatSurvivesReopening() throws {
        let app = UITestNavigation.openEmptySessionBuilder()
        let name = app.textFields["Session name"]
        name.tap()
        name.typeText("M1 RPE\n")
        addExercise(in: app)
        openDetails(in: app)
        XCTAssertEqual(rpeControls(in: app).count, 1, "Target RPE must be a single control")
        XCTAssertTrue(app.staticTexts["RPE 8"].exists, "A new bench press starts at RPE 8")
        tapRPEChoice("RPE 9", in: app)
        XCTAssertTrue(app.staticTexts["RPE 9"].waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "prescription-details-rpe-9"
        shot.lifetime = .keepAlways
        add(shot)

        save(in: app)
        let session = app.staticTexts["M1 RPE"].firstMatch
        XCTAssertTrue(session.waitForExistence(timeout: 15))
        session.tap()
        reopen(in: app)
        XCTAssertTrue(app.staticTexts["RPE 9"].waitForExistence(timeout: 5), "A saved RPE must survive reopening")

        tapRPEChoice("No target", in: app)
        XCTAssertTrue(app.staticTexts["RPE —"].waitForExistence(timeout: 5))
        save(in: app)
        reopen(in: app)
        XCTAssertTrue(app.staticTexts["RPE —"].waitForExistence(timeout: 5), "No target must survive reopening")
        XCTAssertEqual(rpeControls(in: app).count, 1)
    }

    /// A decimal target such as 8.5 comes from holding an RPE chip. The
    /// card's own press-and-hold menu must not take that press, and it must
    /// still open from the card's title row.
    @MainActor
    func testHoldingAnRPEChipSetsADecimalTarget() throws {
        let app = UITestNavigation.openEmptySessionBuilder()
        addExercise(in: app)
        openDetails(in: app)

        let title = app.staticTexts.matching(NSPredicate(format: "label == %@", exerciseName))
            .allElementsBoundByIndex.first(where: { $0.isHittable })
        XCTAssertNotNil(title, "The exercise's card must be visible")
        title?.press(forDuration: 1.0)
        let menuItem = app.buttons["Edit prescription"]
        XCTAssertTrue(menuItem.waitForExistence(timeout: 5), "The card's menu must still open from its title row")
        // The menu item collapses the card; open the details again.
        menuItem.tap()
        openDetails(in: app)

        let chip = rpeControls(in: app).firstMatch.buttons
            .matching(NSPredicate(format: "label ==[c] %@", "RPE 8")).firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 10))
        UITestNavigation.reveal(chip, in: app)
        chip.press(forDuration: 1.0)
        let wheel = app.pickerWheels.firstMatch
        XCTAssertTrue(wheel.waitForExistence(timeout: 5), "Holding an RPE chip must open the decimal picker")
        wheel.adjust(toPickerWheelValue: "8.5")
        app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Done")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["RPE 8.5"].waitForExistence(timeout: 5))
    }

    /// Adds the bench press to the open session editor.
    @MainActor
    private func addExercise(in app: XCUIApplication) {
        app.buttons["Add exercise"].tap()
        let search = app.textFields["library.search.picker"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText(exerciseName)
        let row = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH[c] %@", "exercise.pick.", exerciseName
        )).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
    }

    /// Expands the exercise's card and opens EDIT PRESCRIPTION.
    @MainActor
    private func openDetails(in app: XCUIApplication) {
        let card = app.staticTexts.matching(NSPredicate(format: "label == %@", exerciseName))
        XCTAssertTrue(card.firstMatch.waitForExistence(timeout: 10))
        let visible = card.allElementsBoundByIndex.first(where: { $0.isHittable })
        XCTAssertNotNil(visible, "The exercise's card must be visible")
        visible?.tap()
        let details = app.buttons["prescription.details"]
        XCTAssertTrue(details.waitForExistence(timeout: 10))
        details.tap()
    }

    /// From the session's detail screen: Edit, then the prescription details.
    @MainActor
    private func reopen(in app: XCUIApplication) {
        let edit = app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Edit")).firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 15))
        edit.tap()
        openDetails(in: app)
    }

    @MainActor
    private func save(in app: XCUIApplication) {
        let save = app.buttons["Save session ▸"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: save)
        XCTAssertEqual(XCTWaiter().wait(for: [closed], timeout: 10), .completed, "Saving must close the editor")
    }

    @MainActor
    private func rpeControls(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "prescription.rpe")
    }

    @MainActor
    private func tapRPEChoice(_ label: String, in app: XCUIApplication) {
        let choice = rpeControls(in: app).firstMatch.buttons
            .matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 10), "Missing RPE choice: \(label)")
        UITestNavigation.reveal(choice, in: app)
        choice.tap()
    }

    @MainActor
    private func control(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        let element = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 10), "Missing control: \(identifier)")
        UITestNavigation.reveal(element, in: app)
        return element
    }
}
