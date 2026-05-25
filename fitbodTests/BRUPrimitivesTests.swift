// BRUPrimitivesTests.swift
// fitbodTests
//
// Swift Testing suite for Phase 04.1-01 BRU primitive components.
//
// Strategy:
//   1. Call-shape compile checks: `_ = <Primitive>(...)` — if an init signature or
//      default-argument contract changes, this won't compile. Covers the 04.1 interface
//      contracts from 02-UI-SPEC.md lines 510-525.
//   2. File-text source-anchor checks: load each primitive's .swift source file and
//      assert BRU token identifiers are present (Color.bruInk, BRUFont.labelSmall, etc.)
//      and forbidden shape identifiers are absent (RoundedRectangle, Capsule, Circle in code).
//      Matches the precedent set by Phase 6 SessionLoggerCopyTests + RoutineBuilderCopyTests.
//   3. allPrimitivesAvoidForbiddenShapes: aggregates the forbidden-shape check across all 10.
//
// Run via:
//   xcodebuild test -scheme fitbod -only-testing:fitbodTests/BRUPrimitivesTests

import Foundation
import SwiftUI
import Testing
@testable import fitbod

// MARK: - BRUPrimitivesTests

@Suite("BRUPrimitives", .serialized)
@MainActor
struct BRUPrimitivesTests {

    // MARK: - Path Helper

    /// Computes the absolute path to a source file under fitbod/Design/ relative
    /// to this test file's location.
    ///
    /// Layout:
    ///   fitbodTests/BRUPrimitivesTests.swift   ← #filePath
    ///   fitbod/Design/<Primitive>.swift         ← target
    ///
    /// We go up one level from fitbodTests/ → project root, then into fitbod/Design/.
    private func designFilePath(for name: String) -> URL {
        let thisFile = URL(fileURLWithPath: #filePath)
        let projectRoot = thisFile
            .deletingLastPathComponent() // fitbodTests/
            .deletingLastPathComponent() // project root
        return projectRoot
            .appendingPathComponent("fitbod")
            .appendingPathComponent("Design")
            .appendingPathComponent("\(name).swift")
    }

    private func loadSource(for name: String) throws -> String {
        let url = designFilePath(for: name)
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - Task 1: BRUChip call-shape + source-anchor

    @Test("bruChipCallShapeCompiles — 04.1 interface contract")
    func bruChipCallShapeCompiles() throws {
        // Init shape from 02-UI-SPEC.md line 510:
        //   BRUChip(_ label: String, color: Color? = nil, fill: Bool = false, textCase: Text.Case? = .uppercase)
        _ = BRUChip("LINEAR")
        _ = BRUChip("ACTIVE", color: .bruSignal, fill: true)
        _ = BRUChip("Compound", textCase: nil)

        // Source-anchor: verify the implementation references BRU tokens
        let source = try loadSource(for: "BRUChip")
        #expect(source.contains("Color.bruInk"),
                "BRUChip.swift must reference Color.bruInk for outline/fill color")
        #expect(source.contains("BRUFont.labelSmall"),
                "BRUChip.swift must reference BRUFont.labelSmall for chip text")
        #expect(source.contains(".tracking("),
                "BRUChip.swift must apply .tracking() for 1.2 letterspacing")
        #expect(!source.contains("RoundedRectangle("),
                "BRUChip.swift must NOT use RoundedRectangle — sharp-cornered Rectangle only")
        #expect(!source.contains("Capsule()"),
                "BRUChip.swift must NOT use Capsule() — sharp-cornered Rectangle only")
    }

    // MARK: - Task 2: BRUHeaderBar call-shape + source-anchor

    @Test("bruHeaderBarCallShapeCompiles — 04.1 HeaderSlot interface contract")
    func bruHeaderBarCallShapeCompiles() throws {
        // Legacy HeaderAction init (all pre-04.1 callers continue to work)
        _ = BRUHeaderBar(center: "Today")
        _ = BRUHeaderBar(left: HeaderAction("‹") {}, center: "Edit")

        // Phase 04.1 HeaderSlot init per 02-UI-SPEC.md line 511:
        //   BRUHeaderBar(left: HeaderSlot? = nil, center: String? = nil, right: HeaderSlot? = nil)
        _ = BRUHeaderBar(left: .back, center: "Block · Upper Hyp", right: .action("EDIT") {})
        _ = BRUHeaderBar(left: .cancel, center: "Add Phase")
        _ = BRUHeaderBar(left: .none, center: "Title", right: .text("INFO"))

        let source = try loadSource(for: "BRUHeaderBar")
        #expect(source.contains("Color.bruPaper"),
                "BRUHeaderBar.swift must reference Color.bruPaper for background")
        #expect(source.contains("Color.bruInk"),
                "BRUHeaderBar.swift must reference Color.bruInk for text and border")
        #expect(source.contains("BRUFont.labelSmall"),
                "BRUHeaderBar.swift must reference BRUFont.labelSmall for slot text")
        #expect(source.contains("HeaderSlot"),
                "BRUHeaderBar.swift must declare the HeaderSlot enum for 04.1 API")
    }

    // MARK: - Task 3: BRUSectionHead call-shape + source-anchor

    @Test("bruSectionHeadCallShapeCompiles — 04.1 rightAction interface contract")
    func bruSectionHeadCallShapeCompiles() throws {
        // Init shape from 02-UI-SPEC.md line 512:
        //   BRUSectionHead(_ title: String, right: String? = nil, rightAction: (() -> Void)? = nil)
        _ = BRUSectionHead("Lift list")
        _ = BRUSectionHead("Past sessions", right: "14 sessions")
        _ = BRUSectionHead("Phases", right: "+ ADD PHASE", rightAction: {})

        let source = try loadSource(for: "BRUSectionHead")
        #expect(source.contains("Color.bruInk"),
                "BRUSectionHead.swift must reference Color.bruInk for title text")
        #expect(source.contains("Color.bruSignal"),
                "BRUSectionHead.swift must reference Color.bruSignal for tappable right action")
        #expect(source.contains("BRUFont.labelSmall"),
                "BRUSectionHead.swift must reference BRUFont.labelSmall for right label")
        #expect(source.contains("rightAction"),
                "BRUSectionHead.swift must declare rightAction parameter for 04.1 tappable-right contract")
    }

    // MARK: - Task 4: BRUButton call-shape + source-anchor

    @Test("bruButtonCallShapeCompiles — three Kind variants")
    func bruButtonCallShapeCompiles() throws {
        // Init shape from 02-UI-SPEC.md line 513:
        //   BRUButton(_ kind: Kind = .primary, _ label: String, action: @escaping () -> Void)
        // Existing shape: BRUButton(_ label: String, kind: Kind = .primary, size: Size = .md, action:)
        _ = BRUButton("Apply changes ▸", kind: .primary) {}
        _ = BRUButton("Start next ▸", kind: .signal) {}
        _ = BRUButton("Plan custom", kind: .ghost) {}

        let source = try loadSource(for: "BRUButton")
        #expect(source.contains("Color.bruInk"),
                "BRUButton.swift must reference Color.bruInk for .primary fill and .ghost border")
        #expect(source.contains("Color.bruSignal"),
                "BRUButton.swift must reference Color.bruSignal for .signal fill")
        #expect(source.contains("Color.bruPaper"),
                "BRUButton.swift must reference Color.bruPaper for text on filled kinds")
        #expect(source.contains("BRUFont.labelSmall"),
                "BRUButton.swift must reference BRUFont.labelSmall for button text")
        #expect(!source.contains("RoundedRectangle("),
                "BRUButton.swift must NOT use RoundedRectangle — sharp 0-radius corners only")
    }

    // MARK: - Task 5: BRUDivider call-shape + source-anchor

    @Test("bruDividerCallShapeCompiles — hair and ink weights")
    func bruDividerCallShapeCompiles() throws {
        // Init shape from 02-UI-SPEC.md line 514:
        //   BRUDivider(_ weight: Weight)
        _ = BRUDivider(.hair)
        _ = BRUDivider(.ink)
        _ = BRUDivider()  // default is .hair

        let source = try loadSource(for: "BRUDivider")
        #expect(source.contains("Color.bruHair") || source.contains(".bruHair"),
                "BRUDivider.swift must reference bruHair color for .hair weight")
        #expect(source.contains("Color.bruInk") || source.contains(".bruInk"),
                "BRUDivider.swift must reference bruInk color for .ink weight")
        #expect(source.contains("Rectangle()"),
                "BRUDivider.swift must use Rectangle() — not Capsule/RoundedRectangle")
    }

    // MARK: - Task 6: BRUDashedSlot call-shape + source-anchor

    @Test("bruDashedSlotCallShapeCompiles — 04.1 positional init contract")
    func bruDashedSlotCallShapeCompiles() throws {
        // 04.1 positional init from 02-UI-SPEC.md line 515:
        //   BRUDashedSlot(_ caption: String, action: (() -> Void)? = nil)
        _ = BRUDashedSlot("+ ADD PHASE")
        _ = BRUDashedSlot("+ ADD PHASE") {}

        // Legacy labeled init still works
        _ = BRUDashedSlot(label: "Add exercise", hint: "↘ FROM LIBRARY") {}

        let source = try loadSource(for: "BRUDashedSlot")
        #expect(source.contains("Color.bruInk") || source.contains(".bruInk"),
                "BRUDashedSlot.swift must reference bruInk for dashed border color")
        #expect(source.contains("StrokeStyle"),
                "BRUDashedSlot.swift must use StrokeStyle for dashed border rendering")
        #expect(source.contains(".tracking("),
                "BRUDashedSlot.swift must apply .tracking() for letterspacing")
        #expect(!source.contains("RoundedRectangle("),
                "BRUDashedSlot.swift must NOT use RoundedRectangle")
    }

    // MARK: - Task 7: BRUPillButton call-shape + source-anchor

    @Test("bruPillButtonCallShapeCompiles — 04.1 fill param contract")
    func bruPillButtonCallShapeCompiles() throws {
        // 04.1 init from 02-UI-SPEC.md line 522:
        //   BRUPillButton(_ label: String, fill: Color = .bruSignal, action: @escaping () -> Void)
        _ = BRUPillButton("DISMISS") {}
        _ = BRUPillButton("Start next ▸", fill: .bruSignal) {}
        _ = BRUPillButton("Apply changes ▸", fill: .bruInk) {}

        let source = try loadSource(for: "BRUPillButton")
        #expect(source.contains("Color.bruPaper") || source.contains(".bruPaper"),
                "BRUPillButton.swift must reference bruPaper for text color")
        #expect(source.contains("BRUFont.labelSmall"),
                "BRUPillButton.swift must reference BRUFont.labelSmall for button text")
        #expect(source.contains(".tracking("),
                "BRUPillButton.swift must apply .tracking() for letterspacing")
        #expect(!source.contains("Capsule()"),
                "BRUPillButton.swift must NOT use Capsule() — rectangular shape only")
    }

    // MARK: - Task 8: BRUDisplay call-shape + source-anchor

    @Test("bruDisplayCallShapeCompiles — Size typealias + default size contract")
    func bruDisplayCallShapeCompiles() throws {
        // 04.1 init from 02-UI-SPEC.md line 512:
        //   BRUDisplay(_ value: String, size: Size = .large, color: Color = .bruInk)
        _ = BRUDisplay("142")                                  // default size (.large)
        _ = BRUDisplay("142", size: .hero, color: .bruPaper)
        _ = BRUDisplay("12", size: .medium)

        // BRUDisplay.Size typealias for BRUDisplaySize must be accessible
        let heroSize: BRUDisplay.Size = .hero
        let largeSize: BRUDisplay.Size = .large
        let mediumSize: BRUDisplay.Size = .medium
        #expect(heroSize.pointSize == 56, "BRUDisplay.Size.hero must be 56pt")
        #expect(largeSize.pointSize == 32, "BRUDisplay.Size.large must be 32pt")
        #expect(mediumSize.pointSize == 18, "BRUDisplay.Size.medium must be 18pt")

        let source = try loadSource(for: "BRUDisplay")
        #expect(source.contains("typealias Size"),
                "BRUDisplay.swift must declare `typealias Size = BRUDisplaySize` for 04.1 contract")
        #expect(source.contains("SpaceGrotesk-Bold"),
                "BRUDisplay.swift must use SpaceGrotesk-Bold font per BRU type scale")
    }

    // MARK: - Task 9: BRUReadout call-shape + source-anchor

    @Test("bruReadoutCallShapeCompiles — size param contract")
    func bruReadoutCallShapeCompiles() throws {
        // 04.1 init from 02-UI-SPEC.md line 516:
        //   BRUReadout(label: String, value: String, valueColor: Color = .bruInk, size: BRUDisplay.Size = .medium)
        _ = BRUReadout(label: "SESSIONS", value: "12")
        _ = BRUReadout(label: "SESSIONS", value: "12", valueColor: .bruSignal)
        _ = BRUReadout(label: "TOTAL", value: "142", valueColor: .bruInk, size: .large)
        _ = BRUReadout(label: "SESSIONS", value: "12", size: .medium)

        let source = try loadSource(for: "BRUReadout")
        #expect(source.contains("Color.bruMuted") || source.contains(".bruMuted"),
                "BRUReadout.swift must reference bruMuted for label caption color")
        #expect(source.contains("BRUFont.labelSmall"),
                "BRUReadout.swift must reference BRUFont.labelSmall for the micro caption")
        #expect(source.contains(".tracking("),
                "BRUReadout.swift must apply .tracking() for letterspacing")
        #expect(source.contains("size"),
                "BRUReadout.swift must store/reference the size parameter for BRUDisplay.Size contract")
    }

    // MARK: - Task 10: BRUCornerBadge call-shape + source-anchor

    @Test("bruCornerBadgeCallShapeCompiles — fill param contract")
    func bruCornerBadgeCallShapeCompiles() throws {
        // 04.1 init from 02-UI-SPEC.md line 524:
        //   BRUCornerBadge(_ label: String, fill: Color = .bruSignal)
        _ = BRUCornerBadge("PR")
        _ = BRUCornerBadge("DL", fill: .bruSignal)
        _ = BRUCornerBadge("STR", fill: .bruInk)

        let source = try loadSource(for: "BRUCornerBadge")
        #expect(source.contains("Color.bruPaper") || source.contains(".bruPaper"),
                "BRUCornerBadge.swift must reference bruPaper for text color")
        #expect(source.contains("Color.bruSignal") || source.contains(".bruSignal"),
                "BRUCornerBadge.swift must reference bruSignal as default fill color")
        #expect(source.contains(".textCase(.uppercase)") || source.contains("textCase(.uppercase)"),
                "BRUCornerBadge.swift must apply uppercase text transform")
        #expect(!source.contains("RoundedRectangle("),
                "BRUCornerBadge.swift must NOT use RoundedRectangle — fill badge is rectangular")
    }

    // MARK: - Task 11: allPrimitivesAvoidForbiddenShapes

    @Test("allPrimitivesAvoidForbiddenShapes — no RoundedRectangle/Capsule/Circle in body code")
    func allPrimitivesAvoidForbiddenShapes() throws {
        let primitiveNames = [
            "BRUChip", "BRUHeaderBar", "BRUSectionHead", "BRUButton",
            "BRUDivider", "BRUDashedSlot", "BRUPillButton", "BRUDisplay",
            "BRUReadout", "BRUCornerBadge",
        ]

        // Patterns that indicate forbidden shapes in actual code (not comments).
        // We strip comment lines before checking to avoid false positives from
        // documentation like "// BRU contract: NO Capsule() / NO RoundedRectangle".
        let forbiddenPatterns = ["RoundedRectangle(", "Capsule()", "Circle()"]

        for name in primitiveNames {
            let source = try loadSource(for: name)

            // Strip single-line comments (// ...) to avoid comment false positives.
            // This is a conservative check — multi-line /* */ comments are rare in these files.
            let codeLines = source.split(separator: "\n", omittingEmptySubsequences: false)
                .filter { line in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    return !trimmed.hasPrefix("//")
                }
            let codeOnly = codeLines.joined(separator: "\n")

            for pattern in forbiddenPatterns {
                #expect(!codeOnly.contains(pattern),
                        "\(name).swift contains forbidden shape '\(pattern)' in code — BRU contract requires Rectangle() only")
            }
        }
    }
}
