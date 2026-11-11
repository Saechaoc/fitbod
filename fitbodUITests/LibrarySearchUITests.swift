import XCTest

/// Library search finds an exercise by the words of its name in any order,
/// and by the names people use for it, showing the name it matched (RM-022).
final class LibrarySearchUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAnAliasFindsItsExerciseAndSaysSo() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Library", in: app)
        let search = app.textFields["library.search.browser"]
        XCTAssertTrue(UITestNavigation.appears(search))

        search.tap()
        search.typeText("stairmaster")
        let climber = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Stair Climber")).firstMatch
        XCTAssertTrue(UITestNavigation.appears(climber), "An alias finds its exercise")
        XCTAssertTrue(
            climber.label.localizedCaseInsensitiveContains("stairmaster"),
            "The row shows the alias it was found by: \(climber.label)"
        )

        app.buttons["Clear search"].tap()
        search.tap()
        search.typeText("press bench barbell medium")
        let bench = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Barbell Bench Press - Medium Grip")).firstMatch
        XCTAssertTrue(UITestNavigation.appears(bench), "Words find a name in any order")
    }
}
