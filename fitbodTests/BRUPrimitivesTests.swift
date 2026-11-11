// BRUPrimitivesTests.swift
// fitbodTests
//
// Call-shape compile checks for the Phase 04.1-01 BRU primitives: if an init
// signature or default argument changes, this file stops compiling. The banned
// shapes and tokens are SwiftLint rules (.swiftlint.yml), not tests.
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

    // MARK: - Task 1: BRUChip call shape

    @Test("bruChipCallShapeCompiles — 04.1 interface contract")
    func bruChipCallShapeCompiles() throws {
        // Init shape from 02-UI-SPEC.md line 510:
        //   BRUChip(_ label: String, color: Color? = nil, fill: Bool = false, textCase: Text.Case? = .uppercase)
        _ = BRUChip("LINEAR")
        _ = BRUChip("ACTIVE", color: .bruSignal, fill: true)
        _ = BRUChip("Compound", textCase: nil)
    }

    // MARK: - Task 2: BRUHeaderBar call shape

    @Test("bruHeaderBarCallShapeCompiles — 04.1 HeaderSlot interface contract")
    func bruHeaderBarCallShapeCompiles() throws {
        // Legacy HeaderAction init (all pre-04.1 callers continue to work)
        _ = BRUHeaderBar(center: "Today")
        _ = BRUHeaderBar(left: HeaderAction("‹") {}, center: "Edit")

        // Phase 04.1 HeaderSlot factory per 02-UI-SPEC.md line 511:
        //   BRUHeaderBar.slots(left: HeaderSlot? = nil, center: String? = nil, right: HeaderSlot? = nil)
        // Factory avoids Swift overload ambiguity with the legacy HeaderAction? init.
        _ = BRUHeaderBar.slots(left: .back, center: "Block · Upper Hyp", right: .action("EDIT") {})
        _ = BRUHeaderBar.slots(left: .cancel, center: "Add Phase")
        _ = BRUHeaderBar.slots(left: .empty, center: "Title", right: .text("INFO"))
    }

    // MARK: - Task 3: BRUSectionHead call shape

    @Test("bruSectionHeadCallShapeCompiles — 04.1 rightAction interface contract")
    func bruSectionHeadCallShapeCompiles() throws {
        // Init shape from 02-UI-SPEC.md line 512:
        //   BRUSectionHead(_ title: String, right: String? = nil, rightAction: (() -> Void)? = nil)
        _ = BRUSectionHead("Lift list")
        _ = BRUSectionHead("Past sessions", right: "14 sessions")
        _ = BRUSectionHead("Phases", right: "+ ADD PHASE", rightAction: {})
    }

    // MARK: - Task 4: BRUButton call shape

    @Test("bruButtonCallShapeCompiles — three Kind variants")
    func bruButtonCallShapeCompiles() throws {
        // Init shape from 02-UI-SPEC.md line 513:
        //   BRUButton(_ kind: Kind = .primary, _ label: String, action: @escaping () -> Void)
        // Existing shape: BRUButton(_ label: String, kind: Kind = .primary, size: Size = .md, action:)
        _ = BRUButton("Apply changes ▸", kind: .primary) {}
        _ = BRUButton("Start next ▸", kind: .signal) {}
        _ = BRUButton("Plan custom", kind: .ghost) {}
    }

    // MARK: - Task 5: BRUDivider call shape

    @Test("bruDividerCallShapeCompiles — hair and ink weights")
    func bruDividerCallShapeCompiles() throws {
        // Init shape from 02-UI-SPEC.md line 514:
        //   BRUDivider(_ weight: Weight)
        _ = BRUDivider(.hair)
        _ = BRUDivider(.ink)
        _ = BRUDivider()  // default is .hair
    }

    // MARK: - Task 6: BRUDashedSlot call shape

    @Test("bruDashedSlotCallShapeCompiles — 04.1 positional init contract")
    func bruDashedSlotCallShapeCompiles() throws {
        // 04.1 positional init from 02-UI-SPEC.md line 515:
        //   BRUDashedSlot(_ caption: String, action: (() -> Void)? = nil)
        _ = BRUDashedSlot("+ ADD PHASE")
        _ = BRUDashedSlot("+ ADD PHASE") {}

        // Legacy labeled init still works
        _ = BRUDashedSlot(label: "Add exercise", hint: "↘ FROM LIBRARY") {}
    }

    // MARK: - Task 7: BRUPillButton call shape

    @Test("bruPillButtonCallShapeCompiles — 04.1 fill param contract")
    func bruPillButtonCallShapeCompiles() throws {
        // 04.1 init from 02-UI-SPEC.md line 522:
        //   BRUPillButton(_ label: String, fill: Color = .bruSignal, action: @escaping () -> Void)
        _ = BRUPillButton("DISMISS") {}
        _ = BRUPillButton("Start next ▸", fill: .bruSignal) {}
        _ = BRUPillButton("Apply changes ▸", fill: .bruInk) {}
    }

    // MARK: - Task 8: BRUDisplay call shape

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
    }

    // MARK: - Task 9: BRUReadout call shape

    @Test("bruReadoutCallShapeCompiles — size param contract")
    func bruReadoutCallShapeCompiles() throws {
        // 04.1 init from 02-UI-SPEC.md line 516:
        //   BRUReadout(label: String, value: String, valueColor: Color = .bruInk, size: BRUDisplay.Size = .medium)
        _ = BRUReadout(label: "SESSIONS", value: "12")
        _ = BRUReadout(label: "SESSIONS", value: "12", valueColor: .bruSignal)
        _ = BRUReadout(label: "TOTAL", value: "142", valueColor: .bruInk, size: .large)
        _ = BRUReadout(label: "SESSIONS", value: "12", size: .medium)
    }

    // MARK: - Task 10: BRUCornerBadge call shape

    @Test("bruCornerBadgeCallShapeCompiles — fill param contract")
    func bruCornerBadgeCallShapeCompiles() throws {
        // 04.1 init from 02-UI-SPEC.md line 524:
        //   BRUCornerBadge(_ label: String, fill: Color = .bruSignal)
        _ = BRUCornerBadge("PR")
        _ = BRUCornerBadge("DL", fill: .bruSignal)
        _ = BRUCornerBadge("STR", fill: .bruInk)
    }
}
