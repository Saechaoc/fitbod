//
//  LayoutAuditUITests.swift
//  fitbodUITests
//
//  Screenshot tour of every milestone-1 screen with realistic data
//  (`-seed-demo-history`: two routines, three weeks of workouts), at
//  default text, at an accessibility text size, and in dark mode at the
//  largest non-accessibility size. CI runs it on the smallest and the
//  largest iPhone, so the exported screenshots cover both extremes.
//
//  Beyond screenshots, the audit asserts what can be checked mechanically:
//  the set-entry controls and the workout's primary actions stay inside the
//  screen and remain hittable at every size (the set row stacks instead of
//  overflowing).
//

import XCTest

final class LayoutAuditUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTourDefaultText() throws {
        let app = launchFitbod(reset: true, demoHistory: true)
        tour(app, prefix: "A")
    }

    @MainActor
    func testTourAccessibilityText() throws {
        let app = launchFitbod(reset: true, demoHistory: true, contentSize: Launch.accessibilityLarge)
        tour(app, prefix: "B-ax")
    }

    @MainActor
    func testTourDarkLargestText() throws {
        let app = launchFitbod(reset: true, demoHistory: true, dark: true, contentSize: Launch.extraExtraExtraLarge)
        tour(app, prefix: "C-dark")
    }

    // MARK: - Tour

    private let upper = "Upper A · Strength"

    @MainActor
    private func tour(_ app: XCUIApplication, prefix: String) {
        XCTContext.runActivity(named: "Today") { _ in
            waitExists(app.buttons["today.start.\(upper)"], timeout: 30)
            snapshot(app, "\(prefix)01-today")
        }

        XCTContext.runActivity(named: "Routines + detail") { _ in
            app.tabBars.buttons["Routines"].tap()
            let row = waitExists(app.buttons["routine.row.\(upper)"])
            snapshot(app, "\(prefix)02-routines")
            revealAndTap(row, in: app)
            waitExists(app.buttons["routine.startWorkout"])
            snapshot(app, "\(prefix)03-routine-detail")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        XCTContext.runActivity(named: "Library + exercise with history") { _ in
            app.tabBars.buttons["Library"].tap()
            let search = waitHittable(app.visibleSearchField)
            snapshot(app, "\(prefix)04-library")
            search.tap()
            search.typeText("bench press")
            dismissKeyboard(in: app)
            revealAndTap(app.exerciseRow(named: "Barbell Bench Press - Medium Grip"), in: app)
            waitExists(app.element("exercise.detail.title"))
            snapshot(app, "\(prefix)05-exercise-detail")
            app.navigationBars.buttons.element(boundBy: 0).tap()
            waitHittable(app.buttons["Clear search"]).tap()
        }

        XCTContext.runActivity(named: "History + workout detail") { _ in
            app.tabBars.buttons["History"].tap()
            let row = waitExists(app.element("history.row"))
            snapshot(app, "\(prefix)06-history")
            revealAndTap(row, in: app)
            waitExists(app.element("summary.title"))
            snapshot(app, "\(prefix)07-history-detail")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        XCTContext.runActivity(named: "Settings + component gallery") { _ in
            app.tabBars.buttons["Settings"].tap()
            snapshot(app, "\(prefix)08-settings")
            revealAndTap(app.buttons["settings.gallery"], in: app)
            waitExists(app.navigationBars["GALLERY"])
            snapshot(app, "\(prefix)09-gallery-1")
            for page in 2...4 {
                app.swipeUp(velocity: .fast)
                snapshot(app, "\(prefix)09-gallery-\(page)")
            }
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        XCTContext.runActivity(named: "Workout: previous, set row, rest timer") { _ in
            app.tabBars.buttons["Today"].tap()
            waitHittable(app.buttons["today.start.\(upper)"]).tap()
            waitExists(app.element("workout.title"), timeout: 20)
            snapshot(app, "\(prefix)10-workout")
            assertOnScreen(app.buttons["workout.finish"], in: app)

            let previous = app.buttons["set.0.0.previous"]
            revealAndTap(previous, in: app)
            for id in ["set.0.0.weight", "set.0.0.reps"] {
                assertOnScreen(app.textFields[id], in: app)
            }
            assertOnScreen(app.buttons["set.0.0.rpe"], in: app)
            let complete = app.buttons["set.0.0.complete"]
            assertOnScreen(complete, in: app)
            snapshot(app, "\(prefix)11-set-row-ready")
            complete.tap()
            XCTAssertEqual(complete.value as? String, "complete")

            waitExists(app.element("rest.dock"))
            for id in ["rest.minus15", "rest.plus15", "rest.skip"] {
                assertOnScreen(app.buttons[id], in: app)
            }
            snapshot(app, "\(prefix)12-rest-dock")

            app.element("rest.remaining").tap()
            waitExists(app.navigationBars["REST TIMER"])
            snapshot(app, "\(prefix)13-rest-sheet")
            tapDialogButton("Done", in: app)

            app.buttons["workout.options"].tap()
            tapDialogButton("Discard workout", in: app)
            tapDialogButton("Discard", in: app)
            waitGone(app.element("workout.title"))
        }
    }

    /// The element exists, is hittable and lies horizontally inside the
    /// window (no clipped or overflowing controls).
    @MainActor
    private func assertOnScreen(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        if !element.waitForExistence(timeout: 5) || !element.isHittable {
            reveal(element, in: app)
        }
        waitHittable(element, file: file, line: line)
        let window = app.windows.firstMatch.frame
        let frame = element.frame
        XCTAssertGreaterThanOrEqual(frame.minX, window.minX - 1, "\(element.identifier) starts off-screen: \(frame)", file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, window.maxX + 1, "\(element.identifier) overflows the screen: \(frame)", file: file, line: line)
    }
}
