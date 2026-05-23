//
//  RoutineDraft.swift
//  fitbod
//
//  Wave-3 plan 03-02 — the ephemeral `@Observable` form-holder for the
//  routine builder. Three nested types:
//
//    1. `RoutineDraft` — top-level builder state: name, notes, folder,
//       ordered list of exercises. `isValid` gates the Save button.
//    2. `RoutineExerciseDraft` — per-exercise prescription state. Mirrors
//       every field on `RoutineExercise` that the builder edits.
//    3. `PerSetOverrideDraft` — one row of the "Per-set overrides"
//       sub-list inside the prescription editor.
//
//  ## MV-VM-lite (FOUND-06)
//
//  This is NOT a parallel ViewModel mirroring `@Query`. It's a value-
//  shaped mutation surface that the view binds to via `@Bindable`. The
//  `save(into:context:)` method projects the draft onto an actual
//  `Routine` `@Model` row at the user's "Save" tap — until then, every
//  mutation is in-memory only. The `@Query` integration on the routines
//  list (plan 03-01) re-renders automatically when `save(...)` calls
//  `ctx.save()`.
//
//  ## RESEARCH §6 Pitfall 8 — per-set override prune on targetSets shrink
//
//  When the user decreases `RoutineExerciseDraft.targetSets`, any
//  override row whose `setIndex >= newTargetSets` is now an orphan.
//  The `didSet` on `targetSets` prunes those rows immediately so the
//  draft never leaks orphan overrides into the prescription editor
//  sub-list. The pruning is in the draft layer, not the persistence
//  layer — by the time `save(into:context:)` runs, the in-memory list
//  is already correct and is written verbatim.
//
//  ## Save-path round-trip
//
//  `save(into:context:)` rewrites both the parent `RoutineExercise`
//  rows AND the cascade-owned `RoutineExerciseSetOverride` children:
//    - existing RE rows whose draft.id matches are updated in place
//    - draft RE rows with id == nil are inserted (RoutineExercise() +
//      ctx.insert + back-fill draft.id from re.id)
//    - existing RE rows not represented in the draft are deleted
//    - the same three-way merge happens for setOverrides per RE row
//  This shape lets the builder edit an existing `Routine` (edit mode)
//  without dropping its ids — which preserves SwiftData identity for
//  the cascade rules in the schema and the soft `Session.sourceRoutineID`
//  ref that points at the Routine row.
//

import Foundation
import SwiftData

@Observable
@MainActor
public final class RoutineDraft {

    /// Routine name. `isValid` requires non-empty after trim.
    public var name: String = ""

    /// Optional notes (the routine-level notes that survive into the
    /// SessionExercise snapshot via plan 04-01's session header).
    public var notes: String? = nil

    /// Soft `UUID?` ref to `RoutineFolder`. `nil` ⇒ Unfiled. The folder
    /// picker in the builder writes this directly.
    public var folderID: UUID? = nil

    /// Ordered list of exercise drafts. Index in this array is the
    /// canonical `orderIndex` at save time — the `.onMove` handler in
    /// `RoutineBuilderView` rewrites the indices on every reorder
    /// (RESEARCH §6 Pitfall 10).
    public var exercises: [RoutineExerciseDraft] = []

    public init() {}

    /// Build a draft from an existing `Routine` (edit mode). Each
    /// `RoutineExercise` becomes a `RoutineExerciseDraft` whose `id`
    /// field round-trips back to the SwiftData row on save.
    public init(routine: Routine) {
        self.name = routine.name
        self.notes = routine.notes
        self.folderID = routine.folderID
        self.exercises = (routine.exercises ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { RoutineExerciseDraft(re: $0) }
    }

    /// True when the routine has a non-empty name AND at least one
    /// exercise. Drives the Save button's `.disabled(...)` state.
    public var isValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !exercises.isEmpty
    }

    /// Append a brand-new exercise to the draft. Runs the
    /// `PrescriptionDefaults` heuristic (ROUTINE-09) so the user sees
    /// reasonable defaults the moment they tap a search result.
    public func append(exercise: Exercise) {
        let draft = RoutineExerciseDraft()
        draft.exercise = exercise
        PrescriptionDefaults.apply(to: draft, from: exercise)
        draft.orderIndex = exercises.count
        exercises.append(draft)
    }

    /// Project the draft onto a `Routine` row.
    ///
    /// Call sites:
    ///   - Create mode: caller constructs `Routine()`, calls `ctx.insert(routine)`,
    ///     then `draft.save(into: routine, context: ctx)`.
    ///   - Edit mode: caller passes the existing `Routine` from `@Query`.
    ///
    /// Three-way merge per child collection:
    ///   1. Delete RE rows not represented in the draft.
    ///   2. Insert new RE rows where draft.id == nil; back-fill draft.id.
    ///   3. Update existing RE rows in place.
    /// Same shape for the per-RE `RoutineExerciseSetOverride` children.
    public func save(into routine: Routine, context: ModelContext) {
        routine.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        routine.notes = notes
        routine.folderID = folderID
        routine.updatedAt = .now

        // Remove RoutineExercise rows not represented in the draft.
        let existingExercises = routine.exercises ?? []
        let draftIDs = Set(exercises.compactMap { $0.id })
        for old in existingExercises where !draftIDs.contains(old.id) {
            context.delete(old)
        }

        for (i, exDraft) in exercises.enumerated() {
            let re: RoutineExercise
            if let id = exDraft.id,
               let match = existingExercises.first(where: { $0.id == id }) {
                re = match
            } else {
                re = RoutineExercise()
                re.routine = routine
                context.insert(re)
                exDraft.id = re.id
            }

            re.exercise = exDraft.exercise
            re.orderIndex = i
            re.intentRaw = exDraft.intent.rawValue
            re.targetSets = exDraft.targetSets
            re.targetRepsLow = exDraft.targetRepsLow
            re.targetRepsHigh = exDraft.targetRepsHigh
            re.targetRPE = exDraft.targetRPE
            re.targetRIR = nil
            re.prescribedRestSeconds = exDraft.prescribedRestSeconds
            re.progressionKindRaw = exDraft.progressionKind.rawValue
            re.tempo = exDraft.tempo
            re.tracksTempo = exDraft.tracksTempo
            re.tracksPartialReps = exDraft.tracksPartialReps
            re.supersetGroupID = exDraft.supersetGroupID
            re.warmupOverride = exDraft.warmupOverride

            // Three-way merge for the per-set overrides (cascade-owned).
            let existingOverrides = re.setOverrides ?? []
            let draftOverrideIDs = Set(exDraft.setOverrides.compactMap { $0.id })
            for old in existingOverrides where !draftOverrideIDs.contains(old.id) {
                context.delete(old)
            }
            for od in exDraft.setOverrides {
                let ov: RoutineExerciseSetOverride
                if let id = od.id,
                   let match = existingOverrides.first(where: { $0.id == id }) {
                    ov = match
                } else {
                    ov = RoutineExerciseSetOverride()
                    ov.routineExercise = re
                    context.insert(ov)
                    od.id = ov.id
                }
                ov.setIndex = od.setIndex
                ov.targetRepsLow = od.targetRepsLow
                ov.targetRepsHigh = od.targetRepsHigh
                ov.targetRPE = od.targetRPE
            }
        }
    }
}

// MARK: - RoutineExerciseDraft

@Observable
@MainActor
public final class RoutineExerciseDraft: Identifiable {
    /// `nil` until materialized into a `RoutineExercise` row via
    /// `RoutineDraft.save(into:context:)`. The id back-fills from the
    /// inserted row's `id` so subsequent saves update in place.
    public var id: UUID? = nil
    public var exercise: Exercise? = nil
    public var orderIndex: Int = 0
    public var intent: Intent = .hypertrophy

    /// `didSet` enforces RESEARCH §6 Pitfall 8 — when the user shrinks
    /// targetSets, every per-set override row whose setIndex >=
    /// newTargetSets is pruned. Without this guard the overrides would
    /// linger and would either render as orphan rows in the editor or
    /// (worse) be re-applied if the user expanded targetSets back later.
    public var targetSets: Int = 3 {
        didSet {
            if targetSets < oldValue {
                setOverrides = setOverrides.filter { $0.setIndex < targetSets }
            }
        }
    }

    public var targetRepsLow: Int = 8
    public var targetRepsHigh: Int = 12
    public var targetRPE: Double? = 8.0
    public var prescribedRestSeconds: Int = 120
    public var progressionKind: ProgressionKind = .double
    public var tempo: String? = nil
    public var tracksTempo: Bool = false
    public var tracksPartialReps: Bool = false
    public var supersetGroupID: UUID? = nil
    public var setOverrides: [PerSetOverrideDraft] = []

    /// Per-exercise warm-up override. nil = default auto-warm-up behavior
    /// (no override stored). Mirrors `RoutineExercise.warmupOverride` and
    /// is round-tripped through `RoutineDraft.save(into:context:)`.
    public var warmupOverride: WarmupConfig? = nil

    public init() {}

    /// Round-trip from an existing `RoutineExercise` row (edit mode).
    convenience init(re: RoutineExercise) {
        self.init()
        self.id = re.id
        self.exercise = re.exercise
        self.orderIndex = re.orderIndex
        self.intent = re.intent
        // Set targetSets BEFORE setOverrides — the `didSet` prune runs
        // against the still-empty initial overrides, which is a no-op.
        // setOverrides is then assigned from the persisted store; those
        // overrides are guaranteed valid against re.targetSets per the
        // prior save invariants (RESEARCH §6 Pitfall 8 was enforced at
        // the time they were written).
        self.targetSets = re.targetSets
        self.targetRepsLow = re.targetRepsLow
        self.targetRepsHigh = re.targetRepsHigh
        self.targetRPE = re.targetRPE
        self.prescribedRestSeconds = re.prescribedRestSeconds
        self.progressionKind = re.progressionKind
        self.tempo = re.tempo
        self.tracksTempo = re.tracksTempo
        self.tracksPartialReps = re.tracksPartialReps
        self.supersetGroupID = re.supersetGroupID
        self.warmupOverride = re.warmupOverride
        self.setOverrides = (re.setOverrides ?? [])
            .sorted { $0.setIndex < $1.setIndex }
            .map { PerSetOverrideDraft(override: $0) }
    }

    /// Append a new per-set override row to the editor. The caller (the
    /// "Add Override" button in the prescription editor) supplies the
    /// next setIndex; this method just appends and returns the new draft
    /// for SwiftUI focus management.
    @discardableResult
    public func appendOverride(setIndex: Int) -> PerSetOverrideDraft {
        let draft = PerSetOverrideDraft()
        draft.setIndex = setIndex
        setOverrides.append(draft)
        return draft
    }
}

// MARK: - PerSetOverrideDraft

@Observable
@MainActor
public final class PerSetOverrideDraft: Identifiable {
    /// `nil` until materialized into a `RoutineExerciseSetOverride` row.
    public var id: UUID? = nil
    public var setIndex: Int = 0
    public var targetRepsLow: Int? = nil
    public var targetRepsHigh: Int? = nil
    public var targetRPE: Double? = nil

    public init() {}

    convenience init(override: RoutineExerciseSetOverride) {
        self.init()
        self.id = override.id
        self.setIndex = override.setIndex
        self.targetRepsLow = override.targetRepsLow
        self.targetRepsHigh = override.targetRepsHigh
        self.targetRPE = override.targetRPE
    }
}
