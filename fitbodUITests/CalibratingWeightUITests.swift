//
//  CalibratingWeightUITests.swift
//  fitbodUITests
//
//  Ticket T80 (findings F78 and F79): with RPE autoregulation, a set whose
//  exercise is still calibrating shows a weight range until the lifter
//  picks a weight. A logged set shows the weight it logged.
//
//  CalibratingSetSeed's sets show "95 – 105 lb", hold last workout's
//  110 lb, and Why this weight suggests 100 lb.
//

import XCTest

extension UITestNavigation {
    /// A fresh store plus "Calibrating Bench": an RPE-autoregulated bench
    /// press still calibrating, with today's workout in progress (see
    /// CalibratingSetSeed).
    static let calibratingSet = [resetFlag, "-fitbod-seed-calibrating-set"]
}

final class CalibratingWeightUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// A logged calibrating set shows the weight it logged, never the
    /// range; the open set after it keeps its range. Saves the logged set
    /// at default text and AX3.
    @MainActor
    func testCompletedSetShowsLoggedWeight() throws {
        for size in [UITestNavigation.TextSize.default, .ax3] {
            let app = openWorkout(textSize: size)
            let reps = app.textFields["set.reps.1.S1"]
            UITestNavigation.revealInLogger(reps, in: app)
            UITestNavigation.enter("5", into: reps)
            XCTAssertEqual(reps.value as? String, "5", "Set 1 must read the typed reps at \(size)")
            let complete = app.buttons["set.complete.1.S1"]
            UITestNavigation.revealInLogger(complete, in: app)
            complete.tap()
            let logged = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Set 1 complete"), object: complete)
            XCTAssertEqual(XCTWaiter().wait(for: [logged], timeout: 5), .completed, "Set 1 must be logged at \(size)")

            let field = weightField("1.S1", in: app)
            XCTAssertTrue(field.waitForExistence(timeout: 5), "A logged set must show its weight, not the range, at \(size)")
            XCTAssertEqual(field.value as? String, "110 lb", "A logged set must show the weight it logged at \(size)")
            XCTAssertFalse(rangeText("1.S1", in: app).exists, "A logged set must never show the range at \(size)")
            UITestNavigation.revealInLogger(field, in: app)
            UITestNavigation.saveScreenshot("T80", "calibrating-completed", textSize: size)
            revealSet("1.S2", in: app)
            XCTAssertTrue(rangeText("1.S2", in: app).exists, "The open set 2 keeps its range at \(size)")
            app.terminate()
        }
    }

    // MARK: - Navigation

    /// Launches the calibrating seed and opens today's workout.
    @MainActor
    private func openWorkout(textSize: UITestNavigation.TextSize = .default) -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.calibratingSet, textSize: textSize)
        resumeWorkout(in: app)
        return app
    }

    /// Opens today's workout from Today's resume slab, with set 1 in view.
    @MainActor
    private func resumeWorkout(in app: XCUIApplication) {
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10))
        UITestNavigation.reveal(resume, in: app)
        resume.tap()
        XCTAssertTrue(app.otherElements["workout.header"].waitForExistence(timeout: 10), "The workout never opened")
        revealSet("1.S1", in: app)
    }

    /// Scrolls the logger until set `set`'s row is in view. Rows load as
    /// they scroll in, so it first scrolls down until the row exists.
    @MainActor
    private func revealSet(_ set: String, in app: XCUIApplication) {
        let reps = app.textFields["set.reps.\(set)"]
        for _ in 0..<10 where !reps.exists {
            let (top, bottom) = UITestNavigation.loggerSpan(in: app)
            UITestNavigation.dragLogger(from: bottom - 20, to: top + 20, in: app)
        }
        XCTAssertTrue(reps.exists, "Set \(set) never loaded")
        UITestNavigation.revealInLogger(reps, in: app)
    }

    // MARK: - Elements

    /// A set's read-only calibrating range. It carries the weight cell's
    /// identifier, as the field does.
    @MainActor
    private func rangeText(_ set: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(
            format: "identifier == %@ AND label BEGINSWITH %@", "set.weight.\(set)", "Prescribed weight range"
        )).firstMatch
    }

    @MainActor
    private func weightField(_ set: String, in app: XCUIApplication) -> XCUIElement {
        app.textFields.matching(identifier: "set.weight.\(set)").firstMatch
    }
}
