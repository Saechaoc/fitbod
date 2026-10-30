import XCTest

/// Ticket T53, finding F6. The STALLED badge in the workout logger names the
/// window the plateau check used: the exercise's own plateau window when it
/// has one, otherwise the user's setting.
final class StallBadgeWindowUITests: XCTestCase {

    private let benchPress = "Barbell Bench Press - Medium Grip"

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// The seed logs four finished bench press workouts at 100 x 5, across
    /// the user's default window of 4 sessions. Over its own window of 3
    /// sessions the bench press still stalls, so VoiceOver must name 3.
    @MainActor
    func testBadgeNamesTheExercisesOwnWindow() throws {
        let app = UITestNavigation.launch(UITestNavigation.stalledExercise)
        setBenchPressWindow(to: "3 sessions", in: app)

        UITestNavigation.selectTab("Today", in: app)
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10))
        resume.tap()

        let badge = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Stalled:")).firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout: 10), "The bench press must stall over its own 3 sessions")
        UITestNavigation.reveal(badge, in: app)
        UITestNavigation.saveScreenshot("T53", "stalled-card")
        XCTAssertEqual(badge.label, "Stalled: \(benchPress) has been flat for 3 sessions.",
                       "The badge must name the bench press's own window, not the user's 4 sessions")
    }

    // MARK: - Helpers

    /// Library → the seeded bench press → Plateau Detection. Overriding the
    /// global settings starts the window at the user's 4 sessions; step it
    /// down to `window`.
    @MainActor
    private func setBenchPressWindow(to window: String, in app: XCUIApplication) {
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

        let toggle = app.switches["Override global settings"]
        UITestNavigation.reveal(toggle, in: app, maxSwipes: 20)
        toggle.tap()
        let stepper = app.otherElements["Window"]
        UITestNavigation.reveal(stepper, in: app)
        XCTAssertEqual(stepper.value as? String, "4 sessions", "The override must start at the user's window")
        stepDown(stepper, to: window)
    }

    /// Taps the stepper's − cell once. Its value, such as "4 sessions", is
    /// wider than the 64pt `UITestNavigation.tapStepper` assumes, so walk
    /// left from there until a tap lands on −. Taps on the value or the
    /// title do nothing.
    @MainActor
    private func stepDown(_ stepper: XCUIElement, to expected: String) {
        let trailing = stepper.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
        for offset in stride(from: 130, through: 300, by: 10) {
            trailing.withOffset(CGVector(dx: -offset, dy: 0)).tap()
            if stepper.value as? String == expected { return }
        }
        XCTFail("The stepper never reached \(expected); it reads \(stepper.value ?? "nothing")")
    }
}
