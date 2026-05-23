//
//  PlateauOverrideUITests.swift
//  fitbodUITests
//
//  Phase 5 SET-06 — smoke test that the "Plateau Detection" section
//  is reachable from the Library tab's exercise detail view AND that
//  the override toggle is interactive.
//
//  This test launches the app against the simulator's persistent
//  store (no test fixture is required — the Phase 1 importer seeds
//  the library on first launch; subsequent launches load it from
//  disk). The detail view is found by tapping the first Exercise row
//  in the Library tab.
//
//  The full round-trip (toggle ON → edit Steppers → back out → re-enter
//  → assert persistence) is hard to make reliable across simulators
//  because:
//    1. Simulator state isn't reset, so the first Library row varies.
//    2. Stepper "Increment"/"Decrement" button labels are localized.
//    3. The exact text "5 sessions" depends on the user's prior
//       overrides.
//  Round-trip behavior IS tested at the SwiftUI binding + SwiftData
//  layer via the @Bindable write-through. This UI test smoke-checks
//  that the section is mounted + that the toggle responds.
//

import XCTest

final class PlateauOverrideUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func waitForSeedComplete(_ app: XCUIApplication, timeout: TimeInterval = 60) {
        let splash = app.staticTexts["Preparing library…"]
        if splash.exists {
            let pred = NSPredicate(format: "exists == false")
            let exp = XCTNSPredicateExpectation(predicate: pred, object: splash)
            _ = XCTWaiter().wait(for: [exp], timeout: timeout)
        }
    }

    @MainActor
    private func selectLibraryTab(_ app: XCUIApplication) {
        let library = app.tabBars.buttons["Library"]
        if library.waitForExistence(timeout: 10) {
            library.tap()
        }
    }

    /// Tap an exercise that has a known label so the next view is
    /// definitely the detail view (not a filter chip or section header).
    /// SwiftUI's List wraps each row's tap target in a Button inside a
    /// Cell; tapping the Cell itself doesn't always navigate, but
    /// tapping the inner Button does.
    @MainActor
    private func tapFirstExerciseDetail(_ app: XCUIApplication) {
        // Wait for the library list to render. The Library nav title
        // says "Exercises".
        _ = app.staticTexts["Exercises"].waitForExistence(timeout: 30)
        // Find the first Button that has an exercise-like label
        // (contains a "·" separator per the row format).
        let pred = NSPredicate(format: "label CONTAINS '·'")
        let firstButton = app.buttons.matching(pred).firstMatch
        if firstButton.waitForExistence(timeout: 30) {
            firstButton.tap()
        }
    }

    /// Scroll the detail view until the Plateau Detection section is
    /// in the accessibility tree.
    @MainActor
    private func scrollToPlateauSection(_ app: XCUIApplication) -> Bool {
        let header = app.staticTexts["Plateau Detection"]
        if header.exists { return true }
        for _ in 0..<12 {
            app.swipeUp()
            if header.exists { return true }
        }
        return header.exists
    }

    @MainActor
    func testPlateauDetectionSectionReachable() throws {
        let app = XCUIApplication()
        app.launch()
        waitForSeedComplete(app)
        selectLibraryTab(app)
        tapFirstExerciseDetail(app)

        let found = scrollToPlateauSection(app)
        XCTAssertTrue(found, "Expected 'Plateau Detection' section on exercise detail view — SET-06 section is not mounted.")
    }

    @MainActor
    func testOverrideToggleReveals_Steppers() throws {
        let app = XCUIApplication()
        app.launch()
        waitForSeedComplete(app)
        selectLibraryTab(app)
        tapFirstExerciseDetail(app)
        _ = scrollToPlateauSection(app)
        // After finding "Plateau Detection", swipe a few more times to
        // bring the Toggle (which lives BELOW the header) into view.
        app.swipeUp()
        app.swipeUp()

        // SwiftUI Toggle exposes via .switches. The toggle row's outer
        // Switch element responds to `.tap()` but on iOS 26 simulator
        // sometimes needs an explicit coordinate tap on the inner control.
        let togglePred = NSPredicate(format: "label == %@", "Override global settings")
        let toggle = app.switches.matching(togglePred).firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        // Tap via XCUICoordinate to bypass the SwiftUI/UIKit hit-test
        // ambiguity on the outer row vs the inner control.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()

        // Allow SwiftUI a moment to reveal the conditional Stepper +
        // button. Then swipe to bring them into view (they live below
        // the toggle).
        _ = app.staticTexts["Window (sessions)"].waitForExistence(timeout: 5)
        let useDefaults = app.buttons["Use global defaults"]
        for _ in 0..<5 where !useDefaults.exists {
            app.swipeUp()
        }
        XCTAssertTrue(useDefaults.waitForExistence(timeout: 5), "Override toggle did not reveal the Stepper / 'Use global defaults' subview")
    }
}
