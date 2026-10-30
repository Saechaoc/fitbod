//
//  PreviousMatchingIntent.swift
//  fitbod
//
//  The single shared "what did the user log most recently for this
//  exercise at this intent?" query. Used by both:
//    1. SessionFactory.start — to seed weight hints on planned SetEntry
//       rows for a newly-started session.
//    2. PreviousColumn view (plan 04-01) — to render the inline
//       "Previous" column in the session logger
//       ("175 × 8 @ 8 (Mon)" — UI-SPEC Phase 2).
//
//  Centralizing the query prevents the two surfaces from drifting on
//  subtle semantics (working-set filter, warmup exclusion, "top set"
//  tie-breaking, intent split for ROUTINE-08). Its session walk,
//  `lastWorkingSets`, also gives SessionFactory.lastSessionWorkingReps
//  the reps behind double progression's bump, so the bump and the
//  previous top set always read the same workout.
//
//  Phase 3.1 (PIVOT-05 / D-13): the filter source moved from
//  SessionExercise.intentRaw (gone) to Session.intentRaw via post-fetch
//  Swift filter. The Phase 3.1 Session.intentRaw #Index does not help
//  here because the descriptor fetches SessionExercise rows; future
//  optimization could pivot to fetching matching Sessions first, then
//  flat-mapping their exercises. At single-user single-month-of-data
//  scale the Swift post-filter cost is sub-millisecond.
//
//  RESEARCH §6 Pitfall 1 — the new chain `se.session?.intentRaw` is a
//  multi-level optional chain on SessionExercise. Pitfall 1 still
//  forbids that shape INSIDE #Predicate (the related-entity ID compare
//  returns empty results on iOS 17/18). The fix drops the intent filter
//  from #Predicate, which keeps only the single-hop exerciseID gate (as
//  in PlateauDetector.finishedSessionLogs), and post-filters
//  session.intentRaw in Swift.
//

import Foundation
import SwiftData

/// One hit from the previous-matching-intent query: the top working set
/// of the most recent matching session for an (exerciseID, intentRaw)
/// tuple, across every `SessionExercise` in it that logged the exercise.
public struct PreviousMatchingIntentHit: Sendable {
    public let weight: Double
    public let reps: Int
    public let rpe: Double?
    public let sessionStartedAt: Date

    public init(weight: Double, reps: Int, rpe: Double?, sessionStartedAt: Date) {
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.sessionStartedAt = sessionStartedAt
    }
}

public enum PreviousMatchingIntent {
    /// Returns the top-working-set from the most recent matching-intent
    /// session for the given (exerciseID, intentRaw) tuple. Returns nil
    /// when no prior matching session exists.
    ///
    /// "Top working set" is defined as the highest-weight `SetEntry`
    /// among rows that are:
    ///   - non-warmup (`isWarmup == false`)
    ///   - actually logged (`reps > 0`)
    ///   - explicitly committed (`isComplete == true`)
    ///
    /// A session that logs the exercise more than once counts once: its
    /// top working set is read across all of those logs. On a tie in
    /// weight the earlier set wins, by log and then by set (lower
    /// `orderIndex` both times), whatever order SwiftData returns them in.
    ///
    /// The "matching-intent" half is the load-bearing piece of ROUTINE-08
    /// (`same routine recurring with different intent maintains separate
    /// per-intent histories per exercise`). A strength session's top
    /// working set MUST NOT seed a hypertrophy session and vice versa.
    ///
    /// The session walk (which sessions count, the five-session walk back,
    /// the working-set filter and the order the sets come in) is
    /// `lastWorkingSets`, shared with `SessionFactory.lastSessionWorkingReps`.
    ///
    /// Only FINISHED sessions count as "previous" (`completedAt != nil`),
    /// most recent first. The in-progress session and any abandoned,
    /// never-finished session are excluded, so a set the user just logged
    /// can never show up as its own "previous" value. Pass
    /// `excludingSessionID` (the current session) as a second guard for
    /// callers that run while a session is open.
    public static func fetchTopWorkingSet(
        exerciseID: UUID?,
        intentRaw: String,
        context: ModelContext,
        excludingSessionID: UUID? = nil
    ) -> PreviousMatchingIntentHit? {
        guard let last = lastWorkingSets(
            exerciseID: exerciseID,
            intentRaw: intentRaw,
            context: context,
            excludingSessionID: excludingSessionID
        ) else { return nil }

        // The sets come in workout order, then set order, and `max(by:)`
        // keeps the first of equal elements, so the earlier set wins a tie
        // in weight, inside one log as across logs.
        guard let topSet = last.sets.max(by: { $0.weight < $1.weight }) else { return nil }
        return PreviousMatchingIntentHit(
            weight: topSet.weight,
            reps: topSet.reps,
            rpe: topSet.rpe,
            sessionStartedAt: last.session.startedAt
        )
    }

    /// The working sets of the most recent matching-intent session that
    /// has any, read across every log of the exercise in it: in workout
    /// order, then set order (`orderIndex` both times), never in the order
    /// SwiftData returns them. A working set is non-warmup, logged
    /// (`reps > 0`) and committed (`isComplete == true`). Returns nil when
    /// no such session exists.
    ///
    /// A session that logs the exercise more than once counts once, as in
    /// `PlateauDetector.finishedSessionLogs`. Only FINISHED sessions
    /// (`completedAt != nil`) of `intentRaw` count, never
    /// `excludingSessionID`. A session whose logs hold no working set is
    /// skipped, and the walk back stops after five sessions.
    ///
    /// `fetchTopWorkingSet` and `SessionFactory.lastSessionWorkingReps`
    /// both read it, so the previous top set and double progression's bump
    /// always come from the same workout.
    ///
    /// Performance (Phase 3.1): the #Predicate gates on the exercise only,
    /// a single-hop optional chain with its ID captured as a local first
    /// (RESEARCH §6 Pitfall 1). The finished, excluded-session and intent
    /// gates read the parent Session (`se.session?.intentRaw` is the
    /// multi-level chain Pitfall 1 forbids inside #Predicate), so they run
    /// as Swift post-filters, which also drop orphan rows. At single-user
    /// scale (hundreds of SessionExercise rows) the post-filter is
    /// sub-millisecond. Future optimization (Phase 6) could fetch matching
    /// Sessions first via `#Index<Session>([\.intentRaw])`, then flat-map
    /// to their exercises.
    static func lastWorkingSets(
        exerciseID: UUID?,
        intentRaw: String,
        context: ModelContext,
        excludingSessionID: UUID? = nil
    ) -> (session: Session, sets: [SetEntry])? {
        guard let exerciseID else { return nil }

        // RESEARCH §6 Pitfall 1 — local-let captures before #Predicate.
        // SortDescriptor on optional keypath (\.session?.startedAt)
        // also caused type-checking failures in the Swift 6 toolchain
        // — sort in Swift after fetch.
        let targetID = exerciseID
        let targetIntent = intentRaw

        let descriptor = FetchDescriptor<SessionExercise>(
            predicate: #Predicate { se in se.exercise?.id == targetID }
        )

        guard let all = try? context.fetch(descriptor) else { return nil }

        // Each matching session's logs of the exercise, in the order the
        // sessions first appear. A session that logs the exercise several
        // times is one entry.
        var sessions: [(session: Session, logs: [SessionExercise])] = []
        var sessionIndex: [UUID: Int] = [:]
        for se in all {
            guard let session = se.session,
                  session.completedAt != nil,
                  session.id != excludingSessionID,
                  session.intentRaw == targetIntent
            else { continue }
            if let index = sessionIndex[session.id] {
                sessions[index].logs.append(se)
            } else {
                sessionIndex[session.id] = sessions.count
                sessions.append((session, [se]))
            }
        }

        let recent = sessions
            .sorted { $0.session.startedAt > $1.session.startedAt }
            .prefix(5)

        for (session, logs) in recent {
            let workingSets = logs
                .sorted { $0.orderIndex < $1.orderIndex }
                .flatMap { se in
                    (se.sets ?? [])
                        .filter { !$0.isWarmup && $0.reps > 0 && $0.isComplete }
                        .sorted { $0.orderIndex < $1.orderIndex }
                }
            // This session logged the exercise but no working set was
            // committed (e.g., user discarded mid-session). Walk back
            // further until we find one with committed working sets.
            guard !workingSets.isEmpty else { continue }
            return (session, workingSets)
        }
        return nil
    }
}
