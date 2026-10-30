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
        #expect(builder.contains("\"PRESET ▾\""))
        #expect(builder.contains("\"Replace your phases?\""))
        #expect(builder.contains("\"Replace phases\""))
        #expect(builder.contains("\"Keep my phases\""))
        #expect(builder.contains("\"Start From Template\""))
        // Phase 9 split band copy pins (replaces old "ROUTINES · N LINKED" pin)
        #expect(builder.contains("\"Routine\""))
        #expect(builder.contains("\"Scheduling\""))
        #expect(builder.contains("\"None — saves as draft\""))
        #expect(builder.contains("\"ROTATION\""))
        #expect(builder.contains("\"FIXED WEEKLY\""))
        #expect(builder.contains("\"+ ATTACH ▸\""))
        #expect(builder.contains("\"SWAP ▸\""))
        #expect(builder.contains("\"NAME FIRST ↑\""))
        #expect(builder.contains("\"SAVE TEMPLATE ▸\""))
        #expect(builder.contains("\"Couldn't save block. Try again.\""))
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
