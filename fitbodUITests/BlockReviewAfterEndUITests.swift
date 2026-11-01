import XCTest

/// Ticket T99, finding F142. The block review's hero counts the sets that
/// set a PR during the block.
final class BlockReviewAfterEndUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - T99

    /// F142: PRS showed a dash over "COMING IN PHASE 6". The seeded block's
    /// one workout logged the lifter's first bench sets, all 100 x 5, so
    /// only the first set a PR. At default text the three stats keep their
    /// row, each label whole on one line.
    @MainActor
    func testHeroCountsTheBlocksPRs() throws {
        let app = openEndedBlocksReview()
        let prs = heroStat("prs", in: app)
        UITestNavigation.waitUntilStill(prs)
        UITestNavigation.saveScreenshot("T99", "review-hero")

        var problems = heroStatLayoutProblems(in: app, stacked: false)
        problems += try heroStatLabelProblems(in: app)
        let shown = prs.staticTexts.allElementsBoundByIndex.map(\.label)
        if shown != ["PRS", "1", "THIS BLOCK"] {
            problems.append("The PRS stat reads \(shown), not [\"PRS\", \"1\", \"THIS BLOCK\"]")
        }
        XCTAssertTrue(problems.isEmpty, problems.joined(separator: "\n"))
    }

    // MARK: - Helpers

    /// The review's header title.
    @MainActor
    private func reviewTitle(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.labeled("Block review")
    }

    /// The review of the seeded block, numbered 1 and complete, is up and
    /// its actions can be tapped.
    @MainActor
    private func assertReviewOpens(
        in app: XCUIApplication, _ message: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(reviewTitle(in: app).waitForExistence(timeout: 10), message, file: file, line: line)
        let complete = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "BLOCK 1 · COMPLETE"))
        XCTAssertTrue(complete.firstMatch.exists, "The review must be the ended block's", file: file, line: line)
        XCTAssertTrue(app.staticTexts.labeled("Live Block").exists, "The review must name the ended block",
                      file: file, line: line)
        UITestNavigation.hittable(app.buttons, "Plan custom", file: file, line: line)
        UITestNavigation.hittable(app.buttons, "Start next ▸", file: file, line: line)
    }

    /// The review's bottom bar with Plan custom and Start next.
    @MainActor
    private func actionBar(in app: XCUIApplication) -> XCUIElement {
        app.otherElements["blockReview.actionBar"]
    }

    /// The review's scroll view, which ends where the action bar starts.
    @MainActor
    private func reviewScrollView(in app: XCUIApplication) -> XCUIElement {
        app.scrollViews.containing(NSPredicate(format: "identifier == %@", "blockReview.recommendedNext")).firstMatch
    }

    /// Uppercased letters and digits only. Vision reads Space Grotesk's
    /// lowercase "y" as "u" and can read a mono "O" as "0", so each pair
    /// counts as one letter.
    private static func letters(_ text: String) -> String {
        String(text.uppercased().filter { $0.isLetter || $0.isNumber }.map { character -> Character in
            switch character {
            case "0": "O"
            case "Y": "U"
            default: character
            }
        })
    }

    // MARK: - T99 helpers

    /// Launches on Program with Live Block ended after one finished Live
    /// Push workout last week (T87's seed, or the variant `arguments`
    /// names), waits until the seed has ended the block, then makes the
    /// first visit to Today, which opens the block's review.
    @MainActor
    private func openEndedBlocksReview(
        _ arguments: [String]? = nil,
        textSize: UITestNavigation.TextSize = .default, file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIApplication {
        let app = UITestNavigation.launch(
            arguments ?? UITestNavigation.endedBlockWithRecap, textSize: textSize, file: file, line: line
        )
        XCTAssertTrue(app.buttons.labeled("DONE block: Live Block").waitForExistence(timeout: 30),
                      "The seed must end Live Block before Today's first visit", file: file, line: line)
        UITestNavigation.selectTab("Today", in: app)
        assertReviewOpens(in: app, "Today's first visit after the block ended must open its review", file: file, line: line)
        return app
    }

    /// The hero's stats, by name.
    private static let heroStatNames = ["sessions", "tonnage", "prs"]

    /// One of the hero's stats: its label, value and sub-label.
    @MainActor
    private func heroStat(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.otherElements["blockReview.stat.\(name)"]
    }

    /// Each hero stat out of place. At accessibility sizes each stat sits
    /// under the one before it; at default text each sits to its right, in
    /// the same row. No stat overlaps another or runs off the screen's sides.
    @MainActor
    private func heroStatLayoutProblems(in app: XCUIApplication, stacked: Bool) -> [String] {
        let stats = Self.heroStatNames.map { heroStat($0, in: app) }
        guard stats.allSatisfy(\.exists) else { return ["The hero must show its SESSIONS, TONNAGE and PRS stats"] }
        let screen = app.frame
        var problems: [String] = []
        for (name, stat) in zip(Self.heroStatNames, stats) {
            let frame = stat.frame
            if frame.minX < screen.minX - 0.5 || frame.maxX > screen.maxX + 0.5 {
                problems.append("The \(name) stat spans x \(frame.minX) to \(frame.maxX), past the \(screen.width)pt screen")
            }
        }
        for index in stats.indices.dropFirst() {
            let (before, stat) = (stats[index - 1], stats[index])
            let (beforeName, name) = (Self.heroStatNames[index - 1], Self.heroStatNames[index])
            if let overlap = UITestNavigation.overlapProblem(before, stat) {
                problems.append(overlap)
            }
            let (above, frame) = (before.frame, stat.frame)
            if stacked && frame.minY < above.maxY - 0.5 {
                problems.append("The \(name) stat starts at y \(frame.minY), not under the \(beforeName) stat, which ends at y \(above.maxY)")
            }
            if !stacked && (frame.minX < above.maxX - 0.5 || frame.minY >= above.maxY || frame.maxY <= above.minY) {
                problems.append("The \(name) stat at \(frame) is not beside the \(beforeName) stat at \(above), in its row")
            }
        }
        return problems
    }

    /// Each stat label or sub-label that is not whole on one line, read from
    /// the screen once its stat is in view. XCUI reads the whole label
    /// however the text wraps. Every label shares one font, so one taller
    /// than the shortest by half a line wraps; Vision can read spaces into
    /// tracked capitals, so the shown text is compared by its letters.
    @MainActor
    private func heroStatLabelProblems(in app: XCUIApplication) throws -> [String] {
        let stats = Self.heroStatNames.map { heroStat($0, in: app) }
        // The values are numbers; the labels are the texts with letters.
        let labels = stats.map { stat in
            stat.staticTexts.allElementsBoundByIndex.filter { $0.label.contains(where: \.isLetter) }
        }
        guard let oneLine = labels.joined().map(\.frame.height).min() else {
            return ["The hero's stats show no labels"]
        }
        var problems: [String] = []
        for (stat, statLabels) in zip(stats, labels) {
            scrollIntoView(stat, in: app)
            let screenshot = XCUIScreen.main.screenshot()
            for label in statLabels {
                let frame = label.frame
                if frame.height > oneLine * 1.5 {
                    problems.append("The stat label \"\(label.label)\" is \(frame.height)pt tall, more than one \(oneLine)pt line")
                }
                let shown = try UITestNavigation.readText(in: frame.insetBy(dx: -4, dy: -2), of: screenshot)
                if Self.letters(shown) != Self.letters(label.label) {
                    problems.append("The stat label \"\(label.label)\" reads \"\(shown)\" on the screen")
                }
            }
        }
        return problems
    }

    /// Drags the review until `element` lies whole in its scroll view,
    /// above the action bar, the way a lifter scrolls to it, or gives up.
    /// Each drag moves the page by the distance the element lies outside
    /// that span, at most 300pt, in the scroll view's trailing margin, and
    /// holds at its end so the page does not coast on: a slow swipe moved
    /// about 510pt, past a span that can be narrower than that.
    @MainActor
    private func scrollIntoView(_ element: XCUIElement, in app: XCUIApplication) {
        let scroll = reviewScrollView(in: app)
        for _ in 0..<6 {
            let visible = scroll.frame.insetBy(dx: -0.5, dy: -0.5)
            let frame = element.frame
            if visible.contains(frame) && frame.maxY <= actionBar(in: app).frame.minY + 0.5 { return }
            let bottom = min(visible.maxY, actionBar(in: app).frame.minY)
            // Positive drags the page down, to bring back an element above it.
            let distance = frame.minY < visible.minY ? visible.minY + 8 - frame.minY : bottom - 8 - frame.maxY
            let startY = distance > 0 ? visible.minY + 20 : bottom - 20
            let x = scroll.frame.maxX - 8
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: x, dy: startY)).press(
                forDuration: 0.1,
                thenDragTo: origin.withOffset(CGVector(dx: x, dy: startY + max(-300, min(300, distance)))),
                withVelocity: .slow,
                thenHoldForDuration: 0.2
            )
            UITestNavigation.waitUntilStill(element)
        }
    }
}

extension UITestNavigation {
    /// A fresh store with Live Block ended, its review due, and one workout
    /// last week, so this week's recap is due too (ActiveBlockSeed). Program
    /// opens first, because on a fresh store Today can show before the seed.
    static let endedBlockWithRecap = [resetFlag, "-fitbod-seed-ended-block-recap", "-fitbod-start-program"]
}
