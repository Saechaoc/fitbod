//
//  PerMuscleDetailUITests.swift
//  fitbodUITests
//
//  Phase 5 VOL-05 + VOL-06 + SET-05 — smoke test that
//  PerMuscleDetailView is reachable and that the 4 sections are
//  mounted.
//
//  Reaches the detail view via a volume-bar tap (more stable than
//  per-region heatmap path hit-testing across simulator runs).
//  Asserts the navigation title + at least one of the section
//  headers is present.
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

    @MainActor
    func testPerMuscleDetailReachableFromVolumeBarTap() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)

        // The demo Push A trains Chest this week, so its bar is always
        // there to tap.
        let bar = UITestNavigation.volumeBar("Chest", in: app)
        XCTAssertTrue(bar.exists || bar.waitForExistence(timeout: 10), "Today must show Chest's volume bar")
        UITestNavigation.reveal(bar, in: app)
        bar.tap()

        // The bar opens Chest's screen: assert that ONE of the section
        // headers exists.
        let thisWeek = app.staticTexts["This Week"]
        let contributing = app.staticTexts["Contributing Exercises"]
        let frequency = app.staticTexts["Frequency This Week"]
        let adjustTargets = app.staticTexts["Adjust Targets"]

        let landed = thisWeek.waitForExistence(timeout: 5)
                  || contributing.waitForExistence(timeout: 1)
                  || frequency.waitForExistence(timeout: 1)
                  || adjustTargets.waitForExistence(timeout: 1)
        XCTAssertTrue(landed, "Bar tap should land in PerMuscleDetailView (one of 4 section headers visible).")
    }

    /// T109, finding F209: Chest's four targets use BRU steppers, one
    /// adjustable element each with its VoiceOver label and set count,
    /// and no stock iOS stepper is left on the screen.
    @MainActor
    func testVolumeTargetsUseBRUSteppers() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        UITestNavigation.openMuscle("Chest", in: app)
        let edit = app.buttons["Edit volume targets"]
        UITestNavigation.reveal(edit, in: app)
        edit.tap()

        // The targets end with RESET TO RP DEFAULTS; bring it on screen so
        // the screenshot holds all four steppers.
        UITestNavigation.reveal(app.buttons.labeled("Reset to RP defaults"), in: app)
        UITestNavigation.saveScreenshot("T109", "muscle-targets")

        XCTAssertEqual(app.steppers.count, 0, "Chest's targets must use BRU steppers, not the stock iOS stepper")
        for target in Self.chestTargets {
            let stepper = app.otherElements[target.label]
            XCTAssertTrue(stepper.exists, "Missing the BRU stepper \(target.label)")
            XCTAssertEqual(stepper.value as? String, target.value, "\(target.label) must read its set count")
            UITestNavigation.assertTapTarget(stepper.buttons["−"])
            UITestNavigation.assertTapTarget(stepper.buttons["+"])
        }

        // MEV steps down a set at a time, shows the order check once it is
        // below MV's 6 sets, and stops at 1 set, the bottom of every
        // target's range.
        let mev = app.otherElements["Minimum effective volume for Chest"]
        let orderError = app.staticTexts.labeled("Targets must be in order: MV ≤ MEV < MAV < MRV.")
        for sets in (1...7).reversed() {
            mev.buttons["−"].tap()
            XCTAssertEqual(mev.value as? String, sets == 1 ? "1 set" : "\(sets) sets", "− must take MEV down one set")
            XCTAssertEqual(orderError.exists, sets < 6, "The order check must show only while MEV is below MV")
        }
        XCTAssertFalse(mev.buttons["−"].isEnabled, "MEV must stop at 1 set")
    }

    /// T109, finding F210: Chest's two contributing exercises have exactly
    /// three weighted sets each. Rows with the same weighted sets sort by
    /// name, so a second render of the screen keeps their order. The
    /// order rule's other cases are in ContributingExercisesOrderTests.
    @MainActor
    func testContributingExercisesWithEqualCountsKeepTheirOrder() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        UITestNavigation.openMuscle("Chest", in: app)
        let first = tiedContributorOrder(in: app)

        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Edit volume targets"].waitForNonExistence(timeout: 5), "Back must leave Chest's screen")
        UITestNavigation.openMuscle("Chest", in: app)
        let second = tiedContributorOrder(in: app)

        XCTAssertEqual(first, Self.tiedContributors, "Contributing exercises with the same weighted sets must sort by name")
        XCTAssertEqual(second, first, "Contributing exercises must keep their order when the screen renders again")
    }

    // MARK: - Chest

    /// The RP defaults for Chest: MV 6, MEV 8, MAV 16 and MRV 22 sets.
    private static let chestTargets: [(label: String, value: String)] = [
        ("Maintenance volume for Chest", "6 sets"),
        ("Minimum effective volume for Chest", "8 sets"),
        ("Maximum adaptive volume for Chest", "16 sets"),
        ("Maximum recoverable volume for Chest", "22 sets"),
    ]

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
        XCTAssertTrue(app.staticTexts["This Week"].waitForExistence(timeout: 10), "The bar must open \(muscle)'s screen",
                      file: file, line: line)
    }
}
