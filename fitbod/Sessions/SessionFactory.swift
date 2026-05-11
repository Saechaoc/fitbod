//
//  SessionFactory.swift
//  fitbod
//
//  The load-bearing snapshot deep-copy entry point for Phase 2
//  (PITFALLS-doc #1 / ROUTINE-07). `SessionFactory.start(...)` is the
//  ONLY way to create a new `Session` from a `Routine`:
//
//    1. Insert a new `Session` with `sourceRoutineID = routine.id`
//       (soft UUID ref — NOT a SwiftData @Relationship — so deleting the
//       template never erases the history) and
//       `routineSnapshotName = routine.name` (verbatim at start time so
//       a future rename leaves the session header intact).
//    2. For each `RoutineExercise` in `routine.exercises` (sorted by
//       `orderIndex`), create a `SessionExercise` snapshotting every
//       prescription field (intent / targetSets / repsLow / repsHigh /
//       RPE / RIR / restSeconds / tempo / progressionKind). Editing the
//       source `RoutineExercise` tomorrow MUST NOT mutate these rows.
//    3. Pre-populate planned `SetEntry` rows (one per `targetSets`)
//       seeded with weight from the most recent matching-intent set
//       (via `PreviousMatchingIntent`) if available, else 0. Each row
//       carries `isComplete = false` — the explicit "planned but not
//       yet logged" sentinel locked by plan 00-01.
//
//  Per RESEARCH § Pattern 1: the entire deep-copy is a single
//  `try context.save()` transaction so partial state never persists on
//  failure (load-bearing for UI-SPEC § Error states "Couldn't Start
//  Workout" alert).
//
//  Invariants enforced:
//    - One active session at a time (RESEARCH §6 Pitfall 7) — throws
//      `activeSessionAlreadyExists` if any `Session.completedAt == nil`
//      row exists.
//    - Empty routine guard — throws `routineHasNoExercises` if the
//      source routine has zero `RoutineExercise` rows. UI-SPEC says
//      save is disabled when `RoutineDraft.isValid == false` but the
//      factory guards defensively anyway.
//

import Foundation
import SwiftData

public enum SessionFactoryError: Error {
    case activeSessionAlreadyExists
    case routineHasNoExercises
    case persistenceFailed(underlying: Error)
}

public enum SessionFactory {
    /// Start a new session from a routine. Deep-copies every prescription
    /// field from `RoutineExercise` to `SessionExercise` (PITFALLS-doc #1
    /// / ROUTINE-07) and pre-populates planned `SetEntry` rows with
    /// target weight pulled from the most recent matching-intent session
    /// for each exercise (`PreviousMatchingIntent.fetchTopWorkingSet`).
    ///
    /// Returns the newly-inserted `Session`. Caller is responsible for
    /// presenting `SessionLoggerView(session: returnedSession)`.
    ///
    /// Throws `SessionFactoryError.activeSessionAlreadyExists` if any
    /// `Session.completedAt == nil` row already exists (RESEARCH §6
    /// Pitfall 7 — one active session at a time). Caller should surface
    /// the UI-SPEC § Error states "Workout in Progress" alert and not
    /// invoke this method until the active session is finished or
    /// discarded.
    ///
    /// Throws `SessionFactoryError.routineHasNoExercises` if the routine
    /// has no exercises.
    ///
    /// Throws `SessionFactoryError.persistenceFailed(underlying:)` if
    /// `context.save()` fails (e.g., disk full, SwiftData constraint
    /// violation). Caller surfaces UI-SPEC's "Couldn't Start Workout"
    /// alert with the underlying error's `localizedDescription`.
    public static func start(
        routine: Routine,
        on date: Date = .now,
        context: ModelContext
    ) throws -> Session {
        // Empty-routine guard — surface as a typed error BEFORE checking
        // the active-session invariant. Both are blocking conditions, but
        // the empty-routine path is the cheaper check.
        let exercises = (routine.exercises ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
        guard !exercises.isEmpty else {
            throw SessionFactoryError.routineHasNoExercises
        }

        // RESEARCH §6 Pitfall 7 — enforce one active session at a time.
        // An "active" session is any row whose `completedAt == nil`.
        let activeDescriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.completedAt == nil }
        )
        if let existing = try? context.fetch(activeDescriptor), !existing.isEmpty {
            throw SessionFactoryError.activeSessionAlreadyExists
        }

        let session = Session()
        session.startedAt = date
        session.completedAt = nil
        session.routineSnapshotName = routine.name
        session.sourceRoutineID = routine.id          // soft UUID ref
        session.block = routine.block                 // optional; safe to carry forward
        session.notes = nil
        session.totalDurationSeconds = nil
        context.insert(session)

        for (orderIndex, re) in exercises.enumerated() {
            let se = SessionExercise()
            se.session = session
            se.exercise = re.exercise
            se.orderIndex = orderIndex

            // SNAPSHOT: every prescription field copied verbatim. Future
            // edits to `re` will NOT mutate `se` — these are independent
            // rows from this point forward (PITFALLS-doc #1 / ROUTINE-07).
            se.intentRaw = re.intentRaw
            se.targetSets = re.targetSets
            se.targetRepsLow = re.targetRepsLow
            se.targetRepsHigh = re.targetRepsHigh
            se.targetRPE = re.targetRPE
            se.targetRIR = re.targetRIR
            se.prescribedRestSeconds = re.prescribedRestSeconds
            se.tempo = re.tempo
            se.progressionKindRaw = re.progressionKindRaw
            // SNAPSHOT (Wave-4 plan 04-02): the routine-side toggles that
            // gate per-set opt-in row rendering in the session logger.
            // Snapshotting these onto SessionExercise keeps the active
            // session decoupled from subsequent edits to the source
            // RoutineExercise's toggles (PITFALLS-doc #1 / ROUTINE-07).
            se.tracksTempo = re.tracksTempo
            se.tracksPartialReps = re.tracksPartialReps
            // `prescribedWeight` is populated by Phase 3's
            // ProgressionStrategy; for Phase 2 we leave it nil and the
            // SetEntry rows pull a weight hint from
            // `PreviousMatchingIntent` below instead.
            se.pinnedNote = nil

            context.insert(se)

            // Resolve "previous matching-intent weight" for the planned
            // `SetEntry` rows. Returns nil for the first-ever logged
            // session of this (exercise, intent) tuple → set rows default
            // weight = 0.
            let previousHint = PreviousMatchingIntent.fetchTopWorkingSet(
                exerciseID: re.exercise?.id,
                intentRaw: re.intentRaw,
                context: context
            )?.weight ?? 0

            // Pre-populate planned `SetEntry` rows. Each set carries the
            // previous-matching-intent weight as a "suggestion" but
            // `isComplete = false` is the explicit "planned, not yet
            // logged" sentinel (plan 00-01 D-3).
            for setIndex in 0..<re.targetSets {
                let entry = SetEntry()
                entry.sessionExercise = se
                entry.orderIndex = setIndex
                entry.weight = previousHint
                entry.reps = 0
                entry.rpe = nil
                entry.setTypeRaw = SetType.working.rawValue
                entry.isWarmup = false
                entry.isComplete = false                  // SENTINEL
                entry.completedAt = date                  // overwritten on commit
                context.insert(entry)
            }
        }

        do {
            try context.save()
        } catch {
            throw SessionFactoryError.persistenceFailed(underlying: error)
        }
        return session
    }

    /// Convenience accessor for the single active session, if one exists.
    /// Returns nil when no `Session.completedAt == nil` row is present.
    ///
    /// Used by the Today tab's "Resume workout: {name}" banner
    /// (plan 04-01) and by callers that need to gate "Start Workout" UI
    /// before invoking `start(...)`. Centralized here so the
    /// active-session predicate has exactly one definition (and matches
    /// the gate inside `start`).
    public static func active(in context: ModelContext) -> Session? {
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.completedAt == nil }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}
