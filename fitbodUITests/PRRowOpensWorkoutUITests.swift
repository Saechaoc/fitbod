//
//  PRRowOpensWorkoutUITests.swift
//  fitbodUITests
//
//  T136, finding F319, on ProgressHistorySeed's four finished workouts: a
//  tap on a Personal Records row opens the summary of the workout its set
//  was logged in, the screen a History row opens, and the summary's ‹ BACK
//  returns to Personal Records. The row opened a "Session of <date>" stub
//  with no ‹ BACK. VoiceOver reads the row as a button.
//

import XCTest

final class PRRowOpensWorkoutUITests: XCTestCase {

    // The test and its helpers are @MainActor because XCUIApplication and
    // XCUIElement are main-actor types.

    @MainActor
    func testRecordRowOpensItsWorkout() throws {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory)
        let row = firstRecordRow(in: app)
        XCTAssertEqual(row.elementType, .button, "VoiceOver must read the record's row as a button")
        let day = try XCTUnwrap(row.value as? String, "The record's row must say the day its set was logged")

        row.tap()
        let summary = app.staticTexts["WORKOUT COMPLETE"]
        guard summary.waitForExistence(timeout: 10) else {
            let stub = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Session of ")).firstMatch
            XCTFail("A tap on a record's row must open its workout's summary, as a History row does, but it opened "
                    + (stub.exists ? "the \"\(stub.label)\" stub" : "no summary"))
            return
        }
        XCTAssertTrue(dateLine(naming: day, in: app).exists, "The summary must be the workout the record was set in, on \(day)")

        let back = try backControl(in: app)
        UITestNavigation.saveScreenshot("T136", "record-summary")

        back.tap()
        XCTAssertTrue(summary.waitForNonExistence(timeout: 10), "‹ BACK must close the summary")
        XCTAssertTrue(waitUntilHittable(row), "‹ BACK must return to Personal Records")
    }

    // MARK: - Screens

    /// Progress → Personal Records, and its first record's row once it can
    /// be tapped: the heaviest set of 1-6 reps.
    @MainActor
    private func firstRecordRow(in app: XCUIApplication) -> XCUIElement {
        UITestNavigation.selectTab("Progress", in: app)
        let records = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Personal Records")).firstMatch
        UITestNavigation.reveal(records, in: app)
        records.tap()
        let row = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", ", Weight PR, ")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Personal Records must list the seeded records")
        UITestNavigation.reveal(row, in: app)
        return row
    }

    /// The summary's date line when it names `day`, the day a set was
    /// logged, such as "Oct 25, 2026", or the day before it, when the
    /// workout ran past midnight. The line reads like "Sun, Oct 25 at 9:58 AM".
    @MainActor
    private func dateLine(naming day: String, in app: XCUIApplication) -> XCUIElement {
        guard let logged = try? Date(day, strategy: Date.FormatStyle(date: .abbreviated, time: .omitted).parseStrategy),
              let before = Calendar.current.date(byAdding: .day, value: -1, to: logged) else {
            XCTFail("Cannot read \"\(day)\" as a day")
            return app.staticTexts["no such date line"]
        }
        let days = [logged, before]
            .map { NSRegularExpression.escapedPattern(for: $0.formatted(.dateTime.month(.abbreviated).day())) }
            .joined(separator: "|")
        return app.staticTexts.matching(NSPredicate(format: "label MATCHES[c] %@", "\\w+, (\(days))\\b.*")).firstMatch
    }

    /// The summary's back control, which VoiceOver calls "Back", once its
    /// screenshot text reads ‹ BACK, and a full tap target.
    @MainActor
    private func backControl(in app: XCUIApplication) throws -> XCUIElement {
        let back = UITestNavigation.hittable(app.buttons, "Back", exactLabel: true)
        UITestNavigation.waitUntilStill(back, interval: 0.1)
        let shown = UITestNavigation.latin(try UITestNavigation.readText(in: back.frame, of: XCUIScreen.main.screenshot()))
        XCTAssertTrue(shown.contains("BACK"), "The summary must go back with ‹ BACK, but its back control reads \"\(shown)\"")
        UITestNavigation.assertTapTarget(back)
        return back
    }

    @MainActor
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: element)
        return XCTWaiter().wait(for: [hittable], timeout: timeout) == .completed
    }
}
