//
//  ReseedRelaunchUITests.swift
//  fitbodUITests
//
//  T128 (F296): a launch that re-seeds the exercise library over a store
//  with history must not crash, and the launch after it must still show
//  the logged workout with its exercise: the same library row, still
//  linked, not a fresh copy with the same name. History shows the
//  log-time name snapshot whatever the link holds, so the link is read in
//  the Library, where the row's logged count and Recent performance both
//  query by the exercise's id.
//
//  The re-seed is forced the way a stale stamp forces it: the
//  `-exercise_seed_version 0` launch argument makes the app read its seed
//  stamp as 0 for that launch only (the UserDefaults argument domain).
//

import XCTest

final class ReseedRelaunchUITests: XCTestCase {
    private let bench = "Barbell Bench Press - Medium Grip"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testReseedLaunchKeepsTheWorkoutAndItsExercise() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        // The demo seed runs after the catalog import; today's workout means it is saved.
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(resume.exists || resume.waitForExistence(timeout: 30), "The demo workout never started")

        // Re-seed while Today shows the workouts' exercises.
        app.terminate()
        app.launchArguments = ["-exercise_seed_version", "0", UITestNavigation.resetSignalFlag]
        app.launch()
        XCTAssertTrue(UITestNavigation.appears(UITestNavigation.tab("Today", in: app), within: 90),
                      "The re-seed launch never showed the tab bar")
        openWorkout(in: app)

        // The next launch, without flags, the way the lifter opens the app.
        UITestNavigation.relaunch(app)
        openWorkout(in: app)
        XCTAssertTrue(app.staticTexts[bench].exists, "The workout must still list its bench press")

        // The same row, still linked: the Library holds one bench press, and
        // it counts and shows the finished workout.
        app.buttons["Back"].firstMatch.tap()
        app.buttons["Back"].firstMatch.tap()
        UITestNavigation.selectTab("Library", in: app)
        UITestNavigation.type(bench, into: app.textFields["library.search.browser"], replacing: false)
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts.labeled("1 match")), "Exactly one exercise must match the bench press")
        let row = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", bench)).firstMatch
        XCTAssertTrue(row.exists, "The bench press must be listed")
        // The search leaves one row, so the one logged count is the bench press's.
        let logged = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Logged ")).firstMatch
        XCTAssertTrue(logged.exists, "The bench press row must show its logged count")
        XCTAssertTrue(logged.label.contains("Logged once"), "The bench press must count the finished workout; it reads \"\(logged.label)\"")
        row.tap()
        let recent = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "100 lb × 5")).firstMatch
        XCTAssertTrue(UITestNavigation.appears(recent), "Recent performance must show the finished workout's best set")
    }

    /// Today > Sessions > the one finished workout's summary.
    @MainActor
    private func openWorkout(in app: XCUIApplication) {
        let sessions = app.buttons["today.sessions"]
        XCTAssertTrue(UITestNavigation.appears(sessions, within: 30), "Today must show its Sessions count")
        sessions.tap()
        let rows = app.buttons.matching(identifier: "history.row")
        XCTAssertTrue(UITestNavigation.appears(rows.firstMatch), "History must list the finished workout")
        XCTAssertEqual(rows.count, 1)
        rows.firstMatch.tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts["WORKOUT COMPLETE"]))
    }
}
