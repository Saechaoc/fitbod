//
//  ProgressChartFitUITests.swift
//  fitbodUITests
//
//  Ticket T56, findings F24, F25 and F26, on ProgressHistorySeed's four
//  finished workouts of the bench press:
//
//    - The hero above the chart labels its value, its change and its FROM
//      line with the exercise's own unit, as the chart's readouts do: KG
//      once the bench press's unit override is kg, never LB.
//    - The screen shows the bench press's whole name at default text.
//      XCUI reads the full label even when the screen cuts it short, so
//      the test reads the name off a screenshot.
//    - The PR label sits fully inside the chart: it is inside the chart's
//      frame, and nothing in the PR label's color is drawn right of it.
//
//  Ticket T68, finding F50, on the same seed:
//
//    - The hero adds up: its change is its value minus its FROM number,
//      as both are shown.
//    - A weight rounds halves up: the bench press's earliest and best
//      e1RM, 112.5, reads 113 on the PR label and to VoiceOver on the
//      TOP SET chip, where each point is read by its own value.
//      VoiceOver reads the PR once, by its label, not the PR rule's
//      unrounded 112.5.
//

import XCTest

final class ProgressChartFitUITests: XCTestCase {
    private let benchPress = "Barbell Bench Press - Medium Grip"
    /// bruSignal in light mode, the PR label's color.
    private static let signal = UITestNavigation.RGB(hex: 0xFF5C1A)

    override func setUpWithError() throws {
        // Each check reports, so one failure does not hide the rest.
        continueAfterFailure = true
    }

    // MARK: - F24: the hero's unit

    @MainActor
    func testHeroReadsTheExercisesUnit() throws {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory)
        setBenchPressUnit(to: "kg", in: app)
        openBenchPressChart(in: app)

        let hero: [(part: String, pattern: String)] = [
            ("value", #"^\d+ (LB|KG)$"#),
            ("change", #"^[+-] \d+ (LB|KG)$"#),
            ("FROM line", #"^FROM \d+ (LB|KG)$"#),
        ]
        for (part, pattern) in hero {
            let text = app.staticTexts.matching(NSPredicate(format: "label MATCHES[c] %@", pattern)).firstMatch
            XCTAssertTrue(text.waitForExistence(timeout: 5), "The hero shows no \(part)")
            XCTAssertTrue(
                text.label.uppercased().hasSuffix(" KG"),
                "The hero's \(part) must read KG, the bench press's unit, not \"\(text.label)\""
            )
        }
        UITestNavigation.saveScreenshot("T56", "chart-kg")
    }

    // MARK: - F26: the whole name

    @MainActor
    func testScreenShowsTheWholeName() throws {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory)
        openBenchPressChart(in: app)

        let name = app.staticTexts[benchPress].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5), "The screen does not name the bench press")
        UITestNavigation.assertInside(name, app.windows.firstMatch)
        UITestNavigation.assertNoOverlap(name, app.buttons["Back"].firstMatch)

        let screenshot = XCUIScreen.main.screenshot()
        UITestNavigation.saveScreenshot("T56", "header")
        let shown = try UITestNavigation.readText(in: name.frame.insetBy(dx: -4, dy: -4), of: screenshot)
        XCTAssertEqual(
            lettersAndDigits(shown), lettersAndDigits(benchPress),
            "The screen must show the bench press's whole name, but it reads \"\(shown)\""
        )
    }

    // MARK: - F25: the PR label

    @MainActor
    func testPRLabelSitsInsideTheChart() throws {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory)
        openBenchPressChart(in: app)
        let chart = app.otherElements["progress.chart"]
        XCTAssertTrue(chart.waitForExistence(timeout: 5), "The chart never appeared")
        // Let the chart's short transition settle before reading pixels.
        Thread.sleep(forTimeInterval: 0.5)

        let screenshot = XCUIScreen.main.screenshot()
        UITestNavigation.saveScreenshot("T56", "chart-pr")
        let window = app.windows.firstMatch.frame
        let rightOfChart = CGRect(
            x: chart.frame.maxX + 1, y: chart.frame.minY,
            width: window.maxX - chart.frame.maxX - 1, height: chart.frame.height
        )
        let spill = try signalPixels(in: rightOfChart, of: screenshot)
        XCTAssertEqual(spill, 0, "\(spill) pixels in the PR label's color are drawn right of the chart, so the label runs out of it")

        let label = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "PR ")).firstMatch
        XCTAssertTrue(label.exists, "The PR label is not on screen as text, so its frame cannot be checked")
        UITestNavigation.assertInside(label, chart)
    }

    // MARK: - F50: the hero adds up

    @MainActor
    func testHeroAndPRLabelAddUp() throws {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory)
        openBenchPressChart(in: app)

        let value = try heroNumber("value", matching: #"^\d+ (LB|KG)$"#, in: app)
        let change = try heroNumber("change", matching: #"^[+-] \d+ (LB|KG)$"#, in: app)
        let from = try heroNumber("FROM line", matching: #"^FROM \d+ (LB|KG)$"#, in: app)
        XCTAssertEqual(
            value.number - from.number, change.number,
            "The hero reads \"\(value.label)\", \"\(change.label)\" and \"\(from.label)\": its value minus its FROM number must be its change"
        )

        let label = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "PR ")).firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: 5), "The chart shows no PR label")
        XCTAssertEqual(label.label, "PR 113", "The PR label must round the bench press's best e1RM, 112.5, half up")
        UITestNavigation.saveScreenshot("T68", "hero-pr")

        app.buttons["TOP SET"].tap()
        let best = app.otherElements.matching(NSPredicate(format: "value == %@", "113 lb")).firstMatch
        XCTAssertTrue(best.waitForExistence(timeout: 5), "VoiceOver must read the bench press's best e1RM, 112.5, as 113 lb")
        let rule = app.otherElements.matching(NSPredicate(format: "value == %@", "112.5")).firstMatch
        XCTAssertFalse(rule.exists, "VoiceOver must read the PR once, by its label, not the PR rule's unrounded 112.5")
    }

    /// The hero's `part` that matches `pattern`, and its number, negative
    /// after a "-" sign.
    @MainActor
    private func heroNumber(
        _ part: String, matching pattern: String, in app: XCUIApplication
    ) throws -> (label: String, number: Int) {
        let text = app.staticTexts.matching(NSPredicate(format: "label MATCHES[c] %@", pattern)).firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 5), "The hero shows no \(part)")
        let label = text.label
        let number = try XCTUnwrap(Int(label.filter(\.isNumber)), "The hero's \(part), \"\(label)\", shows no number")
        return (label, label.hasPrefix("-") ? -number : number)
    }

    // MARK: - Navigation

    /// Library → the seeded bench press → its weight unit chip.
    @MainActor
    private func setBenchPressUnit(to unit: String, in app: XCUIApplication) {
        UITestNavigation.selectTab("Library", in: app)
        let search = app.textFields["library.search.browser"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: search)
        XCTAssertEqual(XCTWaiter().wait(for: [focused], timeout: 5), .completed, "Search never took keyboard focus")
        search.typeText("Barbell Bench Press")
        XCTAssertEqual(search.value as? String, "Barbell Bench Press", "Search must read what was typed")
        let row = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", benchPress)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()

        // The chip's uppercase style reaches its label: "WEIGHT UNIT: KG".
        let chip = app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Weight unit: \(unit)")).firstMatch
        UITestNavigation.reveal(chip, in: app, maxSwipes: 20)
        chip.tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: chip)
        XCTAssertEqual(XCTWaiter().wait(for: [selected], timeout: 5), .completed, "The \(unit) chip is not selected after a tap")
    }

    /// Progress → the bench press's row → its chart.
    @MainActor
    private func openBenchPressChart(in app: XCUIApplication) {
        UITestNavigation.selectTab("Progress", in: app)
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", benchPress)).firstMatch
        UITestNavigation.reveal(row, in: app)
        row.tap()
        XCTAssertTrue(app.buttons["e1RM"].waitForExistence(timeout: 10), "The progress chart never opened")
    }

    // MARK: - Screenshot readers

    /// How many pixels inside `rect`, in screen points, are close to the
    /// PR label's color.
    @MainActor
    private func signalPixels(in rect: CGRect, of screenshot: XCUIScreenshot) throws -> Int {
        let bytes = try XCTUnwrap(UITestNavigation.pixels(in: rect, of: screenshot), "Cannot read the pixels of \(rect)").bytes
        return stride(from: 0, to: bytes.count, by: 4).filter { index in
            let color = UITestNavigation.RGB(red: Int(bytes[index]), green: Int(bytes[index + 1]), blue: Int(bytes[index + 2]))
            return color.distance(to: Self.signal) <= 40
        }.count
    }

    /// Uppercased letters and digits only, so line breaks, spacing and how
    /// a dash is read do not matter. A name cut short loses its last
    /// letters.
    private func lettersAndDigits(_ text: String) -> String {
        String(text.uppercased().filter { $0.isLetter || $0.isNumber })
    }
}
