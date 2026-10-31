//
//  BlockNameTypingUITests.swift
//  fitbodUITests
//
//  Ticket T24, review item 47. A UI test once typed "Cancel Probe" into
//  New Block's name and got "ancel Probe", even with the keyboard up and a
//  one-second wait. The name field draws its own placeholder over a text
//  field and adds its own tap gesture. These tests type the name the way a
//  person does, one software keyboard key at a time, and with one
//  `typeText` call.
//

import XCTest

final class BlockNameTypingUITests: XCTestCase {
    private static let name = "Cancel Probe"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Tapping one key at a time types the whole name.
    @MainActor
    func testKeyTapsTypeTheWholeName() throws {
        let app = openBlankNewBlock()
        let field = focusNameField(in: app)
        var typed: [String] = []
        for character in Self.name {
            tapKey(character, in: app)
            typed.append("\(character) → \"\(text(of: field))\"")
        }
        XCTContext.runActivity(named: "Key taps: \(typed.joined(separator: ", "))") { _ in }
        UITestNavigation.saveScreenshot("T24", "name-key-taps")
        XCTAssertEqual(text(of: field), Self.name, "Tapping each key must type the whole name")
    }

    /// One `typeText` call into the focused field types the whole name.
    @MainActor
    func testOneTypeTextCallTypesTheWholeName() throws {
        let app = openBlankNewBlock()
        let field = focusNameField(in: app)
        field.typeText(Self.name)
        XCTContext.runActivity(named: "typeText: \"\(text(of: field))\"") { _ in }
        UITestNavigation.saveScreenshot("T24", "name-type-text")
        XCTAssertEqual(text(of: field), Self.name, "One typeText call must type the whole name")
    }

    // MARK: - Helpers

    /// Program → + NEW → + New block → Blank Block: a block with no name.
    @MainActor
    private func openBlankNewBlock() -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.hittable(app.buttons, "+ NEW").tap()
        UITestNavigation.hittable(app.buttons, "+ New block").tap()
        UITestNavigation.hittable(app.buttons, "Blank Block").tap()
        XCTAssertTrue(app.staticTexts.labeled("NEW BLOCK").waitForExistence(timeout: 10), "New Block never opened")
        return app
    }

    /// Taps the empty name field and waits until the software keyboard is
    /// up and the field has keyboard focus.
    @MainActor
    private func focusNameField(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Missing the block name field", file: file, line: line)
        XCTAssertEqual(text(of: field), "", "The block name must start empty", file: file, line: line)
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5),
                      "The software keyboard must appear", file: file, line: line)
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)
        XCTAssertEqual(XCTWaiter().wait(for: [focused], timeout: 5), .completed,
                       "The name field never took keyboard focus", file: file, line: line)
        return field
    }

    /// Taps the software keyboard's key for `character`, shifting first
    /// when the keyboard shows the other case.
    @MainActor
    private func tapKey(_ character: Character, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let keyboard = app.keyboards.firstMatch
        if character == " " {
            keyboard.keys["space"].tap()
            return
        }
        let key = keyboard.keys[String(character)]
        if !key.exists {
            keyboard.buttons["shift"].tap()
        }
        XCTAssertTrue(key.waitForExistence(timeout: 2), "The keyboard has no \(character) key", file: file, line: line)
        key.tap()
    }

    /// The field's text; an empty field reports its placeholder.
    @MainActor
    private func text(of field: XCUIElement) -> String {
        let value = field.value as? String ?? ""
        return value == field.placeholderValue ? "" : value
    }
}
