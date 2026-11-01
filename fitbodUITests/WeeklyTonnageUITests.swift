//
//  WeeklyTonnageUITests.swift
//  fitbodUITests
//
//  Ticket T23, review items 38 and 25, on WeeklyTonnageSeed's finished
//  bench press workouts, one on each of the last few Sundays:
//
//    - A Sunday workout sits in the same week on the chart as in the
//      totals, with the week-start setting at Monday and at Sunday: the
//      axis dates the setting's week starts, read off a screenshot,
//      tapping the workout's bar opens the week that holds it, and
//      VoiceOver names the bar by that week.
//
//  Ticket T104:
//
//    - Last 8 wk holds the eight whole weeks that end with this one, so
//      nine weeks of data never read more than eight weeks.
//

import XCTest

/// Every test and helper here is @MainActor because XCUIApplication and
/// XCUIElement are main-actor isolated.
final class WeeklyTonnageUITests: XCTestCase {
    /// bruInk and bruPaper in light mode.
    private static let ink = UITestNavigation.RGB(hex: 0x0A0A0A)

    override func setUpWithError() throws {
        // Each check reports, so one failure does not hide the rest.
        continueAfterFailure = true
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

    // MARK: - Readers

    @MainActor
    private func rangeLabel(in app: XCUIApplication) -> String {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "TOTAL")).firstMatch.label
    }

    /// How many bars the chart draws, counted on a screenshot.
    @MainActor
    private func drawnBarCount(in app: XCUIApplication) -> Int {
        let chart = app.otherElements["weeklyTonnage.chart"]
        XCTAssertTrue(chart.waitForExistence(timeout: 5), "Missing the chart")
        return drawnBars(in: chart.frame, of: XCUIScreen.main.screenshot()).bars.count
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
