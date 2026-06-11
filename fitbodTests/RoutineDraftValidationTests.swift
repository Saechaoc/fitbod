//
//  RoutineDraftValidationTests.swift
//  fitbodTests
//
//  Validation + Pitfall coverage for `RoutineDraft` and
//  `RoutineExerciseDraft` (plan 03-02).
//
//  Six `@Test` functions:
//
//    1. emptyDraftIsInvalid — `name == ""` → invalid
//    2. noExercisesIsInvalid — name set but exercises empty → invalid
//    3. validDraft — name + ≥1 exercise → valid
//    4. pruneOverridesOnTargetSetsShrink — RESEARCH §6 Pitfall 8:
//       targetSets = 2 while overrides at [0,1,2] → only [0,1] remain
//    5. saveRoundTrip — `save(into:)` writes RE rows + overrides; the
//       round-trip via `RoutineDraft(routine:)` recovers the field
//       values
//    6. routineDraftDefaultIntentIsStrength — Phase 3.1 (PIVOT-04 /
//       D-03 / D-04): RoutineDraft.intent defaults to .strength and
//       RoutineDraft.progressionKind defaults to .double.
//
//  Phase 3.1 (PIVOT-04 / D-10): intent + progressionKind moved from
//  RoutineExerciseDraft (per-exercise) up to RoutineDraft (per-routine).
//  Test 5's save round-trip asserts the new fields persist on Routine
//  and recover via RoutineDraft(routine:); the per-exercise assertions
//  are dropped (fields gone from RoutineExerciseDraft + RoutineExercise).
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("RoutineDraftValidation (plan 03-02)")
struct RoutineDraftValidationTests {

    // MARK: - 1

    @Test("emptyDraftIsInvalid")
    func emptyDraftIsInvalid() {
        let draft = RoutineDraft()
        #expect(draft.isValid == false)
    }

    // MARK: - 2

    @Test("noExercisesIsInvalid")
    func noExercisesIsInvalid() {
        let draft = RoutineDraft()
        draft.name = "Push Day A"
        #expect(draft.isValid == false)
    }

    // MARK: - 3

    @Test("validDraft")
    func validDraft() {
        let draft = RoutineDraft()
        draft.name = "Push Day A"
        let exDraft = RoutineExerciseDraft()
        exDraft.exercise = Exercise(
            name: "Bench",
            canonicalName: "bench",
            equipmentRaw: "barbell",
            mechanicRaw: "compound"
        )
        draft.exercises.append(exDraft)
        #expect(draft.isValid == true)
    }

    // MARK: - 4 — RESEARCH §6 Pitfall 8

    @Test("pruneOverridesOnTargetSetsShrink")
    func pruneOverridesOnTargetSetsShrink() {
        let exDraft = RoutineExerciseDraft()
        exDraft.targetSets = 3
        let ov0 = PerSetOverrideDraft()
        ov0.setIndex = 0
        let ov1 = PerSetOverrideDraft()
        ov1.setIndex = 1
        let ov2 = PerSetOverrideDraft()
        ov2.setIndex = 2
        exDraft.setOverrides = [ov0, ov1, ov2]

        // Shrink targetSets from 3 → 2 — RESEARCH §6 Pitfall 8: the
        // override at setIndex=2 must be pruned.
        exDraft.targetSets = 2

        #expect(exDraft.setOverrides.count == 2)
        let remainingIndices = exDraft.setOverrides.map { $0.setIndex }.sorted()
        #expect(remainingIndices == [0, 1])

        // Re-expanding targetSets does NOT restore pruned overrides
        // (they're gone; the user must re-add them explicitly).
        exDraft.targetSets = 5
        #expect(exDraft.setOverrides.count == 2)
    }

    // MARK: - 5

    @Test("saveRoundTrip — fields persist + recover")
    func saveRoundTrip() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)

        // Pre-create the exercise the draft references.
        let bench = Exercise(
            name: "Barbell Bench Press",
            canonicalName: "barbell bench press",
            equipmentRaw: "barbell",
            mechanicRaw: "compound"
        )
        ctx.insert(bench)
        try ctx.save()

        // Build the draft.
        // Phase 3.1 (PIVOT-04 / D-10): intent + progressionKind are per-Routine.
        let draft = RoutineDraft()
        draft.name = "  Push Day A  "  // verify trim on save
        draft.notes = "Heavy bench focus."
        draft.intent = .strength
        draft.progressionKind = .double
        let exDraft = RoutineExerciseDraft()
        exDraft.exercise = bench
        exDraft.targetSets = 4
        exDraft.targetRepsLow = 3
        exDraft.targetRepsHigh = 5
        exDraft.targetRPE = 8.5
        exDraft.prescribedRestSeconds = 180
        exDraft.tracksTempo = true
        exDraft.tracksPartialReps = false
        exDraft.tempo = "3-1-1-0"
        let ov = PerSetOverrideDraft()
        ov.setIndex = 0
        ov.targetRepsLow = 5
        ov.targetRepsHigh = 5
        ov.targetRPE = 9.0
        exDraft.setOverrides = [ov]
        draft.exercises = [exDraft]

        // Save into a fresh SessionTemplate row.
        let routine = SessionTemplate()
        ctx.insert(routine)
        draft.save(into: routine, context: ctx)
        try ctx.save()

        // Re-fetch via @Model identity.
        let routines = try ctx.fetch(FetchDescriptor<SessionTemplate>())
        #expect(routines.count == 1)
        let saved = try #require(routines.first)
        #expect(saved.name == "Push Day A")  // trim landed
        #expect(saved.notes == "Heavy bench focus.")
        // Phase 3.1: intent + progression persisted on the parent SessionTemplate.
        #expect(saved.intent == .strength)
        #expect(saved.progressionKind == .double)
        #expect((saved.exercises ?? []).count == 1)
        let re = try #require((saved.exercises ?? []).first)
        #expect(re.exercise?.id == bench.id)
        #expect(re.targetSets == 4)
        #expect(re.targetRepsLow == 3)
        #expect(re.targetRepsHigh == 5)
        #expect(re.targetRPE == 8.5)
        #expect(re.prescribedRestSeconds == 180)
        #expect(re.tracksTempo == true)
        #expect(re.tracksPartialReps == false)
        #expect(re.tempo == "3-1-1-0")
        #expect((re.setOverrides ?? []).count == 1)
        let savedOverride = try #require((re.setOverrides ?? []).first)
        #expect(savedOverride.setIndex == 0)
        #expect(savedOverride.targetRepsLow == 5)
        #expect(savedOverride.targetRepsHigh == 5)
        #expect(savedOverride.targetRPE == 9.0)

        // Round-trip via RoutineDraft(routine:) — recover all fields.
        let recovered = RoutineDraft(routine: saved)
        #expect(recovered.name == "Push Day A")
        #expect(recovered.notes == "Heavy bench focus.")
        // Phase 3.1: recovered draft surfaces routine-level intent +
        // progressionKind.
        #expect(recovered.intent == .strength)
        #expect(recovered.progressionKind == .double)
        #expect(recovered.exercises.count == 1)
        let recoveredEx = try #require(recovered.exercises.first)
        #expect(recoveredEx.targetSets == 4)
        #expect(recoveredEx.targetRepsLow == 3)
        #expect(recoveredEx.targetRepsHigh == 5)
        #expect(recoveredEx.targetRPE == 8.5)
        #expect(recoveredEx.prescribedRestSeconds == 180)
        #expect(recoveredEx.tracksTempo == true)
        #expect(recoveredEx.tempo == "3-1-1-0")
        #expect(recoveredEx.setOverrides.count == 1)
        let recoveredOverride = try #require(recoveredEx.setOverrides.first)
        #expect(recoveredOverride.setIndex == 0)
        #expect(recoveredOverride.targetRepsLow == 5)
        #expect(recoveredOverride.targetRepsHigh == 5)
        #expect(recoveredOverride.targetRPE == 9.0)
    }

    // MARK: - 6 — Phase 3.1 (PIVOT-04 / D-03 / D-04)

    @Test("routineDraftDefaultIntentIsStrength — RoutineDraft.intent + .progressionKind defaults")
    func routineDraftDefaultIntentIsStrength() {
        // A freshly-constructed RoutineDraft (used by the "+ New Routine"
        // path in RoutinesListView → RoutineBuilderView) carries the
        // documented Phase 3.1 defaults: intent = .strength, progressionKind
        // = .double. The header pickers in RoutineBuilderView render
        // these as the closed-state values until the user picks a
        // different option.
        let draft = RoutineDraft()
        #expect(draft.intent == .strength)
        #expect(draft.progressionKind == .double)

        // Validity gating is unchanged — intent + progressionKind do
        // NOT gate isValid (only name + ≥1 exercise do).
        #expect(draft.isValid == false)  // empty name + no exercises
    }
}
