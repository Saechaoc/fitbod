import XCTest

/// Ticket T18, review items 35 and 43. An edge swipe from the left goes back
/// one screen on a pushed screen, the same as the screen's own back control.
/// The app hides the system navigation bar to draw its BRU headers, and
/// UIKit's back swipe does not start under a hidden bar. On a stack's root
/// screen the swipe does nothing.
///
/// The swipe test opens one screen the way a user does, swipes back from
/// the left edge across the screen, and checks that the screen closes and
/// the control that opened it shows again where it was. Each swipe back
/// ends near the right edge, so an edge swipe that UIKit starts late still
/// passes halfway (F243).
final class SwipeBackUITests: XCTestCase {
    /// The control `open` tapped last, and where it sat.
    private var lastOpened: (control: XCUIElement, frame: CGRect)?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Today

    @MainActor
    func testHistorySwipesBackToToday() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        let sessions = app.buttons["today.sessions"]
        open(sessions, in: app)
        assertSwipeBack(from: historyRow(in: app), "History", to: sessions, in: app)
    }

    // MARK: - Root screens

    /// On each tab's first screen and on Settings, an edge swipe does
    /// nothing: the screen stays where it was, and it still opens its next
    /// screen and comes back, so nothing is stuck or half drawn. The swipe
    /// runs along the header. Lower down it would start on a full-width
    /// row, and a drag that starts on a row presses it, with or without
    /// the back swipe.
    @MainActor
    func testSwipeOnARootScreenDoesNothing() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)

        let sessions = app.buttons["today.sessions"]
        assertRootIgnoresSwipe(sessions, alongRowOf: app.staticTexts["Fitbod / Today"], "Today", in: app)
        UITestNavigation.saveScreenshot("T18", "today-after-root-swipe")
        assertStillNavigates(from: sessions, to: app.staticTexts["No sessions yet"], in: app)

        UITestNavigation.selectTab("Program", in: app)
        let program = app.staticTexts["PROGRAM"]
        assertRootIgnoresSwipe(program, alongRowOf: program, "Program", in: app)
        UITestNavigation.hittable(app.buttons, "+ NEW").tap()
        UITestNavigation.hittable(app.buttons, "+ New routine").tap()
        assertBackControlReturns(from: nameStep(in: app), to: program, in: app)

        UITestNavigation.selectTab("Progress", in: app)
        let workouts = app.buttons["progress.history"]
        assertRootIgnoresSwipe(workouts, alongRowOf: headerTitle("Progress", in: app), "Progress", in: app)
        assertStillNavigates(from: workouts, to: app.staticTexts["No sessions yet"], in: app)

        UITestNavigation.selectTab("Library", in: app)
        let search = app.textFields["library.search.browser"]
        assertRootIgnoresSwipe(search, alongRowOf: headerTitle("Library", in: app), "Library", in: app)
        UITestNavigation.type("Barbell Bench Press", into: search, replacing: false)
        let bench = benchPressName(in: app)
        assertStillNavigates(from: bench, to: viewAllHistory(in: app), in: app)

        UITestNavigation.openSettings(in: app)
        let close = app.buttons["Close"]
        assertRootIgnoresSwipe(close, alongRowOf: close, "Settings", in: app)
        UITestNavigation.saveScreenshot("T18", "settings-after-root-swipe")
        let inventory = app.buttons.labeled("Plate Inventory")
        open(inventory, in: app)
        UITestNavigation.hittable(app.buttons, "Done ▸").tap()
        XCTAssertTrue(app.otherElements["plateInventory.tabStrip"].waitForNonExistence(timeout: 10),
                      "Done must close Plate Inventory after a swipe on Settings")
        XCTAssertTrue(waitUntilHittable(inventory), "Settings must show again after Plate Inventory closes")
    }

    // MARK: - Screens

    @MainActor
    private func historyRow(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(identifier: "history.row").firstMatch
    }

    /// The name field of the step + New routine opens.
    @MainActor
    private func nameStep(in app: XCUIApplication) -> XCUIElement {
        app.textFields["newRoutine.name"]
    }

    /// The exercise screen's VIEW ALL HISTORY row.
    @MainActor
    private func viewAllHistory(in app: XCUIApplication) -> XCUIElement {
        button(beginningWith: "View all history", in: app)
    }

    @MainActor
    private func button(beginningWith label: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", label)).firstMatch
    }

    @MainActor
    private func benchPressName(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Barbell Bench Press - Medium Grip")).firstMatch
    }

    // MARK: - Navigation

    /// Scrolls `control` into view and taps it once it can be tapped.
    @MainActor
    private func open(_ control: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(control.waitForExistence(timeout: 15), "Missing \(control)", file: file, line: line)
        UITestNavigation.reveal(control, in: app)
        XCTAssertTrue(waitUntilHittable(control), "\(control) cannot be tapped", file: file, line: line)
        lastOpened = (control, control.frame)
        control.tap()
    }

    /// Swipes right from 1pt inside the left edge of the screen, along the
    /// row of `row` or across the middle of the screen, to 2% short of the
    /// right edge. Under load UIKit can start the edge swipe late, about
    /// 100pt into the drag, and move the screen only from there: a drag that
    /// ended at 80% of the width, as `UITestNavigation.swipeBack(in:)`'s
    /// does, then moved the screen just past halfway, and UIKit sprang it
    /// back (F243; T106's recordings of two such failures). Ending near the
    /// right edge keeps a late start well past halfway.
    @MainActor
    private func swipeBack(alongRowOf row: XCUIElement? = nil, in app: XCUIApplication) {
        let y = row?.frame.midY ?? app.frame.midY
        let screen = app.coordinate(withNormalizedOffset: .zero)
        screen.withOffset(CGVector(dx: 1, dy: y)).press(
            forDuration: 0.05, thenDragTo: screen.withOffset(CGVector(dx: app.frame.width * 0.98, dy: y)),
            withVelocity: .default, thenHoldForDuration: 0
        )
    }

    /// Waits until `element` has left the screen: it is gone, or something
    /// covers it. Volume Targets' rows stay in the accessibility tree for
    /// seconds after it closes, by its ‹ as well.
    @MainActor
    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        repeat {
            if !element.exists || !element.isHittable { return true }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date.now < deadline
        return false
    }

    @MainActor
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: element)
        return XCTWaiter().wait(for: [hittable], timeout: timeout) == .completed
    }

    // MARK: - Checks

    /// Waits for the pushed screen, marked by `screen`, to settle, swipes
    /// back from the left edge, across the middle of the screen or along the
    /// row of `row`, and checks that the screen closes and `opener`, the
    /// control that opened it, can be tapped again, where it was when `open`
    /// tapped it.
    @MainActor
    private func assertSwipeBack(
        from screen: XCUIElement, _ name: String, to opener: XCUIElement, in app: XCUIApplication,
        alongRowOf row: XCUIElement? = nil, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(screen.waitForExistence(timeout: 15), "\(name) never opened", file: file, line: line)
        // A swipe during a push does nothing, and XCUI reports where views
        // end up, not where they are mid-push. The screen under leaves the
        // accessibility tree once the push is over.
        _ = opener.waitForNonExistence(timeout: 5)
        UITestNavigation.waitUntilStill(screen, interval: 0.3)
        swipeBack(alongRowOf: row, in: app)
        XCTAssertTrue(waitUntilGone(screen),
                      "An edge swipe on \(name) must go back, but \(name) is still on screen", file: file, line: line)
        XCTAssertTrue(waitUntilHittable(opener, timeout: 5),
                      "The swipe must go back to the screen that opened \(name)", file: file, line: line)
        if let lastOpened, lastOpened.control === opener {
            UITestNavigation.waitUntilStill(opener, interval: 0.3)
            XCTAssertEqual(opener.frame.minX, lastOpened.frame.minX, accuracy: 1,
                           "The screen under \(name) must come back where it was", file: file, line: line)
            XCTAssertEqual(opener.frame.minY, lastOpened.frame.minY, accuracy: 1,
                           "The screen under \(name) must come back where it was", file: file, line: line)
        }
    }

    /// Swipes from the left edge of a root screen, marked by `root`, along
    /// the row of `header`, an element of its header, and checks that the
    /// screen stays put.
    @MainActor
    private func assertRootIgnoresSwipe(
        _ root: XCUIElement, alongRowOf header: XCUIElement, _ name: String, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(waitUntilHittable(root), "\(name) must show", file: file, line: line)
        XCTAssertTrue(header.exists, "\(name) must show its header", file: file, line: line)
        let before = root.frame
        let barsBefore = systemBars(in: app)
        swipeBack(alongRowOf: header, in: app)
        UITestNavigation.waitUntilStill(root, interval: 0.3)
        XCTAssertTrue(root.exists && root.isHittable, "A swipe on \(name) must leave it on screen", file: file, line: line)
        XCTAssertEqual(root.frame, before, "A swipe on \(name) must not move it", file: file, line: line)
        XCTAssertEqual(systemBars(in: app), barsBefore, "A swipe on \(name) must not show or hide a system bar",
                       file: file, line: line)
    }

    /// A tab's header title, not the tab bar cell's label.
    @MainActor
    private func headerTitle(_ title: String, in app: XCUIApplication) -> XCUIElement {
        let titles = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", title))
        return titles.allElementsBoundByIndex.first { $0.frame.maxY < app.frame.midY } ?? titles.firstMatch
    }

    /// Taps `control` and checks that the next screen, marked by `next`,
    /// opens and its back control returns to `control`.
    @MainActor
    private func assertStillNavigates(
        from control: XCUIElement, to next: XCUIElement, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        open(control, in: app, file: file, line: line)
        assertBackControlReturns(from: next, to: control, in: app, file: file, line: line)
    }

    @MainActor
    private func assertBackControlReturns(
        from screen: XCUIElement, to previous: XCUIElement, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(screen.waitForExistence(timeout: 10), "The next screen must open after a swipe on the root", file: file, line: line)
        UITestNavigation.hittable(app.buttons, "Back", file: file, line: line).tap()
        XCTAssertTrue(screen.waitForNonExistence(timeout: 10), "‹ BACK must close the next screen", file: file, line: line)
        XCTAssertTrue(waitUntilHittable(previous), "‹ BACK must return to the root", file: file, line: line)
    }

    /// Where the system navigation bars on screen sit.
    @MainActor
    private func systemBars(in app: XCUIApplication) -> [CGRect] {
        app.navigationBars.allElementsBoundByIndex.filter(\.isHittable).map(\.frame)
    }
}
