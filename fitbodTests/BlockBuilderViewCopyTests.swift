//
//  BlockBuilderViewCopyTests.swift
//  fitbodTests
//
//  Verbatim-copy anchors for UI-SPEC § BlockBuilderView strings.
//

import Foundation
import Testing
@testable import fitbod

@Suite("BlockBuilderViewCopy")
struct BlockBuilderViewCopyTests {
    @Test("verbatim copy strings are present in source")
    func verbatimCopyStringsArePresentInSource() throws {
        let base = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fitbod/Periodization")

        let builder = try String(
            contentsOf: base.appendingPathComponent("BlockBuilderView.swift"),
            encoding: .utf8
        )
        #expect(builder.contains("\"New Block\""))
        #expect(builder.contains("\"Block name\""))
        #expect(builder.contains("\"e.g. Powerlifting Peak Q3\""))
        #expect(builder.contains("\"Start date\""))
        #expect(builder.contains("\"Active block\""))
        #expect(builder.contains("\"Only one block can be active at a time. Activating this block deactivates any other.\""))
        #expect(builder.contains("\"Phases\""))
        #expect(builder.contains("\"+ Phase\""))
        #expect(builder.contains("\"Add a phase to define your mesocycle.\""))
        #expect(builder.contains("\"Total: \\(draft.totalWeeks) weeks across \\(draft.phases.count) phases.\""))
        #expect(builder.contains("\"Block name is required.\""))
        #expect(builder.contains("\"Add at least one phase.\""))
        #expect(builder.contains("\"Couldn't save block. Try again.\""))
        #expect(builder.contains("\"Discard Changes?\""))
        #expect(builder.contains("\"Discard\""))
        #expect(builder.contains("\"Keep Editing\""))
        #expect(builder.contains("\"Cancel\""))
        #expect(builder.contains("\"Save\""))

        let row = try String(
            contentsOf: base.appendingPathComponent("BlockPhaseEditorRow.swift"),
            encoding: .utf8
        )
        #expect(row.contains("\"Weeks\""))
        #expect(row.contains("\"Volume ×\""))
        #expect(row.contains("\"Intensity ×\""))
        #expect(row.contains("\"Delete\""))
        #expect(row.contains("\"Reorder phase \\(displayIndex): \\(BlockPhaseColors.phaseLabel(draft.kind))\""))
    }
}
