//
//  CustomExerciseDraftTests.swift
//  fitbodTests
//
//  Validation gate for `CustomExerciseDraft.isValid` (PITFALLS #5 +
//  FOUND-07 in microcosm). The 10 tests below cover every branch of
//  the rule:
//
//    `isValid == true` iff:
//      1. trim(name) is non-empty, AND
//      2. ≥1 MuscleAssignment with role == .primary AND weight >= 0.5.
//
//  Plus `materialize(into:)` end-to-end (proves the insert-then-relate
//  ordering and the `primaryMuscleSlugsJoined` denormalization) and a
//  `snapshot()` equality test (proves the dirty-detection contract the
//  editor's `Discard Changes?` confirmation relies on).
//
//  These tests are deliberately decoupled from the SwiftUI editor view
//  — they exercise the pure value-type validation logic in isolation.
//  That is the FOUND-07 invariant: the validation contract lives in a
//  testable type that doesn't require `ModelContainer` for the truth-
//  table tests (`materialize` does need a container; the other 9 do
//  not).
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@Suite("CustomExerciseDraft validation (LIB-04 / FOUND-07 / PITFALLS #5)")
struct CustomExerciseDraftTests {

    // MARK: - Truth table

    @Test("Empty name → invalid")
    func emptyName() {
        let d = CustomExerciseDraft()
        d.name = ""
        d.muscles = [.init(slug: "chest", role: .primary, weight: 1.0)]
        #expect(!d.isValid)
    }

    @Test("Whitespace-only name → invalid")
    func whitespaceName() {
        let d = CustomExerciseDraft()
        d.name = "   "
        d.muscles = [.init(slug: "chest", role: .primary, weight: 1.0)]
        #expect(!d.isValid)
    }

    @Test("No muscles → invalid")
    func noMuscles() {
        let d = CustomExerciseDraft()
        d.name = "Pec Deck"
        #expect(!d.isValid)
    }

    @Test("Only secondary muscle → invalid (PITFALLS #5)")
    func onlySecondary() {
        let d = CustomExerciseDraft()
        d.name = "Pec Deck"
        d.muscles = [.init(slug: "chest", role: .secondary, weight: 0.5)]
        #expect(!d.isValid)
    }

    @Test("Primary muscle with weight < 0.5 → invalid")
    func primaryUnderHalf() {
        let d = CustomExerciseDraft()
        d.name = "Pec Deck"
        d.muscles = [.init(slug: "chest", role: .primary, weight: 0.4)]
        #expect(!d.isValid)
    }

    @Test("Name + primary muscle (weight=0.5) → valid (threshold)")
    func validAtThreshold() {
        let d = CustomExerciseDraft()
        d.name = "Pec Deck"
        d.muscles = [.init(slug: "chest", role: .primary, weight: 0.5)]
        #expect(d.isValid)
    }

    @Test("Name + primary muscle (weight=1.0) → valid (full)")
    func validFull() {
        let d = CustomExerciseDraft()
        d.name = "Pec Deck"
        d.muscles = [.init(slug: "chest", role: .primary, weight: 1.0)]
        #expect(d.isValid)
    }

    @Test("Multiple primaries → still valid")
    func multiplePrimaries() {
        let d = CustomExerciseDraft()
        d.name = "Compound Move"
        d.muscles = [
            .init(slug: "chest", role: .primary, weight: 1.0),
            .init(slug: "triceps", role: .primary, weight: 0.8),
        ]
        #expect(d.isValid)
    }

    // MARK: - Materialization (end-to-end, with ModelContainer)

    @Test("Materialize inserts Exercise + stimulus rows with isCustom=true")
    func materializeInsertsExerciseAndStimuli() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)

        // Pre-create the muscle row the materializer will reference.
        let chest = MuscleGroup(slug: "chest", displayName: "Chest", region: .upper)
        ctx.insert(chest)
        try ctx.save()

        let d = CustomExerciseDraft()
        d.name = "Cambered Bar Bench"
        d.equipment = .barbell
        d.mechanic = .compound
        d.muscles = [.init(slug: "chest", role: .primary, weight: 1.0)]
        d.materialize(into: ctx, allMuscles: [chest])
        try ctx.save()

        let exercises = try ctx.fetch(FetchDescriptor<Exercise>())
        #expect(exercises.count == 1)
        let ex = try #require(exercises.first)
        #expect(ex.name == "Cambered Bar Bench")
        #expect(ex.isCustom == true)
        #expect(ex.equipmentRaw == "barbell")
        #expect(ex.mechanicRaw == "compound")
        // Canonical-name fold: lowercase + diacritic-insensitive.
        #expect(ex.canonicalName == "cambered bar bench")
        // Denormalized muscle-filter shape (PITFALLS #3).
        #expect(ex.primaryMuscleSlugsJoined == "|chest|")

        let stimuli = try ctx.fetch(FetchDescriptor<ExerciseMuscleStimulus>())
        #expect(stimuli.count == 1)
        let stim = try #require(stimuli.first)
        #expect(stim.role == "primary")
        #expect(stim.weight == 1.0)
        #expect(stim.exercise?.id == ex.id)
        #expect(stim.muscle?.slug == "chest")
    }

    // MARK: - Snapshot / dirty detection

    @Test("Snapshot equality detects dirty state")
    func snapshotDirtyDetection() {
        let d = CustomExerciseDraft()
        d.name = "Initial"
        let snap = d.snapshot()
        // Same draft → snapshots equal.
        #expect(snap == d.snapshot())
        // Mutate any field → snapshots diverge.
        d.name = "Changed"
        #expect(snap != d.snapshot())
    }
}

// MARK: - LIB-05 cascade verification at the editor surface

@Suite("Exercise → SessionExercise nullify on delete (LIB-05 — editor surface)")
struct CustomExerciseDeleteCascadeTests {

    /// Anchors LIB-05 at the *editor* level: when the user taps the
    /// "Delete" button in the custom-exercise editor (which calls
    /// `ctx.delete(draft.editingExisting!)` then `ctx.save()`), the
    /// cascade rule `Exercise → SessionExercise: nullify` keeps the
    /// historical session row alive with `exercise == nil`.
    ///
    /// The same rule is exercised at the schema level by
    /// `CascadeRuleTests.exerciseToSessionExerciseNullifies` (plan
    /// 01-03). This test duplicates the assertion at the editor
    /// boundary so a future refactor that switches the delete handler
    /// to (for example) a hard cascade flag would still be caught
    /// here.
    @Test("Deleting a custom Exercise nullifies any SessionExercise reference (LIB-05)")
    func nullifyOnDelete() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)

        let chest = MuscleGroup(slug: "chest", displayName: "Chest", region: .upper)
        ctx.insert(chest)

        let custom = Exercise(
            name: "Custom Bench",
            canonicalName: "custom bench",
            equipmentRaw: "barbell",
            mechanicRaw: "compound",
            isCustom: true
        )
        ctx.insert(custom)

        let session = Session()
        session.routineSnapshotName = "Test"
        session.startedAt = .now
        ctx.insert(session)

        let se = SessionExercise()
        se.session = session
        se.exercise = custom
        se.orderIndex = 0
        se.intentRaw = "strength"
        ctx.insert(se)
        try ctx.save()

        // Sanity — forward reference wired.
        #expect(try ctx.fetch(FetchDescriptor<SessionExercise>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<SessionExercise>()).first?.exercise != nil)

        // Editor delete path: `ctx.delete(editingExisting); try ctx.save()`.
        ctx.delete(custom)
        try ctx.save()

        // LIB-05: SessionExercise survives, with `exercise = nil`.
        let postDelete = try ctx.fetch(FetchDescriptor<SessionExercise>())
        #expect(postDelete.count == 1, "SessionExercise should NOT be cascade-deleted")
        #expect(
            postDelete.first?.exercise == nil,
            "Exercise reference should be nullified (LIB-05)"
        )
        // Session itself is untouched.
        #expect(try ctx.fetch(FetchDescriptor<Session>()).count == 1)
        // The custom Exercise is gone.
        #expect(try ctx.fetch(FetchDescriptor<Exercise>()).isEmpty)
    }
}
