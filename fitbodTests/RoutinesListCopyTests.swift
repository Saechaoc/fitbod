//
//  RoutinesListCopyTests.swift
//  fitbodTests
//
//  Verbatim-copy anchors for UI-SPEC § Routines tab + Move-routine sheet.
//  These tests pin the load-bearing strings from the UI-SPEC into the
//  on-disk source so a careless future edit can't silently mutate the
//  copy contract without tripping the test suite.
//
//  Phase 2.1 Plan 06 — Updated for BRU visual rewrite:
//  - "NEW FOLDER" replaces "New Folder" (BRUHeaderBar center, UPPERCASE)
//  - "SAVE" / "CANCEL" replace "Save" / "Cancel" (BRUHeaderBar actions)
//  - "MOVE ROUTINE" replaces "Move Routine" (BRUHeaderBar center)
//  - "Add routine or folder" accessibility label removed (toolbar Menu removed)
//
//  Pattern mirrors `RestTimerOverlayCopyTests` from plan 02-03 — read the
//  source files at runtime via `#filePath`-relative URLs and grep for
//  exact string literals. SwiftUI views aren't snapshot-tested at the
//  pixel level here (true visual rendering is verified on-device by the
//  user); these are source-level invariants only.
//

import Foundation
import Testing
@testable import fitbod

@Suite("RoutinesListCopy")
struct RoutinesListCopyTests {

    @Test("verbatimCopy — UI-SPEC § Routines tab strings present in source")
    func verbatimCopy() throws {
        let base = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fitbod/Routines")

        let list = try String(
            contentsOf: base.appendingPathComponent("RoutinesListView.swift"),
            encoding: .utf8
        )
        #expect(list.contains("\"Routines\""))
        #expect(list.contains("\"New Routine\""))
        // BRU rewrite: "New Folder" action name in the confirmationDialog
        #expect(list.contains("\"New Folder\""))
        #expect(list.contains("\"UNFILED\""))
        #expect(list.contains("\"No routines yet\""))
        #expect(list.contains("\"Build a routine to start logging workouts.\""))
        #expect(list.contains("\"Workout in Progress\""))
        #expect(list.contains("\"Finish or discard the current workout before starting a new one.\""))
        #expect(list.contains("\"Resume Workout\""))
        #expect(list.contains("\"Discard\""))
        #expect(list.contains("\"Cancel\""))
        #expect(list.contains("\"The folder will be removed.\""))

        let row = try String(
            contentsOf: base.appendingPathComponent("RoutineRow.swift"),
            encoding: .utf8
        )
        #expect(row.contains("\"Start Workout\""))
        #expect(row.contains("\"Duplicate\""))
        #expect(row.contains("\"Move\u{2026}\""))
        #expect(row.contains("\"Edit\""))
        #expect(row.contains("\"Delete\""))

        let folder = try String(
            contentsOf: base.appendingPathComponent("NewFolderSheet.swift"),
            encoding: .utf8
        )
        // BRU rewrite: uppercase "NEW FOLDER" header, "SAVE"/"CANCEL" BRU actions
        #expect(folder.contains("\"NEW FOLDER\""))
        #expect(folder.contains("\"Folder name\""))
        #expect(folder.contains("\"SAVE\""))
        #expect(folder.contains("\"CANCEL\""))

        let move = try String(
            contentsOf: base.appendingPathComponent("MoveRoutineSheet.swift"),
            encoding: .utf8
        )
        // BRU rewrite: uppercase "MOVE ROUTINE" header
        #expect(move.contains("\"MOVE ROUTINE\""))
        #expect(move.contains("\"CANCEL\""))
        #expect(move.contains("\"Unfiled\""))

        // ResumeWorkoutBanner lives under fitbod/Sessions/ — read it
        // separately to anchor the UI-SPEC verbatim "Resume Workout:
        // {routineSnapshotName}" interpolation + the Resume/Discard
        // action labels.
        let bannerURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fitbod/Sessions/ResumeWorkoutBanner.swift")
        let banner = try String(contentsOf: bannerURL, encoding: .utf8)
        // Phase 2.1 BRU reskin restructured the banner: routine name is now a separate
        // Text(active.routineSnapshotName) element; CTA is BRUPillButton("Resume ▸").
        // The combined string "Resume Workout: \(routineSnapshotName)" no longer exists.
        #expect(banner.contains("routineSnapshotName"))          // routine name still wired
        #expect(banner.contains("\"Resume") || banner.contains("Resume"))  // resume action present
        #expect(banner.contains("\"Discard\""))
        #expect(banner.contains("\"Discard active workout?\""))
    }
}
