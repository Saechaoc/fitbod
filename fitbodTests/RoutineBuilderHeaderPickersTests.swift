//
//  RoutineBuilderHeaderPickersTests.swift
//  fitbodTests
//
//  Phase 3.1 plan 04 regression suite for the new session-level Intent
//  + Progression header pickers in `RoutineBuilderView`, the persistence
//  round-trip on the `RoutineDraft` save path, and the relocated
//  `snapshotHash()` dirty-check helper.
//
//  Its tests, in order:
//
//    1. `RoutineDraft` defaults to `.strength` + `.double` on
//       new-routine init (no-routine path).
//    2. `RoutineDraft.init(routine:)` round-trips intent +
//       progressionKind from an existing `Routine` (edit-mode path).
//    3. `RoutineDraft.save(into:context:)` writes intent +
//       progressionKind onto the underlying `Routine` row
//       (`routine.intentRaw` + `routine.progressionKindRaw`).
//    4. Mutating `draft.intent` or `draft.progressionKind` makes
//       `draft.snapshotHash()` return a different value — locks the
//       Phase 3.1 dirty-check behavior change (the relocated
//       `snapshotHash()` on `RoutineDraft` is testable now that it's
//       `internal` access). Plan 04 WARNING 1 fix from a prior
//       revision: the test compiles because Plan 04 Task 1 relocated
//       `snapshotHash()` from RoutineBuilderView (private) to
//       RoutineDraft (internal).
//
//  Test framework: Swift Testing (`@Test` / `#expect`). `@MainActor`
//  on tests that touch `ModelContext` per the FilterStatePredicateTests
//  / ExerciseHistoryIntentSplitTests precedent.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@Suite("RoutineBuilderHeaderPickers")
struct RoutineBuilderHeaderPickersTests {

    // MARK: - Helpers

    /// Fresh in-memory V4 ModelContext over FitbodModelContainer.make(inMemory: true) +
    /// FitbodModelContainer.make — mirrors BlockReviewedAtTests +
    /// ExerciseHistoryIntentSplitTests fixture pattern.
    @MainActor
    private func makeContext() throws -> ModelContext {
        let container = try FitbodModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    // MARK: - 1. Defaults on new-routine init

    @Test("RoutineDraft defaults to .strength + .double on new-routine init")
    @MainActor
    func newDraftDefaults() {
        let draft = RoutineDraft()
        #expect(draft.intent == .strength)
        #expect(draft.progressionKind == .double)
    }

    // MARK: - 2. init(routine:) round-trip (edit mode)

    @Test("RoutineDraft init(routine:) round-trips intent + progressionKind from an existing SessionTemplate")
    @MainActor
    func initFromRoutineRoundTrip() throws {
        let ctx = try makeContext()

        let routine = SessionTemplate()
        routine.name = "Edit-Mode Fixture"
        routine.intentRaw = "hypertrophy"
        routine.progressionKindRaw = "rpe"
        ctx.insert(routine)
        try ctx.save()

        let draft = RoutineDraft(routine: routine)
        #expect(draft.intent == .hypertrophy)
        #expect(draft.progressionKind == .rpe)
    }

    // MARK: - 3. save(into:context:) writes intent + progressionKind

    @Test("RoutineDraft.save(into:) writes intent + progressionKind to the Routine")
    @MainActor
    func savePersistsHeaderPickerFields() throws {
        let ctx = try makeContext()

        // Seed an Exercise so the draft's lone RoutineExerciseDraft is
        // non-empty (isValid requires ≥1 exercise) — name + canonicalName
        // + the equipment/mechanic raw strings keep the row hermetic.
        let bench = Exercise(
            name: "Barbell Bench Press",
            canonicalName: "barbell bench press",
            equipmentRaw: "barbell",
            mechanicRaw: "compound"
        )
        ctx.insert(bench)
        try ctx.save()

        // Build a fresh draft with both pickers MUTATED away from the
        // default values so the assertion exercises a real write.
        // Phase 4 requires block/hybrid progression to be inside a
        // resolved block, so this fixture links the routine to one.
        let block = Block()
        block.name = "Peak Block"
        ctx.insert(block)

        let draft = RoutineDraft()
        draft.name = "Header Picker Save Test"
        draft.blockID = block.id
        draft.intent = .power
        draft.progressionKind = .hybrid
        let exDraft = RoutineExerciseDraft()
        exDraft.exercise = bench
        draft.exercises = [exDraft]

        // Save into a fresh SessionTemplate row.
        let routine = SessionTemplate()
        ctx.insert(routine)
        draft.save(into: routine, context: ctx)
        try ctx.save()

        // Re-fetch from the store.
        let routines = try ctx.fetch(FetchDescriptor<SessionTemplate>())
        let saved = try #require(routines.first)
        #expect(saved.intentRaw == "power")
        #expect(saved.progressionKindRaw == "hybrid")
        #expect(saved.block?.id == block.id)
        // Computed accessor sanity-check.
        #expect(saved.intent == .power)
        #expect(saved.progressionKind == .hybrid)
    }

    // MARK: - 4. snapshotHash dirty-check (Phase 3.1 expansion)

    /// Plan 04 WARNING 1 fix — `snapshotHash()` relocated from
    /// `RoutineBuilderView` (private) to `RoutineDraft` (internal) so
    /// the unit-test target can call it via `@testable import fitbod`.
    /// The Phase 3.1 expansion of the hash inputs INCLUDES the two new
    /// picker rawValues (`intent.rawValue` + `progressionKind.rawValue`)
    /// so a header-picker change arms the Cancel-discard prompt. This
    /// test locks that behavior: a future edit that accidentally drops
    /// either component from the hash will fail one of the `#expect`
    /// calls below.
    @Test("mutating intent or progression makes snapshotHash return a different value")
    @MainActor
    func snapshotHashRespondsToPickerMutations() {
        let draft = RoutineDraft()
        let initialHash = draft.snapshotHash()

        draft.intent = .hypertrophy
        #expect(draft.snapshotHash() != initialHash)

        let afterIntent = draft.snapshotHash()
        draft.progressionKind = .rpe
        #expect(draft.snapshotHash() != afterIntent)
    }

    /// Review item 3: the session editor resists a swipe-down, and Back
    /// asks first, only while this hash differs from the one taken when
    /// the editor opened. So every exercise field the editor saves must
    /// move it, including the order of exercises added in this visit.
    @Test("editing or reordering exercises makes snapshotHash return a different value")
    @MainActor
    func snapshotHashRespondsToExerciseEdits() throws {
        let context = ModelContext(try FitbodModelContainer.make(inMemory: true))
        let bench = Exercise()
        let squat = Exercise()
        context.insert(bench)
        context.insert(squat)
        let edits: [(String, (RoutineDraft) -> Void)] = [
            ("reps", { $0.exercises[0].targetRepsLow = 6 }),
            ("RPE", { $0.exercises[0].targetRPE = 9 }),
            ("rest", { $0.exercises[0].prescribedRestSeconds = 180 }),
            ("tempo", { $0.exercises[0].tempo = "3-1-1" }),
            ("tempo tracking", { $0.exercises[0].tracksTempo = true }),
            ("partial reps", { $0.exercises[0].tracksPartialReps = true }),
            ("superset", { $0.exercises[0].supersetGroupID = UUID() }),
            ("warm-ups", { $0.exercises[0].warmupOverride = WarmupConfig(enabled: false) }),
            ("per-set target", { $0.exercises[0].setOverrides[0].targetRPE = 7 }),
            ("order", { $0.exercises.swapAt(0, 1) }),
        ]
        for (field, edit) in edits {
            let draft = RoutineDraft()
            for exercise in [bench, squat] {
                let row = RoutineExerciseDraft()
                row.exercise = exercise
                row.appendOverride(setIndex: 0)
                draft.exercises.append(row)
            }
            let opened = draft.snapshotHash()
            edit(draft)
            #expect(draft.snapshotHash() != opened, "Editing the \(field) must count as unsaved")
        }
    }
}
