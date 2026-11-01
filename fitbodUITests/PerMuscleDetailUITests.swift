//
//  PerMuscleDetailUITests.swift
//  fitbodUITests
//
//  Reaches the detail view via a volume-bar tap (more stable than
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

    // MARK: - Chest

    /// The demo Push A's two chest exercises, in name order.
    private static let tiedContributors = ["Barbell Bench Press - Medium Grip", "Incline Dumbbell Press"]

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
    /// `muscle`'s volume bar on Today, a button that reads "Chest: 6 sets
    /// this week, …", or "1 set" for one.
    static func volumeBar(_ muscle: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH %@ AND label MATCHES %@", muscle + ": ", ".+: [0-9]+ sets? this week, .*"
        )).firstMatch
    }

    /// Taps `muscle`'s volume bar on Today and waits for its screen.
    static func openMuscle(_ muscle: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let bar = volumeBar(muscle, in: app)
        XCTAssertTrue(bar.exists || bar.waitForExistence(timeout: 10), "Today must show \(muscle)'s volume bar",
                      file: file, line: line)
        reveal(bar, in: app)
        bar.tap()
        XCTAssertTrue(appears(app.staticTexts["This Week"]), "The bar must open \(muscle)'s screen",
                      file: file, line: line)
    }
}
