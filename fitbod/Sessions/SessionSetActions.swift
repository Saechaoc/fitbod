//
//  SessionSetActions.swift
//  fitbod
//
//  The set-level mutations the session logger performs, pulled out of the
//  SwiftUI views so they are unit-testable against a real ModelContext:
//
//    - complete    flip isComplete on + stamp completedAt (checkmark tap)
//    - uncomplete  flip isComplete off (tap a completed checkmark); the
//                  logged weight/reps stay so the user can fix and
//                  re-check the set. The rest timer is NOT touched.
//    - delete      remove one set and renumber the rest so orderIndex
//                  stays contiguous (warm-ups first, then working sets)
//    - addSet      append a planned working set at the end
//
//  Every mutation saves immediately. A logged workout must survive the
//  app being killed between sets, so nothing here waits for autosave.
//
//  `isEmptyWorkout` is the one empty-workout rule (decision 6), built on
//  `Session.loggedSetCount`, for session counts and Compare.
//

import Foundation
import SwiftData

public enum SessionSetActions {

    /// Bodyweight uses added load, so zero is a valid recorded weight.
    /// All sets need positive reps and a finite, non-negative weight.
    @MainActor
    public static func canComplete(_ entry: SetEntry) -> Bool {
        guard entry.reps > 0, entry.weight.isFinite, entry.weight >= 0 else { return false }
        let equipment = entry.sessionExercise?.exercise?.equipment
        return entry.weight > 0 || equipment == .bodyweight || equipment == .weightedBodyweight
    }

    /// Mark a set complete. Returns false (and changes nothing) when the
    /// set's input is invalid, matching SetRow's commit guard.
    @MainActor
    @discardableResult
    public static func complete(_ entry: SetEntry, at date: Date = .now, context: ModelContext) -> Bool {
        guard canComplete(entry) else { return false }
        entry.isComplete = true
        entry.completedAt = date
        try? context.save()
        return true
    }

    /// Undo a completion. Weight, reps and RPE are kept.
    @MainActor
    public static func uncomplete(_ entry: SetEntry, context: ModelContext) {
        guard entry.isComplete else { return }
        entry.isComplete = false
        try? context.save()
    }

    /// Delete one set and renumber the survivors of its exercise.
    @MainActor
    public static func delete(_ entry: SetEntry, context: ModelContext) {
        let owner = entry.sessionExercise
        context.delete(entry)
        if let owner {
            renumber(owner, excluding: entry.id)
        }
        try? context.save()
    }

    /// Append a planned working set. Weight is seeded from the last set
    /// in this exercise when it has one, else from the previous finished
    /// session, else 0.
    @MainActor
    @discardableResult
    public static func addSet(to sessionExercise: SessionExercise, context: ModelContext) -> SetEntry {
        let existing = ordered(sessionExercise)
        let lastWorkingWeight = existing.last(where: { !$0.isWarmup && $0.weight > 0 })?.weight
        let seedWeight = lastWorkingWeight ?? PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: sessionExercise.exercise?.id,
            intentRaw: sessionExercise.session?.intentRaw ?? Intent.strength.rawValue,
            context: context,
            excludingSessionID: sessionExercise.session?.id
        )?.weight ?? 0

        let entry = SetEntry()
        context.insert(entry)
        entry.sessionExercise = sessionExercise
        entry.orderIndex = existing.count
        entry.setTypeRaw = SetType.working.rawValue
        entry.isWarmup = false
        entry.isComplete = false
        entry.weight = seedWeight
        try? context.save()
        return entry
    }

    /// Lower the weight of every not-yet-completed working set by
    /// `fraction`, rounded down to `increment`. Completed sets are history
    /// and are never touched. Backs the plateau "DROP INTENSITY" chip.
    @MainActor
    public static func dropIntensity(
        of sessionExercise: SessionExercise,
        fraction: Double,
        increment: Double,
        context: ModelContext
    ) {
        let step = increment > 0 ? increment : 2.5
        for set in (sessionExercise.sets ?? []) where !set.isComplete && !set.isWarmup && set.weight > 0 {
            let lowered = set.weight * (1 - fraction)
            set.weight = max(step, (lowered / step).rounded(.down) * step)
            set.wasManualOverride = true
        }
        try? context.save()
    }

    /// Sets of one exercise in display order: warm-ups first, then
    /// working sets, each by orderIndex.
    public static func ordered(_ sessionExercise: SessionExercise) -> [SetEntry] {
        (sessionExercise.sets ?? []).sorted { lhs, rhs in
            if lhs.isWarmup != rhs.isWarmup { return lhs.isWarmup }
            return lhs.orderIndex < rhs.orderIndex
        }
    }

    /// 1-based position of a set among its own kind (warm-ups count
    /// W1, W2...; working sets count S1, S2... independently).
    public static func displayNumber(of entry: SetEntry) -> Int {
        guard let owner = entry.sessionExercise else { return entry.orderIndex + 1 }
        let peers = ordered(owner).filter { $0.isWarmup == entry.isWarmup }
        return (peers.firstIndex(where: { $0.id == entry.id }) ?? entry.orderIndex) + 1
    }

    /// A finished workout with no logged work sets. History keeps it, but
    /// session counts and Compare leave it out. A workout still in
    /// progress is never empty.
    public static func isEmptyWorkout(_ session: Session) -> Bool {
        session.completedAt != nil && session.loggedSetCount == 0
    }

    private static func renumber(_ sessionExercise: SessionExercise, excluding removedID: UUID) {
        let survivors = ordered(sessionExercise).filter { $0.id != removedID && !$0.isDeleted }
        for (index, set) in survivors.enumerated() where set.orderIndex != index {
            set.orderIndex = index
        }
    }
}
