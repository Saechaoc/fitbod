//
//  CalibratingStepCopyUITests.swift
//  fitbodUITests
//
//  Ticket T97 (finding F137): while RPE autoregulation calibrates from
//  the last session, Why this weight's step 02 shows how it got the
//  weight, in the calibrated line's shape, instead of double
//  progression's "Weight holds.", and step 03 rounds that raw target.
//
//  CalibratingSetSeed's last workout is 110 x 5 at RPE 8, for a set of 6
//  to 8 reps at RPE 8: a 135.6 lb e1RM, 74% of it for 8 reps, 100.2 lb,
//  rounded down to 100 lb.
//

import XCTest

final class CalibratingStepCopyUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// Opens Why this weight on the seed's first set and scrolls to step
    /// 03. Saves the steps, then checks step 02's e1RM line, step 03's
    /// rounding, and that both show whole inside the sheet.
    @MainActor
    func testCalibratingStepsShowComputation() throws {
        let app = UITestNavigation.launch(UITestNavigation.calibratingSet)
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10), "Today must offer the seed's workout")
        UITestNavigation.reveal(resume, in: app)
        resume.tap()
        let why = app.buttons["set.why.1.S1"]
        XCTAssertTrue(why.waitForExistence(timeout: 10), "Set 1 must show WHY")
        UITestNavigation.revealInLogger(why, in: app)
        why.tap()

        let sheet = app.scrollViews.containing(NSPredicate(format: "label ==[c] %@", "Why this weight")).firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "WHY must open Why this weight")
        let stepTwo = step("02", in: sheet)
        let stepThree = step("03", in: sheet)
        for _ in 0..<4 where !(stepThree.exists && stepThree.frame.maxY <= sheet.frame.maxY) {
            sheet.swipeUp(velocity: .slow)
        }
        UITestNavigation.saveScreenshot("T97", "calibrating-why-steps")

        XCTAssertTrue(stepTwo.label.contains("Last session e1RM 135.6 lb → 74% × 8 → 100.2 lb"),
                      "Step 02 must show how the weight was calibrated: \(stepTwo.label)")
        XCTAssertFalse(stepTwo.label.contains("Weight holds."), "Step 02 must not read double progression's hold: \(stepTwo.label)")
        XCTAssertTrue(stepThree.label.contains("100.2 → 100"), "Step 03 must round the raw target: \(stepThree.label)")
        UITestNavigation.assertInside(stepTwo, sheet)
        UITestNavigation.assertInside(stepThree, sheet)
    }

    /// A Why this weight step, one element read from its numeral, "02".
    @MainActor
    private func step(_ index: String, in sheet: XCUIElement) -> XCUIElement {
        sheet.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", index)).firstMatch
    }
}
