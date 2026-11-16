//
//  PerMuscleDetailUITests.swift
//  fitbodUITests
//
//  Reaches the detail view from Today's week board, then a volume-bar tap (more stable than
//  per-region heatmap path hit-testing across simulator runs).
//
//  T109: every test launches on a reset store with the demo Push A, so
//  Chest always has a bar to tap, and two contributing exercises of
//  three sets each.
//

import XCTest

final class PerMuscleDetailUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// T109, finding F210: Chest's two contributing exercises have exactly
    /// three weighted sets each, and rows with the same weighted sets sort
    /// by name. The order rule's other cases, and the tie-breaks that keep
    /// one order on every render, are in ContributingExercisesOrderTests.
    @MainActor
    func testContributingExercisesWithEqualCountsKeepTheirOrder() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        UITestNavigation.openMuscle("Chest", in: app)
        XCTAssertEqual(tiedContributorOrder(in: app), Self.tiedContributors,
                       "Contributing exercises with the same weighted sets must sort by name")
    }

    /// RM-017: Volume folds the muscles not trained this week into one row.
    /// It starts folded, a tap unfolds their bars in place, the neck's bar
    /// opens its screen (the demo Push A never trains the neck), Back keeps
    /// the row open, and a second tap folds the bars again.
    @MainActor
    func testUntrainedMusclesFoldIntoOneRow() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        UITestNavigation.openVolume(in: app)
        let row = app.buttons["volume.untrainedMuscles"]
        let neck = UITestNavigation.volumeBar("Neck", in: app)
        // Every folded muscle's bar would read "<Muscle>: 0 sets this week, Not trained."
        let untrainedBars = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", ": 0 sets this week, Not trained"))
        // The list draws only the rows near the screen. The heatmap comes
        // right after it, so with the heatmap in view the row is drawn, and
        // so would be the last open bars above the heatmap.
        let heatmap = app.staticTexts["Muscle Heatmap"]
        XCTAssertTrue(UITestNavigation.appears(heatmap), "The week board must open Volume")
        UITestNavigation.reveal(heatmap, in: app)
        XCTAssertTrue(row.exists, "Volume must fold the untrained muscles into one row")
        XCTAssertEqual(row.value as? String, "Collapsed")
        XCTAssertFalse(neck.exists, "A folded muscle must show no bar")
        XCTAssertEqual(untrainedBars.count, 0, "The row must start folded")

        UITestNavigation.reveal(row, in: app)
        row.tap()
        XCTAssertEqual(row.value as? String, "Expanded")
        UITestNavigation.reveal(neck, in: app)
        neck.tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts["This Week"]), "The neck's bar must open its screen")

        UITestNavigation.hittable(app.buttons, "Back", exactLabel: true).tap()
        XCTAssertTrue(UITestNavigation.appears(neck), "Back must keep the row open")

        var swipes = 0
        while !(row.exists && row.isHittable) && swipes < 20 {
            app.swipeDown(velocity: .slow)
            swipes += 1
        }
        row.tap()
        XCTAssertEqual(row.value as? String, "Collapsed")
        UITestNavigation.reveal(heatmap, in: app)
        XCTAssertFalse(neck.exists, "A second tap must fold the bars again")
        XCTAssertEqual(untrainedBars.count, 0, "A second tap must fold every untrained bar")
    }

    // MARK: - Chest

    /// The demo Push A's two chest exercises, in name order.
    private static let tiedContributors = ["Bench Press (Barbell)", "Bench Press (Incline Dumbbell)"]

    /// The tied contributors' names from the top of the screen down, once
    /// both rows read three sets.
    @MainActor
    private func tiedContributorOrder(in app: XCUIApplication) -> [String] {
        let rows = Self.tiedContributors.map { app.staticTexts[$0] }
        for row in rows {
            XCTAssertTrue(row.exists || row.waitForExistence(timeout: 5), "Missing the contributing exercise \(row)")
        }
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "3 sets")).count, 2,
                       "Both contributing exercises must read three sets")
        return rows.sorted { $0.frame.minY < $1.frame.minY }.map(\.label)
    }
}

extension UITestNavigation {
    /// `muscle`'s volume bar on Volume, a button that reads "Chest: 6 sets
    /// this week, …", or "1 set" for one.
    static func volumeBar(_ muscle: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH %@ AND label MATCHES %@", muscle + ": ", ".+: [0-9]+ sets? this week, .*"
        )).firstMatch
    }

    /// Opens Volume from Today's week board.
    static func openVolume(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let board = app.buttons["today.weekBoard"]
        XCTAssertTrue(appears(board), "Today must show the week board", file: file, line: line)
        board.tap()
    }

    /// Opens Volume from Today's week board, taps `muscle`'s volume bar and
    /// waits for its screen.
    static func openMuscle(_ muscle: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        openVolume(in: app, file: file, line: line)
        let bar = volumeBar(muscle, in: app)
        XCTAssertTrue(bar.exists || bar.waitForExistence(timeout: 10), "Volume must show \(muscle)'s volume bar",
                      file: file, line: line)
        reveal(bar, in: app)
        bar.tap()
        XCTAssertTrue(appears(app.staticTexts["This Week"]), "The bar must open \(muscle)'s screen",
                      file: file, line: line)
    }
}
