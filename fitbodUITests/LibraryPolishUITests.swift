import XCTest

/// Ticket T37, review items 24 and 25. The Library showed a lone section
/// header "3" for "3/4 Sit-Up", and its search placeholder was very faint.
/// On exercise detail, "View all history" ended in an ASCII ">" in the body
/// font in the review snapshot. At AX3 "RECENT PERFORMANCE" broke as
/// "PERFORMANC" over "E": the section head kept its right label beside the
/// title, so the title's longest word no longer fit the width left to it.
///
/// Names that start with a digit or a symbol now share one "#" section
/// after Z, and the placeholder reads at 4.5:1 or more on paper. At
/// accessibility sizes a section head puts its right label under the
/// title. The run sets the phone's appearance with `xcrun simctl ui`.
///
/// Every test and helper is `@MainActor` because `UITestNavigation` is.
final class LibraryPolishUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Library

    /// The empty search field's placeholder reads at 4.5:1 or more against
    /// the paper behind it.
    @MainActor
    func testSearchPlaceholderReadsAgainstPaper() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Library", in: app)
        let search = app.textFields["library.search.browser"]
        XCTAssertTrue(search.waitForExistence(timeout: 10), "The Library must show its search field")
        XCTAssertEqual(search.placeholderValue, "Search exercises")
        UITestNavigation.waitUntilStill(search)
        UITestNavigation.saveScreenshot("T37", "library-search", appearance: appearance)
        // The field's frame is its whole row: the magnifier at its start and
        // the ink rule under it would outweigh the placeholder. So the
        // placeholder's own line is found, and only its right half, all
        // placeholder and paper, is sampled. Nothing has focused the field,
        // so no caret is drawn.
        let screenshot = XCUIScreen.main.screenshot()
        let placeholder = try XCTUnwrap(
            UITestNavigation.textLines(in: search.frame, of: screenshot).first { $0.text.localizedCaseInsensitiveContains("exercises") },
            "The empty search field must show a placeholder that can be read"
        )
        let sample = CGRect(x: placeholder.box.midX, y: placeholder.box.minY - 2,
                            width: placeholder.box.width / 2 + 2, height: placeholder.box.height + 4)
        let contrast = try XCTUnwrap(TextContrast(in: sample, of: screenshot), "The placeholder is not on screen at \(sample)")
        let measured = "The placeholder at \(sample) is \(contrast.glyph) on \(contrast.background) "
            + "in \(appearance) mode: \(String(format: "%.2f", contrast.ratio)):1"
        XCTContext.runActivity(named: "Contrast: \(measured)") { _ in }
        XCTAssertGreaterThanOrEqual(contrast.ratio, 4.5, "\(measured), below 4.5:1")
    }

    /// Searching "3/4" finds 3/4 Sit-Up under "#". "/" also finds four
    /// names that start with a letter, and "#" comes after their sections.
    @MainActor
    func testNamesThatStartWithADigitShareTheHashSectionAfterTheLetters() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Library", in: app)
        let search = app.textFields["library.search.browser"]
        UITestNavigation.type("3/4", into: search, replacing: false)
        XCTAssertTrue(app.staticTexts.labeled("1 match").waitForExistence(timeout: 10), "Searching 3/4 must find one exercise")
        let sitUp = libraryRow("3/4 Sit-Up", in: app)
        XCTAssertTrue(sitUp.exists || sitUp.waitForExistence(timeout: 10), "Searching 3/4 must find 3/4 Sit-Up")
        let header = sectionHeaders(below: search, in: app).last { $0.frame.maxY <= sitUp.frame.minY + 1 }
        XCTAssertEqual(header?.label, "#", "3/4 Sit-Up must sit in the # section")

        // The field's frame spans its row, so a tap at its end would land
        // on × instead of the text: clear with ×, the way a user would.
        app.buttons["Clear search"].tap()
        UITestNavigation.type("/", into: search, replacing: false)
        XCTAssertTrue(app.staticTexts.labeled("5 matches").waitForExistence(timeout: 10), "Searching / must find five exercises")
        let bradford = libraryRow("Bradford/Rocky Presses", in: app)
        XCTAssertTrue(bradford.exists || bradford.waitForExistence(timeout: 10), "Searching / must find Bradford/Rocky Presses")
        UITestNavigation.waitUntilStill(bradford)
        UITestNavigation.saveScreenshot("T37", "library-sections", appearance: appearance)
        XCTAssertEqual(sectionHeaders(below: search, in: app).map(\.label), ["B", "G", "K", "R", "#"],
                       "Each name must sit under its first letter, and # must come after the letters")
    }

    // MARK: - Exercise detail

    /// At default text the RECENT PERFORMANCE head keeps BEST SET beside
    /// its title, as every section head did before T37. VIEW ALL HISTORY
    /// ends in the same chevron, at the same size and in the same color, as
    /// the progress chart row under it.
    @MainActor
    func testHistoryRowEndsInTheNavigationRowChevron() throws {
        let app = openBenchPress()
        let history = navigationRow("View all history", in: app)
        let progress = navigationRow("View progress chart", in: app)
        XCTAssertTrue(history.exists || history.waitForExistence(timeout: 10), "The bench press must offer its history")
        XCTAssertTrue(progress.exists, "The seeded bench press has logged sets, so it must offer its progress chart")
        bringIntoView(history, progress, below: app.buttons["Copy"], in: app)
        UITestNavigation.saveScreenshot("T37", "exercise-detail-history-row", appearance: appearance)

        let title = app.staticTexts.labeled("Recent performance")
        let best = app.staticTexts.labeled("Best set")
        XCTAssertGreaterThan(best.frame.minX, title.frame.maxX,
                             "At default text BEST SET must sit beside the title, but it is at \(best.frame) and the title at \(title.frame)")
        XCTAssertEqual(best.frame.midY, title.frame.midY, accuracy: 2, "At default text BEST SET must sit on the title's row")

        let screenshot = XCUIScreen.main.screenshot()
        let historyChevron = try XCTUnwrap(RowChevron(endOf: history.frame, in: screenshot),
                                           "VIEW ALL HISTORY must end in a chevron")
        let progressChevron = try XCTUnwrap(RowChevron(endOf: progress.frame, in: screenshot),
                                            "VIEW PROGRESS CHART must end in a chevron")
        XCTContext.runActivity(named: "Chevrons: history \(historyChevron), progress chart \(progressChevron)") { _ in }
        XCTAssertTrue(historyChevron.matches(progressChevron),
                      "VIEW ALL HISTORY's chevron, \(historyChevron), must match VIEW PROGRESS CHART's, \(progressChevron)")
    }

    /// At AX3 the RECENT PERFORMANCE head puts BEST SET under its title,
    /// and the title breaks only between its words.
    @MainActor
    func testRecentPerformanceHeadPutsItsLabelUnderTheTitleAtAX3() throws {
        let app = openBenchPress(textSize: .ax3)
        try assertHeadStacks("Recent performance", right: "Best set", below: app.buttons["Copy"],
                             screen: "exercise-detail-recent-performance", in: app)
    }

    /// Section heads on three other screens at AX3: Settings' EXPORT, a
    /// workout summary's EXERCISES and the custom exercise editor's PRIMARY
    /// MUSCLE STIMULUS.
    @MainActor
    func testSectionHeadsOnOtherScreensPutTheirLabelUnderTheTitleAtAX3() throws {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory, textSize: .ax3)

        UITestNavigation.openSettings(in: app)
        let close = app.buttons["Close"]
        try assertHeadStacks("Export", right: "Data", below: close, screen: "settings-export-head", in: app)
        close.tap()

        // The newest seeded workout logged the bench press and the squat.
        tapWhenReady(app.buttons["today.sessions"], in: app)
        tapWhenReady(app.buttons.matching(identifier: "history.row").firstMatch, in: app)
        XCTAssertTrue(app.staticTexts["WORKOUT COMPLETE"].waitForExistence(timeout: 10), "The workout's summary never opened")
        try assertHeadStacks("Exercises", right: "2", below: UITestNavigation.hittable(app.buttons, "Back", exactLabel: true),
                             screen: "workout-summary-exercises-head", in: app)

        UITestNavigation.selectTab("Library", in: app)
        UITestNavigation.hittable(app.buttons, "+ New", exactLabel: true).tap()
        let save = app.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "+ NEW must open the custom exercise editor")
        try assertHeadStacks("Primary muscle stimulus", right: "Required", below: save,
                             above: app.descendants(matching: .any)["customExercise.status"],
                             screen: "custom-exercise-primary-head", in: app)
    }

    // MARK: - Section heads

    /// A section head puts `right` under `title`, clear of it, and the
    /// title breaks only between its words: read off the screen line by
    /// line, it is the title's words, and no line is a lone letter.
    @MainActor
    private func assertHeadStacks(
        _ title: String, right: String, below header: XCUIElement, above footer: XCUIElement? = nil,
        screen: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let titleText = app.staticTexts.labeled(title)
        // Settings builds its rows lazily, so a head below the fold exists
        // only once the page scrolls near it.
        UITestNavigation.reveal(titleText, in: app)
        bringIntoView(titleText, label(right, nearest: titleText, in: app), below: header, above: footer,
                      in: app, file: file, line: line)
        let rightText = label(right, nearest: titleText, in: app)
        UITestNavigation.saveScreenshot("T37", screen, textSize: .ax3, appearance: appearance)

        // Every check runs, so one failure does not hide the rest.
        let under = rightText.frame.minY >= titleText.frame.maxY - 0.5
        let checks: [(name: String, problem: String?)] = [
            ("\(right) clear of the title", UITestNavigation.overlapProblem(titleText, rightText)),
            ("\(right) under the title", under ? nil : "\(right) at \(rightText.frame) is beside the title at \(titleText.frame)"),
            ("the title on screen", UITestNavigation.insideProblem(titleText, app.windows.firstMatch)),
            ("the title breaks only between words", try wordBreakProblem(titleText, reading: title)),
        ]
        for check in checks {
            XCTContext.runActivity(named: "\(title) head: \(check.name): \(check.problem ?? "passes")") { _ in }
        }
        let problems = checks.compactMap { $0.problem }
        if !problems.isEmpty {
            XCTFail("The \(title) head at AX3: " + problems.joined(separator: "; "), file: file, line: line)
        }
    }

    /// Nil when the title, read off the screen line by line, is its words
    /// and no line is a lone letter.
    @MainActor
    private func wordBreakProblem(_ title: XCUIElement, reading text: String) throws -> String? {
        let expected = words(in: text)
        let screenshot = XCUIScreen.main.screenshot()
        var reads: [String] = []
        // Vision misreads some crops, so the title is read from a few
        // margins around its frame. A word broken over two lines reads as
        // two pieces from every one of them.
        for margin in [CGSize.zero, CGSize(width: 6, height: 2), CGSize(width: 12, height: 0)] {
            let lines = try UITestNavigation.textLines(
                in: title.frame.insetBy(dx: -margin.width, dy: -margin.height), of: screenshot
            ).map { words(in: $0.text) }
            reads.append(lines.map { $0.joined(separator: " ") }.joined(separator: " / "))
            if lines.flatMap({ $0 }) == expected && !lines.contains(where: { $0.joined().count < 2 }) { return nil }
        }
        return "the title must break only between its words, with no line a lone letter, but its lines read \(reads)"
    }

    private func words(in text: String) -> [String] {
        text.uppercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    /// The static text reading `text` nearest the bottom left of `title`,
    /// where a section head's right label sits: a screen can show the same
    /// text elsewhere, such as a workout's exercise count.
    @MainActor
    private func label(_ text: String, nearest title: XCUIElement, in app: XCUIApplication) -> XCUIElement {
        let anchor = CGPoint(x: title.frame.minX, y: title.frame.maxY)
        func distance(_ element: XCUIElement) -> CGFloat {
            hypot(element.frame.minX - anchor.x, element.frame.minY - anchor.y)
        }
        let matches = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", text)).allElementsBoundByIndex
        return matches.min { distance($0) < distance($1) } ?? app.staticTexts.labeled(text)
    }

    // MARK: - Navigation

    /// Library > the seeded bench press, whose four logged workouts fill
    /// RECENT PERFORMANCE and offer its progress chart.
    @MainActor
    private func openBenchPress(textSize: UITestNavigation.TextSize? = nil) -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory, textSize: textSize)
        UITestNavigation.selectTab("Library", in: app)
        UITestNavigation.type("Barbell Bench Press", into: app.textFields["library.search.browser"], replacing: false)
        tapWhenReady(libraryRow("Barbell Bench Press - Medium Grip", in: app), in: app)
        XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 10), "The bench press's detail never opened")
        return app
    }

    /// A Library row, which reads its name first.
    @MainActor
    private func libraryRow(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }

    /// The Library's one-character section headers under the search
    /// field, top first.
    @MainActor
    private func sectionHeaders(below search: XCUIElement, in app: XCUIApplication) -> [XCUIElement] {
        let fieldBottom = search.frame.maxY
        return app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^.$")).allElementsBoundByIndex
            .map { (element: $0, top: $0.frame.minY) }
            .filter { $0.top > fieldBottom }
            .sorted { $0.top < $1.top }
            .map(\.element)
    }

    @MainActor
    private func navigationRow(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", title)).firstMatch
    }

    @MainActor
    private func tapWhenReady(_ control: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(control.waitForExistence(timeout: 15), "Missing \(control)", file: file, line: line)
        UITestNavigation.reveal(control, in: app)
        let deadline = Date.now.addingTimeInterval(10)
        // Polls for a push or a sheet that is still settling, in 0.1 s steps.
        while !control.isHittable && Date.now < deadline { Thread.sleep(forTimeInterval: 0.1) }
        control.tap()
    }

    /// Drags the page in its leading margin until `first` and `second` sit
    /// between `header`, the bottom of the screen's fixed top bar, and the
    /// tab bar or `footer`, a bar fixed over the page's bottom, where
    /// nothing covers them. Each drag holds before it lets go, so the page
    /// stops where the drag ends.
    @MainActor
    private func bringIntoView(
        _ first: XCUIElement, _ second: XCUIElement, below header: XCUIElement, above footer: XCUIElement? = nil,
        in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) {
        let ceiling = header.frame.maxY + 8
        let floor = min(tabBarTop(in: app), footer.flatMap { $0.exists ? $0.frame.minY : nil } ?? .infinity) - 8
        for _ in 0..<12 {
            let top = min(first.frame.minY, second.frame.minY)
            let bottom = max(first.frame.maxY, second.frame.maxY)
            if top >= ceiling && bottom <= floor { return }
            let middle = (ceiling + floor) / 2
            let shift = max(-240, min(240, middle - (top + bottom) / 2))
            let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 8, dy: middle))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: shift)),
                        withVelocity: .slow, thenHoldForDuration: 0.3)
            UITestNavigation.waitUntilStill(first)
        }
        XCTFail("\(first.label) and \(second.label) must fit between the top bar and the tab bar", file: file, line: line)
    }

    /// The top of the tab bar, whose tabs sit in one row, or two at AX3.
    @MainActor
    private func tabBarTop(in app: XCUIApplication) -> CGFloat {
        ["Today", "Program", "Progress", "Library"].map { UITestNavigation.tab($0, in: app).frame.minY }.min() ?? app.frame.maxY
    }

    /// The phone's appearance, which the run sets with `xcrun simctl ui`.
    @MainActor
    private var appearance: UITestNavigation.Appearance {
        XCUIDevice.shared.appearance == .dark ? .dark : .light
    }
}

// MARK: - Screenshot readers

/// A text's glyph color and the background behind it, read from a
/// screenshot with `UITestNavigation.pixels(in:of:)`.
private struct TextContrast {
    let glyph: UITestNavigation.RGB
    let background: UITestNavigation.RGB

    /// The WCAG 2 contrast ratio, from 1 to 21.
    var ratio: Double {
        let lighter = max(glyph.relativeLuminance, background.relativeLuminance)
        let darker = min(glyph.relativeLuminance, background.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Reads every pixel in `region`, in screen points. The commonest color
    /// is the background between the glyphs, and the glyph color is the
    /// pixel whose luminance is farthest from it. Nil when `region` is off
    /// the screenshot.
    @MainActor
    init?(in region: CGRect, of screenshot: XCUIScreenshot) {
        guard let bytes = UITestNavigation.pixels(in: region, of: screenshot)?.bytes,
              let background = commonestColor(in: bytes) else { return nil }
        var glyph = background
        for offset in stride(from: 0, to: bytes.count, by: 4) {
            let pixel = UITestNavigation.RGB(red: Int(bytes[offset]), green: Int(bytes[offset + 1]), blue: Int(bytes[offset + 2]))
            if abs(pixel.relativeLuminance - background.relativeLuminance) > abs(glyph.relativeLuminance - background.relativeLuminance) {
                glyph = pixel
            }
        }
        self.glyph = glyph
        self.background = background
    }
}

/// The ink of the chevron at the trailing end of a navigation row, read
/// from the row's last 48pt: its size and its gap to the row's end, in
/// device pixels, and its strongest color. Two rows that draw the same
/// glyph in the same font and color read the same.
private struct RowChevron: CustomStringConvertible {
    let size: CGSize
    let trailingGap: CGFloat
    let color: UITestNavigation.RGB

    /// Nil when the row's end is off the screenshot or holds no ink.
    @MainActor
    init?(endOf row: CGRect, in screenshot: XCUIScreenshot) {
        // Clear of the hairline over the row and the rule under it.
        let region = CGRect(x: row.maxX - 48, y: row.minY + 3, width: 48, height: row.height - 6)
        guard let cut = UITestNavigation.pixels(in: region, of: screenshot),
              let background = commonestColor(in: cut.bytes) else { return nil }
        let width = Int(cut.frame.width)
        var ink: CGRect?
        var color = background
        for offset in stride(from: 0, to: cut.bytes.count, by: 4) {
            let pixel = UITestNavigation.RGB(
                red: Int(cut.bytes[offset]), green: Int(cut.bytes[offset + 1]), blue: Int(cut.bytes[offset + 2])
            )
            let distance = pixel.distance(to: background)
            // Anti-aliased edges fade into the paper; the glyph's core does not.
            guard distance > 48 else { continue }
            let index = offset / 4
            let dot = CGRect(x: index % width, y: index / width, width: 1, height: 1)
            ink = ink.map { $0.union(dot) } ?? dot
            if distance > color.distance(to: background) { color = pixel }
        }
        guard let ink else { return nil }
        self.size = ink.size
        self.trailingGap = CGFloat(width) - ink.maxX
        self.color = color
    }

    func matches(_ other: RowChevron) -> Bool {
        abs(size.width - other.size.width) <= 2 && abs(size.height - other.size.height) <= 2
            && abs(trailingGap - other.trailingGap) <= 2 && color.distance(to: other.color) <= 16
    }

    var description: String {
        "\(Int(size.width)) x \(Int(size.height))px, \(Int(trailingGap))px from the row's end, \(color)"
    }
}

/// The commonest color in sRGB bytes, four to a pixel.
private func commonestColor(in bytes: [UInt8]) -> UITestNavigation.RGB? {
    var counts: [UInt32: Int] = [:]
    for offset in stride(from: 0, to: bytes.count, by: 4) {
        counts[UInt32(bytes[offset]) << 16 | UInt32(bytes[offset + 1]) << 8 | UInt32(bytes[offset + 2]), default: 0] += 1
    }
    return counts.max { $0.value < $1.value }.map { UITestNavigation.RGB(hex: $0.key) }
}

private extension UITestNavigation.RGB {
    /// WCAG 2 relative luminance, from 0 for black to 1 for white.
    var relativeLuminance: Double {
        func linear(_ channel: Int) -> Double {
            let value = Double(channel) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}
