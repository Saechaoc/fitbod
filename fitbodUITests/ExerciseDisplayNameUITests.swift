//
//  ExerciseDisplayNameUITests.swift
//  fitbodUITests
//
//  T30, review item 21. Screens name an exercise by its catalog name,
//  "Barbell Bench Press - Medium Grip", never by `canonicalName`, the
//  lowercased search key. Today's muscle screen listed CONTRIBUTING
//  EXERCISES by the key, and so did Today's lift list. The muscle screen
//  also showed ADJUST TARGETS twice, as its heading and as the only row
//  under it; that row now reads "Edit volume targets" and opens the
//  targets inline.
//
//  The muscle screen opens from the demo seed's heatmap: its finished
//  Push A this week trained the chest with the bench press. The lift list
//  comes from the active-block seed instead, because Today lists lifts
//  only for a session an active block schedules, and the demo seed has no
//  block. That seed's one session holds the bench press.
//

import XCTest

final class ExerciseDisplayNameUITests: XCTestCase {
    private static let benchPress = "Barbell Bench Press - Medium Grip"

    override func setUpWithError() throws {
        // Every check runs, so one wrong name does not hide the rest.
        continueAfterFailure = true
    }

    // MARK: - Muscle screen

    /// CONTRIBUTING EXERCISES names the bench press with its capitals.
    @MainActor
    func testMuscleScreenNamesContributingExercisesWithCapitals() throws {
        let app = openChest()
        let name = app.staticTexts.labeled(Self.benchPress)
        UITestNavigation.reveal(name, in: app)
        UITestNavigation.saveScreenshot("T30", "muscle-detail")
        XCTAssertEqual(name.label, Self.benchPress,
                       "CONTRIBUTING EXERCISES must show the exercise's name, not its lowercased search key")
    }

    /// ADJUST TARGETS is the section's heading and nothing else.
    @MainActor
    func testMuscleScreenLabelsAdjustTargetsOnce() throws {
        let app = openChest()
        revealAdjustTargets(in: app)
        let labeled = app.descendants(matching: .any).matching(NSPredicate(format: "label ==[c] %@", "Adjust targets"))
        let found = labeled.allElementsBoundByIndex.map {
            "type \($0.elementType.rawValue) \"\($0.label)\" value \"\($0.value as? String ?? "")\""
        }
        XCTAssertEqual(labeled.count, 1,
                       "Only the heading may read ADJUST TARGETS, but the muscle screen has: \(found)")
    }

    /// "Edit volume targets" opens the MEV, MAV and MRV steppers under it
    /// and closes them again, and tells VoiceOver which it did.
    @MainActor
    func testEditVolumeTargetsOpensTheTargetsInline() throws {
        let app = openChest()
        revealAdjustTargets(in: app)
        let row = app.buttons.matching(NSPredicate(format: "label == %@", "Edit volume targets")).firstMatch
        UITestNavigation.reveal(row, in: app)
        UITestNavigation.assertTapTarget(row)
        let reset = app.buttons.labeled("Reset to RP defaults")
        XCTAssertFalse(reset.exists, "The targets start closed")
        XCTAssertEqual(row.value as? String, "Collapsed", "VoiceOver must hear that the targets are closed")
        UITestNavigation.saveScreenshot("T30", "edit-targets-closed")

        row.tap()
        XCTAssertTrue(reset.waitForExistence(timeout: 5), "Edit volume targets must open the steppers under it")
        XCTAssertEqual(row.value as? String, "Expanded", "VoiceOver must hear that the targets are open")
        revealAboveTabBar(reset, in: app)
        UITestNavigation.saveScreenshot("T30", "edit-targets-open")

        for _ in 0..<4 where !row.isHittable {
            app.swipeDown(velocity: .slow)
        }
        row.tap()
        XCTAssertTrue(reset.waitForNonExistence(timeout: 5), "A second tap must close the steppers")
        XCTAssertEqual(row.value as? String, "Collapsed", "VoiceOver must hear that the targets closed")
    }

    // MARK: - Lift list

    /// Today's lift list names the bench press with its capitals, on the
    /// row numbered 01.
    @MainActor
    func testLiftListNamesTheExerciseWithCapitals() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        let number = app.staticTexts["01"]
        let name = app.staticTexts.labeled(Self.benchPress)
        UITestNavigation.reveal(number, in: app)
        UITestNavigation.reveal(name, in: app)
        UITestNavigation.saveScreenshot("T30", "lift-list")
        XCTAssertEqual(name.label, Self.benchPress,
                       "Today's lift list must show the exercise's name, not its lowercased search key")
        XCTAssertEqual(name.frame.midY, number.frame.midY, accuracy: 30, "The name must sit on the row numbered 01")
    }

    // MARK: - Navigation

    /// Launches the demo seed and opens Chest from Today's heatmap, the last
    /// section of Today.
    @MainActor
    private func openChest(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        let chest = app.buttons.matching(NSPredicate(format: "label == %@", "Chest")).firstMatch
        revealAboveTabBar(chest, in: app)
        chest.tap()
        XCTAssertTrue(app.staticTexts.labeled("Contributing Exercises").waitForExistence(timeout: 10),
                      "Tapping Chest on the heatmap must open its muscle screen", file: file, line: line)
        return app
    }

    /// Scrolls until `element` sits clear of the tab bar, which floats over
    /// the end of the screen.
    @MainActor
    private func revealAboveTabBar(_ element: XCUIElement, in app: XCUIApplication) {
        UITestNavigation.reveal(element, in: app)
        let tabBarTop = UITestNavigation.tab("Today", in: app).frame.minY
        for _ in 0..<5 where element.frame.maxY > tabBarTop {
            app.swipeUp(velocity: .slow)
        }
    }

    /// Scrolls the muscle screen to its last section, ADJUST TARGETS.
    @MainActor
    private func revealAdjustTargets(in app: XCUIApplication) {
        UITestNavigation.reveal(app.staticTexts.labeled("Adjust Targets"), in: app)
        app.swipeUp(velocity: .slow)
    }
}
