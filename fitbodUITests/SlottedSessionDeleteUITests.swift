import XCTest

/// T40: real controls must save slot removal, and slotted sessions must
/// reject archiving without losing their finished workouts. Neither journey
/// can be proved by an in-memory model test because each reopens the app.
final class SlottedSessionDeleteUITests: XCTestCase {
    private static let routine = "Delete guard routine"
    private static let session = "Bench & Squat"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // XCUIApplication and the shared navigation helpers require the main actor.
    @MainActor
    func testRemovingSlotPersistsAndSessionCanBeAddedAgain() throws {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory)
        makeRoutine(in: app)
        assertSessionCount(1, in: app)

        tap(app.buttons.labeled("Edit"))
        tap(app.buttons.labeled("Remove \(Self.session)"))
        tap(app.buttons.labeled("Remove Session"))
        assertSessionCount(0, in: app)
        XCTAssertFalse(app.alerts["Couldn't Save"].exists, "Removing a slot must save without an error")
        XCTAssertFalse(app.alerts["Couldn't save"].exists)

        UITestNavigation.relaunch(app)
        openRoutine(in: app)
        assertSessionCount(0, in: app)
        XCTAssertFalse(app.buttons.labeled("Session 1: \(Self.session)").exists)

        // The picker reads the persisted SessionTemplate. Removing its slot
        // must leave it available, and adding it again must create a new slot.
        addSession(in: app)
        assertSessionCount(1, in: app)
        let restored = app.buttons.labeled("Session 1: \(Self.session)")
        XCTAssertTrue(restored.exists || restored.waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts["Couldn't Save"].exists)
    }

    // XCUIApplication and the shared navigation helpers require the main actor.
    @MainActor
    func testArchiveOfSlottedSessionIsBlockedAndHistorySurvivesRelaunch() throws {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory)
        makeRoutine(in: app)
        tap(app.buttons.labeled("Session 1: \(Self.session)"))
        tap(app.buttons.labeled("Edit"))
        tap(app.buttons.labeled("More"))
        tap(app.buttons.labeled("Archive session"))

        // T29 deliberately prevents archiving a template while a routine
        // schedules it. T40 verifies this reachable path keeps the app alive.
        let blocked = app.alerts["Session is in use"]
        XCTAssertTrue(blocked.exists || blocked.waitForExistence(timeout: 5))
        XCTAssertTrue(blocked.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@", Self.routine
        )).firstMatch.exists, "The refusal must identify the routine holding the session")
        XCTAssertEqual(app.state, .runningForeground)
        tap(blocked.buttons["OK"])
        XCTAssertEqual(app.textFields["Session name"].value as? String, Self.session)

        UITestNavigation.relaunch(app)
        UITestNavigation.selectTab("Progress", in: app)
        tap(app.buttons["progress.history"])
        let rows = app.buttons.matching(identifier: "history.row")
        let first = rows.firstMatch
        XCTAssertTrue(first.exists || first.waitForExistence(timeout: 10))
        XCTAssertTrue(first.label.hasPrefix(Self.session), "History must still show the session's logged workout")
        let count = app.staticTexts.labeled("4 sessions")
        XCTAssertTrue(count.exists || count.waitForExistence(timeout: 5),
                      "All four finished workouts from the fixture must survive the archive attempt and relaunch")
        tap(first)
        let complete = app.staticTexts["WORKOUT COMPLETE"]
        XCTAssertTrue(complete.exists || complete.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.labeled(Self.session).exists,
                      "The retained workout must open with its original session name")
    }

    @MainActor
    private func makeRoutine(in app: XCUIApplication) {
        UITestNavigation.selectTab("Program", in: app)
        tap(app.buttons.labeled("+ NEW"))
        tap(app.buttons.labeled("+ New routine"))
        UITestNavigation.type(Self.routine, into: app.textFields["newRoutine.name"])
        tap(app.buttons.labeled("Save"))
        let name = app.descendants(matching: .any).matching(NSPredicate(
            format: "label ==[c] %@ AND value == %@", "Routine name", Self.routine
        )).firstMatch
        XCTAssertTrue(name.exists || name.waitForExistence(timeout: 5))
        addSession(in: app)
    }

    @MainActor
    private func openRoutine(in app: XCUIApplication) {
        UITestNavigation.selectTab("Program", in: app)
        let routine = app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH %@", Self.routine + ","
        )).firstMatch
        tap(routine)
    }

    @MainActor
    private func addSession(in app: XCUIApplication) {
        tap(app.buttons.labeled("+ Add session"))
        let existing = app.buttons.matching(NSPredicate(
            format: "label ==[c] %@ OR label BEGINSWITH[c] %@", Self.session, Self.session + ","
        )).firstMatch
        tap(existing)
    }

    @MainActor
    private func assertSessionCount(_ count: Int, in app: XCUIApplication,
                                    file: StaticString = #filePath, line: UInt = #line) {
        let label = "\(count) \(count == 1 ? "session" : "sessions") · rotates in order"
        let countLabel = app.staticTexts.labeled(label)
        XCTAssertTrue(countLabel.exists || countLabel.waitForExistence(timeout: 5),
                      "The routine must contain \(count) sessions", file: file, line: line)
    }

    @MainActor
    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.exists || element.waitForExistence(timeout: 10), file: file, line: line)
        XCTAssertTrue(element.isHittable, "The intended control must be tappable", file: file, line: line)
        element.tap()
    }
}
