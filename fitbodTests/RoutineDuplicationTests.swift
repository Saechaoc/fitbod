//
//  RoutineDuplicationTests.swift
//  fitbodTests
//
//  Deep-copy correctness coverage for `RoutineDuplicator.duplicate(routine:context:)`
//  (plan 03-03). Six `@Test` functions:
//
//    1. nameSuffixedWithCopy — clone name = "{original} (Copy)"
//    2. deepCopyOfRoutineExercises — RE rows cloned; IDs fresh; exercise
//       refs preserved
//    3. supersetGroupRemappedToClonedGroup — RESEARCH §6 Pitfall 6:
//       SupersetGroup rows cloned + supersetGroupID remapped to the
//       CLONED group, not the source group
//    4. perSetOverridesCloned — per-set overrides cloned with fresh
//       IDs and preserved values
//    5. folderIDPreserved — cloned routine inherits source's folderID
//    6. originalRoutineUntouched — source routine is unchanged (the
//       duplicate is a parallel object)
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("RoutineDuplication (plan 03-03)")
struct RoutineDuplicationTests {

    private func makeContext() throws -> ModelContext {
        let container = try InMemoryContainer.makeEmpty()
        return ModelContext(container)
    }

    /// Seeds a routine with:
    ///   - 2 RoutineExercise rows (Bench, OHP) in order
    ///   - 1 per-set override on the Bench row (setIndex 0, 6 reps @ RPE 9)
    ///   - 1 SupersetGroup linking both RE rows
    private func makeFixture(ctx: ModelContext) throws -> Routine {
        let routine = Routine()
        routine.name = "Push Day"
        routine.notes = "Heavy bench focus"
        ctx.insert(routine)

        let ex1 = Exercise.previewSample(
            name: "Bench",
            equipment: .barbell,
            mechanic: .compound
        )
        let ex2 = Exercise.previewSample(
            name: "OHP",
            equipment: .barbell,
            mechanic: .compound
        )
        ctx.insert(ex1)
        ctx.insert(ex2)

        // Two RoutineExercise rows.
        let re1 = RoutineExercise()
        re1.routine = routine
        re1.exercise = ex1
        re1.orderIndex = 0
        re1.targetSets = 3
        re1.intentRaw = Intent.strength.rawValue
        ctx.insert(re1)

        let re2 = RoutineExercise()
        re2.routine = routine
        re2.exercise = ex2
        re2.orderIndex = 1
        re2.targetSets = 4
        re2.intentRaw = Intent.hypertrophy.rawValue
        ctx.insert(re2)

        // Per-set override on re1 (setIndex 0, 6 reps @ RPE 9).
        let ov = RoutineExerciseSetOverride(
            setIndex: 0,
            targetRepsLow: 6,
            targetRepsHigh: 6,
            targetRPE: 9.0
        )
        ov.routineExercise = re1
        ctx.insert(ov)

        // SupersetGroup linking re1 + re2.
        let group = SupersetGroup(
            routineID: routine.id,
            kindRaw: SupersetKind.paired.rawValue,
            sortOrder: 0
        )
        ctx.insert(group)
        re1.supersetGroupID = group.id
        re2.supersetGroupID = group.id

        try ctx.save()
        return routine
    }

    // MARK: - 1

    @Test("nameSuffixedWithCopy")
    func nameSuffixedWithCopy() throws {
        let ctx = try makeContext()
        let source = try makeFixture(ctx: ctx)
        let copy = RoutineDuplicator.duplicate(routine: source, context: ctx)
        #expect(copy.name == "Push Day (Copy)")
    }

    // MARK: - 2

    @Test("deepCopyOfRoutineExercises")
    func deepCopyOfRoutineExercises() throws {
        let ctx = try makeContext()
        let source = try makeFixture(ctx: ctx)
        let copy = RoutineDuplicator.duplicate(routine: source, context: ctx)

        let copyExercises = (copy.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        #expect(copyExercises.count == 2)
        #expect(copyExercises[0].exercise?.name == "Bench")
        #expect(copyExercises[1].exercise?.name == "OHP")
        // IDs are FRESH — not shared with source.
        let sourceIDs = Set((source.exercises ?? []).map { $0.id })
        let copyIDs = Set(copyExercises.map { $0.id })
        #expect(sourceIDs.isDisjoint(with: copyIDs))
        // Cloned RE rows belong to the cloned routine, not the source.
        for re in copyExercises {
            #expect(re.routine?.id == copy.id)
            #expect(re.routine?.id != source.id)
        }
        // Prescription fields preserved verbatim.
        #expect(copyExercises[0].targetSets == 3)
        #expect(copyExercises[0].intentRaw == Intent.strength.rawValue)
        #expect(copyExercises[1].targetSets == 4)
        #expect(copyExercises[1].intentRaw == Intent.hypertrophy.rawValue)
    }

    // MARK: - 3 — RESEARCH §6 Pitfall 6

    @Test("supersetGroupRemappedToClonedGroup")
    func supersetGroupRemappedToClonedGroup() throws {
        let ctx = try makeContext()
        let source = try makeFixture(ctx: ctx)
        let copy = RoutineDuplicator.duplicate(routine: source, context: ctx)

        // Source's superset group remains attached to source's RE rows only.
        let sourceID = source.id
        let sourceGroups = try ctx.fetch(FetchDescriptor<SupersetGroup>(
            predicate: #Predicate { $0.routineID == sourceID }
        ))
        #expect(sourceGroups.count == 1)

        let copyID = copy.id
        let copyGroups = try ctx.fetch(FetchDescriptor<SupersetGroup>(
            predicate: #Predicate { $0.routineID == copyID }
        ))
        #expect(copyGroups.count == 1)
        #expect(sourceGroups.first?.id != copyGroups.first?.id)

        // Cloned RE rows reference the CLONED group ID, not the source's.
        let copyExercises = (copy.exercises ?? [])
        for re in copyExercises {
            #expect(re.supersetGroupID == copyGroups.first?.id)
            #expect(re.supersetGroupID != sourceGroups.first?.id)
        }
    }

    // MARK: - 4

    @Test("perSetOverridesCloned")
    func perSetOverridesCloned() throws {
        let ctx = try makeContext()
        let source = try makeFixture(ctx: ctx)
        let copy = RoutineDuplicator.duplicate(routine: source, context: ctx)

        let copyRE0 = try #require((copy.exercises ?? []).first { $0.orderIndex == 0 })
        let copyOverrides = copyRE0.setOverrides ?? []
        #expect(copyOverrides.count == 1)
        #expect(copyOverrides.first?.setIndex == 0)
        #expect(copyOverrides.first?.targetRepsLow == 6)
        #expect(copyOverrides.first?.targetRepsHigh == 6)
        #expect(copyOverrides.first?.targetRPE == 9.0)

        // Fresh ID — not shared with source override.
        let sourceRE0 = try #require((source.exercises ?? []).first { $0.orderIndex == 0 })
        let sourceOverrideID = (sourceRE0.setOverrides ?? []).first?.id
        let copyOverrideID = copyOverrides.first?.id
        #expect(sourceOverrideID != copyOverrideID)
        // Cloned override's parent is the cloned RE, not the source RE.
        #expect(copyOverrides.first?.routineExercise?.id == copyRE0.id)
        #expect(copyOverrides.first?.routineExercise?.id != sourceRE0.id)
    }

    // MARK: - 5

    @Test("folderIDPreserved")
    func folderIDPreserved() throws {
        let ctx = try makeContext()
        let folder = RoutineFolder(name: "Hypertrophy Block")
        ctx.insert(folder)

        let source = try makeFixture(ctx: ctx)
        source.folderID = folder.id
        try ctx.save()

        let copy = RoutineDuplicator.duplicate(routine: source, context: ctx)
        #expect(copy.folderID == folder.id)
    }

    // MARK: - 6

    @Test("originalRoutineUntouched")
    func originalRoutineUntouched() throws {
        let ctx = try makeContext()
        let source = try makeFixture(ctx: ctx)
        let sourceName = source.name
        let sourceExerciseCount = (source.exercises ?? []).count
        let sourceRE0 = try #require((source.exercises ?? []).first { $0.orderIndex == 0 })
        let sourceOverrideCount = (sourceRE0.setOverrides ?? []).count

        _ = RoutineDuplicator.duplicate(routine: source, context: ctx)

        #expect(source.name == sourceName)
        #expect((source.exercises ?? []).count == sourceExerciseCount)
        let sourceRE0After = try #require((source.exercises ?? []).first { $0.orderIndex == 0 })
        #expect((sourceRE0After.setOverrides ?? []).count == sourceOverrideCount)
    }
}
