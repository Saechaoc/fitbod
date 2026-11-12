//
//  WeeklyRecapUITests.swift
//  fitbodUITests
//
//  T103, findings F152, F211, F212, F214 and F215. The weekly recap is due
//  only when last week has a workout that counts as a session, one with
//  logged work sets (decision 6), and its sessions chip and its count of
//  the routines those sessions span count only those.
//  Each test seeds last week on a fresh store, so its result never depends
//  on what the phone held before, and finds the recap by its header title,
//  such as "Week 44 · recap", so the absence check fails when the recap
//  shows.
//
//  RM-020. ALL RECAPS on the recap, and Weekly recaps on Progress, list
//  every past week with a workout that counts, and a row reopens that
//  week's recap, with ‹ BACK and no Start button. The recap and the list
//  read their weeks off the main actor, just after they show.
//
//  T114, findings F242 and F277. The sessions chip measures last week
//  against the training days its block planned, "1 / 4 sessions", and
//  without a plan names no target, "1 session".
//

import XCTest

extension UITestNavigation {
    /// A fresh store plus an empty Push A last week, with this week's recap
    /// left due (see DemoWorkoutSeed). Program opens first, because on a
    /// fresh store Today can show before the seed and mark the recap seen.
    static let emptyLastWeek = [resetFlag, "-fitbod-seed-empty-last-week", "-fitbod-start-program"]
    /// A fresh store plus a logged Push A and then an empty Pull B, a second
    /// routine's workout, last week, with this week's recap left due (see
    /// DemoWorkoutSeed). Program opens first, as with `emptyLastWeek`.
    static let recapWithEmpty = [resetFlag, "-fitbod-seed-recap-with-empty", "-fitbod-start-program"]
    /// A fresh store plus a logged Push A last week on Plan Block, which
    /// planned four training days that week, with this week's recap left
    /// due (see DemoWorkoutSeed). Program opens first, as with
    /// `emptyLastWeek`.
    static let recapWithPlan = [resetFlag, "-fitbod-seed-recap-with-plan", "-fitbod-start-program"]
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
        XCTAssertTrue(UITestNavigation.appears(app.otherElements["today.root"]), "Today never showed")
        // Waits the whole 5 s: a recap that is due shows within it.
        XCTAssertFalse(
            recapTitle(in: app).waitForExistence(timeout: 5),
            "Last week's only workout is empty, so the weekly recap must not show"
        )
    }

    /// A logged and an empty workout last week: the recap shows, and its
    /// cover and footer read as they should.
    @MainActor
    func testRecapCountsOnlyTheLoggedWorkout() throws {
        let app = UITestNavigation.launch(UITestNavigation.recapWithEmpty)
        openToday(afterSeeding: 2, in: app)
        let title = recapTitle(in: app)
        guard UITestNavigation.appears(title) else {
            return XCTFail("A logged workout last week must make the weekly recap due")
        }

        let sessions = app.staticTexts["recap.sessions"]
        XCTAssertTrue(UITestNavigation.appears(sessions), "The recap's cover shows no sessions chip")
        XCTAssertEqual(
            sessions.label, "1 session",
            "The empty workout must not count as a session, and with no block last week the chip names no target"
        )
        XCTAssertTrue(
            app.staticTexts["Last week you logged 1 session."].exists,
            "The recap's Sessions section must count the one logged workout"
        )
        let across = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Across ")).firstMatch
        XCTAssertFalse(
            across.exists,
            "Last week's one session is one routine's, but the recap reads \"\(across.label)\""
        )

        let prChip = app.staticTexts["recap.prs"]
        XCTAssertTrue(prChip.exists, "The recap's cover shows no PR chip")
        // Last week's sets were the first ever logged, which set records (RM-036).
        XCTAssertTrue(prChip.label.hasPrefix("\u{2605} "), "The PR chip must count last week's records, but reads \"\(prChip.label)\"")

        let start = app.buttons.matching(NSPredicate(format: "label MATCHES[c] %@", #"Start W\d+.*"#)).firstMatch
        XCTAssertTrue(start.exists, "The recap must offer its Start button")

        let allRecaps = app.buttons.matching(NSPredicate(format: "label ==[c] %@", "All recaps")).firstMatch
        guard allRecaps.exists else { return XCTFail("The recap must offer ALL RECAPS") }
        allRecaps.tap()
        assertListReopensLastWeek(in: app)
    }

    /// Progress → Weekly recaps lists last week, and its row reopens the
    /// recap Today showed for it.
    @MainActor
    func testProgressListsPastRecaps() throws {
        let app = UITestNavigation.launch(UITestNavigation.recapWithEmpty)
        UITestNavigation.selectTab("Progress", in: app)
        let workouts = app.buttons["progress.history"]
        XCTAssertTrue(
            UITestNavigation.waitUntil(timeout: 30) { workouts.exists && workouts.label.contains("2 finished") },
            "The seed must finish its two workouts"
        )
        let recaps = app.buttons["progress.recaps"]
        guard UITestNavigation.appears(recaps) else { return XCTFail("Progress must offer Weekly recaps") }
        recaps.tap()
        assertListReopensLastWeek(in: app)
    }

    /// T114: one session on a block that planned four training days last
    /// week reads against that plan, and is no strong week.
    @MainActor
    func testRecapMeasuresLastWeekAgainstItsPlan() throws {
        let app = UITestNavigation.launch(UITestNavigation.recapWithPlan)
        openToday(afterSeeding: 1, in: app)
        let title = recapTitle(in: app)
        guard UITestNavigation.appears(title) else {
            return XCTFail("A logged workout last week must make the weekly recap due")
        }

        let sessions = app.staticTexts["recap.sessions"]
        XCTAssertTrue(UITestNavigation.appears(sessions), "The recap's cover shows no sessions chip")
        XCTAssertEqual(
            sessions.label, "1 / 4 sessions",
            "Last week's block planned four training days, so the chip must measure the one session against 4"
        )
        let headline = app.staticTexts["recap.headline"]
        XCTAssertTrue(headline.exists, "The recap's cover shows no headline")
        XCTAssertEqual(
            headline.label.replacingOccurrences(of: "\n", with: " "), "Light week.",
            "One session of four planned is no strong week"
        )
    }

    // MARK: - Helpers

    /// On the week list: one row, last week's, with its one session and its
    /// records, which reopens last week's recap with the same counts, ‹ BACK
    /// and no Start button. Back returns to the list.
    @MainActor
    private func assertListReopensLastWeek(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let row = app.buttons["recaps.row"]
        guard UITestNavigation.appears(row) else {
            return XCTFail("The week list must show last week", file: file, line: line)
        }
        XCTAssertEqual(app.buttons.matching(identifier: "recaps.row").count, 1,
                       "Only last week has a workout that counts", file: file, line: line)
        XCTAssertTrue(row.label.contains("1 session · "), "The row reads \"\(row.label)\"", file: file, line: line)
        let records = row.label.firstMatch(of: /, (\d+) records?$/).flatMap { Int($0.1) }
        XCTAssertNotNil(records, "The row must count last week's records, but reads \"\(row.label)\"", file: file, line: line)

        row.tap()
        let sessions = app.staticTexts["recap.sessions"]
        XCTAssertTrue(UITestNavigation.appears(sessions), "The row must reopen its recap", file: file, line: line)
        XCTAssertEqual(sessions.label, "1 session", "The reopened recap must count last week as before", file: file, line: line)
        if let records {
            XCTAssertEqual(app.staticTexts["recap.prs"].label, "\u{2605} \(records) \(records == 1 ? "PR" : "PRs")",
                           "The reopened recap must count the row's records", file: file, line: line)
        }
        XCTAssertTrue(recapTitle(in: app).exists, "The reopened recap must name its week", file: file, line: line)
        // START W{N} alone: Today's "Start workout ▸" stays under the sheet, and
        // the recap under the list keeps its button until the push ends.
        let start = app.buttons.matching(NSPredicate(format: "label MATCHES[c] %@", #"Start W\d+.*"#)).firstMatch
        XCTAssertTrue(UITestNavigation.disappears(start), "A reopened recap has no Start button", file: file, line: line)

        let back = app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Back")).firstMatch
        guard back.exists else { return XCTFail("The reopened recap must offer ‹ BACK", file: file, line: line) }
        back.tap()
        XCTAssertTrue(UITestNavigation.appears(row), "Back must return to the week list", file: file, line: line)
    }

    /// Waits on Progress until the seed has finished `count` workouts,
    /// which its Workouts row counts, empty ones included, then makes the
    /// first visit to Today, which decides whether the recap is due.
    @MainActor
    private func openToday(afterSeeding count: Int, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        UITestNavigation.selectTab("Progress", in: app)
        let workouts = app.buttons["progress.history"]
        XCTAssertTrue(
            UITestNavigation.waitUntil(timeout: 30) { workouts.exists && workouts.label.contains("\(count) finished") },
            "The seed must finish \(count) workouts before Today's first visit", file: file, line: line
        )
        UITestNavigation.selectTab("Today", in: app)
    }

    /// The recap's header title, such as "Week 44 · recap", whose spaces do
    /// not break.
    @MainActor
    private func recapTitle(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label MATCHES[c] %@", #"Week\s\d+\s·\srecap"#)).firstMatch
    }
}
