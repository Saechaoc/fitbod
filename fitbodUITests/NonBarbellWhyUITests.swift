import XCTest

/// A model test cannot prove the logger's separate WHY calculation or its USE write.
final class NonBarbellWhyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // XCUIApplication and shared navigation require the main actor.
    @MainActor
    func testCableWhyUsesIncrementAndUseWritesThatWeight() throws {
        let app = UITestNavigation.openSeededWorkout()
        // Demo Push A's fifth exercise is the cable pushdown with a prior 25 lb set.
        let weight = app.textFields["set.weight.5.S1"]
        let span = UITestNavigation.loggerSpan(in: app)
        for _ in 0..<10 where !weight.exists {
            UITestNavigation.dragLogger(from: span.bottom - 20, to: span.top + 20, in: app)
        }
        XCTAssertTrue(weight.exists)
        UITestNavigation.revealInLogger(weight, in: app)
        XCTAssertEqual(number(in: weight), 25)
        UITestNavigation.enter("90", into: weight)
        let entered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '90 lb'"), object: weight)
        XCTAssertEqual(XCTWaiter().wait(for: [entered], timeout: 5), .completed)

        UITestNavigation.keyboardDone(in: app).tap()
        let why = app.buttons["card.why.5"]
        XCTAssertTrue(UITestNavigation.appears(why))
        XCTAssertTrue(why.label.contains("Suggested 25 lb"))
        let use = UITestNavigation.suggestedWeightAction(for: "5.S1", in: app)
        let suggested = use.label.split(separator: " ").dropFirst().first.flatMap { Double($0) }
        XCTAssertEqual(suggested, 25, "Cable WHY must match increment rounding instead of the 45 lb bar")
        use.tap()
        XCTAssertTrue(!use.exists || use.waitForNonExistence(timeout: 5))
        XCTAssertEqual(number(in: weight), 25, "USE must replace the entered weight with the cable prescription")
    }

    @MainActor
    private func number(in field: XCUIElement) -> Double? {
        guard let value = field.value as? String else { return nil }
        return value.split(separator: " ").first.flatMap {
            Double($0.replacingOccurrences(of: ",", with: "."))
        }
    }
}
