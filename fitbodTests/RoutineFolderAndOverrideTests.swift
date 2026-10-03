//
//  RoutineFolderAndOverrideTests.swift
//  fitbodTests
//
//  RoutineFolder soft-ref and SetOverride cascade behaviour on the live schema.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@Suite("RoutineFolderAndOverride")
struct RoutineFolderAndOverrideTests {

    @Test("Fresh in-memory V2 ModelContainer opens; round-trips a SessionTemplate + new entity")
    func freshV2ContainerRoundTripsRoutineAndNewEntities() throws {
        let container = try FitbodModelContainer.make(inMemory: true)
        let ctx = ModelContext(container)

        let folder = RoutineFolder(name: "Push / Pull / Legs", sortOrder: 0)
        ctx.insert(folder)

        let routine = SessionTemplate()
        routine.name = "Push Day"
        routine.folderID = folder.id           // NEW V2 field
        ctx.insert(routine)

        try ctx.save()

        // Re-fetch and verify the new field survived a save/fetch cycle.
        let fetched = try ctx.fetch(FetchDescriptor<SessionTemplate>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.folderID == folder.id)

        let folders = try ctx.fetch(FetchDescriptor<RoutineFolder>())
        #expect(folders.count == 1)
        #expect(folders.first?.name == "Push / Pull / Legs")
    }

    @Test("Cascade: deleting a SessionExerciseTemplate cascades into its setOverrides")
    func setOverrideCascadeOnRoutineExerciseDelete() throws {
        let container = try FitbodModelContainer.make(inMemory: true)
        let ctx = ModelContext(container)

        let routine = SessionTemplate()
        routine.name = "Test"
        ctx.insert(routine)

        let re = SessionExerciseTemplate()
        re.sessionTemplate = routine
        ctx.insert(re)

        let override1 = RoutineExerciseSetOverride(setIndex: 0, targetRepsLow: 6, targetRepsHigh: 6, targetRPE: 8.5)
        override1.routineExercise = re
        let override2 = RoutineExerciseSetOverride(setIndex: 1, targetRepsLow: 8, targetRepsHigh: 10, targetRPE: 7.5)
        override2.routineExercise = re
        ctx.insert(override1)
        ctx.insert(override2)
        try ctx.save()

        #expect(try ctx.fetch(FetchDescriptor<RoutineExerciseSetOverride>()).count == 2)

        ctx.delete(re)
        try ctx.save()

        // SessionExerciseTemplate.setOverrides has deleteRule: .cascade -> overrides gone.
        #expect(try ctx.fetch(FetchDescriptor<RoutineExerciseSetOverride>()).isEmpty)
    }

    @Test("Soft refs: deleting a RoutineFolder does NOT cascade into session templates")
    func folderDeleteDoesNotCascadeIntoRoutines() throws {
        let container = try FitbodModelContainer.make(inMemory: true)
        let ctx = ModelContext(container)

        let folder = RoutineFolder(name: "Misc")
        ctx.insert(folder)

        let routine = SessionTemplate()
        routine.name = "Stays"
        routine.folderID = folder.id
        ctx.insert(routine)
        try ctx.save()

        ctx.delete(folder)
        try ctx.save()

        // SessionTemplate survives; folderID is now dangling (Unfiled re-mapping
        // happens in the folder-delete handler in plan 03-01, not at the
        // SwiftData level).
        let routines = try ctx.fetch(FetchDescriptor<SessionTemplate>())
        #expect(routines.count == 1)
    }
}
