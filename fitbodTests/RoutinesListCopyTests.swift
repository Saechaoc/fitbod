//
//  RoutinesListCopyTests.swift
//  fitbodTests
//
//  Copy anchors for the Routines tab, its sheets and the start-workout
//  alerts (milestone 1, Chalkline redesign — docs/design/screens.md
//  § Routines). Source-level invariants only; rendering is covered by the
//  XCUITest journey.
//
//  Supersedes the plan 03-01 anchors: the per-tab resume banner became the
//  shared resume card + an auto-presented full-screen workout, and the
//  start/resume alerts moved to `WorkoutLauncher` so every entry point
//  (Today, Routines, routine detail) shows the same copy.
//

import Foundation
import Testing
@testable import fitbod

@Suite("RoutinesListCopy")
struct RoutinesListCopyTests {

    @Test("verbatimCopy — Routines tab strings present in source")
    func verbatimCopy() throws {
        let list = try SourceFile.read("fitbod/Routines/RoutinesListView.swift")
        let listStrings = [
            "\"ROUTINES\"",
            "\"New routine\"",
            "\"New folder\"",
            "\"Add routine or folder\"",
            "\"All routines\"",
            "\"Unfiled\"",
            "\"No routines yet\"",
            "\"Workout in progress\"",
            "\"Resume\"",
            "\"Start workout\"",
            "\"Edit\"",
            "\"Duplicate\"",
            "\"Move…\"",
            "\"Delete\"",
            "\"Past workouts from this routine stay in History.\"",
            "\"Delete folder\"",
            "\"The folder is removed. Its routines move to Unfiled.\"",
        ]
        for string in listStrings {
            #expect(list.contains(string), "RoutinesListView.swift should contain \(string)")
        }

        let row = try SourceFile.read("fitbod/Routines/RoutineRow.swift")
        #expect(row.contains("\"Start\""))
        #expect(row.contains("\"Start \\(routine.name)\""))        // VoiceOver label names the routine

        let launcher = try SourceFile.read("fitbod/Sessions/WorkoutLauncher.swift")
        for string in [
            "\"Workout in progress\"",
            "\"Resume workout\"",
            "\"Routine is empty\"",
            "\"Add at least one exercise to this routine first.\"",
            "\"Couldn't start workout\"",
        ] {
            #expect(launcher.contains(string), "WorkoutLauncher.swift should contain \(string)")
        }

        let folder = try SourceFile.read("fitbod/Routines/NewFolderSheet.swift")
        #expect(folder.contains("\"New Folder\""))
        #expect(folder.contains("\"e.g. Push / Pull / Legs\""))
        #expect(folder.contains("\"Save\""))
        #expect(folder.contains("\"Cancel\""))

        let move = try SourceFile.read("fitbod/Routines/MoveRoutineSheet.swift")
        #expect(move.contains("\"Move Routine\""))
        #expect(move.contains("\"Save\""))
        #expect(move.contains("\"Cancel\""))
        #expect(move.contains("\"Unfiled\""))
    }
}
