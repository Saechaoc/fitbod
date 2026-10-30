//
//  HeatmapHitAreaUITests.swift
//  fitbodUITests
//
//  T14, review item 7, on the demo seed's MUSCLE HEATMAP, the last
//  section of Today:
//
//    - Each block draws and takes taps at its exact grid rectangle,
//      inside its FRONT or BACK box, so no two heatmap buttons overlap.
//    - Tapping a block opens that muscle's detail screen, and tapping the
//      decorative NECK opens nothing.
//    - VoiceOver reads each muscle once: on its left block, and on FRONT
//      for Shoulders and Calves, which both figures draw. The element's
//      label is the muscle and its value is the zone. VoiceOver skips the
//      muscle's other blocks and NECK.
//
//  XCUI cannot see the blocks VoiceOver skips, so the tests tap blocks
//  where the grid draws them: 14pt cells in a 140 x 168pt box, 8pt under
//  its FRONT or BACK label.
//

import XCTest

final class HeatmapHitAreaUITests: XCTestCase {

    override func setUpWithError() throws {
        // Every block gets checked, so one failure does not hide the rest.
        continueAfterFailure = true
    }

    // MARK: - Placement

    @MainActor
    func testButtonsSitOnTheirBlocksInsideTheirBoxes() throws {
        let app = openHeatmap()
        UITestNavigation.saveScreenshot("T14", "heatmap")
        let problems = try placementProblems(in: app)
        XCTAssertTrue(problems.isEmpty, problems.joined(separator: "\n"))
    }

    @MainActor
    func testButtonsKeepTheirBlocksAtAX3() throws {
        let app = openHeatmap(textSize: .ax3)
        UITestNavigation.saveScreenshot("T14", "heatmap", textSize: .ax3)
        let problems = try placementProblems(in: app)
        XCTAssertTrue(problems.isEmpty, problems.joined(separator: "\n"))
    }

    // MARK: - Taps

    @MainActor
    func testTappingNeckOpensNothing() throws {
        let app = openHeatmap()
        for side in Side.allCases {
            // While VoiceOver still reads NECK, a tap goes where XCUI finds
            // it; once VoiceOver skips it, where the grid draws it.
            let element = try gridElements(in: app).first { $0.side == side && $0.label == Block.neck.label }
            let point = element?.frame.center ?? Block.neck.frame(in: box(side, in: app)).center
            let opened = muscleOpened(byTapping: point, in: app, screenshot: "neck-tap-\(side.rawValue.lowercased())")
            XCTAssertNil(opened, "Tapping \(side.rawValue) NECK must open nothing, but it opened \(opened ?? "")")
        }
    }

    @MainActor
    func testEachBlockOpensItsOwnMuscle() throws {
        let app = openHeatmap()
        for side in Side.allCases {
            for block in side.blocks {
                guard let muscle = block.muscle else { continue }
                let center = block.frame(in: box(side, in: app)).center
                XCTAssertEqual(
                    muscleOpened(byTapping: center, in: app), muscle,
                    "Tapping the middle of \(side.rawValue) \(block.label) must open \(muscle)"
                )
            }
        }

        // Spots TRI's and the left LAT's 44pt hit boxes used to cover: 3pt
        // inside the left edge of the left LAT and of UPPER BACK.
        let back = box(.back, in: app)
        let leftLat = try XCTUnwrap(Side.back.blocks.first { $0.label == "LAT" }).frame(in: back)
        let upperBack = try XCTUnwrap(Side.back.blocks.first { $0.label == "UPPER BACK" }).frame(in: back)
        XCTAssertEqual(
            muscleOpened(byTapping: CGPoint(x: leftLat.minX + 3, y: leftLat.midY), in: app), "Lats",
            "The left edge of the left LAT must open Lats"
        )
        XCTAssertEqual(
            muscleOpened(byTapping: CGPoint(x: upperBack.minX + 3, y: upperBack.midY), in: app), "Middle Back",
            "The left end of UPPER BACK must open Middle Back"
        )
    }

    // MARK: - VoiceOver

    @MainActor
    func testVoiceOverReadsEachMuscleOnce() throws {
        let app = openHeatmap()
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "T14-heatmap-accessibility-tree"
        tree.lifetime = .keepAlways
        add(tree)
        let elements = try gridElements(in: app)

        // Labels used to read "Chest: <zone>.", so match the name before a colon.
        let chest = elements.filter { element in element.label.prefix { $0 != ":" } == "Chest" }
        XCTAssertEqual(chest.count, 1, "VoiceOver must read Chest once, but the heatmap has \(chest.count) elements for it: \(chest)")

        let neck = elements.filter { $0.label.localizedCaseInsensitiveContains(Block.neck.label) }
        XCTAssertTrue(neck.isEmpty, "VoiceOver must skip the decorative NECK, but it reads \(neck)")

        let spoken = Side.allCases.flatMap { side in side.blocks.filter(\.isSpoken).map { (side: side, block: $0) } }
        XCTAssertEqual(
            elements.map(\.label).sorted(), spoken.compactMap { $0.block.muscle }.sorted(),
            "VoiceOver must read one element per muscle, labeled with the muscle's name: \(elements)"
        )
        for (side, block) in spoken {
            guard let muscle = block.muscle, let element = elements.first(where: { $0.label == muscle }) else { continue }
            XCTAssertTrue(
                element.side == side && element.frame.matches(block.frame(in: element.box)),
                "VoiceOver must read \(muscle) on \(side.rawValue) \(block.label), but reads it at \(element)"
            )
            XCTAssertTrue(element.isButton, "\(muscle) must keep the button trait: \(element)")
            XCTAssertTrue(
                Self.zoneNames.contains { element.value.hasPrefix($0) },
                "\(muscle) must carry its zone as its value, not \"\(element.value)\""
            )
        }
    }
}

// MARK: - Grid

private extension HeatmapHitAreaUITests {
    /// The start of each zone's text, VolumeZone.verb, or "Not trained".
    static let zoneNames = ["Below MEV", "Productive range", "Near MRV", "Over MRV", "Not trained"]

    /// One block of the 10 x 12 grid, per MuscleRegionPaths, and the detail
    /// screen it opens: its muscle's display name, or nil for NECK.
    struct Block {
        let label: String
        let muscle: String?
        let x: Int
        let y: Int
        let width: Int
        let height: Int
        /// True for the one block per muscle that VoiceOver reads.
        let isSpoken: Bool

        init(_ label: String, _ muscle: String?, x: Int, y: Int, w: Int, h: Int, spoken: Bool = false) {
            self.label = label
            self.muscle = muscle
            self.x = x
            self.y = y
            self.width = w
            self.height = h
            self.isSpoken = spoken
        }

        static let neck = Block("NECK", nil, x: 4, y: 0, w: 2, h: 1)

        /// The block on screen: whole cells, less the 1pt gap between
        /// neighbours.
        func frame(in box: CGRect) -> CGRect {
            CGRect(
                x: box.minX + CGFloat(x) * 14,
                y: box.minY + CGFloat(y) * 14,
                width: CGFloat(width) * 14 - 1,
                height: CGFloat(height) * 14 - 1
            )
        }
    }

    enum Side: String, CaseIterable {
        case front = "FRONT"
        case back = "BACK"

        var blocks: [Block] {
            switch self {
            case .front:
                return [
                    .neck,
                    Block("DELT", "Shoulders", x: 1, y: 1, w: 2, h: 1, spoken: true),
                    Block("DELT", "Shoulders", x: 7, y: 1, w: 2, h: 1),
                    Block("CHEST L", "Chest", x: 3, y: 1, w: 2, h: 2, spoken: true),
                    Block("CHEST R", "Chest", x: 5, y: 1, w: 2, h: 2),
                    Block("BICEP", "Biceps", x: 1, y: 2, w: 2, h: 2, spoken: true),
                    Block("BICEP", "Biceps", x: 7, y: 2, w: 2, h: 2),
                    Block("ABS L", "Abdominals", x: 3, y: 3, w: 2, h: 3, spoken: true),
                    Block("ABS R", "Abdominals", x: 5, y: 3, w: 2, h: 3),
                    Block("FORE", "Forearms", x: 1, y: 4, w: 2, h: 2, spoken: true),
                    Block("FORE", "Forearms", x: 7, y: 4, w: 2, h: 2),
                    Block("QUAD", "Quadriceps", x: 3, y: 6, w: 2, h: 3, spoken: true),
                    Block("QUAD", "Quadriceps", x: 5, y: 6, w: 2, h: 3),
                    Block("CALF", "Calves", x: 3, y: 9, w: 2, h: 2, spoken: true),
                    Block("CALF", "Calves", x: 5, y: 9, w: 2, h: 2),
                ]
            case .back:
                return [
                    .neck,
                    Block("TRAPS", "Traps", x: 3, y: 1, w: 4, h: 1, spoken: true),
                    Block("R.DELT", "Shoulders", x: 1, y: 1, w: 2, h: 1),
                    Block("R.DELT", "Shoulders", x: 7, y: 1, w: 2, h: 1),
                    Block("UPPER BACK", "Middle Back", x: 3, y: 2, w: 4, h: 1, spoken: true),
                    Block("LAT", "Lats", x: 1, y: 2, w: 2, h: 3, spoken: true),
                    Block("LAT", "Lats", x: 7, y: 2, w: 2, h: 3),
                    Block("TRI", "Triceps", x: 0, y: 2, w: 1, h: 2, spoken: true),
                    Block("TRI", "Triceps", x: 9, y: 2, w: 1, h: 2),
                    Block("LOWER BACK", "Lower Back", x: 3, y: 5, w: 4, h: 1, spoken: true),
                    Block("GLUTE", "Glutes", x: 3, y: 6, w: 2, h: 2, spoken: true),
                    Block("GLUTE", "Glutes", x: 5, y: 6, w: 2, h: 2),
                    Block("HAM", "Hamstrings", x: 3, y: 8, w: 2, h: 2, spoken: true),
                    Block("HAM", "Hamstrings", x: 5, y: 8, w: 2, h: 2),
                    Block("CALF", "Calves", x: 3, y: 10, w: 2, h: 1),
                    Block("CALF", "Calves", x: 5, y: 10, w: 2, h: 1),
                ]
            }
        }
    }

    /// Every muscle a block opens, which is also each detail screen's title.
    static let muscleNames = Array(Set(Side.allCases.flatMap { $0.blocks.compactMap(\.muscle) }))

    /// A labeled accessibility element that starts inside a grid.
    struct GridElement: CustomStringConvertible {
        let side: Side
        let box: CGRect
        let label: String
        let value: String
        let frame: CGRect
        let isButton: Bool

        /// `FRONT button "Chest" at (42, 14), 27 x 27`, in points from the
        /// top-left corner of its box.
        var description: String {
            let x = Self.points(frame.minX - box.minX)
            let y = Self.points(frame.minY - box.minY)
            let kind = isButton ? "button" : "element"
            return "\(side.rawValue) \(kind) \"\(label)\" at (\(x), \(y)), \(Self.points(frame.width)) x \(Self.points(frame.height))"
        }

        private static func points(_ value: CGFloat) -> String {
            let rounded = (value * 10).rounded() / 10
            return String(format: "%g", rounded == 0 ? 0 : rounded)
        }
    }

    /// The side's 140 x 168pt grid, centred 8pt under its FRONT or BACK label.
    @MainActor
    func box(_ side: Side, in app: XCUIApplication) -> CGRect {
        let label = app.staticTexts[side.rawValue].frame
        return CGRect(x: label.midX - 70, y: label.maxY + 8, width: 140, height: 168)
    }

    /// Launches the demo seed and scrolls Today to its last section, MUSCLE
    /// HEATMAP, until both grids sit above the tab bar.
    @MainActor
    func openHeatmap(textSize: UITestNavigation.TextSize = .default) -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout, textSize: textSize)
        UITestNavigation.reveal(app.staticTexts[Side.back.rawValue], in: app)
        let tabBarTop = UITestNavigation.tab("Today", in: app).frame.minY
        for _ in 0..<5 where box(.back, in: app).maxY > tabBarTop {
            app.swipeUp(velocity: .slow)
        }
        XCTAssertLessThanOrEqual(box(.back, in: app).maxY, tabBarTop, "The heatmap must sit above the tab bar")
        return app
    }

    /// The heatmap's accessibility elements: each outermost labeled element
    /// that starts inside a grid, read in one snapshot of the screen, FRONT
    /// first and top to bottom. VoiceOver does not read an element's
    /// children on their own, so the walk stops at each element it keeps.
    @MainActor
    func gridElements(in app: XCUIApplication) throws -> [GridElement] {
        let boxes = Side.allCases.map { (side: $0, box: box($0, in: app)) }
        var found: [GridElement] = []
        var pending = [try app.snapshot()]
        while let node = pending.popLast() {
            guard !node.label.isEmpty,
                  let grid = boxes.first(where: { $0.box.insetBy(dx: -0.5, dy: -0.5).contains(node.frame.origin) })
            else {
                pending.append(contentsOf: node.children)
                continue
            }
            found.append(GridElement(
                side: grid.side,
                box: grid.box,
                label: node.label,
                value: node.value as? String ?? "",
                frame: node.frame,
                isButton: node.elementType == .button
            ))
        }
        return found.sorted { ($0.side == .front ? 0 : 1, $0.frame.minY, $0.frame.minX) < ($1.side == .front ? 0 : 1, $1.frame.minY, $1.frame.minX) }
    }

    /// Every way the heatmap's buttons miss their blocks: outside their box,
    /// off every block's grid rectangle, or overlapping another button.
    @MainActor
    func placementProblems(in app: XCUIApplication) throws -> [String] {
        let buttons = try gridElements(in: app).filter(\.isButton)
        guard !buttons.isEmpty else { return ["The heatmap shows no buttons"] }
        var problems: [String] = []
        for (index, button) in buttons.enumerated() {
            if !button.box.insetBy(dx: -0.5, dy: -0.5).contains(button.frame) {
                problems.append("\(button) is not inside its \(button.side.rawValue) box")
            }
            if !button.side.blocks.contains(where: { $0.frame(in: button.box).matches(button.frame) }) {
                problems.append("\(button) is not on any block's grid rectangle")
            }
            for other in buttons[(index + 1)...] {
                let shared = button.frame.intersection(other.frame)
                if !shared.isNull, shared.width > 0.5, shared.height > 0.5 {
                    problems.append("\(button) overlaps \(other)")
                }
            }
        }
        return problems
    }

    /// Taps `point` and returns the muscle whose detail screen opens, or nil
    /// when nothing opens, then goes back to Today. `screenshot` names a
    /// capture taken after the tap.
    @MainActor
    func muscleOpened(byTapping point: CGPoint, in app: XCUIApplication, screenshot: String? = nil) -> String? {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point.x, dy: point.y)).tap()
        let back = app.buttons["Back"]
        let opened = back.waitForExistence(timeout: 3)
        if let screenshot {
            UITestNavigation.saveScreenshot("T14", screenshot)
        }
        guard opened else { return nil }
        let title = app.staticTexts.matching(NSPredicate(format: "label IN %@", argumentArray: [Self.muscleNames])).firstMatch
        let muscle = title.waitForExistence(timeout: 3) ? title.label : "a screen with no muscle title"
        back.tap()
        XCTAssertTrue(back.waitForNonExistence(timeout: 10), "Back must return to Today from \(muscle)")
        return muscle
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }

    /// True when both rectangles agree within half a point, which covers
    /// rounding to the screen's pixels.
    func matches(_ other: CGRect) -> Bool {
        abs(minX - other.minX) <= 0.5 && abs(minY - other.minY) <= 0.5
            && abs(width - other.width) <= 0.5 && abs(height - other.height) <= 0.5
    }
}
