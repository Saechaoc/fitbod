//
//  CalibratingWeightUITests.swift
//  fitbodUITests
//
//  The exercise shows the calibration range while each set holds an editable weight.
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

    /// A calibrating set can be edited directly and logged while the range stays visible.
    @MainActor
    func testCompletedSetShowsLoggedWeight() throws {
        let app = openWorkout()
        let guidance = app.buttons["card.why.1"]
        XCTAssertTrue(UITestNavigation.appears(guidance))
        XCTAssertTrue(guidance.label.contains("95–105 lb"), guidance.label)

        let field = weightField("1.S1", in: app)
        XCTAssertEqual(field.value as? String, "110 lb")
        UITestNavigation.revealInLogger(field, in: app)
        UITestNavigation.enter("97.5", into: field)
        UITestNavigation.keyboardDone(in: app).tap()

        let reps = app.textFields["set.reps.1.S1"]
        UITestNavigation.revealInLogger(reps, in: app)
        UITestNavigation.enter("5", into: reps)
        XCTAssertEqual(reps.value as? String, "5", "Set 1 must read the typed reps")
        UITestNavigation.keyboardDone(in: app).tap()
        let complete = app.buttons["set.complete.1.S1"]
        UITestNavigation.revealInLogger(complete, in: app)
        complete.tap()
        XCTAssertTrue(UITestNavigation.waitUntil(timeout: 5) { complete.exists && complete.label == "Set 1 complete" },
                      "Set 1 must be logged")

        XCTAssertEqual(field.value as? String, "97.5 lb", "The completed set must show the weight it logged")
        XCTAssertTrue(guidance.label.contains("95–105 lb"), "The suggestion stays after logging")
        revealSet("1.S2", in: app)
        XCTAssertEqual(weightField("1.S2", in: app).value as? String, "97.5 lb")
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

    @MainActor
    private func weightField(_ set: String, in app: XCUIApplication) -> XCUIElement {
        app.textFields.matching(identifier: "set.weight.\(set)").firstMatch
    }
}
