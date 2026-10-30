import XCTest

/// Ticket T70, finding F53. After END BLOCK, Today opens the ended block's
/// review the next time it shows. Plan custom puts the review off, so it
/// opens again on later visits until Start next acknowledges it.
///
/// Ticket T86, findings F93, F94 and F96. The review's action bar is as
/// tall as its buttons, so the RECOMMENDED NEXT BLOCK band shows whole above
/// it; the band names the template Start next opens; and once the lifter
/// starts a block, a review put off with Plan custom no longer opens.
final class BlockReviewAfterEndUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// Ending the seeded block from its overview on Today opens its review
    /// when the lifter goes back to Today.
    @MainActor
    func testEndingTheBlockOpensItsReviewOnToday() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        endBlockFromTodaysBand(in: app)
        XCTAssertFalse(reviewTitle(in: app).exists, "The review waits until Today shows")
        UITestNavigation.hittable(app.buttons, "Back").tap()

        assertReviewOpens(in: app, "Going back to Today after END BLOCK must open the block's review")
        XCTAssertTrue(UITestNavigation.tab("Today", in: app).isSelected, "The review must open on Today")
        UITestNavigation.saveScreenshot("T70", "review-after-end")
    }

    /// Plan custom closes the review without acknowledging it, so a later
    /// visit to Today and a relaunch open it again. Start next acknowledges
    /// it and opens New Block from Today; after that it never opens again,
    /// and the block stays completed.
    @MainActor
    func testReviewKeepsOpeningUntilStartNextAcknowledgesIt() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        endBlockFromTodaysBand(in: app)
        UITestNavigation.hittable(app.buttons, "Back").tap()
        assertReviewOpens(in: app, "Going back to Today after END BLOCK must open the block's review")

        closeReview(with: "Plan custom", in: app)
        XCTAssertTrue(app.staticTexts.labeled("No active block.").waitForExistence(timeout: 10),
                      "Plan custom must leave the lifter on Today")
        XCTAssertFalse(reviewTitle(in: app).waitForExistence(timeout: 3), "Plan custom must not reopen the review at once")

        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.selectTab("Today", in: app)
        assertReviewOpens(in: app, "The review must open again on the next visit to Today")
        closeReview(with: "Plan custom", in: app)

        UITestNavigation.relaunch(app)
        assertReviewOpens(in: app, "The review must open again after a relaunch")
        UITestNavigation.hittable(app.buttons, "Start next ▸").tap()
        let newBlock = app.staticTexts.labeled("NEW BLOCK")
        XCTAssertTrue(newBlock.waitForExistence(timeout: 10), "Start next must open New Block")
        // T69: the review shows only on Today, so its builder goes back to Today.
        let back = app.buttons.labeled("< TODAY")
        XCTAssertTrue(back.waitForExistence(timeout: 5), "Start next's builder must read < TODAY")
        XCTAssertFalse(app.buttons.labeled("< PROGRAM").exists, "Start next's builder must not read < PROGRAM")
        UITestNavigation.assertTapTarget(back)
        UITestNavigation.hittable(app.buttons, "Cancel")
        UITestNavigation.saveScreenshot("T70", "start-next-builder")
        UITestNavigation.hittable(app.buttons, "Cancel").tap()
        XCTAssertTrue(newBlock.waitForNonExistence(timeout: 5), "CANCEL must close an untouched New Block")
        closeReview(with: "Plan custom", in: app)

        UITestNavigation.selectTab("Program", in: app)
        XCTAssertTrue(app.buttons.labeled("DONE block: Live Block").waitForExistence(timeout: 10),
                      "Acknowledging the review must leave the block completed")
        UITestNavigation.selectTab("Today", in: app)
        XCTAssertTrue(app.staticTexts.labeled("No active block.").waitForExistence(timeout: 10),
                      "Today must still have no active block")
        XCTAssertFalse(reviewTitle(in: app).waitForExistence(timeout: 3), "An acknowledged review must not open again")

        UITestNavigation.relaunch(app)
        XCTAssertTrue(app.staticTexts.labeled("No active block.").waitForExistence(timeout: 10),
                      "Today must still have no active block after a relaunch")
        XCTAssertFalse(reviewTitle(in: app).waitForExistence(timeout: 3),
                       "An acknowledged review must not open after a relaunch")
    }

    // MARK: - T86

    /// F93: on the small phone the action bar took about 350pt and cut off
    /// the RECOMMENDED NEXT BLOCK band. F94: the band recommended
    /// "Intensification · 4 weeks", and Start next opened the 8-week
    /// Hypertrophy Meso.
    @MainActor
    func testReviewFitsAndNamesTheTemplateStartNextOpens() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        endBlockFromTodaysBand(in: app)
        UITestNavigation.hittable(app.buttons, "Back").tap()
        assertReviewOpens(in: app, "Going back to Today after END BLOCK must open the block's review")
        UITestNavigation.waitUntilStill(actionBar(in: app))
        UITestNavigation.saveScreenshot("T86", "review")

        var problems: [String] = []
        if let tall = UITestNavigation.heightProblem(actionBar(in: app), atMost: 64) {
            problems.append(tall)
        }
        problems += bandPlacementProblems(in: app)
        problems += [bandWidthProblem(in: app)].compactMap { $0 }
        problems += try bandWordProblems(in: app)
        let recommended = recommendation(in: app)

        UITestNavigation.hittable(app.buttons, "Start next ▸").tap()
        XCTAssertTrue(app.staticTexts.labeled("NEW BLOCK").waitForExistence(timeout: 10), "Start next must open New Block")
        let weeks = builderTotalWeeks(in: app)
        let opened = "\(builderBlockName(in: app)) · \(weeks) \(weeks == "1" ? "week" : "weeks")"
        if recommended != opened {
            problems.append("The band recommends \"\(recommended)\", but Start next opens \"\(opened)\"")
        }
        XCTAssertTrue(problems.isEmpty, problems.joined(separator: "\n"))
    }

    /// F93 at AX3: the action bar is as tall as its buttons, and the band,
    /// scrolled to the end of the review, shows whole above it, with no word
    /// broken across lines.
    @MainActor
    func testReviewFitsTheSmallPhoneAtAX3() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock, textSize: .ax3)
        endBlockFromTodaysBand(in: app)
        UITestNavigation.hittable(app.buttons, "Back").tap()
        assertReviewOpens(in: app, "Going back to Today after END BLOCK must open the block's review")
        UITestNavigation.waitUntilStill(actionBar(in: app))
        UITestNavigation.saveScreenshot("T86", "review", textSize: .ax3)

        var problems: [String] = []
        let bar = actionBar(in: app).frame
        let buttons = ["Plan custom", "Start next ▸"].map { UITestNavigation.hittable(app.buttons, $0).frame }
        let tallest = buttons.map(\.height).max() ?? 0
        if bar.height > tallest + 0.5 {
            problems.append("The action bar is \(bar.height)pt tall, but its tallest button is \(tallest)pt")
        }
        scrollToBand(in: app)
        UITestNavigation.saveScreenshot("T86", "review-band", textSize: .ax3)
        problems += bandPlacementProblems(in: app)
        problems += [bandWidthProblem(in: app)].compactMap { $0 }
        problems += try bandWordProblems(in: app)
        XCTAssertTrue(problems.isEmpty, problems.joined(separator: "\n"))
    }

    /// F96: Plan custom put the review off, and the lifter then started a
    /// block from Program. The ended block was still the last to end, so its
    /// review covered Today on every visit during the new block. Ending the
    /// new block opens its own review, and the one put off never returns.
    @MainActor
    func testStartingABlockStopsAReviewPutOff() throws {
        let app = UITestNavigation.launch(UITestNavigation.blockStates)
        endBlockFromTodaysBand("Spring Block", in: app)
        UITestNavigation.hittable(app.buttons, "Back").tap()
        XCTAssertTrue(reviewTitle(in: app).waitForExistence(timeout: 10),
                      "Going back to Today after END BLOCK must open the block's review")
        closeReview(with: "Plan custom", in: app)

        startBlockFromProgram("Summer Block", in: app)
        UITestNavigation.selectTab("Today", in: app)
        XCTAssertTrue(app.staticTexts.labeled("SUMMER BLOCK").waitForExistence(timeout: 10),
                      "Today must show the started block's band")
        let opened = reviewTitle(in: app).waitForExistence(timeout: 3)
        UITestNavigation.saveScreenshot("T86", "today-after-start")
        XCTAssertFalse(opened, "No review may open on Today while a block is active")

        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.selectTab("Today", in: app)
        XCTAssertFalse(reviewTitle(in: app).waitForExistence(timeout: 3),
                       "No review may open on a later visit to Today while a block is active")

        UITestNavigation.relaunch(app)
        XCTAssertTrue(app.staticTexts.labeled("SUMMER BLOCK").waitForExistence(timeout: 10),
                      "The started block must stay active after a relaunch")
        XCTAssertFalse(reviewTitle(in: app).waitForExistence(timeout: 3),
                       "No review may open after a relaunch while a block is active")

        endBlockFromTodaysBand("Summer Block", in: app)
        UITestNavigation.hittable(app.buttons, "Back").tap()
        XCTAssertTrue(reviewTitle(in: app).waitForExistence(timeout: 10), "Ending the started block must open its review")
        XCTAssertTrue(app.staticTexts.labeled("Summer Block").exists, "The review must be the block that ended last")
        XCTAssertFalse(app.staticTexts.labeled("Spring Block").exists, "The review put off before the start must not return")
    }

    // MARK: - Helpers

    /// Today's band opens the seeded active block's overview, whose END
    /// BLOCK ends the block after it asks.
    @MainActor
    private func endBlockFromTodaysBand(
        _ block: String = "Live Block", in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) {
        UITestNavigation.selectTab("Today", in: app)
        let band = app.staticTexts.labeled(block.uppercased())
        XCTAssertTrue(band.waitForExistence(timeout: 10), "Today must show the active block's band", file: file, line: line)
        band.tap()
        UITestNavigation.hittable(app.buttons, "END BLOCK", file: file, line: line).tap()
        let alert = app.alerts["End block?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "END BLOCK must ask before it ends the block",
                      file: file, line: line)
        alert.buttons["End Block"].tap()
        XCTAssertTrue(app.buttons.labeled("END BLOCK").waitForNonExistence(timeout: 5),
                      "An ended block offers no END BLOCK", file: file, line: line)
    }

    /// The review's header title.
    @MainActor
    private func reviewTitle(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.labeled("Block review")
    }

    /// The review of the seeded block, numbered 1 and complete, is up and
    /// its actions can be tapped.
    @MainActor
    private func assertReviewOpens(
        in app: XCUIApplication, _ message: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(reviewTitle(in: app).waitForExistence(timeout: 10), message, file: file, line: line)
        let complete = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "BLOCK 1 · COMPLETE"))
        XCTAssertTrue(complete.firstMatch.exists, "The review must be the ended block's", file: file, line: line)
        XCTAssertTrue(app.staticTexts.labeled("Live Block").exists, "The review must name the ended block",
                      file: file, line: line)
        UITestNavigation.hittable(app.buttons, "Plan custom", file: file, line: line)
        UITestNavigation.hittable(app.buttons, "Start next ▸", file: file, line: line)
    }

    /// Closes the review with `action` and waits until it is gone.
    @MainActor
    private func closeReview(with action: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        UITestNavigation.hittable(app.buttons, action, file: file, line: line).tap()
        XCTAssertTrue(reviewTitle(in: app).waitForNonExistence(timeout: 5), "\(action) must close the review",
                      file: file, line: line)
    }

    /// The review's bottom bar with Plan custom and Start next.
    @MainActor
    private func actionBar(in app: XCUIApplication) -> XCUIElement {
        app.otherElements["blockReview.actionBar"]
    }

    /// The RECOMMENDED NEXT BLOCK band.
    @MainActor
    private func recommendedBand(in app: XCUIApplication) -> XCUIElement {
        app.otherElements["blockReview.recommendedNext"]
    }

    /// The review's scroll view, which ends where the action bar starts.
    @MainActor
    private func reviewScrollView(in app: XCUIApplication) -> XCUIElement {
        app.scrollViews.containing(NSPredicate(format: "identifier == %@", "blockReview.recommendedNext")).firstMatch
    }

    /// The band's recommendation, such as "Hypertrophy Meso · 8 weeks".
    @MainActor
    private func recommendation(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> String {
        let text = recommendedBand(in: app).staticTexts.matching(NSPredicate(format: "label CONTAINS %@", " · ")).firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 5), "The band must recommend a block", file: file, line: line)
        return text.label
    }

    /// Each band text that does not lie whole in the review's scroll view,
    /// above the action bar.
    @MainActor
    private func bandPlacementProblems(in app: XCUIApplication) -> [String] {
        let texts = recommendedBand(in: app).staticTexts.allElementsBoundByIndex
        guard !texts.isEmpty else { return ["The review shows no RECOMMENDED NEXT BLOCK band"] }
        let barTop = actionBar(in: app).frame.minY
        let visible = reviewScrollView(in: app).frame.insetBy(dx: -0.5, dy: -0.5)
        return texts.compactMap { text in
            let frame = text.frame
            guard frame.maxY > barTop + 0.5 || !visible.contains(frame) else { return nil }
            return "The band's \"\(text.label)\" spans y \(frame.minY) to \(frame.maxY), "
                + "but the review shows y \(visible.minY + 0.5) to \(visible.maxY - 0.5) above the action bar at y \(barTop)"
        }
    }

    /// The band's fill runs edge to edge, like the bands above it.
    @MainActor
    private func bandWidthProblem(in app: XCUIApplication) -> String? {
        let band = recommendedBand(in: app).frame
        let review = reviewScrollView(in: app).frame
        guard band.minX > review.minX + 0.5 || band.maxX < review.maxX - 0.5 else { return nil }
        return "The band spans x \(band.minX) to \(band.maxX), but the review spans x \(review.minX) to \(review.maxX)"
    }

    /// Each band text that breaks a word across lines, read from the screen.
    /// XCUI reads the whole label however the text wraps. Each word must
    /// show whole on one line; Vision can read spaces into tracked capitals,
    /// so a line is compared without them.
    @MainActor
    private func bandWordProblems(in app: XCUIApplication) throws -> [String] {
        let screenshot = XCUIScreen.main.screenshot()
        return try recommendedBand(in: app).staticTexts.allElementsBoundByIndex.compactMap { text in
            let lines = try UITestNavigation.textLines(in: text.frame.insetBy(dx: -4, dy: -4), of: screenshot)
            let shown = lines.map { Self.letters($0.text) }
            // A one-letter word cannot break.
            let broken = text.label.split(separator: " ").map { Self.letters(String($0)) }
                .filter { word in word.count > 1 && !shown.contains { $0.contains(word) } }
            guard !broken.isEmpty else { return nil }
            return "The band's \"\(text.label)\" breaks \(broken) across lines: the screen reads \(lines.map(\.text))"
        }
    }

    /// Uppercased letters and digits only. Vision reads Space Grotesk's
    /// lowercase "y" as "u" and can read a mono "O" as "0", so each pair
    /// counts as one letter.
    private static func letters(_ text: String) -> String {
        String(text.uppercased().filter { $0.isLetter || $0.isNumber }.map { character -> Character in
            switch character {
            case "0": "O"
            case "Y": "U"
            default: character
            }
        })
    }

    /// Swipes the review up until the band lies whole above the action bar,
    /// the way a lifter scrolls to the end of the review, or gives up.
    @MainActor
    private func scrollToBand(in app: XCUIApplication) {
        let scroll = reviewScrollView(in: app)
        for _ in 0..<6 {
            if bandPlacementProblems(in: app).isEmpty { return }
            scroll.swipeUp(velocity: .slow)
            UITestNavigation.waitUntilStill(recommendedBand(in: app))
        }
    }

    /// New Block's name field; an empty field reports its placeholder.
    @MainActor
    private func builderBlockName(in app: XCUIApplication) -> String {
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Missing the block name field")
        let value = field.value as? String ?? ""
        return value == field.placeholderValue ? "" : value
    }

    /// New Block's TOTAL WEEKS, read as "Total weeks, 8, edit phase durations".
    @MainActor
    private func builderTotalWeeks(in app: XCUIApplication) -> String {
        let cell = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Total weeks, ")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "Missing TOTAL WEEKS")
        let parts = cell.label.components(separatedBy: ", ")
        return parts.count > 1 ? parts[1] : "?"
    }

    /// Program's card for the ready `block` opens its overview, whose START
    /// BLOCK starts it; ‹ BACK then returns to Program.
    @MainActor
    private func startBlockFromProgram(_ block: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        UITestNavigation.selectTab("Program", in: app)
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "READY block: \(block)")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Program must list \(block) as ready", file: file, line: line)
        UITestNavigation.reveal(card, in: app)
        card.tap()
        UITestNavigation.hittable(app.buttons, "START BLOCK ▸", file: file, line: line).tap()
        XCTAssertTrue(app.buttons.labeled("END BLOCK").waitForExistence(timeout: 10),
                      "START BLOCK must make \(block) the active block", file: file, line: line)
        UITestNavigation.hittable(app.buttons, "Back", file: file, line: line).tap()
    }
}
