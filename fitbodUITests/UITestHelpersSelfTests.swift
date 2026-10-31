import XCTest

/// Uses every T01 launch, screenshot, frame, pixel and gesture helper at
/// least once, and checks the text sizes T90 added. The first two tests are
/// the fresh-store repro: the check can fail, and two launches with the
/// reset flag in one test process both start fresh.
final class UITestHelpersSelfTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testRelaunchWithoutResetIsNotFresh() {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10), "The seed must leave a workout to resume")

        UITestNavigation.relaunch(app)

        XCTAssertTrue(resume.waitForExistence(timeout: 10), "A relaunch must keep the seeded workout")
        XCTAssertEqual(UITestNavigation.storeFreshness(in: app), "not fresh: no reset on this launch")
    }

    @MainActor
    func testTwoResetLaunchesInOneProcessAreBothFresh() {
        let seeded = UITestNavigation.launch(UITestNavigation.seededWorkout)
        XCTAssertEqual(UITestNavigation.storeFreshness(in: seeded), "fresh")
        XCTAssertTrue(seeded.buttons["resumeSlab.resume"].waitForExistence(timeout: 10), "The seed must leave a workout to resume")

        let fresh = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.assertFreshStore(in: fresh)
        XCTAssertTrue(fresh.staticTexts.labeled("Build your first routine").waitForExistence(timeout: 10))
        XCTAssertFalse(fresh.buttons["resumeSlab.resume"].exists, "The second reset must drop the seeded workout")
    }

    /// Default text is pinned too, so the comparison holds whatever the
    /// simulator's own text size is.
    @MainActor
    func testAX3LaunchMakesTextTallerAndScreenshotsKeepTheirNames() {
        let app = UITestNavigation.launch(UITestNavigation.freshStore, textSize: .default)
        let heading = app.staticTexts.labeled("Build your first routine")
        UITestNavigation.reveal(heading, in: app)
        let defaultHeight = heading.frame.height
        let defaultName = UITestNavigation.saveScreenshot("T01", "today-empty", textSize: .default)

        let ax3 = UITestNavigation.launch(UITestNavigation.freshStore, textSize: .ax3)
        let ax3Heading = ax3.staticTexts.labeled("Build your first routine")
        UITestNavigation.reveal(ax3Heading, in: ax3)
        let ax3Height = ax3Heading.frame.height
        let ax3Name = UITestNavigation.saveScreenshot("T01", "today-empty", textSize: .ax3, appearance: .light)

        let heights = String(format: "%.1fpt tall at default text and %.1fpt at AX3", defaultHeight, ax3Height)
        XCTContext.runActivity(named: "\"Build your first routine\" is \(heights)") { _ in }
        XCTAssertGreaterThan(ax3Height, defaultHeight * 1.3, "AX3 must make the heading much taller than default text")
        XCTAssertTrue(defaultName.hasPrefix("T01-today-empty-") && defaultName.hasSuffix("-default-light"), defaultName)
        XCTAssertTrue(ax3Name.hasPrefix("T01-today-empty-") && ax3Name.hasSuffix("-ax3-light"), ax3Name)
        XCTAssertFalse(ax3Name.contains("pt-"), "A lane phone must be named small or large: \(ax3Name)")
    }

    /// The sizes between default text and AX3 pass the content size
    /// categories PRListAndSeriesUITests once passed by hand, name their
    /// screenshots with its tokens, and each makes the heading taller than
    /// the size before it.
    @MainActor
    func testSizesBetweenDefaultAndAX3PinTheirCategoriesAndNameScreenshots() {
        let sizes: [(size: UITestNavigation.TextSize, category: String, token: String)] = [
            (.xl, "UICTContentSizeCategoryXL", "xl"),
            (.xxl, "UICTContentSizeCategoryXXL", "xxl"),
            (.xxxl, "UICTContentSizeCategoryXXXL", "xxxl"),
        ]
        var shorter = (token: "default", height: headingHeight(at: .default))
        for (size, category, token) in sizes {
            XCTAssertEqual(size.launchArguments, ["-UIPreferredContentSizeCategoryName", category])
            let height = headingHeight(at: size)
            let name = UITestNavigation.saveScreenshot("T90", "today-empty", textSize: size)
            XCTContext.runActivity(named: "\"Build your first routine\" is \(String(format: "%.1f", height))pt tall at \(token)") { _ in }
            XCTAssertGreaterThan(height, shorter.height, "\(token) must make the heading taller than \(shorter.token)")
            XCTAssertTrue(name.hasPrefix("T90-today-empty-") && name.hasSuffix("-\(token)-light"), name)
            XCTAssertFalse(name.contains("pt-"), "A lane phone must be named small or large: \(name)")
            shorter = (token, height)
        }
    }

    @MainActor
    func testFrameChecksPassGoodFramesAndReportBadOnes() {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        let today = UITestNavigation.tab("Today", in: app)
        let library = UITestNavigation.tab("Library", in: app)
        let window = app.windows.firstMatch
        let caption = app.staticTexts.labeled("Day streak")
        XCTAssertTrue(caption.waitForExistence(timeout: 10))

        UITestNavigation.assertNoOverlap(today, library)
        UITestNavigation.assertInside(today, window)
        UITestNavigation.assertNotTallerThanWide(today)
        UITestNavigation.assertTapTarget(today)
        UITestNavigation.assertHeight(today, atMost: 80)

        expectProblem(UITestNavigation.overlapProblem(today, window), mentioning: "\"Today\"", "overlaps")
        expectProblem(UITestNavigation.insideProblem(today, library), mentioning: "\"Today\"", "is not inside", "\"Library\"")
        expectProblem(UITestNavigation.tallerThanWideProblem(window), mentioning: "taller than it is wide")
        expectProblem(UITestNavigation.tapTargetProblem(caption), mentioning: "\"Day streak\"", "44 x 44pt tap target")
        expectProblem(UITestNavigation.heightProblem(today, atMost: 20), mentioning: "\"Today\"", "taller than 20pt")
    }

    /// The selected tab is filled with bruInk; the others sit on bruBg.
    @MainActor
    func testPixelCheckReadsTheTabBarColors() {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        let today = UITestNavigation.tab("Today", in: app).frame
        let library = UITestNavigation.tab("Library", in: app).frame
        let screenshot = XCUIScreen.main.screenshot()
        let selectedFill = CGPoint(x: today.minX + 4, y: today.minY + 20)
        let unselectedFill = CGPoint(x: library.minX + 4, y: library.minY + 20)

        UITestNavigation.assertColor(at: selectedFill, in: screenshot, is: UITestNavigation.RGB(hex: 0x0A0A0A))
        UITestNavigation.assertColor(at: unselectedFill, in: screenshot, is: UITestNavigation.RGB(hex: 0xF2EFE7))
        expectProblem(
            UITestNavigation.colorProblem(at: selectedFill, in: screenshot, is: UITestNavigation.RGB(hex: 0xFAFAF7)),
            mentioning: "#0A0A0A", "not #FAFAF7"
        )
        XCTAssertNil(UITestNavigation.color(at: CGPoint(x: -1, y: today.minY), in: screenshot), "A point off the screen has no color")
    }

    @MainActor
    func testSheetSwipeDownFromTheTopEdgeClosesSettings() {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.openSettings(in: app)

        UITestNavigation.swipeSheetDown(in: app)

        XCTAssertTrue(app.buttons["Close"].waitForNonExistence(timeout: 10), "A swipe down from the top edge must close Settings")
        XCTAssertNil(UITestNavigation.topSheet(in: app))
    }

    /// A half-height sheet floats above the bottom of the screen on iOS 26
    /// and later, and `topSheet(in:)` still finds it, so `swipeSheetDown`
    /// closes it (F171). New Block's Edit Block Duration sheet opens at
    /// half height at default text.
    @MainActor
    func testTopSheetFindsAHalfHeightSheetAndSwipesItDown() {
        let app = UITestNavigation.launch(UITestNavigation.freshStore, textSize: .default)
        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.hittable(app.buttons, "+ NEW").tap()
        UITestNavigation.hittable(app.buttons, "+ New block").tap()
        UITestNavigation.hittable(app.buttons, "Blank Block").tap()
        let newBlock = app.staticTexts.labeled("NEW BLOCK")
        XCTAssertTrue(newBlock.waitForExistence(timeout: 10), "New Block never opened")
        let totalWeeks = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Total weeks, ")).firstMatch
        XCTAssertTrue(totalWeeks.waitForExistence(timeout: 5), "Missing TOTAL WEEKS")
        totalWeeks.tap()
        let title = app.staticTexts.labeled("Edit Block Duration")
        XCTAssertTrue(title.waitForExistence(timeout: 5), "TOTAL WEEKS must open the duration sheet")
        UITestNavigation.waitUntilStill(title)

        let sheet = UITestNavigation.topSheet(in: app)

        guard let sheet else {
            return XCTFail("topSheet(in:) must find the half-height Edit Block Duration sheet")
        }
        let window = app.windows.firstMatch.frame
        let gap = String(format: "%.1f", window.maxY - sheet.frame.maxY)
        XCTContext.runActivity(named: "The sheet is \(sheet.frame), \(gap)pt above the bottom of \(window)") { _ in }
        UITestNavigation.assertInside(title, sheet)
        XCTAssertLessThan(sheet.frame.height, window.height * 0.75, "The duration sheet must open at half height")

        UITestNavigation.swipeSheetDown(in: app)

        XCTAssertTrue(title.waitForNonExistence(timeout: 10), "A swipe down from the top edge must close the duration sheet")
        XCTAssertTrue(newBlock.exists, "Closing the duration sheet must leave New Block open")
    }

    /// Fitbod's pushed screens lose the system back swipe when they hide
    /// the navigation bar (T18), so the swipe is checked on the system
    /// Settings app, whose General screen pops with it. On fitbod's root
    /// screen the swipe changes nothing.
    @MainActor
    func testEdgeSwipeGoesBackOnePushedScreen() {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.swipeBack(in: app)
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5), "An edge swipe on Today must leave Today on screen")
        XCTAssertTrue(UITestNavigation.tab("Today", in: app).isSelected)

        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        defer { settings.terminate() }
        // Settings can reopen where an earlier run left it.
        for _ in 0..<3 where !settings.navigationBars["Settings"].waitForExistence(timeout: 3) {
            settings.navigationBars.buttons.firstMatch.tap()
        }
        let general = settings.buttons["com.apple.settings.general"]
        XCTAssertTrue(general.waitForExistence(timeout: 10), "Settings must list General")
        general.tap()
        XCTAssertTrue(settings.navigationBars["General"].waitForExistence(timeout: 10), "General must push")

        UITestNavigation.swipeBack(in: settings)

        XCTAssertTrue(settings.navigationBars["Settings"].waitForExistence(timeout: 10), "The edge swipe must go back to the Settings list")
        XCTAssertTrue(settings.navigationBars["General"].waitForNonExistence(timeout: 5))
    }

    /// Fails unless the check reported a problem whose message mentions
    /// every one of `words`.
    private func expectProblem(_ problem: String?, mentioning words: String..., file: StaticString = #filePath, line: UInt = #line) {
        guard let problem else {
            return XCTFail("The check must report a problem", file: file, line: line)
        }
        XCTContext.runActivity(named: "Reported: \(problem)") { _ in }
        for word in words {
            XCTAssertTrue(problem.contains(word), "\"\(problem)\" must mention \(word)", file: file, line: line)
        }
    }

    /// Launches a fresh store at `textSize` and returns the height of
    /// Today's "Build your first routine".
    @MainActor
    private func headingHeight(at textSize: UITestNavigation.TextSize) -> CGFloat {
        let app = UITestNavigation.launch(UITestNavigation.freshStore, textSize: textSize)
        let heading = app.staticTexts.labeled("Build your first routine")
        UITestNavigation.reveal(heading, in: app)
        return heading.frame.height
    }
}
