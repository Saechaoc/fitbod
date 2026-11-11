import XCTest

/// Opening an exercise from Library search and coming back must leave the
/// tab bar on screen: a search field still editing hides it.
final class LibrarySearchBackUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTabBarComesBackAfterOpeningASearchResult() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Library", in: app)

        let search = app.textFields["library.search.browser"]
        XCTAssertTrue(UITestNavigation.appears(search))
        search.tap()
        search.typeText("Bench Press (Barbell)")
        let result = app.staticTexts["Bench Press (Barbell)"]
        XCTAssertTrue(UITestNavigation.appears(result))
        result.tap()

        let back = app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Back")).firstMatch
        XCTAssertTrue(UITestNavigation.appears(back))
        back.tap()

        XCTAssertTrue(UITestNavigation.appears(search))
        XCTAssertTrue(UITestNavigation.appears(UITestNavigation.tab("Today", in: app)),
                      "The tab bar must come back after Back from a search result")
    }
}
