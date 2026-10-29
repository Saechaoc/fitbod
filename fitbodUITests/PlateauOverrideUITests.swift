//
//  PlateauOverrideUITests.swift
//  fitbodUITests
//
//  Phase 5 SET-06: the "Plateau Detection" section is reachable from an
//  exercise's detail screen in the Library tab, and the override toggle
//  reveals the per-exercise controls.
//
//  Each test starts from a fresh store (the importer seeds the catalog on
//  first launch) and opens a known catalog exercise, so the result does not
//  depend on what earlier runs left in the simulator.
//

import XCTest

final class PlateauOverrideUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Library → search → Barbell Bench Press detail.
    @MainActor
    private func openBenchPressDetail() -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Library", in: app)
        let search = app.textFields["library.search.browser"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: focused, object: search)], timeout: 5), .completed)
        search.typeText("Barbell Bench Press")
        let row = app.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH %@", "Barbell Bench Press"
        )).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        return app
    }

    @MainActor
    func testPlateauDetectionSectionReachable() throws {
        let app = openBenchPressDetail()
        UITestNavigation.reveal(app.staticTexts["Plateau Detection"], in: app)
    }

    @MainActor
    func testOverrideToggleRevealsSteppers() throws {
        let app = openBenchPressDetail()
        let toggle = app.switches["Override global settings"]
        UITestNavigation.reveal(toggle, in: app)
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.tap()

        let useDefaults = app.buttons["Use global defaults"]
        UITestNavigation.reveal(useDefaults, in: app)
        XCTAssertEqual(toggle.value as? String, "1")
        // BRUStepper is one adjustable element labeled by its title.
        XCTAssertTrue(app.otherElements["Window"].exists)
        XCTAssertTrue(app.otherElements["Tolerance"].exists)

        useDefaults.tap()
        XCTAssertTrue(useDefaults.waitForNonExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0")
    }
}
