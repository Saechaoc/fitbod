//
//  SessionFactoryTests.swift
//  fitbodTests
//
//  The canonical proof of Phase 2's load-bearing snapshot semantic
//  (PITFALLS-doc #1 / ROUTINE-07 / SESS-01). Eight `@Test` functions
//  cover:
//
//    1. snapshotsAllPrescriptionFields — every RoutineExercise
//       prescription field is copied verbatim onto SessionExercise.
//    2. editingRoutineAfterStartLeavesSnapshotIntact — the headline
//       invariant: mutating the routine AFTER session start MUST NOT
//       mutate the snapshotted SessionExercise rows.
//    3. sessionLinksRoutineByUUIDAndName — Session.sourceRoutineID is
//       the routine's UUID (soft ref); Session.routineSnapshotName
//       survives a subsequent rename of the source routine.
//    4. plannedSetEntriesCount — one SetEntry per `targetSets`; all
//       carry `isComplete = false` (the plan 00-01 sentinel).
//    5. activeSessionInvariant — second `start` throws when the first
//       session is still unfinished (RESEARCH §6 Pitfall 7).
//    6. emptyRoutineGuard — empty routine throws
//       `routineHasNoExercises`.
//    7. orderIndexPreservedAcrossSnapshot — RoutineExercise.orderIndex
//       translates 1:1 to SessionExercise.orderIndex.
//    8. blockReferenceCopiedFromRoutine — optional `Block` link
//       survives the snapshot.
//
//  Each test builds its own ModelContainer via Schema(SchemaV2.models)
//  + FitbodSchemaMigrationPlan to exercise the production wiring
//  literally (mirroring the SchemaV2MigrationTests pattern from
//  plan 00-02).
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("SessionFactory", .serialized)
struct SessionFactoryTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV2.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    /// Builds a fixture routine with two distinct exercises, each carrying
    /// a unique prescription field set so per-field snapshot checks are
    /// unambiguous.
    @discardableResult
    private func makeFixtureRoutine(ctx: ModelContext) throws -> Routine {
        let ex1 = Exercise.previewSample(
            name: "Bench",
            equipment: .barbell,
            mechanic: .compound,
            primaryMuscleSlugs: ["chest"]
        )
        let ex2 = Exercise.previewSample(
            name: "OHP",
            equipment: .barbell,
            mechanic: .compound,
            primaryMuscleSlugs: ["shoulders"]
        )
        ctx.insert(ex1)
        ctx.insert(ex2)

        let routine = Routine()
        routine.name = "Push Day"
        ctx.insert(routine)

        let re1 = RoutineExercise()
        re1.routine = routine
        re1.exercise = ex1
        re1.orderIndex = 0
        re1.intentRaw = Intent.strength.rawValue
        re1.targetSets = 3
        re1.targetRepsLow = 5
        re1.targetRepsHigh = 5
        re1.targetRPE = 8.5
        re1.targetRIR = 2
        re1.prescribedRestSeconds = 180
        re1.tempo = "3-1-1-0"
        re1.progressionKindRaw = ProgressionKind.rpe.rawValue
        ctx.insert(re1)

        let re2 = RoutineExercise()
        re2.routine = routine
        re2.exercise = ex2
        re2.orderIndex = 1
        re2.intentRaw = Intent.hypertrophy.rawValue
        re2.targetSets = 4
        re2.targetRepsLow = 8
        re2.targetRepsHigh = 12
        re2.targetRPE = 8.0
        re2.targetRIR = nil
        re2.prescribedRestSeconds = 90
        re2.tempo = nil
        re2.progressionKindRaw = ProgressionKind.double.rawValue
        ctx.insert(re2)

        try ctx.save()
        return routine
    }

    // MARK: - 1. snapshot fidelity (SESS-01)

    @Test("snapshotsAllPrescriptionFields — every RoutineExercise field is copied verbatim")
    func snapshotsAllPrescriptionFields() throws {
        let ctx = try makeContext()
        let routine = try makeFixtureRoutine(ctx: ctx)

        let session = try SessionFactory.start(routine: routine, on: .now, context: ctx)
        let ses = (session.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        #expect(ses.count == 2)

        // Exercise 1 — strength / 3 sets / 5x5 @ RPE 8.5 / 180s rest / RPE prog
        #expect(ses[0].intentRaw == Intent.strength.rawValue)
        #expect(ses[0].targetSets == 3)
        #expect(ses[0].targetRepsLow == 5)
        #expect(ses[0].targetRepsHigh == 5)
        #expect(ses[0].targetRPE == 8.5)
        #expect(ses[0].targetRIR == 2)
        #expect(ses[0].prescribedRestSeconds == 180)
        #expect(ses[0].tempo == "3-1-1-0")
        #expect(ses[0].progressionKindRaw == ProgressionKind.rpe.rawValue)

        // Exercise 2 — hypertrophy / 4 sets / 8-12 @ RPE 8 / 90s rest / double prog
        #expect(ses[1].intentRaw == Intent.hypertrophy.rawValue)
        #expect(ses[1].targetSets == 4)
        #expect(ses[1].targetRepsLow == 8)
        #expect(ses[1].targetRepsHigh == 12)
        #expect(ses[1].targetRPE == 8.0)
        #expect(ses[1].targetRIR == nil)
        #expect(ses[1].prescribedRestSeconds == 90)
        #expect(ses[1].tempo == nil)
        #expect(ses[1].progressionKindRaw == ProgressionKind.double.rawValue)
    }

    // MARK: - 2. snapshot is immutable to template edits (ROUTINE-07 / PITFALLS-doc #1)

    @Test("editingRoutineAfterStartLeavesSnapshotIntact — ROUTINE-07 / PITFALLS-doc #1")
    func editingRoutineAfterStartLeavesSnapshotIntact() throws {
        let ctx = try makeContext()
        let routine = try makeFixtureRoutine(ctx: ctx)

        let session = try SessionFactory.start(routine: routine, on: .now, context: ctx)

        // Mutate the routine AFTER session-start across every prescription
        // field on the first RoutineExercise.
        let re1 = (routine.exercises ?? []).first { $0.orderIndex == 0 }!
        re1.targetSets = 99
        re1.targetRepsLow = 99
        re1.targetRepsHigh = 99
        re1.targetRPE = 9.9
        re1.targetRIR = 999
        re1.intentRaw = Intent.power.rawValue
        re1.prescribedRestSeconds = 999
        re1.tempo = "X-X-X-X"
        re1.progressionKindRaw = ProgressionKind.hybrid.rawValue
        try ctx.save()

        // Re-fetch the SessionExercise belonging to THIS session at
        // orderIndex 0 and verify every snapshot field is unchanged.
        let sessionID = session.id
        let descriptor = FetchDescriptor<SessionExercise>(
            predicate: #Predicate { $0.orderIndex == 0 }
        )
        let snapshot = try ctx.fetch(descriptor).first { $0.session?.id == sessionID }!
        #expect(snapshot.targetSets == 3)
        #expect(snapshot.targetRepsLow == 5)
        #expect(snapshot.targetRepsHigh == 5)
        #expect(snapshot.targetRPE == 8.5)
        #expect(snapshot.targetRIR == 2)
        #expect(snapshot.intentRaw == Intent.strength.rawValue)
        #expect(snapshot.prescribedRestSeconds == 180)
        #expect(snapshot.tempo == "3-1-1-0")
        #expect(snapshot.progressionKindRaw == ProgressionKind.rpe.rawValue)
    }

    // MARK: - 3. session ↔ routine link (sourceRoutineID + routineSnapshotName)

    @Test("sessionLinksRoutineByUUIDAndName — sourceRoutineID is the routine UUID; name survives rename")
    func sessionLinksRoutineByUUIDAndName() throws {
        let ctx = try makeContext()
        let routine = try makeFixtureRoutine(ctx: ctx)

        let session = try SessionFactory.start(routine: routine, on: .now, context: ctx)
        #expect(session.sourceRoutineID == routine.id)
        #expect(session.routineSnapshotName == "Push Day")

        // Renaming the routine MUST NOT affect the snapshot name.
        routine.name = "Push Day v2"
        try ctx.save()
        #expect(session.routineSnapshotName == "Push Day")
        // sourceRoutineID also unchanged (it's the routine's id; renaming
        // doesn't change identity).
        #expect(session.sourceRoutineID == routine.id)
    }

    // MARK: - 4. planned SetEntry count + sentinel state (SESS-03)

    @Test("plannedSetEntriesCount — one SetEntry per targetSets; all carry isComplete = false")
    func plannedSetEntriesCount() throws {
        let ctx = try makeContext()
        let routine = try makeFixtureRoutine(ctx: ctx)

        let session = try SessionFactory.start(routine: routine, on: .now, context: ctx)
        let ses = (session.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        #expect((ses[0].sets ?? []).count == 3)   // bench: 3 sets
        #expect((ses[1].sets ?? []).count == 4)   // OHP: 4 sets

        // All planned sets carry isComplete == false (the plan 00-01 D-3 sentinel).
        for se in ses {
            for set in (se.sets ?? []) {
                #expect(set.isComplete == false)
                #expect(set.isWarmup == false)
                #expect(set.setTypeRaw == SetType.working.rawValue)
                #expect(set.reps == 0)             // user-fillable
                #expect(set.rpe == nil)            // user-fillable
            }
        }
    }

    // MARK: - 5. one-active-session invariant (RESEARCH §6 Pitfall 7)

    @Test("activeSessionInvariant — start throws when an unfinished session exists")
    func activeSessionInvariant() throws {
        let ctx = try makeContext()
        let routine = try makeFixtureRoutine(ctx: ctx)

        _ = try SessionFactory.start(routine: routine, on: .now, context: ctx)

        do {
            _ = try SessionFactory.start(routine: routine, on: .now, context: ctx)
            Issue.record("Expected SessionFactoryError.activeSessionAlreadyExists, but start returned a Session")
        } catch SessionFactoryError.activeSessionAlreadyExists {
            // expected
        } catch {
            Issue.record("Expected activeSessionAlreadyExists; got \(error)")
        }

        // The active() helper also returns a non-nil hit when the first
        // session is still open.
        let active = SessionFactory.active(in: ctx)
        #expect(active != nil)
        #expect(active?.completedAt == nil)
    }

    // MARK: - 6. empty-routine guard

    @Test("emptyRoutineGuard — start throws when routine has no exercises")
    func emptyRoutineGuard() throws {
        let ctx = try makeContext()

        let empty = Routine()
        empty.name = "Empty"
        ctx.insert(empty)
        try ctx.save()

        do {
            _ = try SessionFactory.start(routine: empty, on: .now, context: ctx)
            Issue.record("Expected routineHasNoExercises error, but start returned a Session")
        } catch SessionFactoryError.routineHasNoExercises {
            // expected
        } catch {
            Issue.record("Expected routineHasNoExercises; got \(error)")
        }
    }

    // MARK: - 7. orderIndex preserved across snapshot

    @Test("orderIndexPreservedAcrossSnapshot — RoutineExercise.orderIndex translates to SessionExercise.orderIndex")
    func orderIndexPreservedAcrossSnapshot() throws {
        let ctx = try makeContext()
        let routine = try makeFixtureRoutine(ctx: ctx)

        // Swap the orderIndex on the source routine BEFORE starting.
        let re1 = (routine.exercises ?? []).first { $0.orderIndex == 0 }!
        let re2 = (routine.exercises ?? []).first { $0.orderIndex == 1 }!
        re1.orderIndex = 1
        re2.orderIndex = 0
        try ctx.save()

        let session = try SessionFactory.start(routine: routine, on: .now, context: ctx)
        let ses = (session.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }

        // After the swap: OHP is at orderIndex 0; Bench is at orderIndex 1.
        #expect(ses[0].exercise?.canonicalName == "ohp")
        #expect(ses[1].exercise?.canonicalName == "bench")
    }

    // MARK: - 8. block reference survives snapshot

    @Test("blockReferenceCopiedFromRoutine — optional Block link survives snapshot")
    func blockReferenceCopiedFromRoutine() throws {
        let ctx = try makeContext()
        let routine = try makeFixtureRoutine(ctx: ctx)

        let block = Block()
        block.name = "Hypertrophy I"
        ctx.insert(block)
        routine.block = block
        try ctx.save()

        let session = try SessionFactory.start(routine: routine, on: .now, context: ctx)
        #expect(session.block?.id == block.id)
    }
}
