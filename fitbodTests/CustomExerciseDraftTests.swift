//
//  CustomExerciseDraftTests.swift
//  fitbodTests
//
//  Validation gate for `CustomExerciseDraft.isValid` (PITFALLS #5 +
//  FOUND-07 in microcosm). The 13 tests below cover every branch of
//  the rule:
//
//    `isValid == true` iff:
//      1. trim(name) is non-empty, AND
//      2. ≥1 MuscleAssignment with role == .primary AND weight >= 0.5,
//         unless the draft is cardio (`cardioDraft`).
//
//  Plus `materialize(into:)` end-to-end (proves the insert-then-relate
//  ordering and the `primaryMuscleSlugsJoined` denormalization), three
//  saved-name tests (prove `materialize` and `updateExisting(in:)` store
//  `name` and `canonicalName` without outer whitespace, ticket T54), a
//  `snapshot()` equality test (proves the dirty-detection contract the
//  editor's `Discard Changes?` confirmation relies on) and a family and
//  brand test (RM-022).
//
//  These tests are deliberately decoupled from the SwiftUI editor view
//  — they exercise the pure value-type validation logic in isolation.
//  That is the FOUND-07 invariant: the validation contract lives in a
//  testable type that doesn't require `ModelContainer` for the truth-
//  table tests (the four save tests do need a container; the other 9
//  do not).
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

    @Test("Cardio needs no muscle, saves as cardio, and stores a tracking choice only when it differs from the equipment's")
    @MainActor
    func cardioDraft() throws {
        let d = CustomExerciseDraft()
        d.name = "Air Bike"
        d.equipment = .cardioMachine
        let untouched = d.snapshot()
        // A cardio machine tracks time and distance until another choice is made.
        #expect(d.effectiveTracking == .durationDistance)
        #expect(d.isValid, "cardio saves with no muscle")
        d.tracking = .duration
        #expect(!d.isValid, "a timed hold still needs its muscle")
        d.tracking = .durationLevel
        #expect(d.isValid)
        #expect(d.snapshot() != untouched, "picking what a set tracks makes the draft dirty")

        let ctx = try LoggerFixtures.makeContext()
        let saved = try d.materialize(into: ctx, allMuscles: [])
        #expect(saved.isCardio && saved.tracking == .durationLevel)
        #expect(saved.trackingRaw == Tracking.durationLevel.rawValue)
        #expect(saved.primaryMuscleSlugsJoined.isEmpty && (saved.muscleStimuli ?? []).isEmpty)

        // Back to what the equipment implies: no choice is stored.
        d.editingExisting = saved
        d.tracking = .durationDistance
        try d.updateExisting(in: ctx, allMuscles: [])
        #expect(saved.trackingRaw == nil && saved.tracking == .durationDistance && saved.isCardio)

        // Weight and reps on the same machine is strength again.
        d.tracking = .weightReps
        #expect(!d.isValid, "a strength exercise needs its muscle")
        d.muscles = [.init(slug: "quadriceps", role: .primary, weight: 1.0)]
        try d.updateExisting(in: ctx, allMuscles: [])
        #expect(!saved.isCardio && saved.trackingRaw == Tracking.weightReps.rawValue)
    }

    @Test("Family and brand save on create and update, a brand only on equipment that takes one, and both make the draft dirty")
    @MainActor
    func familyAndBrand() throws {
        let d = CustomExerciseDraft()
        d.name = "Iso-Lateral Chest Press"
        d.equipment = .machine
        d.muscles = [.init(slug: "chest", role: .primary, weight: 1.0)]
        let untouched = d.snapshot()
        d.familyName = "Chest Press"
        #expect(d.snapshot() != untouched, "picking a family makes the draft dirty")
        let familyPicked = d.snapshot()
        d.brand = MachineBrand.hammerStrength.rawValue
        #expect(d.snapshot() != familyPicked, "picking a brand makes the draft dirty")

        let ctx = try LoggerFixtures.makeContext()
        let saved = try d.materialize(into: ctx, allMuscles: [])
        #expect(saved.familyName == "Chest Press" && saved.brand == "Hammer Strength")

        // A barbell takes no brand: the edit drops it and keeps the family.
        d.editingExisting = saved
        d.equipment = .barbell
        #expect(!d.takesBrand)
        try d.updateExisting(in: ctx, allMuscles: [])
        #expect(saved.familyName == "Chest Press" && saved.brand == nil)

        d.familyName = nil
        try d.updateExisting(in: ctx, allMuscles: [])
        #expect(saved.familyName == nil)
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
        try d.materialize(into: ctx, allMuscles: [chest])
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

    // MARK: - Saved name (ticket T54, finding F16)

    @Test("Materialize saves the name without outer spaces")
    func materializeTrimsName() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)

        let quads = MuscleGroup(slug: "quadriceps", displayName: "Quadriceps", region: .lower)
        ctx.insert(quads)
        try ctx.save()

        let d = CustomExerciseDraft()
        d.name = " Zercher Squat "
        d.muscles = [.init(slug: "quadriceps", role: .primary, weight: 1.0)]
        try d.materialize(into: ctx, allMuscles: [quads])
        try ctx.save()

        let exercises = try ctx.fetch(FetchDescriptor<Exercise>())
        #expect(exercises.count == 1)
        let ex = try #require(exercises.first)
        #expect(ex.name == "Zercher Squat")
        #expect(ex.canonicalName == "zercher squat")
        // The editor's field keeps what was typed.
        #expect(d.name == " Zercher Squat ")
    }

    @Test("Update saves the edited name without outer spaces")
    func updateExistingTrimsName() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)

        let quads = MuscleGroup(slug: "quadriceps", displayName: "Quadriceps", region: .lower)
        ctx.insert(quads)
        let existing = Exercise(
            name: "Zercher",
            canonicalName: "zercher",
            equipmentRaw: "barbell",
            mechanicRaw: "compound",
            isCustom: true
        )
        ctx.insert(existing)
        try ctx.save()

        let d = CustomExerciseDraft()
        d.editingExisting = existing
        d.name = " Zercher Squat "
        d.muscles = [.init(slug: "quadriceps", role: .primary, weight: 1.0)]
        try d.updateExisting(in: ctx, allMuscles: [quads])
        try ctx.save()

        let exercises = try ctx.fetch(FetchDescriptor<Exercise>())
        #expect(exercises.count == 1)
        let ex = try #require(exercises.first)
        #expect(ex.name == "Zercher Squat")
        #expect(ex.canonicalName == "zercher squat")
        #expect(d.name == " Zercher Squat ")
    }

    @Test("Saving keeps inner spaces and drops outer line breaks")
    func materializeKeepsInnerSpaces() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)

        let quads = MuscleGroup(slug: "quadriceps", displayName: "Quadriceps", region: .lower)
        ctx.insert(quads)
        try ctx.save()

        let d = CustomExerciseDraft()
        d.name = "\nZercher  Squat \n"
        d.muscles = [.init(slug: "quadriceps", role: .primary, weight: 1.0)]
        try d.materialize(into: ctx, allMuscles: [quads])
        try ctx.save()

        let ex = try #require(try ctx.fetch(FetchDescriptor<Exercise>()).first)
        #expect(ex.name == "Zercher  Squat")
        #expect(ex.canonicalName == "zercher  squat")
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
        // Phase 3.1: intent lives on the parent Session now (PIVOT-02).
        session.intentRaw = "strength"
        ctx.insert(session)

        let se = SessionExercise()
        se.session = session
        se.exercise = custom
        se.orderIndex = 0
        ctx.insert(se)
        try ctx.save()

        // Sanity — forward reference wired.
        #expect(try ctx.fetch(FetchDescriptor<SessionExercise>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<SessionExercise>()).first?.exercise != nil)

        // Editor delete path: nullify references, delete, save.
        try ExerciseDeletion.delete(custom, context: ctx)

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
