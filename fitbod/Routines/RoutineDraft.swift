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
//  ## Phase 3.1 PIVOT-04 — intent + progression are PER-ROUTINE now
//
//  Per UI-SPEC § Stateful types (Phase 3.1 additions), `intent: Intent`
//  and `progressionKind: ProgressionKind` live on `RoutineDraft` (the
//  per-routine surface), NOT on `RoutineExerciseDraft` (the per-exercise
//  surface) as they did in Phase 2/3. The two fields are direct
//  `@Bindable` surfaces for the new header pickers in
//  `RoutineBuilderView` (per UI-SPEC § Component Inventory — modified
//  views table). The save path writes `routine.intentRaw` /
//  `routine.progressionKindRaw` onto the persisted `Routine` row; the
//  `RoutineExerciseDraft` no longer carries either field.
//
//  ## Phase 3.1 — `snapshotHash()` lives HERE for testability
//
//  The routine-builder dirty-check helper relocated from
//  `RoutineBuilderView` (where it was a `private func` on the view) to
//  this file (where it's an `internal func` on the draft). The body
//  reads only `RoutineDraft` stored properties — no view state was
//  ever referenced — so the relocation is mechanical. Lifting the
//  function makes Test #6 in `RoutineBuilderHeaderPickersTests`
//  viable: `draft.snapshotHash()` is reachable from the test target
//  via `@testable import fitbod`. The Phase 3.1 expansion includes
//  `intent.rawValue` + `progressionKind.rawValue` in the hash so a
//  header-picker change arms the Cancel-discard prompt.
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

    /// Soft draft ref to `Block`. The save path fetches by UUID and
    /// materializes `Routine.block`, or nils the relationship when the
    /// id is absent/unknown.
    public var blockID: UUID? = nil

    /// Ordered list of exercise drafts. Index in this array is the
    /// canonical `orderIndex` at save time — the `.onMove` handler in
    /// `RoutineBuilderView` rewrites the indices on every reorder
    /// (RESEARCH §6 Pitfall 10).
    public var exercises: [RoutineExerciseDraft] = []

    /// Phase 3.1 PIVOT-04 — session-level training intent for THIS
    /// routine. Bound directly to the Intent header picker in
    /// `RoutineBuilderView`. Default `.strength` per D-03 in
    /// 03.1-CONTEXT.md. Persists onto `Routine.intentRaw` at save time.
    public var intent: Intent = .strength

    /// Phase 3.1 PIVOT-04 — session-level weight-progression strategy
    /// for THIS routine. Bound directly to the Progression header
    /// picker in `RoutineBuilderView`. Default `.double` per D-04 in
    /// 03.1-CONTEXT.md. Persists onto `Routine.progressionKindRaw` at
    /// save time.
    public var progressionKind: ProgressionKind = .double

    public init() {}

    /// Build a draft from an existing `Routine` (edit mode). Each
    /// `RoutineExercise` becomes a `RoutineExerciseDraft` whose `id`
    /// field round-trips back to the SwiftData row on save.
    public init(routine: SessionTemplate) {
        self.name = routine.name
        self.notes = routine.notes
        self.folderID = routine.folderID
        self.blockID = routine.block?.id
        // Phase 3.1 PIVOT-04 — pull session-level Intent + Progression
        // off the persisted SessionTemplate row. The accessors are computed
        // (`intentRaw` → `Intent`) per FOUND-03 enum-as-String at
        // persistence, typed enum in memory.
        self.intent = routine.intent
        self.progressionKind = routine.progressionKind
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

    /// Phase 4 (D-19 relocated): block-aware filter for the
    /// session-level Progression header picker. `.block` and `.hybrid`
    /// strategies require a routine.block to be meaningful — without a
    /// block, BlockPeriodizedStrategy has no phase to read multipliers
    /// from and HybridStrategy's min(blockTarget, rpeTarget) reduces to
    /// rpeTarget. The picker therefore hides those two cases when the
    /// routine has no block. After Phase 3.1's PIVOT-04 hoisted
    /// Progression to the session level, this filter lives on the
    /// builder header picker (not on the removed per-exercise row).
    ///
    /// Static so it can be called from view-body computed properties
    /// without needing a draft instance, and from tests via
    /// `@testable import fitbod`.
    public static func availableProgressionKinds(hasBlock: Bool) -> [ProgressionKind] {
        if hasBlock {
            return ProgressionKind.allCases
        } else {
            return [.rpe, .double]
        }
    }

    public static func requiresBlock(_ progressionKind: ProgressionKind) -> Bool {
        progressionKind == .block || progressionKind == .hybrid
    }

    /// Phase 4 (D-19 relocated): save-path guard so a draft whose
    /// `progressionKind` is `.block` or `.hybrid` cannot persist
    /// without a real block. If the draft is dirtied to one of the
    /// block-required cases via a direct property mutation (not the
    /// picker — the picker is filtered) and the routine has no block,
    /// the guard demotes the selection to `.double` (the universal
    /// default per D-04).
    internal func guardedProgressionSelection(hasBlock: Bool) -> ProgressionKind {
        let kinds = RoutineDraft.availableProgressionKinds(hasBlock: hasBlock)
        if kinds.contains(progressionKind) {
            return progressionKind
        }
        return .double
    }

    public func enforceBlockProgressionEligibility(hasBlock: Bool) {
        let guarded = guardedProgressionSelection(hasBlock: hasBlock)
        if guarded != progressionKind {
            progressionKind = guarded
        }
    }

    public func enforceBlockProgressionEligibility() {
        enforceBlockProgressionEligibility(hasBlock: blockID != nil)
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
    public func save(into routine: SessionTemplate, context: ModelContext) {
        routine.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        routine.notes = notes
        routine.folderID = folderID
        // Phase 3.1 PIVOT-04 — write session-level Intent to the
        // persisted SessionTemplate row. Progression writes after resolving
        // the Phase 4 block link so .block/.hybrid cannot persist without a
        // real block.
        routine.intentRaw = intent.rawValue
        routine.updatedAt = .now

        let resolvedBlock: Block?
        if let blockID {
            let targetID = blockID
            let descriptor = FetchDescriptor<Block>(
                predicate: #Predicate<Block> { $0.id == targetID }
            )
            resolvedBlock = (try? context.fetch(descriptor))?.first
        } else {
            resolvedBlock = nil
        }

        routine.block = resolvedBlock
        if resolvedBlock == nil {
            blockID = nil
        }
        enforceBlockProgressionEligibility(hasBlock: resolvedBlock != nil)
        routine.progressionKindRaw = progressionKind.rawValue

        // Remove SessionExerciseTemplate rows not represented in the draft.
        let existingExercises = routine.exercises ?? []
        let draftIDs = Set(exercises.compactMap { $0.id })
        for old in existingExercises where !draftIDs.contains(old.id) {
            context.delete(old)
        }

        for (i, exDraft) in exercises.enumerated() {
            let re: SessionExerciseTemplate
            if let id = exDraft.id,
               let match = existingExercises.first(where: { $0.id == id }) {
                re = match
            } else {
                re = SessionExerciseTemplate()
                re.sessionTemplate = routine
                context.insert(re)
                exDraft.id = re.id
            }

            re.exercise = exDraft.exercise
            re.orderIndex = i
            // Phase 3.1 PIVOT-04 — `re.intentRaw` and
            // `re.progressionKindRaw` are GONE (Plan 02 removed both
            // fields from RoutineExercise). Intent + progression are
            // session-level now and live on the parent Routine row
            // (written above via `routine.intentRaw = intent.rawValue`).
            re.targetSets = exDraft.targetSets
            re.targetRepsLow = exDraft.targetRepsLow
            re.targetRepsHigh = exDraft.targetRepsHigh
            re.targetRPE = exDraft.targetRPE
            re.targetRIR = nil
            re.prescribedRestSeconds = exDraft.prescribedRestSeconds
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

    /// Cheap fingerprint for the routine-builder dirty-check: every field
    /// `save(into:context:)` writes, with the exercises and their per-set
    /// overrides in order. `RoutineBuilderView.hasUnsavedChanges` compares
    /// it with the one taken when the builder opened, to decide whether
    /// Back and Discard ask first and whether a swipe-down is resisted.
    ///
    /// Internal (not private) access so the unit-test target can call
    /// it via `@testable import fitbod`. Relocated in Phase 3.1 from
    /// `RoutineBuilderView` (where it was `private func`) to this draft
    /// so Test #6 in `RoutineBuilderHeaderPickersTests` is viable.
    func snapshotHash() -> String {
        func text(_ value: Any?) -> String { value.map { "\($0)" } ?? "nil" }
        let rows = exercises.map { ex in
            let overrides = ex.setOverrides.map { od in
                ([od.setIndex, od.targetRepsLow, od.targetRepsHigh, od.targetRPE] as [Any?])
                    .map(text).joined(separator: ":")
            }
            let fields: [Any?] = [
                ex.id, ex.exercise?.id, ex.targetSets, ex.targetRepsLow, ex.targetRepsHigh,
                ex.targetRPE, ex.prescribedRestSeconds, ex.tempo, ex.tracksTempo,
                ex.tracksPartialReps, ex.supersetGroupID, ex.warmupOverride,
                overrides.joined(separator: ";"),
            ]
            return fields.map(text).joined(separator: "/")
        }
        let fields: [Any?] = [name, notes, folderID, blockID, intent.rawValue, progressionKind.rawValue]
        return (fields.map(text) + [rows.joined(separator: ",")]).joined(separator: "|")
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
    // Phase 3.1 PIVOT-04 — `intent: Intent` REMOVED. The training intent
    // is now session-level and lives on the parent `RoutineDraft.intent`.

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

    /// The most reps either end of the target range can step to.
    public static let maxTargetReps = 50

    /// What the low end of the rep range can step through. It stops at
    /// the high end, so low can never pass high. Stored values outside
    /// the bounds (typed before the editor used steppers) still give a
    /// valid range that the user can step back from.
    public var targetRepsLowRange: ClosedRange<Int> {
        1...min(max(targetRepsHigh, 1), Self.maxTargetReps)
    }

    /// What the high end can step through. It stops at the low end, so
    /// high can never drop below low.
    public var targetRepsHighRange: ClosedRange<Int> {
        min(max(targetRepsLow, 1), Self.maxTargetReps)...Self.maxTargetReps
    }

    public var targetRPE: Double? = 8.0
    public var prescribedRestSeconds: Int = 120
    // Phase 3.1 PIVOT-04 — `progressionKind: ProgressionKind` REMOVED.
    // The progression strategy is now session-level and lives on the
    // parent `RoutineDraft.progressionKind`.
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
    convenience init(re: SessionExerciseTemplate) {
        self.init()
        self.id = re.id
        self.exercise = re.exercise
        self.orderIndex = re.orderIndex
        // Phase 3.1 PIVOT-04 — `self.intent = re.intent` REMOVED.
        // RoutineExercise no longer carries intent (Plan 02); the
        // session-level intent lives on the parent RoutineDraft, which
        // is initialised from `routine.intent` in `RoutineDraft.init(routine:)`.
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
        // Phase 3.1 PIVOT-04 — `self.progressionKind = re.progressionKind`
        // REMOVED. RoutineExercise no longer carries progressionKind
        // (Plan 02); the session-level progression lives on the parent
        // RoutineDraft.
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
