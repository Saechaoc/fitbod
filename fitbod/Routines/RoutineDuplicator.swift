//
//  RoutineDuplicator.swift
//  fitbod
//
//  Wave-3 plan 03-03 — deep-copy entry point for the "Duplicate" action
//  on a routine row in `RoutinesListView` (ROUTINE-06). The duplicator
//  copies the source `Routine` + every owned `RoutineExercise` + the
//  cascade-owned `RoutineExerciseSetOverride` rows + the soft-ref
//  `SupersetGroup` rows that belong to the source routine. Every UUID
//  is freshly minted and the cloned `RoutineExercise.supersetGroupID`
//  is remapped via a `[UUID: UUID]` map so the clones reference the
//  CLONED group, never the source group.
//
//  ## RESEARCH §6 Pitfall 6 (deep-copy correctness)
//
//  Pitfall 6 — duplication must deep-copy supersets AND per-set
//  overrides; UUIDs must be remapped. The naive shape ("copy
//  RoutineExercise rows and verbatim-copy supersetGroupID") would
//  point every cloned RE at the SOURCE'S SupersetGroup, so editing
//  the duplicate's superset would also mutate the original's. This
//  module owns the remap: SupersetGroup rows are cloned FIRST so the
//  `groupIDMap` is fully populated before the RoutineExercise clones
//  reference it.
//
//  ## PITFALLS-doc #1 (deep-copy ≠ shared reference)
//
//  Every cloned row is a fresh `RoutineExercise()` / `SupersetGroup()`
//  / `RoutineExerciseSetOverride()` insert — NEVER a shared reference
//  to the source. The clones' field values are copied verbatim from
//  the source rows; only the IDs (and the soft-ref `supersetGroupID`
//  via the map) diverge.
//
//  ## Naming convention
//
//  The cloned routine's name is `"{original name} (Copy)"` (UI-SPEC
//  pattern matching the existing "Duplicate" affordance). The folder
//  membership (`folderID`) is preserved — the duplicate lives in the
//  same folder as the original. `createdAt` / `updatedAt` are set to
//  `.now`; `isArchived` is reset to `false`. The optional `block` ref
//  is preserved (a Phase 4 concern).
//
//  ## Failure handling
//
//  `try? context.save()` at the end is non-fatal — a save failure is
//  logged via the existing console path (SwiftData prints a console
//  warning on save failure), not surfaced as a user-visible alert. The
//  duplicate action is low-stakes (the user can retry) and the alert
//  surface would interrupt the typical Routines-tab flow more than it
//  would help.
//

import Foundation
import SwiftData

public enum RoutineDuplicator {
    /// Deep-copies a `Routine` + all its `RoutineExercise` rows + all
    /// their per-set overrides + all `SupersetGroup` rows belonging to
    /// the source routine. The cloned routine gets name
    /// `"{original} (Copy)"` and inherits the source's `folderID`.
    ///
    /// Returns the new `Routine`. RESEARCH §6 Pitfall 6 — every UUID
    /// is freshly minted; `supersetGroupID` refs on cloned
    /// `RoutineExercise` rows are remapped via a `[UUID: UUID]` map.
    @MainActor
    @discardableResult
    public static func duplicate(routine: Routine, context: ModelContext) -> Routine {
        let copy = Routine()
        copy.name = "\(routine.name) (Copy)"
        copy.notes = routine.notes
        copy.folderID = routine.folderID
        copy.createdAt = .now
        copy.updatedAt = .now
        copy.isArchived = false
        copy.block = routine.block
        context.insert(copy)

        // Clone SupersetGroup rows FIRST so we have a map from source
        // group ID → cloned group ID for use when reassigning
        // RoutineExercise.supersetGroupID below. RESEARCH §6 Pitfall 6
        // — the order is load-bearing.
        let sourceID = routine.id
        let sourceGroups = (try? context.fetch(FetchDescriptor<SupersetGroup>(
            predicate: #Predicate { $0.routineID == sourceID }
        ))) ?? []

        var groupIDMap: [UUID: UUID] = [:]
        for sg in sourceGroups {
            let cloned = SupersetGroup(
                routineID: copy.id,
                kindRaw: sg.kindRaw,
                sortOrder: sg.sortOrder
            )
            context.insert(cloned)
            groupIDMap[sg.id] = cloned.id
        }

        // Clone RoutineExercise rows in orderIndex order so the
        // cloned routine's exercise list mirrors the source's visual
        // order verbatim.
        for re in (routine.exercises ?? []).sorted(by: { $0.orderIndex < $1.orderIndex }) {
            let clonedRE = RoutineExercise()
            clonedRE.routine = copy
            clonedRE.exercise = re.exercise
            clonedRE.orderIndex = re.orderIndex
            clonedRE.intentRaw = re.intentRaw
            clonedRE.targetSets = re.targetSets
            clonedRE.targetRepsLow = re.targetRepsLow
            clonedRE.targetRepsHigh = re.targetRepsHigh
            clonedRE.targetRPE = re.targetRPE
            clonedRE.targetRIR = re.targetRIR
            clonedRE.prescribedRestSeconds = re.prescribedRestSeconds
            clonedRE.tempo = re.tempo
            clonedRE.notes = re.notes
            clonedRE.progressionKindRaw = re.progressionKindRaw
            clonedRE.generateWarmups = re.generateWarmups
            clonedRE.tracksTempo = re.tracksTempo
            clonedRE.tracksPartialReps = re.tracksPartialReps

            // RESEARCH §6 Pitfall 6 — remap superset ID via the group
            // map. If the source row was in a group, the clone joins
            // the CLONED group (not the source group); otherwise stay
            // unassigned.
            if let sourceGroupID = re.supersetGroupID,
               let mapped = groupIDMap[sourceGroupID] {
                clonedRE.supersetGroupID = mapped
            } else {
                clonedRE.supersetGroupID = nil
            }

            context.insert(clonedRE)

            // Clone per-set overrides (cascade-owned by RE). Iterate
            // in setIndex order so the cloned override list mirrors
            // the source's logical order; SwiftData doesn't guarantee
            // collection order on relationship fetches.
            for ov in (re.setOverrides ?? []).sorted(by: { $0.setIndex < $1.setIndex }) {
                let clonedOv = RoutineExerciseSetOverride(
                    setIndex: ov.setIndex,
                    targetRepsLow: ov.targetRepsLow,
                    targetRepsHigh: ov.targetRepsHigh,
                    targetRPE: ov.targetRPE
                )
                clonedOv.routineExercise = clonedRE
                context.insert(clonedOv)
            }
        }

        try? context.save()
        return copy
    }
}
