import XCTest

/// Ticket T112, findings F229 to F231. An exercise's history shows a row
/// for every workout: its date, intent chip, e1RM, TOP line and set chips.
/// Every row was blank, because each date section and its one row shared
/// the workout's id. A row whose workout set a PR shows "★ PR", and the
/// intent chips and stat labels keep their words whole on the small phone.
///
/// The progress-history seed logs four bench press workouts, a week
/// apart. The newest is a strength workout of 107.5×2 @9.5, 95×6 @8 and
/// 90×5 @7, so its e1RM is 120.3, and its 107.5 is the heaviest bench yet.
final class ExerciseHistoryRowsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNewestWorkoutRowShowsItsE1RMAndSetChips() throws {
        let app = openBenchPressHistory()
        let e1RM = e1RMs(in: app).firstMatch
        XCTAssertTrue(e1RM.waitForExistence(timeout: 10), "The history must show its workout rows")
        XCTAssertEqual(e1RM.label, "e1RM 120.3", "The first row must be the newest workout")
        for chip in ["107.5×2 @9.5", "95×6 @8", "90×5 @7"] {
            XCTAssertTrue(app.staticTexts[chip].exists, "The newest workout's row must show its set chip \(chip)")
        }
        XCTAssertTrue(app.staticTexts["107.5×2 @9.5"].frame.minY > e1RM.frame.maxY,
                      "The set chips must sit under the row's top line")
        // The row's date line shows the date, and no section header repeats it.
        XCTAssertEqual(e1RMs(in: app).count, 4, "Each of the four bench workouts must have its row")
        let date = try XCTUnwrap(dateLine(of: e1RM, in: app), "The newest row must show its date")
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", date.label)).count, 1,
                       "The date \(date.label) must show once, not in a header and the row")
    }

    @MainActor
    func testWorkoutThatSetAPRShowsThePRChip() throws {
        let app = openBenchPressHistory()
        let e1RM = e1RMs(in: app).firstMatch
        XCTAssertTrue(e1RM.waitForExistence(timeout: 10), "The history must show its workout rows")
        let prChips = app.staticTexts.matching(NSPredicate(format: "label == %@", "★ PR"))
        let onNewestRow = prChips.allElementsBoundByIndex.contains { abs($0.frame.midY - e1RM.frame.midY) < 20 }
        XCTAssertTrue(onNewestRow, "The newest workout's 107.5 is a weight PR, so its row must show ★ PR")
    }

    @MainActor
    func testChipAndStatLabelKeepTheirWordsWholeAtDefaultText() throws {
        try assertWordsWhole(textSize: .default)
    }

    @MainActor
    func testChipAndStatLabelKeepTheirWordsWholeAtAX3() throws {
        try assertWordsWhole(textSize: .ax3)
    }

    // MARK: - Helpers

    /// Reads the STRENGTH chip and the "Workouts · 30d" cell off the
    /// screen: a word broken over two lines reads as two words.
    @MainActor
    private func assertWordsWhole(textSize: UITestNavigation.TextSize) throws {
        let app = openBenchPressHistory(textSize: textSize)
        let strength = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "STRENGTH ·")).firstMatch
        XCTAssertTrue(strength.waitForExistence(timeout: 10), "Missing the STRENGTH chip")
        let workouts = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Workouts · 30d")).firstMatch
        XCTAssertTrue(workouts.waitForExistence(timeout: 10), "Missing the Workouts · 30d cell")
        UITestNavigation.waitUntilStill(strength)
        UITestNavigation.saveScreenshot("T112", "exercise-history", textSize: textSize)
        // At AX3 the stat strip stacks and the chip strip scrolls sideways,
        // so the chip can sit under the tab bar or off the trailing edge.
        // The Workouts cell is read first, before the page scrolls.
        let screen = CGRect(x: 0, y: 0, width: app.frame.width, height: tabBarTop(in: app))
        try assertWordWhole("WORKOUTS", in: workouts, within: screen)
        bringOnScreen(strength, within: screen, in: app)
        UITestNavigation.saveScreenshot("T112", "exercise-history-chips", textSize: textSize)
        try assertWordWhole("STRENGTH", in: strength, within: screen)
    }

    @MainActor
    private func assertWordWhole(_ word: String, in element: XCUIElement, within screen: CGRect) throws {
        XCTAssertTrue(screen.contains(element.frame), "\(word) must sit on the screen, at \(element.frame)")
        // Vision misreads widely spaced capitals in some crops, so the word
        // is read from a few margins around the frame. A word broken over
        // two lines reads as two pieces from every one of them.
        let screenshot = XCUIScreen.main.screenshot()
        var reads: [String] = []
        for margin in [CGSize.zero, CGSize(width: 4, height: 4), CGSize(width: 8, height: 0)] {
            let text = try UITestNavigation.readText(
                in: element.frame.insetBy(dx: -margin.width, dy: -margin.height), of: screenshot
            )
            reads.append(text)
            let words = text.uppercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
            if words.contains(word) { return }
        }
        XCTFail("\(word) must not break inside the word, but the screen reads \(reads)")
    }

    /// The top of the tab bar, whose tabs sit in one row, or two at AX3.
    @MainActor
    private func tabBarTop(in app: XCUIApplication) -> CGFloat {
        ["Today", "Program", "Progress", "Library"].map { UITestNavigation.tab($0, in: app).frame.minY }.min() ?? app.frame.maxY
    }

    /// Scrolls the page up, then the chip strip sideways, the way a user
    /// would, until `chip` sits wholly inside `screen`.
    @MainActor
    private func bringOnScreen(_ chip: XCUIElement, within screen: CGRect, in app: XCUIApplication) {
        for _ in 0..<6 where chip.frame.maxY > screen.maxY {
            let page = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            page.press(forDuration: 0.05, thenDragTo: page.withOffset(CGVector(dx: 0, dy: -200)),
                       withVelocity: .slow, thenHoldForDuration: 0.3)
            UITestNavigation.waitUntilStill(chip)
        }
        for _ in 0..<4 where chip.frame.maxX > screen.maxX {
            let start = chip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let overflow = chip.frame.maxX - screen.maxX + 16
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: -overflow, dy: 0)),
                        withVelocity: .slow, thenHoldForDuration: 0.3)
            UITestNavigation.waitUntilStill(chip)
        }
    }

    /// Every workout row's e1RM, top row first.
    @MainActor
    private func e1RMs(in app: XCUIApplication) -> XCUIElementQuery {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "e1RM "))
    }

    /// The text at the leading end of `e1RM`'s line: the row's date.
    @MainActor
    private func dateLine(of e1RM: XCUIElement, in app: XCUIApplication) -> XCUIElement? {
        app.staticTexts.allElementsBoundByIndex
            .filter { abs($0.frame.midY - e1RM.frame.midY) < 20 && $0.frame.minX < 40 }
            .first
    }

    /// Library > the seeded bench press > VIEW ALL HISTORY.
    @MainActor
    private func openBenchPressHistory(textSize: UITestNavigation.TextSize? = nil) -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory, textSize: textSize)
        UITestNavigation.selectTab("Library", in: app)
        UITestNavigation.type("Barbell Bench Press", into: app.textFields["library.search.browser"], replacing: false)
        let bench = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Barbell Bench Press - Medium Grip")).firstMatch
        tapWhenReady(bench, in: app)
        tapWhenReady(app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "View all history")).firstMatch, in: app)
        let prs = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "PRs · 30d")).firstMatch
        XCTAssertTrue(prs.waitForExistence(timeout: 10), "VIEW ALL HISTORY must open the bench press's history")
        UITestNavigation.waitUntilStill(prs, interval: 0.3)
        return app
    }

    @MainActor
    private func tapWhenReady(_ control: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(control.waitForExistence(timeout: 15), "Missing \(control)", file: file, line: line)
        UITestNavigation.reveal(control, in: app)
        let deadline = Date.now.addingTimeInterval(10)
        while !control.isHittable && Date.now < deadline { Thread.sleep(forTimeInterval: 0.25) }
        control.tap()
    }
}
