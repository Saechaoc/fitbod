import XCTest

/// Ticket T110, finding F223. The session editor offered "Per-set
/// overrides" and "+ ADD OVERRIDE", but nothing applies an override: the
/// logger builds every working set from the exercise's own prescription.
/// The editor no longer offers them.
///
/// The test opens the progress-history seed's "Bench & Squat" the way a
/// user does: Today's + New routine, + Add session, the routine's session,
/// then Edit, and opens the bench press's EDIT PRESCRIPTION.
final class PerSetOverridesRemovedUITests: XCTestCase {

    private static let session = "Bench & Squat"
    private static let routine = "Upper Lower"
    private static let bench = "Barbell Bench Press - Medium Grip"

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// Nothing in the session editor reads "Per-set overrides" or
    /// "Add override", and the set list still shows S1 to S3 as WORK sets.
    @MainActor
    func testSessionEditorOffersNoPerSetOverrides() throws {
        let app = openEditor()
        let title = app.staticTexts.matching(NSPredicate(format: "label == %@", Self.bench)).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10), "Missing \(Self.bench)")
        title.tap()
        let details = app.buttons["prescription.details"]
        XCTAssertTrue(details.waitForExistence(timeout: 10), "\(Self.bench)'s row must open")
        UITestNavigation.reveal(details, in: app)
        details.tap()
        let warmup = app.switches.matching(NSPredicate(format: "label == %@", "Auto warm-up")).firstMatch
        XCTAssertTrue(warmup.waitForExistence(timeout: 10), "EDIT PRESCRIPTION must open")
        // The section sat under Auto warm-up, at the end of the details.
        UITestNavigation.reveal(warmup, in: app)
        app.swipeUp()
        UITestNavigation.saveScreenshot("T110", "editor-details")

        for text in ["Per-set overrides", "Add override"] {
            let matches = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", text))
            XCTAssertEqual(matches.count, 0, "The session editor must not offer \"\(text)\"")
        }
        let override = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Reps override"))
        XCTAssertEqual(override.count, 0, "The session editor must show no override rows")
        for set in 1...3 {
            XCTAssertTrue(app.staticTexts["S\(set)"].exists, "The set list must still show S\(set)")
        }
    }

    // MARK: - Navigation

    /// The session editor on "Bench & Squat", opened from its routine.
    @MainActor
    private func openEditor() -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory)
        UITestNavigation.selectTab("Today", in: app)
        UITestNavigation.hittable(app.buttons, "+ New routine").tap()
        UITestNavigation.type(Self.routine, into: app.textFields["newRoutine.name"])
        UITestNavigation.hittable(app.buttons, "Save", exactLabel: true).tap()
        XCTAssertTrue(app.textFields["newRoutine.name"].waitForNonExistence(timeout: 10), "SAVE must leave the name step")
        let picker = app.staticTexts.labeled("Existing sessions")
        UITestNavigation.hittable(app.buttons, "+ Add session").tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "+ Add session must list the existing sessions")
        UITestNavigation.hittable(app.buttons, Self.session).tap()
        XCTAssertTrue(picker.waitForNonExistence(timeout: 5), "Adding \(Self.session) must close the session picker")
        UITestNavigation.hittable(app.buttons, "Session 1: \(Self.session)", exactLabel: true).tap()
        XCTAssertTrue(app.staticTexts.labeled("Session").waitForExistence(timeout: 10), "The routine's row must open the session")
        UITestNavigation.hittable(app.buttons, "Edit", exactLabel: true).tap()
        XCTAssertTrue(app.textFields["Session name"].waitForExistence(timeout: 10), "Edit must open the session editor")
        return app
    }
}
