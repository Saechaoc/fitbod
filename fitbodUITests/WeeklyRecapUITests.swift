//
//  WeeklyRecapUITests.swift
//  fitbodUITests
//
//  T103, findings F152, F211, F212, F214 and F215. The weekly recap is due
//  only when last week has a workout that counts as a session, one with
//  logged work sets (decision 6), and its sessions chip counts only those.
//  Each test seeds last week on a fresh store, so its result never depends
//  on what the phone held before, and finds the recap by its header title,
//  such as "Week 44 · recap", so the absence check fails when the recap
//  shows. On the recap, the cover's PR chip draws its label in a color
//  that reads on its fill, and START W{N} ▸ is the footer's only button:
//  ALL RECAPS did nothing, because no screen lists past recaps.
//

import XCTest

extension UITestNavigation {
    /// A fresh store plus an empty Push A last week, with this week's recap
    /// left due (see DemoWorkoutSeed). Program opens first, because on a
    /// fresh store Today can show before the seed and mark the recap seen.
    static let emptyLastWeek = [resetFlag, "-fitbod-seed-empty-last-week", "-fitbod-start-program"]
    /// A fresh store plus a logged Push A and then an empty one last week,
    /// with this week's recap left due (see DemoWorkoutSeed). Program opens
    /// first, as with `emptyLastWeek`.
    static let recapWithEmpty = [resetFlag, "-fitbod-seed-recap-with-empty", "-fitbod-start-program"]
}

final class WeeklyRecapUITests: XCTestCase {

    override func setUpWithError() throws {
        // Each check reports, so one failure does not hide the rest.
        continueAfterFailure = true
    }

    /// Last week's only workout is empty, so nothing last week counts as a
    /// session and the recap is not due.
    @MainActor
    func testRecapDoesNotShowForAnEmptyWorkoutAlone() throws {
        let app = UITestNavigation.launch(UITestNavigation.emptyLastWeek)
        openToday(afterSeeding: 1, in: app)
        XCTAssertTrue(app.buttons["today.sessions"].waitForExistence(timeout: 10), "Today never showed")
        XCTAssertFalse(
            recapTitle(in: app).waitForExistence(timeout: 5),
            "Last week's only workout is empty, so the weekly recap must not show"
        )
        UITestNavigation.saveScreenshot("T103", "today-no-recap")
    }

    /// A logged and an empty workout last week: the recap shows, and its
    /// cover and footer read as they should.
    @MainActor
    func testRecapCountsOnlyTheLoggedWorkout() throws {
        let app = UITestNavigation.launch(UITestNavigation.recapWithEmpty)
        openToday(afterSeeding: 2, in: app)
        let title = recapTitle(in: app)
        guard title.waitForExistence(timeout: 10) else {
            return XCTFail("A logged workout last week must make the weekly recap due")
        }
        UITestNavigation.waitUntilStill(title)
        let screenshot = XCUIScreen.main.screenshot()
        UITestNavigation.saveScreenshot("T103", "recap")

        let sessions = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", #"\d+ / \d+ sessions"#)).firstMatch
        XCTAssertTrue(sessions.exists, "The recap's cover shows no sessions chip")
        XCTAssertEqual(sessions.label, "1 / 1 sessions", "The empty workout must not count as a session")

        let prChip = app.staticTexts["No PRs this wk"]
        XCTAssertTrue(prChip.exists, "The recap's cover shows no PR chip")
        let shown = try UITestNavigation.readText(in: prChip.frame.insetBy(dx: -4, dy: -4), of: screenshot)
        XCTAssertTrue(
            shown.localizedCaseInsensitiveContains("No PRs"),
            "The PR chip's label must read on its fill, but the screen shows \"\(shown)\""
        )

        let allRecaps = app.buttons.matching(NSPredicate(format: "label ==[c] %@", "All recaps")).firstMatch
        XCTAssertFalse(allRecaps.exists, "ALL RECAPS did nothing, so the recap must not offer it")
        let start = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Start W")).firstMatch
        XCTAssertTrue(start.exists, "The recap must offer its Start button")
        XCTAssertEqual(
            start.frame.width, app.windows.firstMatch.frame.width, accuracy: 1,
            "START must fill the recap's footer"
        )
    }

    // MARK: - Helpers

    /// Waits on Progress until the seed has finished `count` workouts,
    /// which its Workouts row counts, empty ones included, then makes the
    /// first visit to Today, which decides whether the recap is due.
    @MainActor
    private func openToday(afterSeeding count: Int, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        UITestNavigation.selectTab("Progress", in: app)
        let workouts = app.buttons["progress.history"]
        let seeded = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "\(count) finished"),
            object: workouts
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [seeded], timeout: 30), .completed,
            "The seed must finish \(count) workouts before Today's first visit", file: file, line: line
        )
        UITestNavigation.selectTab("Today", in: app)
    }

    /// The recap's header title, such as "Week 44 · recap".
    @MainActor
    private func recapTitle(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label ENDSWITH[c] %@", " · recap")).firstMatch
    }
}
