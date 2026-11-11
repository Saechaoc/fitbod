import XCTest

/// A bench set records how long it took, and its exercise shows the time
/// from its first set to its last (RM-062): from a skipped rest, from START,
/// and as corrected by hand.
final class SetDurationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testABenchSetShowsItsDurationAndTheExerciseTotal() throws {
        let app = UITestNavigation.openSeededWorkout()

        // Set 1 has no rest before it, so its time is unknown.
        complete("1.S1", in: app)
        XCTAssertFalse(app.buttons["set.duration.1.S1"].exists, "The first set's start is unknown")
        XCTAssertTrue(UITestNavigation.appears(app.buttons["set.start.1.S2"], within: 5), "The next set offers START")

        // Set 2 starts when the rest is skipped.
        let skip = app.buttons["rest.skip"]
        XCTAssertTrue(UITestNavigation.appears(skip))
        skip.tap()
        sleep(3)
        complete("1.S2", in: app)
        XCTAssertGreaterThanOrEqual(seconds(of: "1.S2", in: app), 3)
        let header = app.buttons["card.toggle.1"]
        XCTAssertTrue(
            header.label.range(of: #"sets done\W+(time )?\d+:\d\d"#, options: [.regularExpression, .caseInsensitive]) != nil,
            "The exercise shows its time: \(header.label)"
        )

        // Set 3 starts at START, which ends the rest.
        let start = app.buttons["set.start.1.S3"]
        UITestNavigation.revealInLogger(start, in: app)
        start.tap()
        XCTAssertTrue(UITestNavigation.disappears(skip, within: 5), "START ends the rest")
        sleep(2)
        complete("1.S3", in: app)
        XCTAssertGreaterThanOrEqual(seconds(of: "1.S3", in: app), 2)

        // A tap corrects the time.
        let time = app.buttons["set.duration.1.S3"]
        UITestNavigation.revealInLogger(time, in: app)
        time.tap()
        let field = app.textFields["set.durationField.1.S3"]
        XCTAssertTrue(UITestNavigation.appears(field, within: 5))
        UITestNavigation.enter("45", into: field)
        UITestNavigation.keyboardDone(in: app).tap()
        XCTAssertTrue(UITestNavigation.appears(time, within: 5))
        XCTAssertEqual(time.value as? String, "0:45")

        // The summary, History's own screen, shows the exercise time.
        app.buttons["More"].tap()
        let finish = app.buttons["Finish"]
        XCTAssertTrue(UITestNavigation.appears(finish, within: 5))
        finish.tap()
        let confirm = app.buttons["finish.confirm"]
        XCTAssertTrue(UITestNavigation.appears(confirm, within: 5))
        confirm.tap()
        let exercise = app.buttons.matching(identifier: "summary.exercise").firstMatch
        XCTAssertTrue(UITestNavigation.appears(exercise), "Finish should open the summary")
        XCTAssertTrue(
            exercise.label.range(of: #"sets? · (.* · )?\d+:\d\d"#, options: [.regularExpression, .caseInsensitive]) != nil,
            "The exercise line shows its time: \(exercise.label)"
        )
    }

    // MARK: - Steps

    /// Types 5 reps into the set and taps its Done.
    @MainActor
    private func complete(_ suffix: String, in app: XCUIApplication) {
        let reps = app.textFields["set.reps.\(suffix)"]
        UITestNavigation.revealInLogger(reps, in: app)
        UITestNavigation.enter("5", into: reps)
        UITestNavigation.keyboardDone(in: app).tap()
        let done = app.buttons["set.complete.\(suffix)"]
        UITestNavigation.revealInLogger(done, in: app)
        done.tap()
        XCTAssertTrue(UITestNavigation.waitUntil(timeout: 5) { done.label.hasSuffix("complete") && !done.label.hasPrefix("Mark") })
    }

    /// The set's time chip, in seconds.
    @MainActor
    private func seconds(of suffix: String, in app: XCUIApplication) -> Int {
        let time = app.buttons["set.duration.\(suffix)"]
        XCTAssertTrue(UITestNavigation.appears(time, within: 5), "Set \(suffix) shows its time")
        let parts = (time.value as? String ?? "").split(separator: ":").compactMap { Int($0) }
        return parts.reduce(0) { $0 * 60 + $1 }
    }
}
