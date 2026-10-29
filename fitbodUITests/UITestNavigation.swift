import XCTest

/// Shared navigation through the real four-tab shell and Today settings sheet.
@MainActor
enum UITestNavigation {
    /// A fresh store: the catalog only, no workouts.
    static let freshStore = ["-fitbod-reset-store"]
    /// A fresh store plus the demo Push A: one finished workout this week
    /// and today's workout in progress (see DemoWorkoutSeed).
    static let seededWorkout = ["-fitbod-reset-store", "-fitbod-seed-demo-workout"]

    /// Launches the app and waits until the tab bar is up, which happens
    /// after the first-launch catalog import.
    static func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(tab("Today", in: app).waitForExistence(timeout: 90), "The tab bar never appeared")
        return app
    }

    /// A tab bar cell. BRUTabBar identifies each cell by its tab name.
    static func tab(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(identifier: name).firstMatch
    }

    /// Taps a tab in the BRU tab bar and waits until it is the selected one.
    static func selectTab(_ name: String, in app: XCUIApplication) {
        let cell = tab(name, in: app)
        XCTAssertTrue(cell.waitForExistence(timeout: 90), "Missing tab: \(name)")
        cell.tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: cell)
        XCTAssertEqual(XCTWaiter().wait(for: [selected], timeout: 5), .completed, "Tab not selected: \(name)")
    }

    static func openSettings(in app: XCUIApplication) {
        selectTab("Today", in: app)
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label ==[c] %@", "Settings"
        )).firstMatch.exists)
    }

    static func reveal(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 12) {
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable { return }
            let scroll = app.scrollViews.allElementsBoundByIndex.last(where: { $0.isHittable })
            if let scroll { scroll.swipeUp(velocity: .slow) }
            else { app.swipeUp(velocity: .slow) }
        }
        XCTAssertTrue(element.exists && element.isHittable, "Expected a visible control: \(element)")
    }
}
