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
//  tie-breaking, intent split for ROUTINE-08).
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
//  returns empty results on iOS 17/18). The fix mirrors
//  SessionFactory.fetchHistoryPoints / lastSessionWorkingReps: drop the
//  intent filter from #Predicate, post-filter ALL fetched results by
//  both exerciseID AND session.intentRaw in Swift.
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
    /// top working set is read across all of those logs, and on a tie in
    /// weight the earlier log's set (lower `orderIndex`) wins.
    ///
    /// The "matching-intent" half is the load-bearing piece of ROUTINE-08
    /// (`same routine recurring with different intent maintains separate
    /// per-intent histories per exercise`). A strength session's top
    /// working set MUST NOT seed a hypertrophy session and vice versa.
    ///
    /// Performance (Phase 3.1): the descriptor fetches ALL SessionExercise
    /// rows (no #Predicate filter on intent, since `se.session?.intentRaw`
    /// is a multi-level optional chain that triggers Pitfall 1). The
    /// Swift post-filter step keeps only rows matching both exerciseID
    /// AND parent-session intent, groups them by session, then sorts the
    /// sessions by startedAt and keeps the 5 most-recent. At single-user
    /// single-month-of-data scale (hundreds of SessionExercise rows) the
    /// unfiltered fetch + Swift filter is sub-millisecond. Future
    /// optimization (Phase 6) could fetch matching Sessions first via the
    /// new `#Index<Session>([\.intentRaw])`, then flat-map to their
    /// exercises.
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
        guard let exerciseID else { return nil }

        // Phase 3.1 (PIVOT-05 / D-13): no #Predicate filter — both the
        // intent gate (`session?.intentRaw`) and the exerciseID gate
        // (`exercise?.id`) are post-filtered in Swift. The intent chain
        // is multi-level optional which Pitfall 1 forbids inside the
        // predicate body; the exerciseID chain is single-level optional
        // and could in principle live inside #Predicate, but keeping
        // both gates side-by-side in Swift mirrors
        // SessionFactory.fetchHistoryPoints and keeps the workaround
        // shape consistent across the three queries.
        //
        // SortDescriptor on optional keypath (\.session?.startedAt)
        // also caused type-checking failures in the Swift 6 toolchain
        // — sort in Swift after fetch.
        let targetID = exerciseID
        let targetIntent = intentRaw

        let descriptor = FetchDescriptor<SessionExercise>()

        guard let all = try? context.fetch(descriptor) else { return nil }

        // Each matching session's logs of the exercise, in the order the
        // sessions first appear. A session that logs the exercise several
        // times is one entry, as in `PlateauDetector.finishedSessionLogs`.
        var sessions: [(session: Session, logs: [SessionExercise])] = []
        var sessionIndex: [UUID: Int] = [:]
        for se in all {
            guard let session = se.session,
                  session.completedAt != nil,
                  session.id != excludingSessionID,
                  se.exercise?.id == targetID,
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
            // The logs are read in workout order, and a later log's set
            // replaces the pick only when it is heavier, so the earlier
            // log's set wins a tie in weight.
            var heaviest: SetEntry?
            for se in logs.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                let workingSets = (se.sets ?? []).filter { entry in
                    !entry.isWarmup && entry.reps > 0 && entry.isComplete
                }
                guard let logTop = workingSets.max(by: { $0.weight < $1.weight }) else { continue }
                if let best = heaviest, best.weight >= logTop.weight { continue }
                heaviest = logTop
            }
            guard let topSet = heaviest else {
                // This session logged the exercise but no working set was
                // committed (e.g., user discarded mid-session). Walk back
                // further until we find one with committed working sets.
                continue
            }
            return PreviousMatchingIntentHit(
                weight: topSet.weight,
                reps: topSet.reps,
                rpe: topSet.rpe,
                sessionStartedAt: session.startedAt
            )
        }
        return nil
    }
}
