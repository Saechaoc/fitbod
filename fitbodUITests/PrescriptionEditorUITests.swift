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
        attachScreenshot(of: app, named: "prescription-details-rpe-9")

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

    /// T49: a half step such as 8.5 comes from holding an RPE chip. The
    /// card's own press-and-hold menu must not take that hold, and it must
    /// still open from the card's title row, where Remove still works. The
    /// picker starts at the held number, Cancel keeps the old target, and
    /// Done saves the new one, which shows as its own chip, not as chip 8.
    @MainActor
    func testHoldingAnRPEChipSetsADecimalTarget() throws {
        let app = UITestNavigation.openEmptySessionBuilder()
        addExercise(in: app)
        openDetails(in: app)

        cardTitle(in: app).press(forDuration: 1.0)
        let menuItem = app.buttons["Edit prescription"]
        XCTAssertTrue(menuItem.waitForExistence(timeout: 5), "The card's menu must still open from its title row")
        // The menu item collapses the card; open the details again.
        menuItem.tap()
        openDetails(in: app)

        holdRPEChip("RPE 8", in: app).adjust(toPickerWheelValue: "8.5")
        UITestNavigation.tapPickerButton("Cancel", in: app)
        XCTAssertTrue(app.staticTexts["RPE 8"].waitForExistence(timeout: 5), "Cancel must keep the old target")

        let wheel = holdRPEChip("RPE 9", in: app)
        XCTAssertEqual(wheel.value as? String, "9.0", "The picker must start at the held number")
        attachScreenshot(of: app, named: "editor-picker")
        UITestNavigation.tapPickerButton("Cancel", in: app)
        XCTAssertTrue(app.staticTexts["RPE 8"].waitForExistence(timeout: 5), "A hold alone must not pick the chip")

        holdRPEChip("RPE 8", in: app).adjust(toPickerWheelValue: "8.5")
        UITestNavigation.tapPickerButton("Done", in: app)
        XCTAssertTrue(app.staticTexts["RPE 8.5"].waitForExistence(timeout: 5))
        assertHalfStepChip("RPE 8.5", in: app)

        let title = cardTitle(in: app)
        title.press(forDuration: 1.0)
        let remove = app.buttons["Remove"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5), "The card's menu must open from its title row")
        remove.tap()
        let removed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: title)
        XCTAssertEqual(XCTWaiter().wait(for: [removed], timeout: 5), .completed, "Remove must remove the exercise")
    }

    /// T49: a half-step target survives saving and reopening as its own
    /// chip, and a tap on chip 8 then sets a whole 8 again.
    @MainActor
    func testAHalfStepTargetSurvivesReopeningAsItsOwnChip() throws {
        let app = UITestNavigation.openEmptySessionBuilder()
        let name = app.textFields["Session name"]
        name.tap()
        name.typeText("M1 Half\n")
        addExercise(in: app)
        openDetails(in: app)
        holdRPEChip("RPE 8", in: app).adjust(toPickerWheelValue: "8.5")
        UITestNavigation.tapPickerButton("Done", in: app)

        save(in: app)
        let session = app.staticTexts["M1 Half"].firstMatch
        XCTAssertTrue(session.waitForExistence(timeout: 15))
        session.tap()
        reopen(in: app)
        XCTAssertTrue(app.staticTexts["RPE 8.5"].waitForExistence(timeout: 5), "A saved half step must survive reopening")
        assertHalfStepChip("RPE 8.5", in: app)
        attachScreenshot(of: app, named: "editor-half-step")

        tapRPEChoice("RPE 8", in: app)
        XCTAssertTrue(app.staticTexts["RPE 8"].waitForExistence(timeout: 5), "A tap on chip 8 must set a whole 8")
        XCTAssertTrue(rpeChip("RPE 8", in: app).isSelected)
        XCTAssertFalse(rpeChip("RPE 8.5", in: app).exists, "The half-step chip must go with the half step")
    }

    /// Holds a target RPE chip and returns the decimal picker's wheel.
    @MainActor
    private func holdRPEChip(_ label: String, in app: XCUIApplication) -> XCUIElement {
        let chip = rpeChip(label, in: app)
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "Missing RPE choice: \(label)")
        UITestNavigation.reveal(chip, in: app)
        chip.press(forDuration: 1.0)
        let wheel = app.pickerWheels.firstMatch
        XCTAssertTrue(wheel.waitForExistence(timeout: 5), "Holding an RPE chip must open the decimal picker")
        return wheel
    }

    @MainActor
    private func rpeChip(_ label: String, in app: XCUIApplication) -> XCUIElement {
        rpeControls(in: app).firstMatch.buttons
            .matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
    }

    /// A stored half step shows as its own selected chip, never as chip 8.
    @MainActor
    private func assertHalfStepChip(_ label: String, in app: XCUIApplication) {
        let chip = rpeChip(label, in: app)
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "The half step must show as its own chip")
        XCTAssertTrue(chip.isSelected, "\(label) must read as selected")
        XCTAssertFalse(rpeChip("RPE 8", in: app).isSelected, "Chip 8 must not look selected")
    }

    /// The exercise card's title, scrolled back into view.
    @MainActor
    private func cardTitle(in app: XCUIApplication) -> XCUIElement {
        let title = app.staticTexts.matching(NSPredicate(format: "label == %@", exerciseName)).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10), "The exercise's card must exist")
        for _ in 0..<6 where !title.isHittable {
            app.scrollViews.allElementsBoundByIndex.last(where: { $0.isHittable })?.swipeDown(velocity: .slow)
        }
        XCTAssertTrue(title.isHittable, "The exercise's card must be visible")
        return title
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
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
        let choice = rpeChip(label, in: app)
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
