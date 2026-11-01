//
//  CopySweepUITests.swift
//  fitbodUITests
//
//  T34, review item 25, findings F163 and F213. On the small phone:
//
//    - A routine with one session reads "1 session" on Program, and its
//      block's week strip reads "0 / 1 SESSION DONE".
//    - The logger's exercise menu offers "Remove from workout".
//    - The pushed screens go back with ‹ BACK, not a bare ‹. VoiceOver
//      calls both "Back", so the shown text comes off a screenshot.
//      History's summary of a deleted workout is the one no test can open;
//      UICopyRulesTests pins its label.
//    - The weekly recap closes with DONE on the right, and no line of its
//      header title starts with "·", at default text or at AX3.
//

import XCTest

final class CopySweepUITests: XCTestCase {

    override func setUpWithError() throws {
        // Each check reports, so one failure does not hide the rest.
        continueAfterFailure = true
    }

    /// Live Routine has one session, which Program's row and the active
    /// block's week strip count in the singular.
    @MainActor
    func testRoutineWithOneSessionReadsSingular() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        UITestNavigation.selectTab("Program", in: app)
        let routine = UITestNavigation.hittable(app.buttons, "Live Routine")
        XCTAssertTrue(routine.label.components(separatedBy: ", ").contains("1 session"),
                      "Program's routine row must read 1 session, but reads \"\(routine.label)\"")
        UITestNavigation.saveScreenshot("T34", "program-routine-row")

        open(button(beginningWith: "ACTIVE block: Live Block", in: app), in: app)
        let done = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", #"\d+ / \d+ SESSIONS? DONE"#)).firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 10), "The block's week strip shows no session count")
        XCTAssertEqual(done.label, "0 / 1 SESSION DONE", "The week strip must count one session in the singular")
    }

    @MainActor
    func testExerciseMenuOffersRemoveFromWorkout() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        open(app.buttons["resumeSlab.resume"], in: app)
        let bench = app.staticTexts["Barbell Bench Press - Medium Grip"].firstMatch
        XCTAssertTrue(bench.waitForExistence(timeout: 10), "The workout must show the bench press")
        // The menu opens on a long press.
        bench.press(forDuration: 1)
        let remove = app.buttons["Remove from workout"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5), "The exercise menu must offer Remove from workout")
        XCTAssertFalse(app.buttons["Remove from Session"].exists, "A logged workout is a workout on screen")
        UITestNavigation.saveScreenshot("T34", "logger-exercise-menu")
    }

    /// Today's pushed screens: History, a workout's summary opened from
    /// History, and a muscle's volume detail, which opens from further down
    /// Today.
    @MainActor
    func testTodaysPushedScreensGoBackWithBack() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        let sessions = app.buttons["today.sessions"]
        open(sessions, in: app)
        let row = app.buttons.matching(identifier: "history.row").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "History never opened")
        open(row, in: app)
        XCTAssertTrue(app.staticTexts["WORKOUT COMPLETE"].waitForExistence(timeout: 10), "The workout's summary never opened")
        try assertGoesBackWithBack("The workout's summary", screen: "history-summary", in: app)
        XCTAssertTrue(waitUntilHittable(row), "‹ BACK on the summary must return to History")
        try assertGoesBackWithBack("History", screen: "history", in: app)
        XCTAssertTrue(waitUntilHittable(sessions), "‹ BACK on History must return to Today")

        open(app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Chest:")).firstMatch, in: app)
        XCTAssertTrue(app.staticTexts.labeled("Contributing Exercises").waitForExistence(timeout: 10), "The chest's detail never opened")
        try assertGoesBackWithBack("The chest's volume detail", screen: "muscle-detail", in: app)
    }

    /// Progress's and Library's pushed screens: an exercise's chart, its
    /// records, and its history, which counts workouts as workouts.
    @MainActor
    func testProgressAndLibraryScreensGoBackWithBack() throws {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory)
        UITestNavigation.selectTab("Progress", in: app)
        let bench = button(beginningWith: "Barbell Bench Press", in: app)
        open(bench, in: app)
        XCTAssertTrue(app.buttons["e1RM"].waitForExistence(timeout: 10), "The bench press's chart never opened")
        try assertGoesBackWithBack("The bench press's chart", screen: "exercise-chart", in: app)

        let records = button(beginningWith: "Personal Records", in: app)
        open(records, in: app)
        let record = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", ", Weight PR, ")).firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 10), "Personal Records never opened")
        try assertGoesBackWithBack("Personal Records", screen: "personal-records", in: app)

        UITestNavigation.selectTab("Library", in: app)
        UITestNavigation.type("Barbell Bench Press", into: app.textFields["library.search.browser"], replacing: false)
        open(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Barbell Bench Press - Medium Grip")).firstMatch, in: app)
        open(button(beginningWith: "View all history", in: app), in: app)
        // The seed logs the bench press's 13 work sets in four workouts,
        // all in the last 30 days.
        let workouts = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Workouts · 30d")).firstMatch
        if workouts.waitForExistence(timeout: 10) {
            XCTAssertEqual(workouts.value as? String, "4", "Workouts · 30d must count the four workouts")
        } else {
            XCTFail("The bench press's history must count Workouts · 30d")
        }
        XCTAssertTrue(app.staticTexts.labeled("13 sets across 4 workouts").exists,
                      "The history's count line must count workouts, as in 13 sets across 4 workouts")
        try assertGoesBackWithBack("The bench press's history", screen: "exercise-history", in: app)
    }

    @MainActor
    func testWeeklyRecapClosesWithDone() throws {
        try assertWeeklyRecapCloses(textSize: .default)
    }

    /// At AX3 the header stacks its title over its labels, so the title
    /// wraps at another width.
    @MainActor
    func testWeeklyRecapClosesWithDoneAtAX3() throws {
        try assertWeeklyRecapCloses(textSize: .ax3)
    }

    // MARK: - Checks

    /// Reads the back control off the screen, saves the screen, checks the
    /// control reads ‹ BACK and is a full tap target, and taps it.
    @MainActor
    private func assertGoesBackWithBack(
        _ name: String, screen: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let back = UITestNavigation.hittable(app.buttons, "Back", exactLabel: true, file: file, line: line)
        UITestNavigation.waitUntilStill(back, interval: 0.1)
        let shown = UITestNavigation.latin(try UITestNavigation.readText(in: back.frame, of: XCUIScreen.main.screenshot()))
        UITestNavigation.saveScreenshot("T34", screen)
        XCTAssertTrue(shown.contains("BACK"), "\(name) must go back with ‹ BACK, but its back control reads \"\(shown)\"",
                      file: file, line: line)
        UITestNavigation.assertTapTarget(back, file: file, line: line)
        back.tap()
    }

    /// Opens the weekly recap at `textSize` and checks its header: DONE on
    /// the right, no back control, and no line of the title that starts
    /// with "·". XCUI reads the whole title however it wraps, so the lines
    /// come off a screenshot.
    @MainActor
    private func assertWeeklyRecapCloses(textSize: UITestNavigation.TextSize) throws {
        let app = UITestNavigation.launch(UITestNavigation.recapWithEmpty, textSize: textSize)
        openToday(afterSeeding: 2, in: app)
        let title = app.staticTexts.matching(NSPredicate(format: "label MATCHES[c] %@", #"Week\s\d+\s·\srecap"#)).firstMatch
        guard title.waitForExistence(timeout: 10) else {
            return XCTFail("A logged workout last week must make the weekly recap due")
        }
        UITestNavigation.waitUntilStill(title)
        let screenshot = XCUIScreen.main.screenshot()
        UITestNavigation.saveScreenshot("T34", "weekly-recap-header", textSize: textSize)

        let lines = try UITestNavigation.textLines(in: title.frame.insetBy(dx: -4, dy: -4), of: screenshot).map(\.text)
        XCTAssertFalse(lines.isEmpty, "The recap's title shows no text")
        let dotFirst = lines.filter { $0.trimmingCharacters(in: .whitespaces).first.map { "·•∙⋅.".contains($0) } ?? false }
        XCTAssertEqual(dotFirst, [], "No line of the recap's title may start with ·, but it reads \(lines)")

        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Back")).firstMatch.exists,
                       "The recap shows information only, so it closes with DONE, not ‹")
        let done = UITestNavigation.hittable(app.buttons, "Done", exactLabel: true)
        let shown = UITestNavigation.latin(try UITestNavigation.readText(in: done.frame, of: screenshot))
        XCTAssertTrue(shown.contains("DONE"), "The recap's close control must read DONE, but reads \"\(shown)\"")
        XCTAssertGreaterThan(done.frame.midX, app.windows.firstMatch.frame.midX, "DONE must sit on the right")
        XCTAssertLessThan(done.frame.maxY, app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Start W")).firstMatch.frame.minY,
                          "DONE must sit in the recap's header, above its footer")
        UITestNavigation.assertTapTarget(done)
        UITestNavigation.assertInside(done, app.windows.firstMatch)

        done.tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 10), "DONE must close the weekly recap")
    }

    // MARK: - Navigation

    /// Waits on Progress until the seed has finished `count` workouts,
    /// which its Workouts row counts, empty ones included, then makes the
    /// first visit to Today, which decides whether the recap is due.
    @MainActor
    private func openToday(afterSeeding count: Int, in app: XCUIApplication) {
        UITestNavigation.selectTab("Progress", in: app)
        let seeded = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "\(count) finished"),
            object: app.buttons["progress.history"]
        )
        XCTAssertEqual(XCTWaiter().wait(for: [seeded], timeout: 30), .completed,
                       "The seed must finish \(count) workouts before Today's first visit")
        UITestNavigation.selectTab("Today", in: app)
    }

    @MainActor
    private func button(beginningWith label: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", label)).firstMatch
    }

    /// Scrolls `control` into view and taps it once it can be tapped.
    @MainActor
    private func open(_ control: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(control.exists || control.waitForExistence(timeout: 15), "Missing \(control)", file: file, line: line)
        UITestNavigation.reveal(control, in: app)
        XCTAssertTrue(waitUntilHittable(control), "\(control) cannot be tapped", file: file, line: line)
        control.tap()
    }

    @MainActor
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: element)
        return XCTWaiter().wait(for: [hittable], timeout: timeout) == .completed
    }
}
