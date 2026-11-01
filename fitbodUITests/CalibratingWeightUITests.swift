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
    /// range; the open set after it keeps its range.
    @MainActor
    func testCompletedSetShowsLoggedWeight() throws {
        let app = openWorkout()
        let reps = app.textFields["set.reps.1.S1"]
        UITestNavigation.revealInLogger(reps, in: app)
        UITestNavigation.enter("5", into: reps)
        XCTAssertEqual(reps.value as? String, "5", "Set 1 must read the typed reps")
        let complete = app.buttons["set.complete.1.S1"]
        UITestNavigation.revealInLogger(complete, in: app)
        complete.tap()
        XCTAssertTrue(UITestNavigation.waitUntil(timeout: 5) { complete.exists && complete.label == "Set 1 complete" },
                      "Set 1 must be logged")

        let field = weightField("1.S1", in: app)
        XCTAssertTrue(UITestNavigation.appears(field, within: 5), "A logged set must show its weight, not the range")
        XCTAssertEqual(field.value as? String, "110 lb", "A logged set must show the weight it logged")
        XCTAssertFalse(rangeText("1.S1", in: app).exists, "A logged set must never show the range")
        revealSet("1.S2", in: app)
        XCTAssertTrue(rangeText("1.S2", in: app).exists, "The open set 2 keeps its range")
    }

    // MARK: - Navigation

    /// Launches the calibrating seed and opens today's workout.
    @MainActor
    private func openWorkout() -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.calibratingSet)
        resumeWorkout(in: app)
        return app
    }

    /// Opens today's workout from Today's resume slab, with set 1 in view.
    @MainActor
    private func resumeWorkout(in app: XCUIApplication) {
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(UITestNavigation.appears(resume))
        UITestNavigation.reveal(resume, in: app)
        resume.tap()
        XCTAssertTrue(UITestNavigation.appears(app.otherElements["workout.header"]), "The workout never opened")
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
