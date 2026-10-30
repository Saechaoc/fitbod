//
//  CalibratingWeightUITests.swift
//  fitbodUITests
//
//  Ticket T80 (findings F78 and F79): with RPE autoregulation, a set whose
//  exercise is still calibrating shows a weight range until the lifter
//  picks a weight. Override in Why this weight turns the cell into the
//  weight field, holding the set's weight, and focuses it (decision 8). A
//  typed weight or Use keeps showing, a logged set shows the weight it
//  logged, and the range shows whole inside the weight column at default
//  text and at AX3 on the 390pt phone.
//
//  CalibratingSetSeed's sets show "95 – 105 lb", hold last workout's
//  110 lb, and Why this weight suggests 100 lb.
//

import XCTest

extension UITestNavigation {
    /// A fresh store plus "Calibrating Bench": an RPE-autoregulated bench
    /// press still calibrating, with today's workout in progress (see
    /// CalibratingSetSeed).
    static let calibratingSet = [resetFlag, "-fitbod-seed-calibrating-set"]
}

final class CalibratingWeightUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// Override on an open calibrating set closes the sheet, turns the
    /// range into the weight field holding the set's weight, and focuses it.
    /// Ending the edit without picking a weight brings the range back.
    @MainActor
    func testOverrideFocusesWeightField() throws {
        let app = openWorkout()
        XCTAssertTrue(rangeText("1.S1", in: app).waitForExistence(timeout: 10), "An untouched calibrating set must show its range")

        tapOverride(on: "1.S1", in: app)
        let field = weightField("1.S1", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Override must turn the range into the weight field")
        XCTAssertTrue(waitForFocus(field), "Override must focus the weight field")
        XCTAssertTrue(app.keyboards.firstMatch.exists, "Override must bring up the keyboard")
        XCTAssertEqual(field.value as? String, "110 lb", "The field must hold the set's weight")
        XCTAssertFalse(rangeText("1.S1", in: app).exists, "The field must replace the range")

        tapKeyboardDone(in: app)
        XCTAssertTrue(rangeText("1.S1", in: app).waitForExistence(timeout: 5),
                      "Without a weight picked, the set must show its range again")
        XCTAssertFalse(field.exists, "The range must replace the field again")
    }

    /// A weight typed after Override, and a suggestion taken with Use, keep
    /// showing once editing ends and after a relaunch. A set left alone
    /// keeps its range. Saves the typed weight at default text and AX3.
    @MainActor
    func testTypedWeightAndUseKeepShowing() throws {
        for size in [UITestNavigation.TextSize.default, .ax3] {
            let app = openWorkout(textSize: size)
            tapOverride(on: "1.S1", in: app)
            let field = weightField("1.S1", in: app)
            XCTAssertTrue(field.waitForExistence(timeout: 5), "Override must show the weight field at \(size)")
            XCTAssertTrue(waitForFocus(field), "Override must focus the weight field at \(size)")
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "102.5")
            XCTAssertEqual(field.value as? String, "102.5 lb", "The field must read the typed weight at \(size)")
            tapKeyboardDone(in: app)

            XCTAssertEqual(field.value as? String, "102.5 lb", "The typed weight must keep showing at \(size)")
            XCTAssertFalse(rangeText("1.S1", in: app).exists, "The range must not come back at \(size)")
            XCTAssertTrue(overrideMark("1.S1", in: app).exists, "A typed weight away from the suggestion shows its M at \(size)")
            UITestNavigation.revealInLogger(field, in: app)
            UITestNavigation.saveScreenshot("T80", "calibrating-typed-weight", textSize: size)

            let use = openWhy(of: "1.S2", in: app)
                .buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Use ")).firstMatch
            XCTAssertTrue(use.waitForExistence(timeout: 5), "Why this weight must offer Use at \(size)")
            XCTAssertTrue(use.label.hasPrefix("Use 100 "), "The seed's suggestion is 100 lb: \(use.label)")
            use.tap()
            XCTAssertTrue(waitUntilGone(use), "Use must close the sheet at \(size)")
            XCTAssertEqual(weightField("1.S2", in: app).value as? String, "100 lb", "Use must show its weight at \(size)")
            XCTAssertFalse(overrideMark("1.S2", in: app).exists, "A weight Use wrote has no M at \(size)")
            revealSet("1.S3", in: app)
            XCTAssertTrue(rangeText("1.S3", in: app).exists, "A set left alone keeps its range at \(size)")

            UITestNavigation.relaunch(app, textSize: size)
            resumeWorkout(in: app)
            XCTAssertEqual(weightField("1.S1", in: app).value as? String, "102.5 lb", "The typed weight must show after a relaunch at \(size)")
            revealSet("1.S2", in: app)
            XCTAssertEqual(weightField("1.S2", in: app).value as? String, "100 lb", "Use's weight must show after a relaunch at \(size)")
            revealSet("1.S3", in: app)
            XCTAssertTrue(rangeText("1.S3", in: app).exists, "The untouched set keeps its range after a relaunch at \(size)")
            app.terminate()
        }
    }

    /// A logged calibrating set shows the weight it logged, never the
    /// range; the open set after it keeps its range. Saves the logged set
    /// at default text and AX3.
    @MainActor
    func testCompletedSetShowsLoggedWeight() throws {
        for size in [UITestNavigation.TextSize.default, .ax3] {
            let app = openWorkout(textSize: size)
            let reps = app.textFields["set.reps.1.S1"]
            UITestNavigation.revealInLogger(reps, in: app)
            focus(reps)
            reps.typeText("5")
            XCTAssertEqual(reps.value as? String, "5", "Set 1 must read the typed reps at \(size)")
            let complete = app.buttons["set.complete.1.S1"]
            UITestNavigation.revealInLogger(complete, in: app)
            complete.tap()
            let logged = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Set 1 complete"), object: complete)
            XCTAssertEqual(XCTWaiter().wait(for: [logged], timeout: 5), .completed, "Set 1 must be logged at \(size)")

            let field = weightField("1.S1", in: app)
            XCTAssertTrue(field.waitForExistence(timeout: 5), "A logged set must show its weight, not the range, at \(size)")
            XCTAssertEqual(field.value as? String, "110 lb", "A logged set must show the weight it logged at \(size)")
            XCTAssertFalse(rangeText("1.S1", in: app).exists, "A logged set must never show the range at \(size)")
            UITestNavigation.revealInLogger(field, in: app)
            UITestNavigation.saveScreenshot("T80", "calibrating-completed", textSize: size)
            revealSet("1.S2", in: app)
            XCTAssertTrue(rangeText("1.S2", in: app).exists, "The open set 2 keeps its range at \(size)")
            app.terminate()
        }
    }

    /// The range lies inside the weight column, between the PREVIOUS column
    /// and the reps field, and the screen shows all of it: in line at
    /// default text, stacked at AX3. Saves the untouched set at both sizes.
    @MainActor
    func testRangeShowsWholeInWeightColumn() throws {
        for size in [UITestNavigation.TextSize.default, .ax3] {
            let app = openWorkout(textSize: size)
            let range = rangeText("1.S1", in: app)
            XCTAssertTrue(range.waitForExistence(timeout: 10), "An untouched calibrating set must show its range at \(size)")
            UITestNavigation.revealInLogger(range, in: app)
            let reps = app.textFields["set.reps.1.S1"]
            let previous = try XCTUnwrap(previousColumn(before: reps, in: app), "Set 1 must show its PREVIOUS column at \(size)")

            let column = weightColumn(after: previous, before: reps, in: app, textSize: size)
            XCTAssertTrue(
                column.insetBy(dx: -0.5, dy: -0.5).contains(range.frame),
                "The range at \(range.frame) must lie inside the weight column at \(column) at \(size)"
            )
            UITestNavigation.assertNoOverlap(range, reps)
            UITestNavigation.assertNoOverlap(range, previous)

            let screenshot = XCUIScreen.main.screenshot()
            let shown = try UITestNavigation.readText(in: range.frame.insetBy(dx: -4, dy: -4), of: screenshot)
            XCTAssertEqual(
                lettersAndDigits(shown), lettersAndDigits("95 – 105 lb"),
                "The screen must show the range whole at \(size), but it reads \"\(shown)\""
            )
            UITestNavigation.saveScreenshot("T80", "calibrating-range", textSize: size)
            app.terminate()
        }
    }

    // MARK: - Navigation

    /// Launches the calibrating seed and opens today's workout.
    @MainActor
    private func openWorkout(textSize: UITestNavigation.TextSize = .default) -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.calibratingSet, textSize: textSize)
        resumeWorkout(in: app)
        return app
    }

    /// Opens today's workout from Today's resume slab, with set 1 in view.
    @MainActor
    private func resumeWorkout(in app: XCUIApplication) {
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10))
        UITestNavigation.reveal(resume, in: app)
        resume.tap()
        XCTAssertTrue(app.otherElements["workout.header"].waitForExistence(timeout: 10), "The workout never opened")
        revealSet("1.S1", in: app)
    }

    /// One tap on a set's WHY; returns the sheet once its Override shows.
    @discardableResult
    @MainActor
    private func openWhy(of set: String, in app: XCUIApplication) -> XCUIApplication {
        revealSet(set, in: app)
        let why = app.buttons["set.why.\(set)"]
        XCTAssertTrue(why.waitForExistence(timeout: 5), "Set \(set) must show WHY")
        UITestNavigation.revealInLogger(why, in: app)
        why.tap()
        XCTAssertTrue(app.buttons.labeled("Override").waitForExistence(timeout: 5), "WHY must open Why this weight")
        return app
    }

    /// Scrolls the logger until set `set`'s row is in view. Rows load as
    /// they scroll in, so it first scrolls down until the row exists.
    @MainActor
    private func revealSet(_ set: String, in app: XCUIApplication) {
        let reps = app.textFields["set.reps.\(set)"]
        for _ in 0..<10 where !reps.exists {
            let (top, bottom) = UITestNavigation.loggerSpan(in: app)
            UITestNavigation.dragLogger(from: bottom - 20, to: top + 20, in: app)
        }
        XCTAssertTrue(reps.exists, "Set \(set) never loaded")
        UITestNavigation.revealInLogger(reps, in: app)
    }

    /// WHY, then Override, which must close the sheet.
    @MainActor
    private func tapOverride(on set: String, in app: XCUIApplication) {
        let override = openWhy(of: set, in: app).buttons.labeled("Override")
        override.tap()
        XCTAssertTrue(waitUntilGone(override), "Override must close the sheet")
    }

    /// The DONE bar over the number pad ends editing.
    @MainActor
    private func tapKeyboardDone(in app: XCUIApplication) {
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "The keyboard must be up")
        let done = app.buttons.matching(NSPredicate(format: "label ==[c] %@", "DONE")).allElementsBoundByIndex
            .filter { $0.frame.maxY <= keyboard.frame.minY + 1 }
            .max { $0.frame.maxY < $1.frame.maxY }
        guard let done else { return XCTFail("The keyboard must show its DONE bar") }
        done.tap()
        XCTAssertTrue(waitUntilGone(keyboard), "DONE must close the keyboard")
    }

    /// Taps `field` until it has keyboard focus, so typing reaches it.
    @MainActor
    private func focus(_ field: XCUIElement) {
        for _ in 0..<3 {
            field.tap()
            if waitForFocus(field, timeout: 2) { return }
        }
        XCTFail("\(field.identifier) never took keyboard focus")
    }

    // MARK: - Elements

    /// A set's read-only calibrating range. It carries the weight cell's
    /// identifier, as the field does.
    @MainActor
    private func rangeText(_ set: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(
            format: "identifier == %@ AND label BEGINSWITH %@", "set.weight.\(set)", "Prescribed weight range"
        )).firstMatch
    }

    @MainActor
    private func weightField(_ set: String, in app: XCUIApplication) -> XCUIElement {
        app.textFields.matching(identifier: "set.weight.\(set)").firstMatch
    }

    /// A set's "M" mark, which shares the weight cell's identifier.
    @MainActor
    private func overrideMark(_ set: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(
            format: "identifier == %@ AND label == %@", "set.weight.\(set)", "changed from prescription"
        )).firstMatch
    }

    /// The PREVIOUS column of the set whose reps field is `reps`: in line
    /// with it at default text, above it at AX3.
    @MainActor
    private func previousColumn(before reps: XCUIElement, in app: XCUIApplication) -> XCUIElement? {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Previous:"))
            .allElementsBoundByIndex
            .filter { $0.frame.midY <= reps.frame.midY + 1 }
            .max { $0.frame.midY < $1.frame.midY }
    }

    /// The weight column of a set row: between the PREVIOUS column and the
    /// reps field, across the row at default text, and down the screen's
    /// width at AX3, where the row stacks its fields.
    @MainActor
    private func weightColumn(
        after previous: XCUIElement,
        before reps: XCUIElement,
        in app: XCUIApplication,
        textSize: UITestNavigation.TextSize
    ) -> CGRect {
        switch textSize {
        case .default, .xl, .xxl, .xxxl:
            return CGRect(
                x: previous.frame.maxX, y: app.frame.minY,
                width: reps.frame.minX - previous.frame.maxX, height: app.frame.height
            )
        case .ax3:
            return CGRect(
                x: app.frame.minX, y: previous.frame.maxY,
                width: app.frame.width, height: reps.frame.minY - previous.frame.maxY
            )
        }
    }

    // MARK: - Waits

    @MainActor
    private func waitForFocus(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: element)
        return XCTWaiter().wait(for: [focused], timeout: timeout) == .completed
    }

    @MainActor
    private func waitUntilGone(_ element: XCUIElement) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: 5) == .completed
    }

    // MARK: - Screenshot reader

    /// Uppercased letters and digits only, so line breaks, spacing and how
    /// the dash is read do not matter. A range cut short loses its last
    /// letters.
    private func lettersAndDigits(_ text: String) -> String {
        String(text.uppercased().filter { $0.isLetter || $0.isNumber })
    }
}
