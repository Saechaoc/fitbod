//
//  RoutinesListCopyTests.swift
//  fitbodTests
//
//  Verbatim-copy anchors for UI-SPEC § Routines tab + Move-routine sheet.
//  These tests pin the load-bearing strings from the UI-SPEC into the
//  on-disk source so a careless future edit can't silently mutate the
//  copy contract without tripping the test suite.
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
        #expect(list.contains("\"New Folder\""))
        #expect(list.contains("\"Add routine or folder\""))
        #expect(list.contains("\"Unfiled\""))
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
        #expect(row.contains("\"Move…\""))
        #expect(row.contains("\"Edit\""))
        #expect(row.contains("\"Delete\""))
        #expect(row.contains("\"play.fill\""))

        let folder = try String(
            contentsOf: base.appendingPathComponent("NewFolderSheet.swift"),
            encoding: .utf8
        )
        #expect(folder.contains("\"New Folder\""))
        #expect(folder.contains("\"e.g. Push / Pull / Legs\""))
        #expect(folder.contains("\"Save\""))
        #expect(folder.contains("\"Cancel\""))

        let move = try String(
            contentsOf: base.appendingPathComponent("MoveRoutineSheet.swift"),
            encoding: .utf8
        )
        #expect(move.contains("\"Move Routine\""))
        #expect(move.contains("\"Save\""))
        #expect(move.contains("\"Cancel\""))
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
        #expect(banner.contains("\"Resume Workout: \\(active.routineSnapshotName)\""))
        #expect(banner.contains("\"Resume\""))
        #expect(banner.contains("\"Discard\""))
        #expect(banner.contains("\"Discard active workout?\""))
    }
}
