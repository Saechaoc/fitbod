//
//  WeeklyTonnageUITests.swift
//  fitbodUITests
//
//  Ticket T23, review items 38 and 25, on WeeklyTonnageSeed's finished
//  bench press workouts, one on each of the last few Sundays:
//
//    - The axis title names the unit setting: TONNAGE (LB) with Settings
//      at lb and TONNAGE (KG) at kg. Units relabel the stored numbers, so
//      the total stays the same.
//    - The range label counts weeks with the shared plural rule:
//      "TOTAL · 1 WEEK" and "TOTAL · 8 WEEKS".
//    - With one week of data, the bar uses less than half of the plot.
//      XCUI reports Swift Charts bars at frames that differ from what is
//      drawn, so the test measures the bar's ink on a screenshot.
//    - A Sunday workout sits in the same week on the chart as in the
//      totals, with the week-start setting at Monday and at Sunday: the
//      axis dates the setting's week starts, read off a screenshot,
//      tapping the workout's bar opens the week that holds it, and
//      VoiceOver names the bar by that week.
//    - With no block, the block filter reads "No block data yet. Define a
//      block in Program."
//    - Screenshots of the chart with one week and with eight weeks, in lb
//      and in kg.
//
//  Ticket T104, findings F158 to F162 and F165:
//
//    - Weekly Tonnage opens in twenty fresh launches in a row on the
//      progress history seed, where it crashed, without the app crashing.
//    - With Last 26 wk, VoiceOver reads each week with data as its own
//      element, by its week and its tonnage, rather than a month at a time,
//      and activating one opens that week, whose total equals the bar.
//    - Last 8 wk holds the eight whole weeks that end with this one, so
//      nine weeks of data never read more than eight weeks.
//    - The chart and its week detail go back with ‹ BACK.
//
//  Ticket T118, findings F249 and F245:
//
//    - The previous-best rule's label reads whole, PREVIOUS BEST, inside
//      the chart, read off a screenshot.
//    - A tap on a week's workout row opens that workout's summary, and
//      ‹ BACK returns to the week. VoiceOver reads the row as a button.
//

import XCTest

/// Every test and helper here is @MainActor because XCUIApplication and
/// XCUIElement are main-actor isolated.
final class WeeklyTonnageUITests: XCTestCase {
    /// bruInk and bruPaper in light mode.
    private static let ink = UITestNavigation.RGB(hex: 0x0A0A0A)
    private static let paper = UITestNavigation.RGB(hex: 0xFAFAF7)

    override func setUpWithError() throws {
        // Each check reports, so one failure does not hide the rest.
        continueAfterFailure = true
    }

    // MARK: - The axis title's unit

    @MainActor
    func testAxisTitleNamesTheUnitSetting() throws {
        let app = launch(weeks: 1)
        setUnit("lb", in: app)
        openWeeklyTonnage(in: app)
        XCTAssertTrue(
            app.staticTexts["TONNAGE (LB)"].waitForExistence(timeout: 5),
            "With Settings at lb, the axis title must read TONNAGE (LB), not \(axisTitle(in: app))"
        )
        let total = heroTotal(in: app)
        UITestNavigation.saveScreenshot("T23", "tonnage-1wk-lb")

        setUnit("kg", in: app)
        UITestNavigation.selectTab("Progress", in: app)
        XCTAssertTrue(
            app.staticTexts["TONNAGE (KG)"].waitForExistence(timeout: 5),
            "With Settings at kg, the axis title must read TONNAGE (KG), not \(axisTitle(in: app))"
        )
        XCTAssertNotNil(total)
        XCTAssertEqual(heroTotal(in: app), total, "Units relabel the total and never convert it")
        UITestNavigation.saveScreenshot("T23", "tonnage-1wk-kg")
    }

    // MARK: - One week of data

    @MainActor
    func testOneWeekDrawsOneNarrowBar() throws {
        let app = launch(weeks: 1)
        openWeeklyTonnage(in: app)
        XCTAssertTrue(
            app.staticTexts["TOTAL · 1 WEEK"].waitForExistence(timeout: 5),
            "One week of data must read TOTAL · 1 WEEK, not \(rangeLabel(in: app))"
        )

        let chart = app.otherElements["weeklyTonnage.chart"]
        XCTAssertTrue(chart.waitForExistence(timeout: 5), "Missing the chart")
        let screenshot = XCUIScreen.main.screenshot()
        let bars = drawnBars(in: chart.frame, of: screenshot).bars
        XCTAssertEqual(bars.count, 1, "One week of data must draw one bar, not \(bars)")
        let plotStart = try XCTUnwrap(plotStart(in: chart.frame, of: screenshot), "Found no plot in the chart")
        let bar = try XCTUnwrap(bars.first)
        // The plot runs at least from its start to the bar's right edge, so
        // a bar narrower than half of that uses less than half of the plot.
        let span = bar.upperBound - plotStart
        let width = bar.upperBound - bar.lowerBound
        XCTAssertLessThan(
            width, span / 2,
            "The bar is \(Int(width))pt wide in a plot at least \(Int(span))pt wide: one week must not fill the chart"
        )
        UITestNavigation.saveScreenshot("T23", "tonnage-1wk-bar")
    }

    // MARK: - Eight weeks of data

    @MainActor
    func testEightWeeksReadEightWeeks() throws {
        let app = launch(weeks: 8)
        setUnit("lb", in: app)
        openWeeklyTonnage(in: app)
        let eightWeeks = app.staticTexts["TOTAL · 8 WEEKS"]
        XCTAssertTrue(
            eightWeeks.exists || eightWeeks.waitForExistence(timeout: 5),
            "Eight weeks of data must read TOTAL · 8 WEEKS, not \(rangeLabel(in: app))"
        )
        XCTAssertEqual(drawnBarCount(in: app), 8, "Eight weeks of data must draw eight bars in Last 26 wk")
        XCTAssertTrue(app.staticTexts["TONNAGE (LB)"].exists, "The axis title must read TONNAGE (LB)")
        UITestNavigation.saveScreenshot("T23", "tonnage-8wk-26wk-lb")
        app.buttons["Last 8 weeks"].tap()
        // Last 8 wk holds the eight whole weeks that end with this one (T104).
        let inLastEight = Self.seededWeeks(8, inLast: 8, weekStartsMonday: true)
        XCTAssertEqual(drawnBarCount(in: app), inLastEight, "Last 8 wk must draw the \(inLastEight) weeks of data in its eight whole weeks")
        UITestNavigation.saveScreenshot("T23", "tonnage-8wk-8wk-lb")

        setUnit("kg", in: app)
        UITestNavigation.selectTab("Progress", in: app)
        XCTAssertTrue(app.staticTexts["TONNAGE (KG)"].waitForExistence(timeout: 5), "The axis title must read TONNAGE (KG)")
        UITestNavigation.saveScreenshot("T23", "tonnage-8wk-8wk-kg")
        app.buttons["Last 26 weeks"].tap()
        UITestNavigation.saveScreenshot("T23", "tonnage-8wk-26wk-kg")
    }

    // MARK: - A Sunday workout's week

    @MainActor
    func testSundayWorkoutSharesItsWeekWhenWeeksStartMonday() throws {
        try checkSundayWorkoutsWeek(weekStartsSunday: false)
    }

    @MainActor
    func testSundayWorkoutSharesItsWeekWhenWeeksStartSunday() throws {
        try checkSundayWorkoutsWeek(weekStartsSunday: true)
    }

    /// Two Sunday workouts: the axis must date the setting's week starts,
    /// and the newest bar must open the week that holds its workout.
    @MainActor
    private func checkSundayWorkoutsWeek(weekStartsSunday: Bool) throws {
        let app = launch(weeks: 2, weekStartsSunday: weekStartsSunday)
        openWeeklyTonnage(in: app)
        app.buttons["Last 8 weeks"].tap()
        XCTAssertTrue(
            app.staticTexts["TOTAL · 2 WEEKS"].waitForExistence(timeout: 5),
            "Two Sundays a week apart are two weeks, not \(rangeLabel(in: app))"
        )
        let firstWeekday = weekStartsSunday ? 1 : 2
        let setting = weekStartsSunday ? "Sunday" : "Monday"
        let calendar = Calendar(identifier: .gregorian)

        let chart = app.otherElements["weeklyTonnage.chart"]
        XCTAssertTrue(chart.exists || chart.waitForExistence(timeout: 5), "Missing the chart")
        let screenshot = XCUIScreen.main.screenshot()
        let dates = try axisDates(in: chart.frame, of: screenshot)
        XCTAssertGreaterThanOrEqual(dates.count, 2, "Read too few axis dates: \(dates.map(\.text))")
        for (text, date) in dates {
            XCTAssertEqual(
                calendar.component(.weekday, from: date), firstWeekday,
                "The axis dates \(text), a \(date.formatted(.dateTime.weekday(.wide))), but the totals' weeks start on \(setting)"
            )
        }
        UITestNavigation.saveScreenshot("T23", "sunday-workouts-\(setting.lowercased())-weeks")

        // Swift Charts reports bars at frames other than the drawn ones, so
        // tap the middle of the newest bar as drawn.
        let spokenWeeks = chart.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Week of "))
        let newestSpoken = spokenWeeks.allElementsBoundByIndex.max { $0.frame.midX < $1.frame.midX }?.label
        let drawn = drawnBars(in: chart.frame, of: screenshot)
        let newest = try XCTUnwrap(drawn.bars.last, "The chart draws no bars")
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: (newest.lowerBound + newest.upperBound) / 2, dy: drawn.row))
            .tap()
        let title = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of ")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Tapping a bar must open its week")
        XCTAssertEqual(newestSpoken, title.label, "VoiceOver must name the newest bar by the week it opens")
        let week = try XCTUnwrap(Self.date(title.label, format: "'Week of 'MMM d, yyyy"), "Cannot read \(title.label)")
        XCTAssertEqual(calendar.component(.weekday, from: week), firstWeekday, "\(title.label) must start on \(setting)")

        let workout = app.buttons.matching(identifier: "weekDetail.row").firstMatch
        XCTAssertTrue(workout.exists || workout.waitForExistence(timeout: 5), "\(title.label) must list the Sunday workout")
        // The row reads its workout, its day, then its tonnage: "Tonnage
        // Weeks, Sun, Oct 25 · 1,500 lb".
        let day = workout.label.range(of: "Sun, [A-Z][a-z]{2} [0-9]{1,2}", options: .regularExpression)
            .map { String(workout.label[$0]) } ?? workout.label
        let sunday = try XCTUnwrap(Self.date(day, format: "EEE, MMM d", near: week), "Cannot read \(workout.label)")
        let weekEnd = try XCTUnwrap(calendar.date(byAdding: .day, value: 7, to: week))
        XCTAssertTrue(
            week <= sunday && sunday < weekEnd,
            "The bar holds the workout of \(workout.label), outside \(title.label)"
        )
        UITestNavigation.saveScreenshot("T23", "sunday-workout-\(setting.lowercased())-week-detail")
    }

    // MARK: - The block filter

    @MainActor
    func testBlockFilterSendsYouToProgram() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        openWeeklyTonnage(in: app)
        XCTAssertTrue(
            app.staticTexts["No block data yet. Define a block in Program."].waitForExistence(timeout: 5),
            "With no block, the block filter must send you to Program"
        )
        UITestNavigation.saveScreenshot("T23", "block-filter-empty")
    }

    // MARK: - T104: twenty opens without a crash

    /// Weekly Tonnage crashed inside Swift Charts about one open in six,
    /// on a Dictionary key that broke Hashable, right after its row was
    /// tapped on the progress history seed. Twenty fresh launches of the app
    /// each open it there and read the whole screen, as VoiceOver does, and
    /// the app must still be running every time. Only the first launch
    /// resets and seeds the store; the other nineteen reopen the app on it,
    /// a new process each time, without importing the catalog again.
    @MainActor
    func testOpensTwentyTimesWithoutCrashing() throws {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory)
        var downOn: [Int] = []
        for open in 1...20 {
            if open > 1 {
                UITestNavigation.relaunch(app)
            }
            openWeeklyTonnage(in: app)
            let chart = app.otherElements["weeklyTonnage.chart"]
            let drawn = chart.exists || chart.waitForExistence(timeout: 10)
            _ = try? app.snapshot()
            if !drawn || app.state != .runningForeground {
                downOn.append(open)
            }
        }
        XCTAssertEqual(downOn, [], "Weekly Tonnage must open every time, but the app went down on opens \(downOn) of 20")
    }

    // MARK: - T104: one VoiceOver element per week

    /// With Last 26 wk, VoiceOver read the bars a month at a time, such as
    /// "Sep 1, 2026 to Oct 1, 2026", and could not open a week. Each week
    /// with data must be its own element, named by its week and read as its
    /// tonnage, and activating one must open that week, whose total is the
    /// bar's.
    @MainActor
    func testEachWeekIsItsOwnVoiceOverElement() throws {
        let weeks = 10
        let app = launch(weeks: weeks)
        openWeeklyTonnage(in: app)
        let range = app.staticTexts["TOTAL · \(weeks) WEEKS"]
        XCTAssertTrue(
            range.exists || range.waitForExistence(timeout: 5),
            "Last 26 wk must hold all \(weeks) weeks of data, not \(rangeLabel(in: app))"
        )
        let chart = app.otherElements["weeklyTonnage.chart"]
        XCTAssertTrue(chart.exists || chart.waitForExistence(timeout: 5), "Missing the chart")
        UITestNavigation.saveScreenshot("T104", "tonnage-26wk")

        let elements = try chartElements(in: chart)
        let heard = elements.map { "\($0.label): \($0.value)" }.joined(separator: "\n")
        let weekElements = elements.filter { $0.label.hasPrefix("Week of ") }
        XCTAssertEqual(weekElements.count, weeks, "VoiceOver must read each of the \(weeks) weeks by itself, but hears:\n\(heard)")
        XCTAssertEqual(Set(weekElements.map(\.label)).count, weekElements.count, "Two elements name the same week:\n\(heard)")
        let calendar = Calendar(identifier: .gregorian)
        for element in weekElements {
            XCTAssertNotNil(
                element.value.range(of: "^[0-9][0-9,]* lb$", options: .regularExpression),
                "\(element.label) must read its tonnage in lb, not \"\(element.value)\""
            )
            let week = Self.date(element.label, format: "'Week of 'MMM d, yyyy")
            XCTAssertEqual(week.map { calendar.component(.weekday, from: $0) }, 2, "\(element.label) must name a Monday week")
        }
        let stretches = elements.filter { $0.label.contains(" to ") || $0.value.contains(" to ") }
        XCTAssertEqual(stretches.map(\.label), [], "No element may read a stretch of weeks:\n\(heard)")

        // Activate the fourth newest week, as VoiceOver's double tap does,
        // at the element's own place on the chart.
        let byAge = weekElements.sorted { $0.frame.midX > $1.frame.midX }
        let target = try XCTUnwrap(byAge.dropFirst(3).first, "Too few week elements to pick one:\n\(heard)")
        chart.descendants(matching: .any).matching(NSPredicate(format: "label == %@", target.label)).firstMatch.tap()
        let title = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of ")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Activating \(target.label) must open its week")
        XCTAssertEqual(title.label, target.label, "Activating \(target.label) opened another week")
        let total = app.staticTexts[target.value.replacingOccurrences(of: " lb", with: "")]
        XCTAssertTrue(
            total.exists || total.waitForExistence(timeout: 5),
            "\(target.label)'s detail must total the bar's \(target.value), but shows \(heroTotal(in: app) ?? "no total")"
        )
        UITestNavigation.saveScreenshot("T104", "week-detail")
    }

    // MARK: - T104: Last 8 wk holds whole weeks

    /// Last 8 wk rolled its lower bound with the clock, so it could hold
    /// nine weeks. It holds the eight whole weeks that end with this one:
    /// with nine weeks of Sunday workouts, it counts only the Sundays in
    /// those weeks.
    @MainActor
    func testLastEightWeeksHoldsEightWholeWeeks() throws {
        let app = launch(weeks: 9)
        let expected = Self.seededWeeks(9, inLast: 8, weekStartsMonday: true)
        openWeeklyTonnage(in: app)
        app.buttons["Last 8 weeks"].tap()
        let label = "TOTAL · \(expected) WEEK\(expected == 1 ? "" : "S")"
        XCTAssertTrue(
            app.staticTexts[label].waitForExistence(timeout: 5),
            "Last 8 wk must count the \(expected) weeks of data in its eight whole weeks, \(label), not \(rangeLabel(in: app))"
        )
        XCTAssertEqual(drawnBarCount(in: app), expected, "Last 8 wk must draw the \(expected) weeks in its eight whole weeks")
        UITestNavigation.saveScreenshot("T104", "tonnage-8wk-9wk-data")
    }

    // MARK: - T104: ‹ BACK

    /// The chart and its week detail are pushed screens, so each goes back
    /// with ‹ BACK rather than a bare ‹. VoiceOver calls both "Back", so the
    /// shown text comes off a screenshot.
    @MainActor
    func testChartAndWeekDetailGoBackWithBack() throws {
        let app = launch(weeks: 2)
        openWeeklyTonnage(in: app)
        let chartBack = try back(on: "Weekly Tonnage", in: app)
        UITestNavigation.saveScreenshot("T104", "tonnage-back")

        // Tap the middle of the newest bar as drawn.
        let chart = app.otherElements["weeklyTonnage.chart"]
        XCTAssertTrue(chart.waitForExistence(timeout: 5), "Missing the chart")
        let drawn = drawnBars(in: chart.frame, of: XCUIScreen.main.screenshot())
        let newest = try XCTUnwrap(drawn.bars.last, "The chart draws no bars")
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: (newest.lowerBound + newest.upperBound) / 2, dy: drawn.row))
            .tap()
        let title = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of ")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Tapping a bar must open its week")
        let detailBack = try back(on: "The week detail", in: app)
        UITestNavigation.saveScreenshot("T104", "week-detail-back")

        detailBack.tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 5), "‹ BACK must close the week detail")
        let rangeChip = app.buttons["Last 8 weeks"]
        XCTAssertTrue(rangeChip.exists || rangeChip.waitForExistence(timeout: 5), "‹ BACK must return to the chart")
        chartBack.tap()
        XCTAssertTrue(app.buttons["Last 8 weeks"].waitForNonExistence(timeout: 5), "‹ BACK must close the chart")
    }

    // MARK: - T118: the previous-best label

    /// Swift Charts drew the previous-best rule's label past the rule's
    /// trailing end and cut it at the chart's edge, so the small phone read
    /// "PREVIOU". The label must read whole inside the chart. XCUI reads a
    /// label whole however the screen cuts it, so the text comes off a
    /// screenshot.
    @MainActor
    func testPreviousBestLabelReadsWhole() throws {
        let app = launch(weeks: 2)
        openWeeklyTonnage(in: app)
        let chart = app.otherElements["weeklyTonnage.chart"]
        XCTAssertTrue(chart.exists || chart.waitForExistence(timeout: 5), "Missing the chart")
        // The push must stop moving the chart before its pixels are read.
        UITestNavigation.waitUntilStill(chart, interval: 0.1)
        let read = try UITestNavigation.textLines(in: chart.frame, of: XCUIScreen.main.screenshot()).map(\.text)
        XCTAssertTrue(
            read.contains { Self.squeezed($0).contains("PREVIOUSBEST") },
            "The chart must label its previous best PREVIOUS BEST, whole, but reads \(read)"
        )
        UITestNavigation.saveScreenshot("T118", "tonnage-previous-best")
    }

    // MARK: - T118: a week's rows open their workouts

    /// Each row in a week's detail showed a "›", but a tap on it opened
    /// nothing. A tap on the row must open its workout's summary, as a
    /// History row does, and the summary's ‹ BACK must return to the week.
    /// VoiceOver must read the row as a button.
    @MainActor
    func testWeekRowOpensItsWorkout() throws {
        let app = launch(weeks: 2)
        openWeeklyTonnage(in: app)
        let week = try openNewestWeek(in: app)
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Tonnage Weeks"))
            .firstMatch
        XCTAssertTrue(row.exists || row.waitForExistence(timeout: 5), "\(week) must list its workout")
        XCTAssertEqual(row.elementType, .button, "VoiceOver must read the workout's row as a button")
        UITestNavigation.assertTapTarget(row)

        row.tap()
        let summary = app.staticTexts["WORKOUT COMPLETE"]
        guard summary.waitForExistence(timeout: 5) else {
            XCTFail("A tap on the workout's row in \(week) must open its summary, but nothing opened")
            return
        }
        UITestNavigation.saveScreenshot("T118", "week-row-summary")
        try back(on: "The workout's summary", in: app).tap()
        XCTAssertTrue(summary.waitForNonExistence(timeout: 5), "‹ BACK must close the summary")
        let title = app.staticTexts[week]
        XCTAssertTrue(title.exists || title.waitForExistence(timeout: 5), "‹ BACK must return to \(week)")
    }

    // MARK: - Navigation

    /// Launches on a fresh store with `weeks` finished Sunday workouts.
    @MainActor
    private func launch(weeks: Int, weekStartsSunday: Bool = false) -> XCUIApplication {
        var arguments = [UITestNavigation.resetFlag, "-fitbod-seed-weekly-tonnage", String(weeks)]
        if weekStartsSunday {
            arguments.append("-fitbod-week-starts-sunday")
        }
        return UITestNavigation.launch(arguments)
    }

    @MainActor
    private func openWeeklyTonnage(in app: XCUIApplication) {
        UITestNavigation.selectTab("Progress", in: app)
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Weekly Tonnage")).firstMatch
        XCTAssertTrue(row.exists || row.waitForExistence(timeout: 10), "Progress must offer Weekly Tonnage")
        row.tap()
        XCTAssertTrue(app.buttons["Last 8 weeks"].waitForExistence(timeout: 5), "Weekly Tonnage did not open")
    }

    /// Taps the middle of the newest bar as drawn, since Swift Charts
    /// reports bars at frames other than the drawn ones, and returns the
    /// title of the week it opens, such as "Week of Oct 19, 2026".
    @MainActor
    private func openNewestWeek(in app: XCUIApplication) throws -> String {
        let chart = app.otherElements["weeklyTonnage.chart"]
        XCTAssertTrue(chart.exists || chart.waitForExistence(timeout: 5), "Missing the chart")
        // The push must stop moving the chart before its pixels are read.
        UITestNavigation.waitUntilStill(chart, interval: 0.1)
        let drawn = drawnBars(in: chart.frame, of: XCUIScreen.main.screenshot())
        let newest = try XCTUnwrap(drawn.bars.last, "The chart draws no bars")
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: (newest.lowerBound + newest.upperBound) / 2, dy: drawn.row))
            .tap()
        let title = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of ")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Tapping a bar must open its week")
        return title.label
    }

    /// Sets Units in Settings, which opens from Today, and closes it.
    @MainActor
    private func setUnit(_ unit: String, in app: XCUIApplication) {
        UITestNavigation.openSettings(in: app)
        let option = app.buttons.labeled(unit)
        XCTAssertTrue(option.exists || option.waitForExistence(timeout: 5), "Missing the \(unit) unit")
        option.tap()
        XCTAssertTrue(option.isSelected, "Units must switch to \(unit)")
        app.buttons["Close"].tap()
    }

    // MARK: - Readers

    @MainActor
    private func axisTitle(in app: XCUIApplication) -> String {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "TONNAGE")).firstMatch.label
    }

    @MainActor
    private func rangeLabel(in app: XCUIApplication) -> String {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "TOTAL")).firstMatch.label
    }

    /// The hero's total, such as "1,500".
    @MainActor
    private func heroTotal(in app: XCUIApplication) -> String? {
        let total = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[0-9][0-9,]*$")).firstMatch
        return total.waitForExistence(timeout: 5) ? total.label : nil
    }

    /// `text` as Vision reads it, in Latin capitals without spaces, with
    /// each zero or Q read as the O it stands for: Vision can read the mono
    /// font's O as either.
    @MainActor
    private static func squeezed(_ text: String) -> String {
        UITestNavigation.latin(text)
            .filter { !$0.isWhitespace }
            .replacingOccurrences(of: "0", with: "O")
            .replacingOccurrences(of: "Q", with: "O")
    }

    /// How many bars the chart draws, counted on a screenshot.
    @MainActor
    private func drawnBarCount(in app: XCUIApplication) -> Int {
        let chart = app.otherElements["weeklyTonnage.chart"]
        XCTAssertTrue(chart.waitForExistence(timeout: 5), "Missing the chart")
        return drawnBars(in: chart.frame, of: XCUIScreen.main.screenshot()).bars.count
    }

    /// The header's back control, which VoiceOver calls "Back", once its
    /// screenshot text reads ‹ BACK.
    @MainActor
    private func back(on screen: String, in app: XCUIApplication) throws -> XCUIElement {
        let back = UITestNavigation.hittable(app.buttons, "Back", exactLabel: true)
        UITestNavigation.waitUntilStill(back, interval: 0.1)
        let shown = UITestNavigation.latin(try UITestNavigation.readText(in: back.frame, of: XCUIScreen.main.screenshot()))
        XCTAssertTrue(shown.contains("BACK"), "\(screen) must go back with ‹ BACK, but its back control reads \"\(shown)\"")
        UITestNavigation.assertTapTarget(back)
        return back
    }

    /// The label, value and frame of every element inside the chart that
    /// has a label, as VoiceOver meets them.
    @MainActor
    private func chartElements(in chart: XCUIElement) throws -> [(label: String, value: String, frame: CGRect)] {
        var found: [(label: String, value: String, frame: CGRect)] = []
        func walk(_ node: XCUIElementSnapshot) {
            if !node.label.isEmpty {
                found.append((node.label, node.value as? String ?? "", node.frame))
            }
            node.children.forEach(walk)
        }
        try chart.snapshot().children.forEach(walk)
        return found
    }

    /// How many of the `weeks` Sundays that WeeklyTonnageSeed logs fall in
    /// the last `range` whole weeks, this one included, as the week-start
    /// setting starts them.
    private static func seededWeeks(_ weeks: Int, inLast range: Int, weekStartsMonday: Bool, now: Date = .now) -> Int {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = weekStartsMonday ? 2 : 1
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
              let first = calendar.date(byAdding: .weekOfYear, value: 1 - range, to: thisWeek) else { return 0 }
        return seededSundays(weeks, now: now).filter { $0 >= first }.count
    }

    /// The starts of the `weeks` workouts WeeklyTonnageSeed logs, newest
    /// first, worked out as the seed does: 09:00 on the latest Sunday, or
    /// earlier that Sunday so the hour-long workout is over, else 09:00 the
    /// Sunday before, then a week apart.
    private static func seededSundays(_ weeks: Int, now: Date) -> [Date] {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: now)
        let daysSinceSunday = calendar.component(.weekday, from: today) - 1
        guard let sunday = calendar.date(byAdding: .day, value: -daysSinceSunday, to: today),
              let nine = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: sunday) else { return [] }
        let latest = now.addingTimeInterval(-3600)
        guard let newest = latest >= sunday ? min(nine, latest) : calendar.date(byAdding: .day, value: -7, to: nine) else { return [] }
        return (0..<weeks).compactMap { calendar.date(byAdding: .day, value: -7 * $0, to: newest) }
    }

    /// The bars drawn in `frame`: the runs of bruInk, in points, across the
    /// screenshot row that holds the most ink, and that row's y. Only bars
    /// are drawn in ink.
    @MainActor
    private func drawnBars(in frame: CGRect, of screenshot: XCUIScreenshot) -> (bars: [ClosedRange<CGFloat>], row: CGFloat) {
        guard let (pixelFrame, bytes) = UITestNavigation.pixels(in: frame, of: screenshot) else { return ([], 0) }
        let width = Int(pixelFrame.width)
        let scale = screenshot.image.scale
        var widest: [ClosedRange<Int>] = []
        var widestRow = 0
        for row in 0..<Int(pixelFrame.height) {
            var runs: [ClosedRange<Int>] = []
            var start: Int?
            for column in 0...width {
                let isInk = column < width && Self.color(column, row, width: width, bytes: bytes).distance(to: Self.ink) <= 24
                if isInk, start == nil {
                    start = column
                } else if !isInk, let first = start {
                    runs.append(first...(column - 1))
                    start = nil
                }
            }
            if runs.map(\.count).reduce(0, +) > widest.map(\.count).reduce(0, +) {
                widest = runs
                widestRow = row
            }
        }
        let bars = widest.map { run in
            (pixelFrame.minX + CGFloat(run.lowerBound)) / scale...(pixelFrame.minX + CGFloat(run.upperBound + 1)) / scale
        }
        return (bars, (pixelFrame.minY + CGFloat(widestRow)) / scale)
    }

    /// The plot's left edge in `frame`: the leftmost pixel, on any row, that
    /// is not paper. The y axis sits on the right, so nothing in the chart is
    /// drawn left of the plot.
    @MainActor
    private func plotStart(in frame: CGRect, of screenshot: XCUIScreenshot) -> CGFloat? {
        guard let (pixelFrame, bytes) = UITestNavigation.pixels(in: frame, of: screenshot) else { return nil }
        let width = Int(pixelFrame.width)
        var leftmost: Int?
        for row in 0..<Int(pixelFrame.height) {
            for column in 0..<min(width, leftmost ?? width)
            where Self.color(column, row, width: width, bytes: bytes).distance(to: Self.paper) > 24 {
                leftmost = column
                break
            }
        }
        return leftmost.map { (pixelFrame.minX + CGFloat($0)) / screenshot.image.scale }
    }

    private static func color(_ column: Int, _ row: Int, width: Int, bytes: [UInt8]) -> UITestNavigation.RGB {
        let index = (row * width + column) * 4
        return UITestNavigation.RGB(red: Int(bytes[index]), green: Int(bytes[index + 1]), blue: Int(bytes[index + 2]))
    }

    /// The dates the x axis prints along the bottom of `frame`, such as
    /// "Oct 12", read off the screenshot.
    @MainActor
    private func axisDates(in frame: CGRect, of screenshot: XCUIScreenshot) throws -> [(text: String, date: Date)] {
        let band = CGRect(x: frame.minX, y: frame.maxY - 30, width: frame.width, height: 34)
        let months = "Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec"
        let label = try Regex("(\(months)) ?([0-9]{1,2})")
        return try UITestNavigation.textLines(in: band, of: screenshot).flatMap { line in
            // OCR can read the O of "Oct" as a zero.
            line.text.replacingOccurrences(of: "0ct", with: "Oct").matches(of: label).compactMap { match in
                let text = String(match.output[0].substring ?? "")
                return Self.date(text, format: "MMM d", near: .now).map { (text, $0) }
            }
        }
    }

    /// Parses `text` in US English. A format without a year takes the year
    /// that puts the date within half a year of `reference`.
    private static func date(_ text: String, format: String, near reference: Date? = nil) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        guard let parsed = formatter.date(from: text) else { return nil }
        guard let reference else { return parsed }
        let calendar = Calendar(identifier: .gregorian)
        var parts = calendar.dateComponents([.month, .day], from: parsed)
        let year = calendar.component(.year, from: reference)
        return [year - 1, year, year + 1].compactMap { candidate -> Date? in
            parts.year = candidate
            return calendar.date(from: parts)
        }
        .min { abs($0.timeIntervalSince(reference)) < abs($1.timeIntervalSince(reference)) }
    }
}
