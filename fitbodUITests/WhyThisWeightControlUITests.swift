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
        UITestNavigation.revealInLogger(weight, in: app)
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

    /// Ticket T09: a logged set shows no WHY, because its weight is history,
    /// not a suggestion to take. The open set below keeps WHY, and the
    /// logged row keeps WHY's space, so both rows' RPE chips stay in line.
    @MainActor
    func testLoggedSetHidesWhy() throws {
        let app = UITestNavigation.openSeededWorkout()
        XCTAssertTrue(app.buttons["set.why.1.S1"].waitForExistence(timeout: 5), "An open set shows WHY")
        let reps = app.textFields["set.reps.1.S1"]
        UITestNavigation.revealInLogger(reps, in: app)
        reps.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        reps.typeText("6")
        let complete = app.buttons["set.complete.1.S1"]
        UITestNavigation.revealInLogger(complete, in: app)
        complete.tap()
        let logged = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Set 1 complete"), object: complete
        )
        XCTAssertEqual(XCTWaiter().wait(for: [logged], timeout: 5), .completed, "Set 1 must be logged")

        XCTAssertTrue(waitUntilGone(app.buttons["set.why.1.S1"]), "A logged set must not show WHY")
        let openWhy = app.buttons["set.why.1.S2"]
        XCTAssertTrue(openWhy.exists, "The open set 2 keeps its WHY")
        attachScreenshot(of: app, named: "logged-set-without-why")

        // Set 1's chips sit between its checkmark and set 2's line; set 2's
        // share a line with its WHY.
        let chips = app.buttons.matching(NSPredicate(format: "label == %@", "RPE 6")).allElementsBoundByIndex
        let secondRowTop = app.buttons["set.complete.1.S2"].frame.minY
        let loggedChip = chips.first { $0.frame.minY >= complete.frame.maxY - 1 && $0.frame.maxY <= secondRowTop + 1 }
        let openChip = chips.first { abs($0.frame.midY - openWhy.frame.midY) < 2 }
        guard let loggedChip, let openChip else {
            return XCTFail("Missing set 1 or set 2 RPE chips: \(chips.map(\.frame))")
        }
        XCTAssertEqual(loggedChip.frame.minX, openChip.frame.minX, accuracy: 0.5,
                       "A logged set's RPE chips must stay in line with an open set's")
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
        XCTAssertTrue(use.waitForExistence(timeout: 5))
        XCTAssertTrue(use.label.hasPrefix("Use 95 "), "Without small plates the suggestion is 95 lb: \(use.label)")
        use.tap()
        XCTAssertTrue(waitUntilGone(use), "Use must close the sheet")
        XCTAssertEqual(numericWeight(weight), 95, "Use must write the suggested weight into the set")
        XCTAssertFalse(overrideMark(in: app).waitForExistence(timeout: 2),
                       "Use must clear the set's \"changed from prescription\" mark")

        UITestNavigation.relaunch(app)
        resumeWorkout(in: app)
        XCTAssertEqual(numericWeight(weightField(in: app)), 95)
        XCTAssertFalse(overrideMark(in: app).waitForExistence(timeout: 2),
                       "The cleared mark must stay cleared after a relaunch")
    }

    /// Ticket T09: WHY keeps a 44pt target and stays on the 390pt screen at
    /// default text and at AX3, where the set row stacks its fields, and it
    /// never covers the RPE chips. Saves set 1's row at both sizes.
    @MainActor
    func testWhyFitsAtDefaultTextAndAX3() throws {
        for size in [UITestNavigation.TextSize.default, .ax3] {
            let app = UITestNavigation.launch(UITestNavigation.seededWorkout, textSize: size)
            let resume = app.buttons["resumeSlab.resume"]
            UITestNavigation.reveal(resume, in: app)
            resume.tap()
            let why = app.buttons["set.why.1.S1"]
            UITestNavigation.reveal(why, in: app)
            UITestNavigation.revealInLogger(why, in: app)
            UITestNavigation.assertTapTarget(why)
            XCTAssertGreaterThanOrEqual(why.frame.minX, app.frame.minX, "WHY must start on screen at \(size)")
            XCTAssertLessThanOrEqual(why.frame.maxX, app.frame.maxX, "WHY must end on screen at \(size)")
            let chip = app.buttons.matching(NSPredicate(format: "label == %@", "RPE 6")).allElementsBoundByIndex
                .filter { $0.frame.minY >= why.frame.minY - 1 }
                .min { $0.frame.minY < $1.frame.minY }
            XCTAssertNotNil(chip, "Set 1's RPE chips must follow its WHY at \(size)")
            if let chip {
                // Brings the chips into view with WHY for the screenshot.
                UITestNavigation.revealInLogger(chip, in: app)
                UITestNavigation.assertNoOverlap(why, chip)
            }
            UITestNavigation.saveScreenshot("T09", "set-row-why", textSize: size)
            app.terminate()
        }
    }

    /// Ticket T61: an exercise with no history has no suggestion, which the
    /// strategies give as 0. Why-this-weight keeps its explanation and
    /// Override but offers no Use, which would only empty the weight field.
    /// Ticket T79: nor does its hero show a 0. It shows the empty weight
    /// field's dash, read as "none", and with nothing to round, the steps
    /// end at 02. Saves the hero, then the sheet scrolled to its steps.
    @MainActor
    func testNoHistoryWhyOffersNoUse() throws {
        let app = UITestNavigation.openEmptySessionBuilder()
        let name = app.textFields["Session name"]
        name.tap()
        name.typeText("T61 First Bench\n")
        app.buttons["Add exercise"].tap()
        let search = app.textFields["library.search.picker"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Barbell Bench Press - Medium Grip")
        let pick = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH[c] %@",
            "exercise.pick.", "Barbell Bench Press - Medium Grip"
        )).firstMatch
        XCTAssertTrue(pick.waitForExistence(timeout: 10))
        pick.tap()
        let save = app.buttons["Save session ▸"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()
        let session = app.staticTexts["T61 First Bench"].firstMatch
        XCTAssertTrue(session.waitForExistence(timeout: 15))
        session.tap()
        let start = app.buttons.labeled("Start workout ▸")
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        UITestNavigation.reveal(start, in: app)
        start.tap()
        XCTAssertTrue(weightField(in: app).waitForExistence(timeout: 15))

        tapWhy(in: app)
        let heading = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Why this weight")).firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 5), "WHY must open Why-this-weight")
        let override = app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Override")).firstMatch
        XCTAssertTrue(override.waitForExistence(timeout: 5), "Override must stay")
        let use = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Use ")).firstMatch
        XCTAssertFalse(use.exists, "A suggestion of 0 is no suggestion, so the sheet must not offer Use")
        UITestNavigation.saveScreenshot("T61", "why-no-history")

        let sheet = app.scrollViews.containing(NSPredicate(format: "label ==[c] %@", "Why this weight")).firstMatch
        let hero = sheet.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Recommended weight")).firstMatch
        XCTAssertTrue(hero.exists, "The sheet must show its hero")
        UITestNavigation.saveScreenshot("T79", "why-no-history-hero")
        let stepTwo = sheet.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "02")).firstMatch
        sheet.swipeUp(velocity: .slow)
        sheet.swipeUp(velocity: .slow)
        XCTAssertTrue(stepTwo.isHittable, "Scrolling the sheet must show step 02")
        UITestNavigation.saveScreenshot("T79", "why-no-history-steps")
        XCTAssertTrue(hero.label.hasPrefix("Recommended weight: none"),
                      "A suggestion of 0 must show the empty weight's dash, not a 0: \(hero.label)")
        let stepThree = sheet.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "03")).firstMatch
        XCTAssertFalse(stepThree.exists, "A suggestion of 0 has nothing to round, so the sheet must leave out step 03")
    }

    /// Ticket T89 (finding F103): the hero shows the set's rep range and
    /// type. Push A's bench is a working set for 5 to 8 reps with no target
    /// RPE, so the hero reads "×5–8" and "WORKING", not "×—" and "TOP SET".
    /// Saves the hero.
    @MainActor
    func testWhyHeroShowsSetRepRangeAndType() throws {
        let app = UITestNavigation.openSeededWorkout()
        tapWhy(in: app)
        let hero = whyHero(in: app)
        XCTAssertTrue(hero.waitForExistence(timeout: 5), "WHY must open Why-this-weight's hero")
        UITestNavigation.saveScreenshot("T89", "push-a-why-hero")
        XCTAssertTrue(hero.label.contains(", reps 5 to 8,"), "The hero must show the set's 5 to 8 rep range: \(hero.label)")
        XCTAssertTrue(hero.label.hasSuffix(", Working"), "The hero must name the set's type: \(hero.label)")
    }

    /// Ticket T89 (finding F103): with a target RPE, the hero shows it, and
    /// step 02 reads "Target @ RPE 8". Calibrating Bench is a working set for
    /// 6 to 8 reps at RPE 8. Saves the hero, then the steps.
    @MainActor
    func testWhyShowsSetTargetRPE() throws {
        let app = UITestNavigation.launch(UITestNavigation.calibratingSet)
        resumeWorkout(in: app)
        tapWhy(in: app)
        let hero = whyHero(in: app)
        XCTAssertTrue(hero.waitForExistence(timeout: 5), "WHY must open Why-this-weight's hero")
        UITestNavigation.saveScreenshot("T89", "calibrating-why-hero")
        let stepTwo = whyStep("02", in: app)
        scrollWhySheet(toShow: stepTwo, in: app)
        UITestNavigation.saveScreenshot("T89", "calibrating-why-steps")
        XCTAssertTrue(hero.label.contains(", reps 6 to 8, RPE 8, Working"),
                      "The hero must show the set's rep range, target RPE and type: \(hero.label)")
        XCTAssertTrue(stepTwo.label.localizedCaseInsensitiveContains("Target @ RPE 8"),
                      "Step 02 must name the set's target RPE: \(stepTwo.label)")
    }

    /// Ticket T89 (finding F105): the steps fill the sheet's width, however
    /// short their text. Their numerals line up with the section head, and
    /// their closing 2pt rule, 12pt below step 03, spans the sheet. Saves
    /// Push A's sheet scrolled to its steps.
    @MainActor
    func testWhyStepsFillSheetWidth() throws {
        let app = UITestNavigation.openSeededWorkout()
        tapWhy(in: app)
        let stepThree = whyStep("03", in: app)
        XCTAssertTrue(stepThree.waitForExistence(timeout: 5), "Push A's suggestion must have a step 03")
        scrollWhySheet(toShow: stepThree, below: 12, in: app)
        UITestNavigation.saveScreenshot("T89", "push-a-why-steps")
        let heading = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Why this weight")).firstMatch
        for index in ["01", "02", "03"] {
            XCTAssertEqual(whyStep(index, in: app).frame.minX, heading.frame.minX, accuracy: 0.5,
                           "Step \(index)'s numeral must line up with the section head")
        }
        let sheet = whySheet(in: app)
        let rule = stepThree.frame.maxY + 11
        let screenshot = XCUIScreen.main.screenshot()
        for x in [sheet.frame.minX + 4, sheet.frame.maxX - 4] {
            UITestNavigation.assertColor(at: CGPoint(x: x, y: rule), in: screenshot, is: UITestNavigation.RGB(hex: 0x0A0A0A))
        }
    }

    @MainActor
    private func tapWhy(in app: XCUIApplication) {
        let why = app.buttons["set.why.1.S1"]
        XCTAssertTrue(why.waitForExistence(timeout: 5), "Set 1 must show a visible WHY control")
        XCTAssertGreaterThanOrEqual(why.frame.width, 44)
        XCTAssertGreaterThanOrEqual(why.frame.height, 44)
        UITestNavigation.revealInLogger(why, in: app)
        why.tap()
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Why-this-weight's scrolling content, above its footer bar.
    @MainActor
    private func whySheet(in app: XCUIApplication) -> XCUIElement {
        app.scrollViews.containing(NSPredicate(format: "label ==[c] %@", "Why this weight")).firstMatch
    }

    /// Why-this-weight's hero, one element read as "Recommended weight …".
    @MainActor
    private func whyHero(in app: XCUIApplication) -> XCUIElement {
        whySheet(in: app).descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Recommended weight")).firstMatch
    }

    /// A Why-this-weight step, one element read from its numeral, "01".
    @MainActor
    private func whyStep(_ index: String, in app: XCUIApplication) -> XCUIElement {
        whySheet(in: app).descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", index)).firstMatch
    }

    /// Scrolls Why-this-weight until `element`, and `below` points under
    /// it, show above the footer bar.
    @MainActor
    private func scrollWhySheet(toShow element: XCUIElement, below: CGFloat = 0, in app: XCUIApplication) {
        let sheet = whySheet(in: app)
        for _ in 0..<4 where !(element.exists && element.frame.maxY + below <= sheet.frame.maxY) {
            sheet.swipeUp(velocity: .slow)
        }
        XCTAssertLessThanOrEqual(element.frame.maxY + below, sheet.frame.maxY, "Scrolling the sheet must show \(element)")
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
        XCTAssertTrue(resume.waitForExistence(timeout: 10))
        resume.tap()
        XCTAssertTrue(app.textFields["set.reps.1.S1"].waitForExistence(timeout: 10))
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
        XCTAssertTrue(done.waitForExistence(timeout: 10))
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
        XCTAssertTrue(close.waitForExistence(timeout: 10))
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
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: 5) == .completed
    }
}
