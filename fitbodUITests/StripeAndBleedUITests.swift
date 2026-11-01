import XCTest

/// Ticket T17, review items 30 and 16. A thin stripe beside other content
/// no longer stretches its row: the live-edit banner is a compact band and
/// the Plate Inventory tab strip a normal strip, and each stripe keeps its
/// color and width. A BRUButton's fill stops at its own frame, so SAVE's
/// fill in the session editor's bottom bar never reaches the home
/// indicator area, and enabled and disabled buttons keep their fills.
final class StripeAndBleedUITests: XCTestCase {

    // Light-mode BRU colors.
    private static let paper = UITestNavigation.RGB(hex: 0xFAFAF7)
    private static let signal = UITestNavigation.RGB(hex: 0xFF5C1A)
    private static let ink = UITestNavigation.RGB(hex: 0x0A0A0A)
    private static let bg2 = UITestNavigation.RGB(hex: 0xEDEAE0)
    private static let faint = UITestNavigation.RGB(hex: 0xE8E5DD)

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Live-edit banner

    /// The routine editor of a routine on an active block. The banner sits
    /// above the scroll view, and its stripe took half of the free height.
    @MainActor
    func testRoutineEditorShowsACompactLiveEditBanner() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        openSeededRoutine(in: app)
        let banner = liveEditBanner(in: app)
        UITestNavigation.saveScreenshot("T17", "routine-banner")
        UITestNavigation.assertHeight(banner, atMost: 120)
        assertSignalStripe(on: banner)
    }

    /// The session editor of a session on an active block shows the banner
    /// under its header.
    @MainActor
    func testSessionEditorShowsACompactLiveEditBanner() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        openSeededSessionEditor(in: app)
        let banner = liveEditBanner(in: app)
        UITestNavigation.saveScreenshot("T17", "session-editor-banner")
        UITestNavigation.assertHeight(banner, atMost: 120)
        assertSignalStripe(on: banner)
    }

    /// At AX3 the banner grows with its wrapped text and stays clear of the
    /// routine's name field. Under the header it took about a third of the
    /// space above the tab bar and pushed the first session under the tab
    /// bar, so at accessibility sizes it scrolls with the page, after the
    /// sessions (T108), and drags bring it whole onto the screen.
    @MainActor
    func testLiveEditBannerFitsItsTextAtAX3() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock, textSize: .ax3)
        openSeededRoutine(in: app)
        let name = app.textFields["Routine name"]
        XCTAssertTrue(name.exists || name.waitForExistence(timeout: 10))
        XCTAssertTrue(name.isHittable, "The routine's name field must show when the screen opens")

        // Slow drags in the trailing margin, clear of the session row's
        // press, until the banner's frame sits whole above the tab bar's
        // 2pt rule; the extra 10pt covers the drag the page takes before it
        // starts to scroll.
        let banner = liveEditBanner(in: app)
        let tabBarTop = UITestNavigation.tab("Today", in: app).frame.minY - 2
        let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.width - 8, dy: tabBarTop - 20))
        for _ in 0..<4 {
            let overflow = banner.frame.maxY - (tabBarTop - 20)
            if overflow <= 0 { break }
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -(overflow + 10))),
                        withVelocity: .slow, thenHoldForDuration: 0.3)
            UITestNavigation.waitUntilStill(banner, interval: 0.3)
        }
        UITestNavigation.saveScreenshot("T17", "routine-banner", textSize: .ax3)
        XCTAssertLessThanOrEqual(banner.frame.maxY, tabBarTop, "Drags must bring the banner at \(banner.frame) whole above the tab bar")
        UITestNavigation.assertInside(banner, app.windows.firstMatch)
        XCTAssertGreaterThan(banner.frame.height, 120, "At AX3 the banner's text needs more than its default height")
        UITestNavigation.assertNoOverlap(banner, name)
    }

    // MARK: - Plate Inventory tab strip

    /// Settings > Plate Inventory. The 1pt separators between the tabs
    /// stretched the strip to half of the free height.
    @MainActor
    func testPlateInventoryTabStripIsANormalStrip() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.openSettings(in: app)
        let inventory = app.buttons.labeled("Plate Inventory")
        UITestNavigation.reveal(inventory, in: app)
        inventory.tap()
        let strip = app.otherElements["plateInventory.tabStrip"]
        XCTAssertTrue(strip.waitForExistence(timeout: 10), "Plate Inventory must show its tab strip")
        UITestNavigation.waitUntilStill(strip, interval: 0.3)
        UITestNavigation.saveScreenshot("T17", "plate-inventory-tabs")
        UITestNavigation.assertHeight(strip, atMost: 60)

        // The separator after DUMBBELLS is still a 1pt ink line from the top
        // of the strip to its bottom, between two paper tabs.
        let dumbbells = app.buttons.labeled("DUMBBELLS")
        XCTAssertTrue(dumbbells.exists)
        let screenshot = XCUIScreen.main.screenshot()
        let line = dumbbells.frame.maxX + 0.5
        let top = strip.frame.minY + 5
        for y in [top, strip.frame.midY, strip.frame.maxY - 5] {
            UITestNavigation.assertColor(at: CGPoint(x: line, y: y), in: screenshot, is: Self.ink)
        }
        UITestNavigation.assertColor(at: CGPoint(x: line - 2.5, y: top), in: screenshot, is: Self.paper)
        UITestNavigation.assertColor(at: CGPoint(x: line + 2.5, y: top), in: screenshot, is: Self.paper)
    }

    // MARK: - Bottom bar fill

    /// The session editor's DISCARD and SAVE bar sits on the home indicator
    /// area. SAVE's signal fill ran on below the bar to the bottom of the
    /// screen; that area must show the sheet's paper.
    @MainActor
    func testSaveFillStopsAboveTheHomeIndicator() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        openSeededSessionEditor(in: app)
        let save = app.buttons["Save session ▸"]
        UITestNavigation.waitUntilStill(save, interval: 0.3)
        UITestNavigation.saveScreenshot("T17", "session-editor-bottom-bar")
        let screenshot = XCUIScreen.main.screenshot()
        let frame = save.frame
        let bottom = screenshot.image.size.height
        XCTAssertLessThan(frame.maxY, bottom - 20, "SAVE must sit above the home indicator area: \(frame)")

        // Inside SAVE, clear of its 1.5pt border, is the signal fill.
        UITestNavigation.assertColor(at: CGPoint(x: frame.minX + 6, y: frame.minY + 6), in: screenshot, is: Self.signal)
        // Below it, down to the bottom of the screen, is the sheet's paper.
        // The x is SAVE's middle, clear of the home indicator and the corner.
        for y in [frame.maxY + 2, (frame.maxY + bottom) / 2, bottom - 2] {
            UITestNavigation.assertColor(at: CGPoint(x: frame.midX, y: y), in: screenshot, is: Self.paper)
        }
    }

    // MARK: - Button states

    /// The component gallery's enabled signal button keeps its signal fill,
    /// and its disabled one its faint fill, inside their frames.
    @MainActor
    func testEnabledAndDisabledButtonsKeepTheirFills() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.openSettings(in: app)
        let gallery = app.buttons["settings.componentGallery"]
        UITestNavigation.reveal(gallery, in: app)
        gallery.tap()
        let enabled = app.buttons.labeled("Signal action ▸")
        let disabled = app.buttons.labeled("Unavailable")
        XCTAssertTrue(disabled.waitForExistence(timeout: 10))
        UITestNavigation.reveal(disabled, in: app)
        XCTAssertTrue(enabled.isHittable)
        XCTAssertFalse(disabled.isEnabled)
        UITestNavigation.waitUntilStill(disabled, interval: 0.3)
        UITestNavigation.saveScreenshot("T17", "button-states")

        let screenshot = XCUIScreen.main.screenshot()
        for (button, fill) in [(enabled, Self.signal), (disabled, Self.faint)] {
            let frame = button.frame
            UITestNavigation.assertColor(at: CGPoint(x: frame.minX + 6, y: frame.minY + 6), in: screenshot, is: fill)
            UITestNavigation.assertColor(at: CGPoint(x: frame.maxX - 6, y: frame.maxY - 6), in: screenshot, is: fill)
        }
    }

    // MARK: - Helpers

    /// Program > the seeded routine: the routine editor.
    @MainActor
    private func openSeededRoutine(in app: XCUIApplication) {
        UITestNavigation.selectTab("Program", in: app)
        let routine = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Live Routine")).firstMatch
        XCTAssertTrue(routine.waitForExistence(timeout: 10), "Program must list the seeded routine")
        UITestNavigation.reveal(routine, in: app)
        routine.tap()
        XCTAssertTrue(app.buttons["Session 1: Live Push"].waitForExistence(timeout: 10))
    }

    /// The routine's session, then EDIT: the session editor sheet.
    @MainActor
    private func openSeededSessionEditor(in app: XCUIApplication) {
        openSeededRoutine(in: app)
        app.buttons["Session 1: Live Push"].tap()
        XCTAssertTrue(app.buttons.labeled("Start workout ▸").waitForExistence(timeout: 10))
        app.buttons.labeled("Edit").tap()
        XCTAssertTrue(app.buttons["Save session ▸"].waitForExistence(timeout: 10))
    }

    /// The banner on the screen on top, once it has stopped moving.
    @MainActor
    private func liveEditBanner(in app: XCUIApplication) -> XCUIElement {
        let banners = app.descendants(matching: .any).matching(identifier: "liveEditBanner")
        XCTAssertTrue(banners.firstMatch.waitForExistence(timeout: 10), "A routine on an active block must show the live-edit banner")
        let banner = banners.allElementsBoundByIndex.last(where: \.isHittable) ?? banners.firstMatch
        UITestNavigation.waitUntilStill(banner, interval: 0.3)
        return banner
    }

    /// The 4pt signal stripe runs the banner's full height at its leading
    /// edge, and the banner's fill starts right after it.
    @MainActor
    private func assertSignalStripe(on banner: XCUIElement) {
        let frame = banner.frame
        let screenshot = XCUIScreen.main.screenshot()
        // The bottom 2pt are the banner's ink rule.
        for y in [frame.minY + 3, frame.midY, frame.maxY - 6] {
            UITestNavigation.assertColor(at: CGPoint(x: frame.minX + 2, y: y), in: screenshot, is: Self.signal)
            UITestNavigation.assertColor(at: CGPoint(x: frame.minX + 6, y: y), in: screenshot, is: Self.bg2)
        }
    }
}

extension UITestNavigation {
    /// A fresh store plus a routine whose session sits on an active block
    /// (ActiveBlockSeed).
    static let activeBlock = [resetFlag, "-fitbod-seed-active-block"]
}
