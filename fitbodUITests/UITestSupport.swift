//
//  UITestSupport.swift
//  fitbodUITests
//
//  Shared helpers for the milestone-1 XCUITests: launching with the app's
//  test switches (see `LaunchConfiguration`), waiting, revealing rows in
//  lazy lists, typing into fields, tapping dialog buttons, and attaching
//  named screenshots that CI exports as verification evidence.
//

import XCTest

enum Launch {
    static let uiTesting = "-ui-testing"
    static let resetStore = "-reset-store"
    static let demoHistory = "-seed-demo-history"
    static let darkMode = "-ui-dark-mode"

    /// UIContentSizeCategory raw values for `-UIPreferredContentSizeCategoryName`.
    static let extraExtraExtraLarge = "UICTContentSizeCategoryXXXL"
    static let accessibilityLarge = "UICTContentSizeCategoryAccessibilityL"
}

extension XCTestCase {

    /// Launches the app with the given switches. `waitForTabs` waits until
    /// the first-launch library seed has finished and the tab bar is up.
    @MainActor
    @discardableResult
    func launchFitbod(
        reset: Bool,
        demoHistory: Bool = false,
        dark: Bool = false,
        contentSize: String? = nil,
        waitForTabs: Bool = true,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = [Launch.uiTesting]
        if reset { arguments.append(Launch.resetStore) }
        if demoHistory { arguments.append(Launch.demoHistory) }
        if dark { arguments.append(Launch.darkMode) }
        if let contentSize { arguments += ["-UIPreferredContentSizeCategoryName", contentSize] }
        app.launchArguments = arguments
        app.launch()
        if waitForTabs {
            XCTAssertTrue(
                app.tabBars.buttons["Today"].waitForExistence(timeout: 120),
                "The tab bar never appeared (library seed did not finish?)",
                file: file, line: line
            )
        }
        return app
    }

    /// Attaches a full-screen screenshot that CI keeps as evidence.
    @MainActor
    func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Waits until `element` exists and is hittable.
    @MainActor
    @discardableResult
    func waitHittable(
        _ element: XCUIElement,
        timeout: TimeInterval = 15,
        _ message: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let predicate = NSPredicate(format: "exists == true AND hittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, message ?? "Not hittable in time: \(element)", file: file, line: line)
        return element
    }

    /// Waits until `element` exists.
    @MainActor
    @discardableResult
    func waitExists(
        _ element: XCUIElement,
        timeout: TimeInterval = 15,
        _ message: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), message ?? "Missing: \(element)", file: file, line: line)
        return element
    }

    /// Waits until `element` is gone.
    @MainActor
    func waitGone(_ element: XCUIElement, timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed, "Still present: \(element)", file: file, line: line)
    }

    /// Swipes the front-most list up until `element` is hittable (rows in
    /// SwiftUI lists are created lazily, so they may not exist yet).
    @MainActor
    func reveal(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) {
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < maxSwipes {
            let lists = app.collectionViews.allElementsBoundByIndex.filter(\.exists)
            if let list = lists.last {
                list.swipeUp(velocity: .slow)
            } else {
                app.swipeUp(velocity: .slow)
            }
            swipes += 1
        }
    }

    /// Reveals and taps.
    @MainActor
    func revealAndTap(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        if !element.waitForExistence(timeout: 3) || !element.isHittable {
            reveal(element, in: app)
        }
        waitHittable(element, file: file, line: line).tap()
    }

    /// Taps the first hittable button with `label` whose identifier is not
    /// excluded — for confirmation dialogs whose action shares its title
    /// with a button on the screen behind it.
    @MainActor
    func tapDialogButton(
        _ label: String,
        in app: XCUIApplication,
        excluding identifiers: Set<String> = [],
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        let query = app.buttons.matching(NSPredicate(format: "label == %@", label))
        while Date() < deadline {
            let candidates = query.allElementsBoundByIndex.filter {
                $0.exists && $0.isHittable && !identifiers.contains($0.identifier)
            }
            if let button = candidates.last {
                button.tap()
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTFail("No tappable dialog button \"\(label)\"", file: file, line: line)
    }

    /// Dismisses the keyboard through the workout keyboard toolbar, or the
    /// keyboard's own return / search key.
    @MainActor
    func dismissKeyboard(in app: XCUIApplication) {
        guard app.keyboards.count > 0 else { return }
        let done = app.buttons["keyboard.done"]
        if done.exists && done.isHittable {
            done.tap()
            return
        }
        let keyboard = app.keyboards.firstMatch
        for key in ["Search", "search", "Return", "return", "Done", "done"] {
            let button = keyboard.buttons[key]
            if button.exists && button.isHittable {
                button.tap()
                return
            }
        }
        app.typeText("\n")
    }
}

extension XCUIApplication {
    /// Any element with this accessibility identifier.
    func element(_ identifier: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Library / picker row for an exercise, matched by its spoken label
    /// ("Barbell Squat, Barbell · Quadriceps").
    func exerciseRow(named name: String) -> XCUIElement {
        descendants(matching: .any)
            .matching(identifier: "exercise.row")
            .matching(NSPredicate(format: "label BEGINSWITH %@", name + ","))
            .firstMatch
    }

    /// The search field that is currently on screen (the library tab and
    /// the exercise picker both use `library.search`).
    var visibleSearchField: XCUIElement {
        let fields = textFields.matching(identifier: "library.search").allElementsBoundByIndex
        return fields.last(where: { $0.exists && $0.isHittable }) ?? textFields["library.search"]
    }
}

extension XCUIElement {
    /// Taps the trailing edge so the cursor lands after existing text.
    func tapAtEnd() {
        coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
    }

    /// Replaces the text of a plain text field.
    func replaceText(with text: String) {
        tapAtEnd()
        let current = (value as? String) ?? ""
        if !current.isEmpty, current != placeholderValue {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        typeText(text)
    }
}
