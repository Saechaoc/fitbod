import XCTest

@MainActor
extension XCUIElementQuery {
    /// The first match whose label equals `label` in any case. BRU labels
    /// reach accessibility uppercased.
    func labeled(_ label: String) -> XCUIElement {
        matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
    }
}

extension UITestNavigation {
    /// Drags from a sheet's header to the bottom of the screen, the way a
    /// user swipes a sheet away.
    static func dragSheetDown(from header: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(appears(header))
        header.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.05,
            thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
        )
    }
}
