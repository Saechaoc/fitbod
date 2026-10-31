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
//  `Session.loggedSetCount`. `countedWorkouts` applies it for Compare and
//  windowed session counts; `emptyWorkoutIDs` applies it to a whole history
//  for the all-time counts to cache, reading only what they have not.
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

    /// The workouts that count as sessions, in the order given: finished
    /// ones that are not empty. Lazy, so a reader that stops early, such as
    /// Compare taking the latest two, reads no further workouts' sets.
    /// Compare and the windowed session counts read these; History still
    /// lists every finished workout.
    public static func countedWorkouts(_ sessions: [Session]) -> LazyFilterSequence<[Session]> {
        sessions.lazy.filter { $0.completedAt != nil && !isEmptyWorkout($0) }
    }

    /// The ids of the empty workouts among `finished`, for an all-time
    /// session count to cache per set of finished workouts instead of
    /// reading them per render. `known` is an earlier answer: the finished
    /// workouts it covered, and the empty ones among them. Covered workouts
    /// keep their answers and only the missing ones are read. When there is
    /// no earlier answer, or many workouts are missing, as after a restore,
    /// two prefetching fetches bring every finished workout's exercises and
    /// sets in at once, instead of a store trip per workout and per exercise.
    @MainActor
    public static func emptyWorkoutIDs(
        among finished: [Session],
        known: (finished: [PersistentIdentifier], empty: Set<PersistentIdentifier>)?,
        in context: ModelContext
    ) -> Set<PersistentIdentifier> {
        // shortcut: a finished workout's sets never change in the app, so a
        // covered workout keeps its answer. Only SessionLoggerView, with the
        // cards and sheets it hosts, edits sets, and every way into it
        // (Today's resume slab, ResumeWorkoutBanner, starting a workout)
        // opens a workout in progress. Finish shows the read-only
        // SessionDetailView in a full-screen cover whose dismissal closes the
        // logger, and History opens the same SessionDetailView.
        // BackupRestorer.performRestore replaces every workout with new rows,
        // so all of their ids go missing.
        let covered = Set(known?.finished ?? [])
        let missing = finished.filter { !covered.contains($0.persistentModelID) }
        if known == nil || missing.count > batchedReadThreshold {
            var workouts = FetchDescriptor<Session>(predicate: #Predicate { $0.completedAt != nil })
            workouts.relationshipKeyPathsForPrefetching = [\.exercises]
            var exercises = FetchDescriptor<SessionExercise>()
            exercises.relationshipKeyPathsForPrefetching = [\.sets]
            _ = try? context.fetch(workouts)
            _ = try? context.fetch(exercises)
        }
        let ids = Set(finished.map(\.persistentModelID))
        return (known?.empty ?? []).intersection(ids)
            .union(missing.filter(isEmptyWorkout).map(\.persistentModelID))
    }

    /// Missing workouts past this many, as after a restore, are read in one
    /// batched pass; fewer, such as the one a finish adds, are read directly.
    private static let batchedReadThreshold = 32

    private static func renumber(_ sessionExercise: SessionExercise, excluding removedID: UUID) {
        let survivors = ordered(sessionExercise).filter { $0.id != removedID && !$0.isDeleted }
        for (index, set) in survivors.enumerated() where set.orderIndex != index {
            set.orderIndex = index
        }
    }
}
