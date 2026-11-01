//
//  EmptyWorkoutCountsUITests.swift
//  fitbodUITests
//
//  T22, review items 39 and 40. An empty workout, one finished with no
//  logged work sets, stays in History but is left out of every session
//  count and of Compare (decision 6). On DemoWorkoutSeed's logged Push A
//  followed by an empty one:
//
//    - Progress's Recent rows read "1 session", and the chart a row opens
//      still asks for 2 sessions.
//    - Compare shows its locked state.
//    - Today counts 1 session in all and this week.
//    - History's stat strip and its "Past sessions" header count 1
//      session, and the list still shows both workouts.
//
//  With logged Push As six days and one day ago and an empty one between
//  them, Compare sets the two logged workouts side by side.
//
//  T103, finding F151. With a logged Push A yesterday and an empty one
//  today, Today's Day streak counts only yesterday.
//

import XCTest

extension UITestNavigation {
    /// A fresh store plus a logged Push A 30 minutes ago and an empty one
    /// 15 minutes ago (see DemoWorkoutSeed).
    static let emptyWorkout = [resetFlag, "-fitbod-seed-empty-workout"]
    /// A fresh store plus logged Push As six days and one day ago, and an
    /// empty one three days ago (see DemoWorkoutSeed).
    static let emptyBetween = [resetFlag, "-fitbod-seed-empty-between"]
    /// A fresh store plus a logged Push A a day ago and an empty one two
    /// minutes ago (see DemoWorkoutSeed).
    static let emptyToday = [resetFlag, "-fitbod-seed-empty-today"]
}

final class EmptyWorkoutCountsUITests: XCTestCase {
    /// Every catalog name DemoWorkoutSeed's Push A may use.
    private let pushANames = [
        "Barbell Bench Press - Medium Grip", "Bench Press - Powerlifting",
        "Incline Dumbbell Press",
        "Barbell Shoulder Press", "Dumbbell Shoulder Press",
        "Cable Seated Lateral Raise", "Side Lateral Raise",
        "Triceps Pushdown", "Triceps Pushdown - Rope Attachment",
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - One logged workout, then an empty one

    @MainActor
    func testProgressCountsOnlyTheLoggedWorkout() throws {
        let app = UITestNavigation.launch(UITestNavigation.emptyWorkout)
        UITestNavigation.selectTab("Progress", in: app)

        let bench = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Barbell Bench Press")).firstMatch
        XCTAssertTrue(UITestNavigation.appears(bench), "Progress shows no bench press row")
        let settled = settle(bench, NSPredicate(format: "label CONTAINS %@", "1 session ·"))
        XCTAssertTrue(settled, "The empty workout must not count as a session: \(bench.label)")
        let recentRows = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "last logged"))
        for row in recentRows.allElementsBoundByIndex {
            XCTAssertTrue(
                row.label.contains("1 session ·"),
                "The empty workout must not count as a session: \(row.label)"
            )
        }

        bench.tap()
        let locked = app.staticTexts.matching(NSPredicate(format: "label == %@", "Log 2 sessions to see your trend.")).firstMatch
        XCTAssertTrue(UITestNavigation.appears(locked), "With 1 session the chart must still ask for 2")
    }

    @MainActor
    func testCompareStaysLockedWithOneLoggedWorkout() throws {
        let app = UITestNavigation.launch(UITestNavigation.emptyWorkout)
        UITestNavigation.selectTab("Progress", in: app)
        scrollToCompare(in: app)

        XCTAssertFalse(
            compareRow(in: app).exists,
            "With one logged workout there is nothing to compare, but Compare offers This week vs last week"
        )
        XCTAssertTrue(app.staticTexts["No comparable session yet"].exists, "Compare must show its locked state")
        XCTAssertTrue(app.staticTexts["Log a routine twice to compare."].exists, "Compare must show its locked state")
    }

    @MainActor
    func testTodayCountsOnlyTheLoggedWorkout() throws {
        let app = UITestNavigation.launch(UITestNavigation.emptyWorkout)
        let sessions = app.buttons["today.sessions"]
        XCTAssertTrue(UITestNavigation.appears(sessions))
        XCTAssertTrue(
            settle(sessions, NSPredicate(format: "value == %@", "1")),
            "Today's session total must leave the empty workout out, but it reads \(sessions.value as? String ?? "nothing")"
        )

        // Both workouts started within the last 30 minutes, so they are in
        // this week unless the week (Monday, the fresh store's setting)
        // began even more recently.
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        if let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start,
           Date().timeIntervalSince(weekStart) > 45 * 60 {
            let thisWeek = element(labeled: "Sessions this week", in: app)
            XCTAssertTrue(thisWeek.exists, "Today shows no This week count")
            XCTAssertEqual(thisWeek.value as? String, "1", "This week's count must leave the empty workout out")
        }
    }

    @MainActor
    func testHistoryCountsOnlyTheLoggedWorkout() throws {
        let app = UITestNavigation.launch(UITestNavigation.emptyWorkout)
        let sessions = app.buttons["today.sessions"]
        XCTAssertTrue(UITestNavigation.appears(sessions))
        sessions.tap()

        let rows = app.buttons.matching(identifier: "history.row")
        XCTAssertTrue(UITestNavigation.appears(rows.firstMatch))
        XCTAssertEqual(rows.count, 2, "History must still list the empty workout")

        let strip = element(labeled: "Sessions in the last 30 days", in: app)
        XCTAssertTrue(strip.exists, "History shows no Sessions count")
        XCTAssertEqual(strip.value as? String, "1", "History's Sessions count must leave the empty workout out")
        let perWeek = element(labeled: "Sessions per week, last 4 weeks", in: app)
        XCTAssertEqual(
            perWeek.value as? String,
            (1.0 / 4).formatted(.number.precision(.fractionLength(0...2))),
            "History's Per week must average 1 session over 4 weeks"
        )
        let header = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "1 session")).firstMatch
        XCTAssertTrue(UITestNavigation.appears(header), "The Past sessions header must count 1 session")
    }

    // MARK: - An empty workout between two logged ones

    @MainActor
    func testCompareSetsTheTwoLoggedWorkoutsSideBySide() throws {
        let launchedAt = Date()
        let app = UITestNavigation.launch(UITestNavigation.emptyBetween)
        UITestNavigation.selectTab("Progress", in: app)
        scrollToCompare(in: app)
        let row = compareRow(in: app)
        XCTAssertTrue(row.exists, "Two logged workouts must unlock Compare")
        row.tap()

        let latest = headerDate(daysAgo: 1, since: launchedAt, in: app)
        XCTAssertTrue(UITestNavigation.appears(latest), "Compare must open on the latest logged workout, a day ago")
        let earlier = headerDate(daysAgo: 6, since: launchedAt, in: app)
        XCTAssertTrue(
            earlier.exists,
            "Compare must set the latest logged workout against the one six days ago, past the empty one between them"
        )

        let names = app.staticTexts.matching(NSPredicate(format: "label IN %@", pushANames))
        XCTAssertGreaterThanOrEqual(names.count, 2, "Compare shows fewer than two exercises side by side")
    }

    // MARK: - A logged workout yesterday, an empty one today

    @MainActor
    func testDayStreakCountsOnlyTheLoggedWorkout() throws {
        let app = UITestNavigation.launch(UITestNavigation.emptyToday)
        let streak = element(labeled: "Day streak", in: app)
        XCTAssertTrue(UITestNavigation.appears(streak), "Today shows no Day streak")
        // The empty workout started two minutes before launch: in the first
        // two minutes after midnight it fell yesterday, beside the logged
        // one, and the streak reads 1 under any rule.
        XCTAssertTrue(
            settle(streak, NSPredicate(format: "value == %@", "1 day")),
            "The empty workout today must not add a day to the streak, but it reads \(streak.value as? String ?? "nothing")"
        )
    }

    // MARK: - Helpers

    /// Waits until `element` matches `predicate`. The all-time counts leave
    /// empty workouts out once a screen has read them, a moment after it
    /// appears.
    @MainActor
    private func settle(_ element: XCUIElement, _ predicate: NSPredicate, timeout: TimeInterval = 10) -> Bool {
        UITestNavigation.waitUntil(timeout: timeout) { element.exists && predicate.evaluate(with: element) }
    }

    /// Progress's "This week vs last week" row.
    @MainActor
    private func compareRow(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "This week vs last week")).firstMatch
    }

    /// Scrolls Progress down until its Compare section sits above the tab
    /// bar. Hidden tabs keep their scroll views, so it swipes the one a
    /// user can touch.
    @MainActor
    private func scrollToCompare(in app: XCUIApplication) {
        UITestNavigation.reveal(app.staticTexts["Compare"], in: app)
        app.scrollViews.allElementsBoundByIndex.last(where: { $0.isHittable })?.swipeUp(velocity: .slow)
    }

    /// A stat strip cell, by what VoiceOver calls it.
    @MainActor
    private func element(labeled label: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// Compare's column date for a workout the seed started `daysAgo` days
    /// before launch, as in "OCT 29". It accepts the day before a midnight
    /// that passed since launch too.
    @MainActor
    private func headerDate(daysAgo: Double, since launchedAt: Date, in app: XCUIApplication) -> XCUIElement {
        let labels = Set([launchedAt, Date()].map { now in
            now.addingTimeInterval(-daysAgo * 24 * 3600)
                .formatted(.dateTime.month(.abbreviated).day())
                .uppercased()
        })
        return app.staticTexts.matching(NSPredicate(format: "label IN %@", Array(labels))).firstMatch
    }
}
