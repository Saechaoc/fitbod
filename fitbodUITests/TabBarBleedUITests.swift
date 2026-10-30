import XCTest

/// Ticket T66, finding F45. At accessibility text sizes the tab bar shows
/// its tabs in two rows, and the bottom row sits on the home indicator
/// area. A selected cell's ink fill stops at its own frame, so the area
/// below it shows the bar's background, the way SAVE's fill does in
/// StripeAndBleedUITests. At default text the bar keeps its look.
final class TabBarBleedUITests: XCTestCase {

    // Light-mode BRU colors.
    private static let ink = UITestNavigation.RGB(hex: 0x0A0A0A)
    private static let bg = UITestNavigation.RGB(hex: 0xF2EFE7)

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// At AX3 PROGRESS and LIBRARY make up the bottom row. The selected one
    /// fills its own cell with ink, and the home indicator area below it
    /// shows the bar's bruBg down to the bottom of the screen.
    @MainActor
    func testSelectedFillStopsAboveTheHomeIndicatorAtAX3() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore, textSize: .ax3)
        for name in ["Library", "Progress"] {
            UITestNavigation.selectTab(name, in: app)
            UITestNavigation.saveScreenshot("T66", "tab-bar-\(name.lowercased())", textSize: .ax3)
            let screenshot = XCUIScreen.main.screenshot()
            let frame = UITestNavigation.tab(name, in: app).frame
            let bottom = screenshot.image.size.height
            XCTAssertLessThan(frame.maxY, bottom - 20, "\(name) must sit above the home indicator area at AX3: \(frame)")

            // Inside the cell, clear of its label, is the ink fill.
            UITestNavigation.assertColor(at: CGPoint(x: frame.minX + 6, y: frame.minY + 6), in: screenshot, is: Self.ink)
            UITestNavigation.assertColor(at: CGPoint(x: frame.maxX - 6, y: frame.maxY - 6), in: screenshot, is: Self.ink)
            // Below it, down to the bottom of the screen, is the bar's bruBg.
            // The x is the cell's middle, clear of the home indicator and the corner.
            for y in [frame.maxY + 2, (frame.maxY + bottom) / 2, bottom - 2] {
                UITestNavigation.assertColor(at: CGPoint(x: frame.midX, y: y), in: screenshot, is: Self.bg)
            }
        }
    }

    /// At default text the bar is one row that reaches the bottom of the
    /// screen. Selected LIBRARY shows its 29pt ink band 8pt below the top of
    /// its cell, with bruBg above and below the band.
    @MainActor
    func testDefaultTextKeepsTheSelectedBand() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore, textSize: .default)
        UITestNavigation.selectTab("Library", in: app)
        UITestNavigation.saveScreenshot("T66", "tab-bar-library")
        let screenshot = XCUIScreen.main.screenshot()
        let frame = UITestNavigation.tab("Library", in: app).frame
        let bottom = screenshot.image.size.height
        XCTAssertEqual(frame.maxY, bottom, accuracy: 0.5, "At default text the bar reaches the bottom of the screen: \(frame)")

        UITestNavigation.assertColor(at: CGPoint(x: frame.midX, y: frame.minY + 4), in: screenshot, is: Self.bg)
        for y in [frame.minY + 10, frame.minY + 35] {
            UITestNavigation.assertColor(at: CGPoint(x: frame.minX + 4, y: y), in: screenshot, is: Self.ink)
        }
        for y in [frame.minY + 41, bottom - 2] {
            UITestNavigation.assertColor(at: CGPoint(x: frame.midX, y: y), in: screenshot, is: Self.bg)
        }
    }
}
