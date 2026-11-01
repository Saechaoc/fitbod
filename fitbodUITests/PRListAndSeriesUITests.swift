//
//  PRListAndSeriesUITests.swift
//  fitbodUITests
//
//  T13, review items 31 and 32, on ProgressHistorySeed's four finished
//  workouts of the bench press and the squat:
//
//    - The PR list shows a set once per bucket, names its exercise,
//      lists at most three sets per exercise, and renders every bucket it
//      heads, including 7-10 reps.
//    - Each chart chip plots its own series. Tapping TOP SET, then E1RM,
//      then VOLUME, then AVG RPE changes what the chart reads each time;
//      VOLUME reads the first workout's 2,140, AVG RPE reads its mean RPE,
//      and each chip's legend names the lines it draws.
//
//  The PR list is lazy, so the test reads it one screen at a time and
//  places each row under the bucket header above it.
//

import XCTest

extension UITestNavigation {
    /// A fresh store plus four finished workouts of two exercises (see
    /// ProgressHistorySeed).
    static let progressHistory = [resetFlag, "-fitbod-seed-progress-history"]

    /// `text` in capitals, with each Cyrillic capital that Vision reads for
    /// its Latin twin, such as "К" in "BACК", read as that Latin capital.
    static func latin(_ text: String) -> String {
        let twins: [Character: Character] = [
            "А": "A", "В": "B", "Е": "E", "К": "K", "М": "M", "Н": "H", "О": "O", "Р": "P", "С": "C", "Т": "T", "Х": "X",
        ]
        return String(text.uppercased().map { twins[$0] ?? $0 })
    }
}

final class PRListAndSeriesUITests: XCTestCase {
    private let exerciseNames = ["Barbell Bench Press - Medium Grip", "Barbell Squat"]

    override func setUpWithError() throws {
        // Every bucket and chip gets checked, so one failure does not hide the rest.
        continueAfterFailure = true
    }

    // MARK: - PR list

    @MainActor
    func testPRListShowsDistinctNamedSetsInEveryBucket() throws {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory)
        UITestNavigation.selectTab("Progress", in: app)
        let records = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Personal Records")).firstMatch
        UITestNavigation.reveal(records, in: app)
        records.tap()

        let buckets = try readPRList(in: app)
        XCTAssertFalse(buckets.isEmpty, "The PR list shows no buckets")

        for bucket in buckets {
            let name = "\(bucket.section) \(bucket.header)"
            XCTAssertFalse(bucket.rows.isEmpty, "\(name) shows its header but no rows")

            let repeated = Dictionary(grouping: bucket.rows, by: setKey).filter { $0.value.count > 1 }.keys
            XCTAssertTrue(repeated.isEmpty, "\(name) lists the same set more than once: \(repeated.sorted())")

            let unnamed = bucket.rows.filter { row in !exerciseNames.contains { row.contains($0) } }
            XCTAssertTrue(
                unnamed.isEmpty,
                "\(name): \(unnamed.count) of \(bucket.rows.count) rows show no exercise name, such as \"\(unnamed.first ?? "")\""
            )

            for exercise in exerciseNames {
                let count = bucket.rows.filter { $0.contains(exercise) }.count
                XCTAssertLessThanOrEqual(count, 3, "\(name) lists \(count) sets of \(exercise)")
            }
        }

        let weightHypertrophy = buckets.first { $0.section == "Weight" && $0.header == "7–10 REPS" }
        XCTAssertFalse(weightHypertrophy?.rows.isEmpty ?? true, "Weight 7–10 REPS has no rows")
        XCTAssertEqual(buckets.count, 11, "Each section should head every bucket its sets fall in: \(buckets.map { "\($0.section) \($0.header)" })")

        // One list ranked by weight across both exercises, three sets each:
        // the squat's 140 x 5 and the bench's lighter sets drop out.
        let weightStrength = buckets.first { $0.section == "Weight" && $0.header == "1–6 REPS" }
        XCTAssertEqual(weightStrength?.rows.map(setKey), [
            "Barbell Squat, Weight PR, 160 lb × 3",
            "Barbell Squat, Weight PR, 150 lb × 3",
            "Barbell Squat, Weight PR, 145 lb × 4",
            "Barbell Bench Press - Medium Grip, Weight PR, 107.5 lb × 2",
            "Barbell Bench Press - Medium Grip, Weight PR, 105 lb × 3",
            "Barbell Bench Press - Medium Grip, Weight PR, 102.5 lb × 4",
        ])
    }

    // MARK: - Chart chips

    @MainActor
    func testChipsPlotTheirOwnSeries() throws {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory)
        UITestNavigation.selectTab("Progress", in: app)
        let bench = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Barbell Bench Press")).firstMatch
        UITestNavigation.reveal(bench, in: app)
        bench.tap()
        XCTAssertTrue(UITestNavigation.appears(app.buttons["e1RM"]), "The progress chart never opened")

        var readout = chartReadout(in: app)
        XCTAssertFalse(readout.isEmpty, "The chart reads nothing before any chip is tapped")
        var readouts: [String: String] = [:]
        let intents = ["HYPERTROPHY · 2 SESSIONS", "STRENGTH · 2 SESSIONS"]
        let chips: [(chip: String, legend: [String])] = [
            ("TOP SET", ["TOP SET"]),
            ("e1RM", ["TOP SET", "ALL-SET AVG"]),
            ("VOLUME", intents),
            ("AVG RPE", intents),
        ]
        for (chip, legend) in chips {
            let button = app.buttons[chip]
            button.tap()
            let next = chartReadout(in: app, changingFrom: readout)
            XCTAssertNotEqual(next, readout, "Tapping \(chip) left the chart reading the same:\n\(next)")
            XCTAssertTrue(button.isSelected, "\(chip) is not the selected chip after a tap")
            XCTAssertEqual(legendKeys(in: app), legend, "\(chip)'s legend must name the lines it draws")
            readouts[chip] = next
            readout = next
        }

        let volume = readouts["VOLUME"] ?? ""
        XCTAssertTrue(volume.contains("2,140"), "VOLUME should read the first workout's 2,140:\n\(volume)")
        let rpe = readouts["AVG RPE"] ?? ""
        XCTAssertTrue(rpe.contains("RPE 7.6"), "AVG RPE should read the first workout's mean RPE, 7.6:\n\(rpe)")
    }

    // MARK: - Chart readout

    /// The legend's keys under the chart, left to right, uppercased.
    @MainActor
    private func legendKeys(in app: XCUIApplication) -> [String] {
        let key = /(top set|all-set avg|hypertrophy · \d+ sessions|strength · \d+ sessions)/.ignoresCase()
        return app.staticTexts.allElementsBoundByIndex
            .filter { (try? key.wholeMatch(in: $0.label)) != nil }
            .sorted { $0.frame.minX < $1.frame.minX }
            .map { $0.label.uppercased() }
    }

    /// What the chart says to VoiceOver: the label and value of each
    /// element inside it that has a value, in order.
    @MainActor
    private func chartReadout(in app: XCUIApplication) -> String {
        let screen = app.scrollViews.containing(NSPredicate(format: "label == %@", "e1RM")).firstMatch
        guard let snapshot = try? screen.snapshot() else { return "" }
        var lines: [String] = []
        func walk(_ node: XCUIElementSnapshot) {
            let value = node.value as? String ?? ""
            if node.elementType == .other, !value.isEmpty, !node.label.contains("scroll bar") {
                lines.append("\(node.label): \(value)")
            }
            node.children.forEach(walk)
        }
        walk(snapshot)
        return lines.joined(separator: "\n")
    }

    /// The chart's readout once it differs from `old`, or after three
    /// seconds without a change.
    @MainActor
    private func chartReadout(in app: XCUIApplication, changingFrom old: String) -> String {
        let deadline = Date.now.addingTimeInterval(3)
        var current = chartReadout(in: app)
        while current == old && Date.now < deadline {
            // The poll step the test guide asks for (2.6).
            Thread.sleep(forTimeInterval: 0.1)
            current = chartReadout(in: app)
        }
        // Lets the chart's short transition settle, so the last read is
        // the settled one.
        Thread.sleep(forTimeInterval: 0.4)
        return chartReadout(in: app)
    }

    // MARK: - PR list reader

    private struct Bucket {
        let section: String
        let header: String
        var rows: [String]
    }

    private enum ItemKind {
        case section, header, row
    }

    /// One element of the PR list at its position in the list's content.
    private struct Item {
        let kind: ItemKind
        let label: String
        let y: CGFloat
    }

    private static let sectionNames: Set<String> = ["Weight", "Reps", "Volume", "e1RM"]
    private static let headerNames: Set<String> = ["1–6 REPS", "7–10 REPS", "11+ REPS"]

    /// A row's set: its label without the RPE, so one set logged at two
    /// RPEs still counts as one set.
    private func setKey(_ row: String) -> String {
        row.replacing(/,? @? ?RPE [0-9.]+/, with: "")
    }

    /// Reads every bucket of the PR list, top to bottom, scrolling a screen
    /// at a time.
    @MainActor
    private func readPRList(in app: XCUIApplication) throws -> [Bucket] {
        // The lazy list drops rows far off screen, so the list is found by
        // its first section head once, then used as the screen's scroll view.
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts["Weight"]), "The PR list never appeared")
        let list = app.scrollViews.firstMatch
        var items: [Item] = []
        var offset: CGFloat = 0
        var previous = try visibleItems(in: list)
        merge(previous, offset: offset, into: &items)
        for _ in 2...30 {
            let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
            let end = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.4)
            let current = try visibleItems(in: list)
            let moved = distance(from: previous, to: current)
            guard moved > 1 else { break }
            offset += moved
            merge(current, offset: offset, into: &items)
            previous = current
        }

        var buckets: [Bucket] = []
        var section = ""
        for item in items.sorted(by: { $0.y < $1.y }) {
            switch item.kind {
            case .section:
                section = item.label
            case .header:
                buckets.append(Bucket(section: section, header: item.label, rows: []))
            case .row:
                guard !buckets.isEmpty else {
                    XCTFail("A row sits above every bucket header: \(item.label)")
                    continue
                }
                buckets[buckets.count - 1].rows.append(item.label)
            }
        }
        return buckets
    }

    /// Section heads, bucket headers and rows inside the list, with their
    /// frames on screen. A row is one button; its texts are not read apart.
    @MainActor
    private func visibleItems(in list: XCUIElement) throws -> [(kind: ItemKind, label: String, frame: CGRect)] {
        var found: [(kind: ItemKind, label: String, frame: CGRect)] = []
        func walk(_ node: XCUIElementSnapshot) {
            if node.elementType == .button {
                found.append((.row, node.label, node.frame))
                return
            }
            if node.elementType == .staticText {
                if Self.sectionNames.contains(node.label) { found.append((.section, node.label, node.frame)) }
                if Self.headerNames.contains(node.label) { found.append((.header, node.label, node.frame)) }
            }
            node.children.forEach(walk)
        }
        walk(try list.snapshot())
        return found
    }

    /// How far the content moved up between two reads: the median shift of
    /// the elements whose kind and label appear once in both.
    private func distance(
        from old: [(kind: ItemKind, label: String, frame: CGRect)],
        to new: [(kind: ItemKind, label: String, frame: CGRect)]
    ) -> CGFloat {
        func once(_ items: [(kind: ItemKind, label: String, frame: CGRect)]) -> [String: CGFloat] {
            let grouped = Dictionary(grouping: items) { "\($0.kind)|\($0.label)" }
            return grouped.compactMapValues { $0.count == 1 ? $0[0].frame.minY : nil }
        }
        let before = once(old)
        let after = once(new)
        let shifts = before.compactMap { key, y in after[key].map { y - $0 } }.sorted()
        guard !shifts.isEmpty else { return 0 }
        return shifts[shifts.count / 2]
    }

    /// Adds the elements of one read that are not already in `items`. The
    /// same element is the same kind and label within 8pt of its position.
    private func merge(
        _ visible: [(kind: ItemKind, label: String, frame: CGRect)],
        offset: CGFloat,
        into items: inout [Item]
    ) {
        for element in visible {
            let y = element.frame.minY + offset
            let known = items.contains { $0.kind == element.kind && $0.label == element.label && abs($0.y - y) < 8 }
            if !known {
                items.append(Item(kind: element.kind, label: element.label, y: y))
            }
        }
    }
}
