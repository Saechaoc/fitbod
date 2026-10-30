import XCTest

/// Shared navigation through the real four-tab shell and Today settings sheet.
@MainActor
enum UITestNavigation {
    /// The DEBUG flag that deletes the store before the app opens it
    /// (`DebugLaunchReset.launchArgument`).
    static let resetFlag = "-fitbod-reset-store"
    /// Asks the DEBUG app to report whether this launch reset the store
    /// (`DebugLaunchReset.signalArgument`). Every launch helper passes it.
    static let resetSignalFlag = "-fitbod-reset-signal"

    /// A fresh store: the catalog only, no workouts.
    static let freshStore = [resetFlag]
    /// A fresh store plus the demo Push A: one finished workout this week
    /// and today's workout in progress (see DemoWorkoutSeed).
    static let seededWorkout = [resetFlag, "-fitbod-seed-demo-workout"]

    /// A text size one launch can pin, whatever the simulator's own
    /// setting, and its token in screenshot names.
    enum TextSize: String {
        case `default`
        case ax3

        /// The content size launch argument: Large, the default, or
        /// accessibility extra large, which is AX3.
        var launchArguments: [String] {
            ["-UIPreferredContentSizeCategoryName",
             self == .ax3 ? "UICTContentSizeCategoryAccessibilityXL" : "UICTContentSizeCategoryL"]
        }
    }

    /// True once this test process has launched the app through `launch`.
    private static var hasLaunched = false

    /// Launches the app and waits until the tab bar is up, which happens
    /// after the first-launch catalog import. `textSize` pins the text size
    /// for this launch only. A launch that asks for a reset fails unless the
    /// app reports a fresh store.
    static func launch(
        _ arguments: [String],
        textSize: TextSize? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIApplication {
        // A run that ends with the per-configuration launch tests leaves
        // the phone in landscape.
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        let resets = arguments.contains(resetFlag)
        if resets && !hasLaunched {
            // The first launch in a test process can lose its arguments
            // while the app is still being reinstalled, and start on old
            // data. Launching and terminating once lets the install finish.
            app.launchArguments = [resetFlag]
            app.launch()
            app.terminate()
        }
        hasLaunched = true
        app.launchArguments = (textSize?.launchArguments ?? []) + arguments + [resetSignalFlag]
        app.launch()
        XCTAssertTrue(tab("Today", in: app).waitForExistence(timeout: 90), "The tab bar never appeared", file: file, line: line)
        if resets {
            assertFreshStore(in: app, file: file, line: line)
        }
        return app
    }

    /// Terminates `app` and launches it again without the reset flag, the
    /// way a user reopens it, so it reads back what earlier launches saved.
    static func relaunch(
        _ app: XCUIApplication,
        textSize: TextSize? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        app.terminate()
        app.launchArguments = (textSize?.launchArguments ?? []) + [resetSignalFlag]
        app.launch()
        XCTAssertTrue(tab("Today", in: app).waitForExistence(timeout: 90), "The tab bar never appeared", file: file, line: line)
    }

    /// What the DEBUG app reports about its store on this launch: "fresh",
    /// or "not fresh: " and the reason.
    static func storeFreshness(in app: XCUIApplication) -> String {
        let signal = app.otherElements["debug.resetSignal"]
        guard signal.waitForExistence(timeout: 10) else {
            return "not fresh: the app shows no reset signal, so the launch lost its arguments or is not a DEBUG build"
        }
        return signal.value as? String ?? "not fresh: the reset signal has no value"
    }

    /// Fails the test unless the app reports a fresh store on this launch.
    static func assertFreshStore(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let freshness = storeFreshness(in: app)
        if freshness != "fresh" {
            XCTFail(
                "A launch with \(resetFlag) must start from a fresh store, but the app reports \"\(freshness)\", so the test would run on old data",
                file: file, line: line
            )
        }
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

    /// Taps a BRUStepper's visible − or + cell until it reads `target`, the
    /// way a user steps it.
    static func step(_ stepper: XCUIElement, to target: Int, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<30 {
            guard let value = Int(stepper.value as? String ?? ""), value != target else { break }
            tapStepper(stepper, increment: value < target)
        }
        XCTAssertEqual(stepper.value as? String, String(target), "The stepper must reach \(target)", file: file, line: line)
    }

    /// A BRUStepper is one adjustable element. At default text sizes its
    /// trailing 152pt are [− 44][value 64][+ 44].
    static func tapStepper(_ stepper: XCUIElement, increment: Bool) {
        stepper.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: increment ? -22 : -130, dy: 0)).tap()
    }
}

// MARK: - Screenshots

extension UITestNavigation {
    /// The appearance token in screenshot names. A run sets the appearance
    /// for the whole phone with `xcrun simctl ui <id> appearance`.
    enum Appearance: String {
        case light
        case dark
    }

    /// Attaches a full-screen screenshot that a passing run keeps, named
    /// `<ticket>-<screen>-<phone>-<text size>-<appearance>`, such as
    /// `T15-program-empty-small-ax3-light`. The phone is "small" on the
    /// 390pt iPhone 17e and "large" on the 440pt iPhone 17 Pro Max.
    @discardableResult
    static func saveScreenshot(
        _ ticket: String,
        _ screen: String,
        textSize: TextSize = .default,
        appearance: Appearance = .light
    ) -> String {
        let screenshot = XCUIScreen.main.screenshot()
        let phone = phoneName(width: screenshot.image.size.width)
        let name = [ticket, screen, phone, textSize.rawValue, appearance.rawValue].joined(separator: "-")
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        XCTContext.runActivity(named: "Screenshot \(name)") { $0.add(attachment) }
        return name
    }

    private static func phoneName(width: CGFloat) -> String {
        let points = Int(width.rounded())
        if points == 390 { return "small" }
        if points == 440 { return "large" }
        return "\(points)pt"
    }
}

// MARK: - Frame checks
//
// Each assertion has a `...Problem` twin that returns its failure message,
// or nil when the frames pass, so a self-test can prove the check fails.
// Frames are in points. Overlap and containment allow half a point for
// rounding at a shared edge.

extension UITestNavigation {
    static func assertNoOverlap(_ a: XCUIElement, _ b: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        fail(overlapProblem(a, b), file: file, line: line)
    }

    static func assertInside(_ inner: XCUIElement, _ outer: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        fail(insideProblem(inner, outer), file: file, line: line)
    }

    /// Text one letter wide wraps a letter per line, so its element is
    /// taller than it is wide.
    static func assertNotTallerThanWide(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        fail(tallerThanWideProblem(element), file: file, line: line)
    }

    static func assertTapTarget(
        _ element: XCUIElement,
        minimum: CGFloat = 44,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        fail(tapTargetProblem(element, minimum: minimum), file: file, line: line)
    }

    static func assertHeight(
        _ element: XCUIElement,
        atMost limit: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        fail(heightProblem(element, atMost: limit), file: file, line: line)
    }

    static func overlapProblem(_ a: XCUIElement, _ b: XCUIElement) -> String? {
        if let missing = missing(a, b) { return missing }
        let shared = a.frame.intersection(b.frame)
        guard !shared.isNull, shared.width > 0.5, shared.height > 0.5 else { return nil }
        return "\(describe(a)) overlaps \(describe(b)) by \(points(shared.width)) x \(points(shared.height))pt"
    }

    static func insideProblem(_ inner: XCUIElement, _ outer: XCUIElement) -> String? {
        if let missing = missing(inner, outer) { return missing }
        guard !outer.frame.insetBy(dx: -0.5, dy: -0.5).contains(inner.frame) else { return nil }
        return "\(describe(inner)) is not inside \(describe(outer))"
    }

    static func tallerThanWideProblem(_ element: XCUIElement) -> String? {
        if let missing = missing(element) { return missing }
        let frame = element.frame
        guard frame.height > frame.width + 0.01 else { return nil }
        return "\(describe(element)) is taller than it is wide, so its letters may be stacked"
    }

    static func tapTargetProblem(_ element: XCUIElement, minimum: CGFloat = 44) -> String? {
        if let missing = missing(element) { return missing }
        let frame = element.frame
        guard frame.width < minimum - 0.01 || frame.height < minimum - 0.01 else { return nil }
        return "\(describe(element)) is smaller than a \(points(minimum)) x \(points(minimum))pt tap target"
    }

    static func heightProblem(_ element: XCUIElement, atMost limit: CGFloat) -> String? {
        if let missing = missing(element) { return missing }
        guard element.frame.height > limit + 0.01 else { return nil }
        return "\(describe(element)) is taller than \(points(limit))pt"
    }

    private static func fail(_ problem: String?, file: StaticString, line: UInt) {
        if let problem {
            XCTFail(problem, file: file, line: line)
        }
    }

    private static func missing(_ elements: XCUIElement...) -> String? {
        elements.first { !$0.exists }.map { "Missing element: \($0)" }
    }

    /// `"Today" at (0, 895), 110 x 61`: the identifier, the label, or the
    /// query when the element has neither, and the frame.
    private static func describe(_ element: XCUIElement) -> String {
        let name = [element.identifier, element.label].first { !$0.isEmpty }.map { "\"\($0)\"" } ?? "\(element)"
        let frame = element.frame
        return "\(name) at (\(points(frame.minX)), \(points(frame.minY))), \(points(frame.width)) x \(points(frame.height))"
    }

    private static func points(_ value: CGFloat) -> String {
        String(format: "%g", (value * 10).rounded() / 10)
    }
}

// MARK: - Pixel check

extension UITestNavigation {
    /// An sRGB color with 0-255 channels.
    struct RGB: Equatable, CustomStringConvertible {
        let red: Int
        let green: Int
        let blue: Int

        init(red: Int, green: Int, blue: Int) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        /// `RGB(hex: 0x0A0A0A)` is bruInk in light mode.
        init(hex: UInt32) {
            self.init(red: Int(hex >> 16 & 0xFF), green: Int(hex >> 8 & 0xFF), blue: Int(hex & 0xFF))
        }

        var description: String {
            String(format: "#%02X%02X%02X", red, green, blue)
        }

        /// The largest difference on any one channel.
        func distance(to other: RGB) -> Int {
            max(abs(red - other.red), abs(green - other.green), abs(blue - other.blue))
        }
    }

    /// The sRGB color at `point`, in screen points, of a full-screen
    /// screenshot, or nil when the point is off the image. Screenshot
    /// pixels are device pixels, so the point is scaled by the screen scale.
    static func color(at point: CGPoint, in screenshot: XCUIScreenshot) -> RGB? {
        let image = screenshot.image
        let x = Int((point.x * image.scale).rounded(.down))
        let y = Int((point.y * image.scale).rounded(.down))
        guard let cgImage = image.cgImage,
              (0..<cgImage.width).contains(x), (0..<cgImage.height).contains(y),
              let pixel = cgImage.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)),
              let sRGB = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var bytes = [UInt8](repeating: 0, count: 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        return drawn ? RGB(red: Int(bytes[0]), green: Int(bytes[1]), blue: Int(bytes[2])) : nil
    }

    /// Fails unless the color at `point` is within `tolerance` of `expected`
    /// on every channel.
    static func assertColor(
        at point: CGPoint,
        in screenshot: XCUIScreenshot,
        is expected: RGB,
        tolerance: Int = 8,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        fail(colorProblem(at: point, in: screenshot, is: expected, tolerance: tolerance), file: file, line: line)
    }

    static func colorProblem(at point: CGPoint, in screenshot: XCUIScreenshot, is expected: RGB, tolerance: Int = 8) -> String? {
        let place = "(\(points(point.x)), \(points(point.y)))"
        guard let actual = color(at: point, in: screenshot) else {
            return "No pixel at \(place) in the screenshot"
        }
        guard actual.distance(to: expected) > tolerance else { return nil }
        return "The pixel at \(place) is \(actual), not \(expected) within \(tolerance)"
    }
}

// MARK: - Gestures

extension UITestNavigation {
    /// Swipes the sheet on top down from its top edge to the bottom of the
    /// screen, the way a user flicks it away. Waits up to five seconds for
    /// a sheet that is still sliding up.
    static func swipeSheetDown(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date.now.addingTimeInterval(5)
        var sheet = topSheet(in: app)
        while sheet == nil && Date.now < deadline {
            Thread.sleep(forTimeInterval: 0.25)
            sheet = topSheet(in: app)
        }
        guard let sheet else {
            return XCTFail("No sheet is on screen to swipe down", file: file, line: line)
        }
        let topEdge = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 0, dy: 6))
        let bottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
        topEdge.press(forDuration: 0.05, thenDragTo: bottom, withVelocity: .fast, thenHoldForDuration: 0)
    }

    /// The sheet on top, or nil when none is up. UIKit adds each
    /// presentation to the window as a new layer; a sheet is the view in
    /// the last layer that starts below the top of the screen and reaches
    /// its bottom. A full-screen cover starts at the top, so it is no sheet.
    static func topSheet(in app: XCUIApplication) -> XCUIElement? {
        let window = app.windows.firstMatch
        guard let layer = window.children(matching: .other).allElementsBoundByIndex.last else { return nil }
        let bottom = window.frame.maxY
        return layer.children(matching: .other).allElementsBoundByIndex.first {
            $0.frame.minY > 0.5 && abs($0.frame.maxY - bottom) < 1
        }
    }

    /// Swipes right from the left edge of the screen, the system's back
    /// gesture on a pushed screen. It starts 1pt inside the edge: from
    /// x = 0, the system gesture missed two swipes in three.
    static func swipeBack(in app: XCUIApplication) {
        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: 1, dy: 0))
        let across = app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        edge.press(forDuration: 0.05, thenDragTo: across, withVelocity: .default, thenHoldForDuration: 0)
    }
}
