//
//  BlockAndRoutineTextFitUITests.swift
//  fitbodUITests
//
//  Ticket T26, review item 25. The routine screen's Remove Session? dialog
//  has a visible Keep session, which keeps the session.
//

import XCTest

extension UITestNavigation {
    /// A fresh store plus the Powerbuilding seed (`PowerbuildingSeed`):
    /// "Upper Lower", three sessions of one exercise each, Upper A, Lower A
    /// and Upper B, on an active "Powerbuilding" block in week 1 of 5,
    /// accumulation, and a draft "Powerbuilding" with no routine.
    static let powerbuilding = [resetFlag, "-fitbod-seed-powerbuilding"]
}

final class BlockAndRoutineTextFitUITests: XCTestCase {

    /// The seeded routine's sessions, in order, each "1 exercise · 3 sets
    /// · ~11 min".
    private static let sessions = ["Upper A", "Lower A", "Upper B"]

    @MainActor
    override func setUpWithError() throws {
        // Every label gets checked, so one failure does not hide the rest.
        continueAfterFailure = true
    }

    // MARK: - Remove Session?

    /// Remove Session? offered only a cancel-role Cancel, which iOS 26
    /// hides. Its visible Keep session closes it and keeps the session.
    @MainActor
    func testKeepSessionClosesRemoveSessionAndKeepsTheSession() throws {
        let app = UITestNavigation.launch(UITestNavigation.powerbuilding)
        openRoutine(in: app)
        UITestNavigation.hittable(app.buttons, "Edit", exactLabel: true).tap()
        UITestNavigation.hittable(app.buttons, "Remove Upper A", exactLabel: true).tap()

        let title = app.staticTexts.labeled("Remove Session?")
        XCTAssertTrue(title.waitForExistence(timeout: 5), "REMOVE must ask first")
        UITestNavigation.hittable(app.buttons, "Remove Session", exactLabel: true)
        let keep = app.buttons.labeled("Keep session")
        let shown = keep.waitForExistence(timeout: 5) && keep.isHittable
        UITestNavigation.saveScreenshot("T26", "remove-session-dialog")
        XCTAssertTrue(shown, "Remove Session? must offer a visible Keep session")
        guard shown else { return }

        keep.tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 5), "Keep session must close the dialog")
        UITestNavigation.hittable(app.buttons, "Done", exactLabel: true).tap()
        for (index, name) in Self.sessions.enumerated() {
            XCTAssertTrue(app.buttons["Session \(index + 1): \(name)"].waitForExistence(timeout: 5),
                          "Keep session must keep \(name) in place \(index + 1)")
        }
        XCTAssertTrue(routineMeta(in: app).label.lowercased().hasPrefix("3 sessions"),
                      "The routine must still hold three sessions, but it reads \"\(routineMeta(in: app).label)\"")
    }

    // MARK: - Helpers

    /// Program's row for Upper Lower, read as "Upper Lower, 3 sessions, …".
    @MainActor
    private func routineRow(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Upper Lower,")).firstMatch
    }

    /// Opens Upper Lower from its Program row.
    @MainActor
    private func openRoutine(in app: XCUIApplication) {
        UITestNavigation.selectTab("Program", in: app)
        let row = routineRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Program must list Upper Lower")
        UITestNavigation.reveal(row, in: app)
        row.tap()
        let name = app.descendants(matching: .any).matching(NSPredicate(
            format: "label ==[c] %@ AND value BEGINSWITH %@", "Routine name", "Upper Lower"
        )).firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 10), "Program's row must open Upper Lower")
        UITestNavigation.waitUntilStill(name)
    }

    /// The routine's meta line, "3 sessions · rotates in order".
    @MainActor
    private func routineMeta(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "rotates in order")).firstMatch
    }
}
