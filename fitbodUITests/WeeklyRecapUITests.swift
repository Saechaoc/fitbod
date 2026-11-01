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
//  shows. On the recap, the cover's PR chip draws its label in a color
//  that reads on its fill, and START W{N} ▸ is the footer's only button:
//  ALL RECAPS did nothing, because no screen lists past recaps.
//
//  T114, findings F242 and F277. The sessions chip measures last week
//  against the training days its block planned, "1 / 4 sessions", and
//  without a plan names no target, "1 session". At AX3 on the small phone
//  each cover chip wraps between words, never inside one.
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

        let sessions = app.staticTexts["recap.sessions"]
        XCTAssertTrue(sessions.exists, "The recap's cover shows no sessions chip")
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

    /// T114: one session on a block that planned four training days last
    /// week reads against that plan, and is no strong week.
    @MainActor
    func testRecapMeasuresLastWeekAgainstItsPlan() throws {
        let app = UITestNavigation.launch(UITestNavigation.recapWithPlan)
        openToday(afterSeeding: 1, in: app)
        let title = recapTitle(in: app)
        guard title.waitForExistence(timeout: 10) else {
            return XCTFail("A logged workout last week must make the weekly recap due")
        }
        UITestNavigation.waitUntilStill(title)
        UITestNavigation.saveScreenshot("T114", "recap-target")

        let sessions = app.staticTexts["recap.sessions"]
        XCTAssertTrue(sessions.exists, "The recap's cover shows no sessions chip")
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

    /// T114: at AX3 each cover chip keeps every word whole on one line,
    /// inside the screen and clear of the other chips. XCUI reads a label
    /// whole even where the screen breaks a word, so each chip's lines are
    /// read from a screenshot.
    @MainActor
    func testCoverChipsWrapBetweenWordsAtAX3() throws {
        let app = UITestNavigation.launch(UITestNavigation.recapWithPlan, textSize: .ax3)
        openToday(afterSeeding: 1, in: app)
        let title = recapTitle(in: app)
        guard title.waitForExistence(timeout: 10) else {
            return XCTFail("A logged workout last week must make the weekly recap due")
        }
        UITestNavigation.waitUntilStill(title)
        UITestNavigation.saveScreenshot("T114", "recap-chips", textSize: .ax3)

        let screenshot = XCUIScreen.main.screenshot()
        let window = app.windows.firstMatch
        let ids = ["recap.prs", "recap.sessions", "recap.tonnage"]
        let chips = ids.map { app.staticTexts[$0] }
        for (id, chip) in zip(ids, chips) {
            guard chip.exists else {
                XCTFail("The recap's cover shows no \(id) chip")
                continue
            }
            UITestNavigation.assertInside(chip, window)
            // Inside the chip's 1.5pt outline.
            let lines = try UITestNavigation.textLines(in: chip.frame.insetBy(dx: 3, dy: 2), of: screenshot)
            let read = lines.map { Self.readable($0.text) }
            for word in chip.label.split(separator: " ").map(Self.readable) where !word.isEmpty {
                XCTAssertTrue(
                    read.contains { $0.contains(word) },
                    "\"\(chip.label)\" must keep each word whole on one line, but the chip reads \(lines.map(\.text))"
                )
            }
        }
        for (index, chip) in chips.enumerated() {
            for other in chips.dropFirst(index + 1) {
                UITestNavigation.assertNoOverlap(chip, other)
            }
        }
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

    /// The recap's header title, such as "Week 44 · recap", whose spaces do
    /// not break.
    @MainActor
    private func recapTitle(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label MATCHES[c] %@", #"Week\s\d+\s·\srecap"#)).firstMatch
    }

    /// `text`'s letters and digits in capitals, with the ones Vision mixes
    /// up in a chip's font read alike: I and 1 as L, 0 as O and 5 as S.
    private static func readable<S: StringProtocol>(_ text: S) -> String {
        String(text.uppercased().compactMap { character -> Character? in
            switch character {
            case "I", "1": "L"
            case "0": "O"
            case "5": "S"
            default: character.isLetter || character.isNumber ? character : nil
            }
        })
    }
}
