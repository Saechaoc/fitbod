//
//  SessionSetActions.swift
//  fitbod
//
//  The set-level mutations the session logger performs, pulled out of the
//  SwiftUI views so they are unit-testable against a real ModelContext:
//
//    - complete    save the accepted inputs and completion timestamp
//    - uncomplete  flip isComplete off (tap a completed checkmark); the
//                  logged weight/reps stay so the user can fix and
//                  re-check the set. The rest timer is NOT touched.
//    - delete      remove one set and renumber the rest so orderIndex
//                  stays contiguous (warm-ups first, then working sets)
//    - addSet      append a pending set that receives the logger's offers
//    - finish / deleteWorkout / remove   the workout-level writes; each
//                  throws on a failed save so the logger can say so
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

    /// Whether the set can be completed with its entered values and offers.
    @MainActor
    public static func canComplete(_ entry: SetEntry, suggestion: WorkoutSetSuggestion = .init()) -> Bool {
        isValidSet(
            weight: suggestion.weight(for: entry),
            reps: suggestion.reps(for: entry),
            durationSeconds: suggestion.durationSeconds(for: entry),
            tracking: entry.sessionExercise?.exercise?.tracking
        )
    }

    /// `canComplete`'s rule on raw values, by what the exercise tracks:
    /// load and reps need both, bodyweight reps take zero added load, assisted
    /// reps take a weight of zero or less, and timed sets need a time. With
    /// no tracking (the exercise is gone, or a stored set is read by its own
    /// values) reps or a time is enough.
    public static func isValidSet(
        weight: Double, reps: Int, durationSeconds: Int? = nil, tracking: Tracking?
    ) -> Bool {
        guard weight.isFinite else { return false }
        let timed = (durationSeconds ?? 0) > 0
        switch tracking {
        case .weightReps: return reps > 0 && weight > 0
        case .reps: return reps > 0 && weight >= 0
        // Assistance is stored as a negative weight (ARCHITECTURE.md).
        case .assistedReps: return reps > 0 && weight <= 0
        case .duration, .durationDistance, .durationLevel, .durationStepSpeed, .durationSpeedIncline:
            return timed && weight >= 0
        case nil: return reps > 0 || timed
        }
    }

    /// Save entered values and any accepted offers together as one logged set.
    ///
    /// `startedAt` is when the set began, when the rest before it says so
    /// (`RestTimerEngine.setStart(doneAt:)`). A start the set already has,
    /// from its START chip, wins. A set with no time of its own gets its
    /// start and duration from it; a typed time and a re-checked set keep
    /// theirs (RM-062).
    @MainActor
    @discardableResult
    public static func complete(
        _ entry: SetEntry,
        at date: Date = .now,
        startedAt: Date? = nil,
        suggestion: WorkoutSetSuggestion = .init(),
        context: ModelContext,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) throws -> Bool {
        guard !entry.isComplete, canComplete(entry, suggestion: suggestion) else { return false }
        let oldWeight = entry.weight
        let oldReps = entry.reps
        let oldDate = entry.completedAt
        let oldStart = entry.startedAt
        let oldDuration = entry.durationSeconds
        let oldDistance = entry.distanceMeters
        let oldLevel = entry.level
        let oldSpeed = entry.speedKmh
        let oldIncline = entry.incline
        entry.weight = suggestion.weight(for: entry)
        entry.reps = suggestion.reps(for: entry)
        entry.durationSeconds = suggestion.durationSeconds(for: entry)
        entry.distanceMeters = suggestion.distanceMeters(for: entry)
        entry.level = suggestion.level(for: entry)
        entry.speedKmh = suggestion.speedKmh(for: entry)
        entry.incline = suggestion.incline(for: entry)
        if entry.durationSeconds == nil {
            let start = entry.startedAt ?? startedAt
            let seconds = start.flatMap { setSeconds(from: $0, to: date) }
            // Without a start Done can trust, the time stays unknown.
            entry.startedAt = seconds == nil ? nil : start
            entry.durationSeconds = seconds
        }
        entry.isComplete = true
        entry.completedAt = date
        do {
            try save(context)
            return true
        } catch {
            entry.isComplete = false
            entry.completedAt = oldDate
            entry.weight = oldWeight
            entry.reps = oldReps
            entry.startedAt = oldStart
            entry.durationSeconds = oldDuration
            entry.distanceMeters = oldDistance
            entry.level = oldLevel
            entry.speedKmh = oldSpeed
            entry.incline = oldIncline
            throw error
        }
    }

    /// The seconds from a set's start to its Done when they can be the set's
    /// length: at least a second, and at most an hour. A start further back
    /// is a rest that was never ended, not this set.
    static func setSeconds(from start: Date, to done: Date) -> Int? {
        let seconds = Int(done.timeIntervalSince(start).rounded())
        return (1...3600).contains(seconds) ? seconds : nil
    }

    /// An exercise's time (RM-062): from its first working set's start to its
    /// last Done, rest included. A set whose duration is unknown starts at its
    /// Done. Nil until the span reaches a second.
    static func exerciseSeconds(_ sets: [SetEntry]) -> Int? {
        let done = sets.filter(\.countsAsWork)
        guard let end = done.map(\.completedAt).max(),
              let start = done.map({ $0.completedAt.addingTimeInterval(-Double($0.durationSeconds ?? 0)) }).min()
        else { return nil }
        let seconds = Int(end.timeIntervalSince(start).rounded())
        return seconds > 0 ? seconds : nil
    }

    /// Undo a completion. Weight, reps and RPE are kept.
    @MainActor
    public static func uncomplete(_ entry: SetEntry, context: ModelContext) {
        guard entry.isComplete else { return }
        if entry.weight == 0 && canComplete(entry) {
            // The logged unloaded weight is still an entered value after Undo.
            entry.wasManualOverride = true
        }
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

    /// Append a planned working set with no entered values.
    @MainActor
    @discardableResult
    public static func addSet(to sessionExercise: SessionExercise, context: ModelContext) -> SetEntry {
        let orderIndex = (sessionExercise.sets ?? []).count
        let entry = SetEntry()
        context.insert(entry)
        entry.sessionExercise = sessionExercise
        entry.orderIndex = orderIndex
        entry.setTypeRaw = SetType.working.rawValue
        entry.isWarmup = false
        entry.isComplete = false
        try? context.save()
        return entry
    }

    /// Finish a workout: stamp its end and duration in one save. When the
    /// save fails the workout stays in progress with every set kept, and the
    /// error is thrown for the logger to show.
    @MainActor
    public static func finish(_ session: Session, at date: Date = .now, context: ModelContext) throws {
        let duration = session.totalDurationSeconds
        session.completedAt = date
        session.totalDurationSeconds = Int(date.timeIntervalSince(session.startedAt))
        do {
            try context.save()
        } catch {
            session.completedAt = nil
            session.totalDurationSeconds = duration
            throw error
        }
    }

    /// Delete a workout with its exercises and sets: a discarded one in
    /// progress or a finished one. A failed save rolls the delete back, so it
    /// cannot stay pending and fail every later save.
    @MainActor
    public static func deleteWorkout(_ session: Session, context: ModelContext) throws {
        context.delete(session)
        try saveOrRollBack(context)
    }

    /// Remove one exercise and its sets from a workout in progress.
    @MainActor
    public static func remove(_ sessionExercise: SessionExercise, context: ModelContext) throws {
        context.delete(sessionExercise)
        try saveOrRollBack(context)
    }

    /// Saves, or undoes every unsaved change and rethrows, so a failed
    /// save never lingers to be written by a later one. Not tied to the
    /// main actor, so `BlockLifecycleService` saves through it too.
    static func saveOrRollBack(_ context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            rollBack(context)
            throw error
        }
    }

    /// Undoes every unsaved change, and shows it: SwiftData (Xcode 26.5)
    /// leaves loaded models reading the discarded values after
    /// `rollback()` until they are fetched again, so the changed and
    /// deleted ones are fetched again here. Inserted ones are simply gone.
    static func rollBack(_ context: ModelContext) {
        let touched = context.changedModelsArray + context.deletedModelsArray
        context.rollback()
        for model in touched { refetch(model, in: context) }
    }

    private static func refetch<T: PersistentModel>(_ model: T, in context: ModelContext) {
        let id = model.persistentModelID
        _ = try? context.fetch(FetchDescriptor<T>(predicate: #Predicate { $0.persistentModelID == id }))
    }

    /// Lower the weight of every not-yet-completed working set by
    /// `fraction`, rounded down to `increment`. Completed sets are history
    /// and are never touched. Backs the plateau "DROP INTENSITY" chip.
    @MainActor
    public static func dropIntensity(
        of sessionExercise: SessionExercise,
        fraction: Double,
        increment: Double,
        offers: [UUID: WorkoutSetSuggestion] = [:],
        context: ModelContext
    ) {
        let step = increment > 0 ? increment : 2.5
        for set in (sessionExercise.sets ?? []) where !set.isComplete && !set.isWarmup && set.setType != .warmup {
            let weight = offers[set.id]?.weight(for: set) ?? set.weight
            guard weight.isFinite, weight > 0 else { continue }
            let lowered = weight * (1 - fraction)
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
        // shortcut: a covered workout keeps its answer, because the app
        // changes a finished workout's sets in one place only,
        // SessionEditService.save, and whoever calls it must reset this
        // cache. SessionLoggerView edits sets only of a workout in progress:
        // every way into it (Today's resume slab, ResumeWorkoutBanner,
        // starting a workout) opens one, and Finish closes it.
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
