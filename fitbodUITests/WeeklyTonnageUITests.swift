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

import XCTest

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
        XCTAssertTrue(
            app.staticTexts["TOTAL · 8 WEEKS"].waitForExistence(timeout: 5),
            "Eight weeks of data must read TOTAL · 8 WEEKS, not \(rangeLabel(in: app))"
        )
        XCTAssertEqual(drawnBarCount(in: app), 8, "Eight weeks of data must draw eight bars in Last 26 wk")
        XCTAssertTrue(app.staticTexts["TONNAGE (LB)"].exists, "The axis title must read TONNAGE (LB)")
        UITestNavigation.saveScreenshot("T23", "tonnage-8wk-26wk-lb")
        app.buttons["Last 8 weeks"].tap()
        XCTAssertEqual(drawnBarCount(in: app), 8, "Eight weeks of data must draw eight bars in Last 8 wk")
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
        XCTAssertTrue(chart.waitForExistence(timeout: 5), "Missing the chart")
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
        let spokenWeeks = chart.otherElements.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of "))
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

        let workout = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Sun, ")).firstMatch
        XCTAssertTrue(workout.waitForExistence(timeout: 5), "\(title.label) must list the Sunday workout")
        let sunday = try XCTUnwrap(Self.date(workout.label, format: "EEE, MMM d", near: week), "Cannot read \(workout.label)")
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
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Progress must offer Weekly Tonnage")
        row.tap()
        XCTAssertTrue(app.buttons["Last 8 weeks"].waitForExistence(timeout: 5), "Weekly Tonnage did not open")
    }

    /// Sets Units in Settings, which opens from Today, and closes it.
    @MainActor
    private func setUnit(_ unit: String, in app: XCUIApplication) {
        UITestNavigation.openSettings(in: app)
        let option = app.buttons.labeled(unit)
        XCTAssertTrue(option.waitForExistence(timeout: 5), "Missing the \(unit) unit")
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

    /// How many bars the chart draws, counted on a screenshot.
    @MainActor
    private func drawnBarCount(in app: XCUIApplication) -> Int {
        let chart = app.otherElements["weeklyTonnage.chart"]
        XCTAssertTrue(chart.waitForExistence(timeout: 5), "Missing the chart")
        return drawnBars(in: chart.frame, of: XCUIScreen.main.screenshot()).bars.count
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
