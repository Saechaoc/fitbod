import Vision
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
        case xl
        case xxl
        case xxxl
        case ax3

        /// The content size launch argument: Large, the default; extra
        /// large, extra extra large and extra extra extra large, the sizes
        /// between it and the accessibility sizes; or accessibility extra
        /// large, which is AX3.
        var launchArguments: [String] {
            let category = switch self {
            case .default: "L"
            case .xl: "XL"
            case .xxl: "XXL"
            case .xxxl: "XXXL"
            case .ax3: "AccessibilityXL"
            }
            return ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategory\(category)"]
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
        XCTAssertTrue(appears(tab("Today", in: app), within: 90), "The tab bar never appeared", file: file, line: line)
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
        XCTAssertTrue(appears(tab("Today", in: app), within: 90), "The tab bar never appeared", file: file, line: line)
    }

    /// What the DEBUG app reports about its store on this launch: "fresh",
    /// or "not fresh: " and the reason.
    static func storeFreshness(in app: XCUIApplication) -> String {
        let signal = app.otherElements["debug.resetSignal"]
        guard appears(signal, within: 10) else {
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
        XCTAssertTrue(appears(cell, within: 90), "Missing tab: \(name)")
        cell.tap()
        XCTAssertTrue(waitUntil(timeout: 5) { cell.isSelected }, "Tab not selected: \(name)")
    }

    static func openSettings(in app: XCUIApplication) {
        selectTab("Today", in: app)
        let settings = app.buttons["Settings"]
        XCTAssertTrue(appears(settings))
        settings.tap()
        XCTAssertTrue(appears(app.buttons["Close"]))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label ==[c] %@", "Settings"
        )).firstMatch.exists)
    }

    static func reveal(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 12) {
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable { return }
            swipeUp(in: app)
        }
        XCTAssertTrue(element.exists && element.isHittable, "Expected a visible control: \(element)")
    }

    /// Swipes slowly up on the last scroll view a user can tap, which is
    /// the one on top, or on the app when there is none.
    private static func swipeUp(in app: XCUIApplication) {
        if let scroll = app.scrollViews.allElementsBoundByIndex.last(where: { $0.isHittable }) {
            scroll.swipeUp(velocity: .slow)
        } else {
            app.swipeUp(velocity: .slow)
        }
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

    /// The phone this test runs on, named from the screen's width the way
    /// `saveScreenshot` names it: "small", "large", or the width, such as
    /// "402pt", on any other phone.
    static var phone: String {
        phoneName(width: XCUIScreen.main.screenshot().image.size.width)
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
        let scale = screenshot.image.scale
        let pixel = CGRect(x: (point.x * scale).rounded(.down), y: (point.y * scale).rounded(.down), width: 1, height: 1)
        guard let cut = crop(pixel, of: screenshot), let bytes = sRGBBytes(of: cut.image) else { return nil }
        return RGB(red: Int(bytes[0]), green: Int(bytes[1]), blue: Int(bytes[2]))
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

// MARK: - Screenshot readers

extension UITestNavigation {
    /// The pixels of `rect`, in screen points, cut from a full-screen
    /// screenshot: where they lie in its device pixels, and their sRGB
    /// bytes, four to a pixel, row by row from the top. Nil when `rect` is
    /// off the screenshot.
    static func pixels(in rect: CGRect, of screenshot: XCUIScreenshot) -> (frame: CGRect, bytes: [UInt8])? {
        guard let cut = crop(devicePixels(of: rect, in: screenshot), of: screenshot),
              let bytes = sRGBBytes(of: cut.image) else { return nil }
        return (cut.frame, bytes)
    }

    /// The lines of text drawn inside `rect`, in screen points, read from
    /// the top, each with the box around it in screen points. Read narrow,
    /// single-line crops: on the simulator, Vision's accurate level dropped
    /// whole words from a 390 x 60pt crop (F282).
    static func textLines(in rect: CGRect, of screenshot: XCUIScreenshot) throws -> [(text: String, box: CGRect)] {
        let cut = try XCTUnwrap(crop(devicePixels(of: rect, in: screenshot), of: screenshot),
                                "Cannot crop \(rect) from the screenshot")
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: cut.image).perform([request])
        let scale = screenshot.image.scale
        let frame = CGRect(x: cut.frame.minX / scale, y: cut.frame.minY / scale,
                           width: cut.frame.width / scale, height: cut.frame.height / scale)
        // Vision's boxes are fractions of the crop, from its bottom left:
        // higher lines first, then left to right.
        return (request.results ?? [])
            .sorted { ($0.boundingBox.midY, -$0.boundingBox.minX) > ($1.boundingBox.midY, -$1.boundingBox.minX) }
            .compactMap { observation in
                guard let text = observation.topCandidates(1).first?.string else { return nil }
                let box = observation.boundingBox
                return (text, CGRect(
                    x: frame.minX + box.minX * frame.width, y: frame.minY + (1 - box.maxY) * frame.height,
                    width: box.width * frame.width, height: box.height * frame.height
                ))
            }
    }

    /// The text drawn inside `rect`, in screen points, read line by line
    /// from the top.
    static func readText(in rect: CGRect, of screenshot: XCUIScreenshot) throws -> String {
        try textLines(in: rect, of: screenshot).map(\.text).joined(separator: " ")
    }

    /// The device pixels that cover `rect`, in screen points.
    private static func devicePixels(of rect: CGRect, in screenshot: XCUIScreenshot) -> CGRect {
        let scale = screenshot.image.scale
        return CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale)
            .integral
    }

    /// The part of the screenshot inside `pixels`, in device pixels, and
    /// where that part lies. Nil when no pixel of `pixels` is on it.
    private static func crop(_ pixels: CGRect, of screenshot: XCUIScreenshot) -> (image: CGImage, frame: CGRect)? {
        guard let image = screenshot.image.cgImage else { return nil }
        let frame = pixels.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard !frame.isEmpty, let cut = image.cropping(to: frame) else { return nil }
        return (cut, frame)
    }

    /// `image`'s sRGB bytes, four to a pixel, row by row from the top.
    private static func sRGBBytes(of image: CGImage) -> [UInt8]? {
        guard let sRGB = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        return drawn ? bytes : nil
    }
}

// MARK: - Gestures

extension UITestNavigation {
    /// Swipes the sheet on top down from its header to the bottom of the
    /// screen, the way a user flicks it away. The drag starts 24pt inside the
    /// sheet and at least 70pt from the top of the screen: from the sheet's
    /// very top edge, just below the 390pt phone's status bar, iOS once
    /// dragged a notification banner into Notification Center instead (T101).
    /// Waits up to five seconds for a sheet that is still sliding up.
    static func swipeSheetDown(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date.now.addingTimeInterval(5)
        var sheet = topSheet(in: app)
        while sheet == nil && Date.now < deadline {
            // Polls for a sheet that is still sliding up, in 0.1 s steps.
            Thread.sleep(forTimeInterval: 0.1)
            sheet = topSheet(in: app)
        }
        guard let sheet else {
            return XCTFail("No sheet is on screen to swipe down", file: file, line: line)
        }
        let frame = sheet.frame
        let header = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.midX, dy: max(frame.minY + sheetHeaderDepth, clearOfStatusBar)))
        let bottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
        header.press(forDuration: 0.05, thenDragTo: bottom, withVelocity: .fast, thenHoldForDuration: 0)
    }

    /// How far into a sheet `swipeSheetDown` starts its drag: inside a BRU
    /// sheet's 44pt header row.
    private static let sheetHeaderDepth: CGFloat = 24

    /// How far from the top of the screen the drag starts at least: below
    /// both phones' status bars, where iOS pulls down Notification Center.
    private static let clearOfStatusBar: CGFloat = 70

    /// The sheet on top, or nil when none is up. UIKit adds each
    /// presentation to the window as a new layer; a sheet is the view in
    /// the last layer that starts below the top of the screen and reaches
    /// its bottom, or floats just above it, as a half-height sheet does on
    /// iOS 26 and later. A full-screen cover starts at the top, so it is no
    /// sheet.
    static func topSheet(in app: XCUIApplication) -> XCUIElement? {
        let window = app.windows.firstMatch
        guard let layer = window.children(matching: .other).allElementsBoundByIndex.last else { return nil }
        let bottom = window.frame.maxY
        return layer.children(matching: .other).allElementsBoundByIndex.first {
            let gap = bottom - $0.frame.maxY
            return $0.frame.minY > 0.5 && gap > -1 && gap < floatingSheetGap + 1
        }
    }

    /// How far a half-height sheet floats above the bottom of the screen on
    /// iOS 26 and later.
    private static let floatingSheetGap: CGFloat = 8

    /// Swipes right from the left edge of the screen, the system's back
    /// gesture on a pushed screen. It starts 1pt inside the edge: from
    /// x = 0, the system gesture missed two swipes in three.
    static func swipeBack(in app: XCUIApplication) {
        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: 1, dy: 0))
        let across = app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        edge.press(forDuration: 0.05, thenDragTo: across, withVelocity: .default, thenHoldForDuration: 0)
    }
}

// MARK: - Controls

extension UITestNavigation {
    /// The match a user can tap: a sheet or a dialog leaves same-named
    /// controls under it. A label matches in any case, and so does a label
    /// that goes on after a comma, the way a row reads its texts, such as
    /// "Live Routine, 1 session", unless `exactLabel` is true.
    @discardableResult
    static func hittable(
        _ query: XCUIElementQuery, _ label: String, exactLabel: Bool = false,
        file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement {
        let predicate = exactLabel
            ? NSPredicate(format: "label ==[c] %@", label)
            : NSPredicate(format: "label ==[c] %@ OR label BEGINSWITH[c] %@", label, label + ",")
        let matches = query.matching(predicate)
        XCTAssertTrue(matches.firstMatch.exists || matches.firstMatch.waitForExistence(timeout: 10),
                      "Missing \(label)", file: file, line: line)
        var match: XCUIElement?
        waitUntil(timeout: 5) {
            match = matches.allElementsBoundByIndex.first { $0.isHittable }
            return match != nil
        }
        if let match { return match }
        XCTFail("No tappable \(label)", file: file, line: line)
        return matches.firstMatch
    }

    /// Waits until a push, a sheet or a scroll stops moving `element`: its
    /// frame holds for one `interval`. It gives up after `timeout` seconds.
    static func waitUntilStill(_ element: XCUIElement, interval: TimeInterval = 0.25, timeout: TimeInterval = 5) {
        var last = element.frame
        var stillSince = Date.now
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            // The poll step the test guide asks for (2.6); the frame must
            // still hold for the whole interval.
            Thread.sleep(forTimeInterval: 0.05)
            let frame = element.frame
            if frame != last {
                last = frame
                stillSince = Date.now
            } else if Date.now.timeIntervalSince(stillSince) >= interval {
                return
            }
        }
    }

    /// Polls `condition` every 100 ms until it holds or `timeout`, a
    /// ceiling, runs out, and returns whether it held.
    @discardableResult
    static func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while !condition() {
            guard Date.now < deadline else { return false }
            // The poll step the test guide asks for (2.6).
            Thread.sleep(forTimeInterval: 0.1)
        }
        return true
    }

    /// True when `element` is there now or appears within `timeout`, a
    /// ceiling. It reads `exists` at once, then every 100 ms: a satisfied
    /// `waitForExistence` still costs about a second before its first
    /// check (guide 2.6 and 3.1).
    @discardableResult
    static func appears(_ element: XCUIElement, within timeout: TimeInterval = 10) -> Bool {
        waitUntil(timeout: timeout) { element.exists }
    }

    /// True when `element` is gone now or leaves within `timeout`, a
    /// ceiling, read the same way.
    @discardableResult
    static func disappears(_ element: XCUIElement, within timeout: TimeInterval = 10) -> Bool {
        waitUntil(timeout: timeout) { !element.exists }
    }

    /// Types `text` once the field has keyboard focus, because `typeText`
    /// can drop the first character, and checks that the field holds it.
    /// By default it replaces the field's text, with a tap near the trailing
    /// edge so the cursor lands after any text already there, then presses
    /// return to put the keyboard away. With `replacing` false it taps the
    /// field and types after its text. A number goes through
    /// `enter(_:into:)` instead, which types over it the way a user does.
    static func type(
        _ text: String, into field: XCUIElement, replacing: Bool = true, pressingReturn: Bool = true,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(field.exists || field.waitForExistence(timeout: 10), "Missing \(field)", file: file, line: line)
        if replacing {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        } else {
            field.tap()
        }
        assertKeyboardFocus(field, file: file, line: line)
        // An empty field reports its placeholder as its value.
        if replacing, let current = field.value as? String, !current.isEmpty, current != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(pressingReturn ? text + "\n" : text)
        let value = field.value as? String ?? ""
        XCTAssertEqual(value == field.placeholderValue ? "" : value, text,
                       "The field must hold the typed text", file: file, line: line)
    }
}

// MARK: - Number entry

extension UITestNavigation {
    /// Types `text` the way a user does (T39): one tap on the field once it
    /// stops moving, a wait until it has keyboard focus, then the keys, with
    /// nothing deleted first. A number field selects its whole value as it
    /// takes focus, so the first digit replaces the value rather than
    /// joining it (review item 5). Returns the field's value for the caller
    /// to check; a set's weight reads with its unit, such as "90 lb".
    @discardableResult
    static func enter(_ text: String, into field: XCUIElement, file: StaticString = #filePath, line: UInt = #line) -> String {
        XCTAssertTrue(field.exists || field.waitForExistence(timeout: 10), "Missing \(field)", file: file, line: line)
        // A tap on a field that is still scrolling only stops the scroll.
        waitUntilStill(field)
        // The center is the text area: a search field's frame spans its
        // row, and its trailing end is the clear button (F293).
        field.tap()
        assertKeyboardFocus(field, file: file, line: line)
        field.typeText(text)
        return field.value as? String ?? ""
    }

    /// Fails unless `field` takes keyboard focus within five seconds.
    static func assertKeyboardFocus(_ field: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        // XCUI reads keyboard focus only through a predicate.
        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        XCTAssertTrue(waitUntil { focused.evaluate(with: field) }, "\(field) never took keyboard focus", file: file, line: line)
    }

    /// The DONE that every screen with a number field shows on the
    /// keyboard, since a number pad has no return key.
    static func keyboardDone(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let done = app.buttons.matching(NSPredicate(format: "label == %@", "DONE")).firstMatch
        XCTAssertTrue(done.exists || done.waitForExistence(timeout: 5), "The keyboard must show DONE", file: file, line: line)
        return done
    }

    /// Fails unless `field` lies above the keyboard and above each of `bars`
    /// on screen, such as a save bar, and clear of the keyboard's DONE, so
    /// the lifter can see what they type. DONE floats on a clear bar above
    /// the keyboard, so a field beside it stays in sight.
    static func assertAboveKeyboard(
        _ field: XCUIElement, and bars: [XCUIElement] = [], in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(field.exists, "Missing \(field)", file: file, line: line)
        XCTAssertTrue(keyboard.exists || keyboard.waitForExistence(timeout: 5), "The keyboard must be up", file: file, line: line)
        // The field scrolls into place once the keyboard has shown.
        waitUntilStill(keyboard)
        waitUntilStill(field)
        // The keyboard's panel starts above its keys.
        let panel = app.otherElements["inputView"]
        for cover in [panel.exists ? panel : keyboard] + bars.filter(\.exists) {
            XCTAssertLessThanOrEqual(field.frame.maxY, cover.frame.minY + 0.5,
                                     "\(describe(field)) must sit above \(describe(cover))", file: file, line: line)
        }
        // DONE's glass reaches about 6pt past its frame.
        let done = keyboardDone(in: app, file: file, line: line)
        XCTAssertFalse(field.frame.intersects(done.frame.insetBy(dx: -6, dy: -6)),
                       "\(describe(done)) must not cover \(describe(field))", file: file, line: line)
    }
}

// MARK: - Block builder

extension UITestNavigation {
    /// How `revealAboveBottomBar(_:in:scroll:)` moves a block builder's page.
    enum PageScroll {
        /// Swipes the page up.
        case swipeUp
        /// Drags the page up or down in its leading margin, clear of the
        /// phase cards' swipe gesture, until the element also sits 20pt
        /// below New Block's title, and lets it settle after each drag.
        case dragInMargin
    }

    /// Scrolls a block builder until a tappable `label` sits above its
    /// bottom bar, which covers the end of the scroll view, and returns
    /// that match. A sheet leaves the screen under it in the tree, so only
    /// a tappable match counts.
    @discardableResult
    static func revealAboveBottomBar(
        _ query: XCUIElementQuery, _ label: String, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement {
        let barTop = bottomBarTop(in: app, file: file, line: line)
        let matches = query.matching(NSPredicate(format: "label ==[c] %@", label))
        for _ in 0..<8 {
            if let match = matches.allElementsBoundByIndex.first(where: { $0.isHittable && $0.frame.maxY < barTop }) {
                return match
            }
            swipeUp(in: app)
        }
        XCTFail("\(label) must scroll above the bottom bar", file: file, line: line)
        return matches.firstMatch
    }

    /// Scrolls a block builder until `element` sits above its bottom bar,
    /// which covers the end of the scroll view, where a tap reaches the bar.
    static func revealAboveBottomBar(
        _ element: XCUIElement, in app: XCUIApplication, scroll: PageScroll = .swipeUp,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let barTop = bottomBarTop(in: app, file: file, line: line)
        switch scroll {
        case .swipeUp:
            for _ in 0..<8 {
                if element.exists && element.isHittable && element.frame.maxY < barTop { return }
                swipeUp(in: app)
            }
            XCTAssertLessThan(element.frame.maxY, barTop, "\(element) must scroll above the bottom bar", file: file, line: line)
        case .dragInMargin:
            let pageTop = app.staticTexts.labeled("NEW BLOCK").frame.maxY + 20
            let window = app.windows.firstMatch
            for _ in 0..<8 {
                let frame = element.frame
                if frame.minY >= pageTop && frame.maxY <= barTop { return }
                let distance = frame.maxY > barTop ? -(frame.maxY - barTop + 80) : pageTop - frame.minY + 80
                let start = window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 8, dy: (pageTop + barTop) / 2))
                let end = start.withOffset(CGVector(dx: 0, dy: max(-300, min(300, distance))))
                start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
                waitUntilStill(element)
            }
            XCTFail("\(element) must scroll between New Block's bars", file: file, line: line)
        }
    }

    /// The top of a block builder's bottom bar. The bar's 52pt buttons sit
    /// 24pt below its top edge, and CANCEL's frame is its text.
    private static func bottomBarTop(in app: XCUIApplication, file: StaticString, line: UInt) -> CGFloat {
        hittable(app.buttons, "Cancel", file: file, line: line).frame.midY - 50
    }
}

// MARK: - Workout logger

extension UITestNavigation {
    /// Scrolls the logger until `element` sits between the fixed workout
    /// header and the keyboard's DONE bar or the rest dock, where a user
    /// can see and tap it. XCUITest calls rows under the header hittable,
    /// so a tap there would land on the header.
    static func revealInLogger(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<12 {
            let (top, bottom) = loggerSpan(in: app)
            if element.frame.minY >= top && element.frame.maxY <= bottom { return }
            let delta = (top + bottom) / 2 - element.frame.midY
            let startY = delta > 0 ? top + 20 : bottom - 20
            dragLogger(from: startY, to: min(bottom - 20, max(top + 20, startY + delta)), in: app)
        }
        XCTFail("Could not scroll \(element) into view", file: file, line: line)
    }

    /// The logger's visible span, in screen points: below the fixed workout
    /// header, above the keyboard's DONE bar or the rest dock.
    static func loggerSpan(in app: XCUIApplication) -> (top: CGFloat, bottom: CGFloat) {
        let header = app.otherElements["workout.header"].firstMatch
        let top = (header.exists ? header.frame.maxY : 0) + 8
        let keyboard = app.keyboards.firstMatch
        // The DONE bar sits on top of the number pad.
        var bottom = keyboard.exists ? keyboard.frame.minY - 66 : app.frame.maxY - 24
        let dock = app.descendants(matching: .any).matching(identifier: "rest.status").firstMatch
        if !keyboard.exists && dock.exists {
            bottom = min(bottom, dock.frame.minY - 16)
        }
        return (top, bottom)
    }

    /// A slow drag down the logger in the rows' trailing margin, clear of
    /// their controls: at AX3 a field spans the row, and a drag that starts
    /// on it does not scroll the list.
    static func dragLogger(from startY: CGFloat, to endY: CGFloat, in app: XCUIApplication) {
        let x = app.frame.width - 8
        let origin = app.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: x, dy: startY)).press(
            forDuration: 0.1,
            thenDragTo: origin.withOffset(CGVector(dx: x, dy: endY)),
            withVelocity: .slow,
            thenHoldForDuration: 0.2
        )
    }
}
