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
        #expect(builder.contains("\"NEW BLOCK\""))
        #expect(builder.contains("\"BLOCK NAME\""))
        #expect(builder.contains("\"NAME YOUR BLOCK\""))
        #expect(builder.contains("\"TOTAL WEEKS\""))
        #expect(builder.contains("\"DAYS PER WEEK\""))
        #expect(builder.contains("\"PHASES · \\(phaseCount)\""))
        #expect(builder.contains("\"+ ADD PHASE\""))
        #expect(builder.contains("\"PROGRESSION OVERVIEW\""))
        #expect(builder.contains("\"Apply Preset?\""))
        #expect(builder.contains("\"Start From Template\""))
        #expect(builder.contains("\"ROUTINES · \\(count) LINKED\""))
        #expect(builder.contains("\"NAME FIRST ↑\""))
        #expect(builder.contains("\"SAVE TEMPLATE ▸\""))
        #expect(builder.contains("\"Couldn't save block. Try again.\""))
        #expect(builder.contains("\"Discard Changes?\""))
        #expect(builder.contains("\"Discard\""))
        #expect(builder.contains("\"Keep Editing\""))
        #expect(builder.contains("\"CANCEL\""))
        #expect(builder.contains("\"SAVE\""))

        let row = try String(
            contentsOf: base.appendingPathComponent("BlockPhaseEditorRow.swift"),
            encoding: .utf8
        )
        #expect(row.contains("\"WEEKS\""))
        #expect(row.contains("\"VOL\""))
        #expect(row.contains("\"INT\""))
        #expect(row.contains("\"Reorder phase \\(displayIndex): \\(BlockPhaseColors.phaseLabel(draft.kind))\""))
    }
}
