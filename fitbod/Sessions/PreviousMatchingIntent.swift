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
//  `lastWorkingSets`, also gives SessionFactory.prescription
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
    public let durationSeconds: Int?
    public let distanceMeters: Double?
    public let level: Double?
    /// True when the set was done on another machine than the one asked
    /// about, or without one (RM-066): a reference, never a base for a load.
    public let onOtherMachine: Bool
    /// The machine the set was done on, by name; nil when none was named.
    public let machineName: String?

    public init(
        weight: Double, reps: Int, rpe: Double?, sessionStartedAt: Date,
        durationSeconds: Int? = nil, distanceMeters: Double? = nil, level: Double? = nil,
        onOtherMachine: Bool = false, machineName: String? = nil
    ) {
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.sessionStartedAt = sessionStartedAt
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.level = level
        self.onOtherMachine = onOtherMachine
        self.machineName = machineName
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
    ///   - actually logged (`hasResult`: reps, or a time for a timed set)
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
    /// `lastWorkingSets`, shared with `SessionFactory.prescription`.
    ///
    /// Only FINISHED sessions count as "previous" (`completedAt != nil`),
    /// most recent first. The in-progress session and any abandoned,
    /// never-finished session are excluded, so a set the user just logged
    /// can never show up as its own "previous" value. Pass
    /// `excludingSessionID` (the current session) as a second guard for
    /// callers that run while a session is open.
    ///
    /// `machineID` is the machine of the log asking (RM-066), nil for none:
    /// the hit comes from that machine's workouts, or, when it has none,
    /// from any machine with `onOtherMachine` set.
    public static func fetchTopWorkingSet(
        exerciseID: UUID?,
        intentRaw: String,
        context: ModelContext,
        excludingSessionID: UUID? = nil,
        machineID: UUID? = nil
    ) -> PreviousMatchingIntentHit? {
        guard let exerciseID,
              let last = lastWorkingSets(
                  in: logs(of: exerciseID, context: context),
                  intentRaw: intentRaw,
                  excludingSessionID: excludingSessionID,
                  machineID: machineID
              )
        else { return nil }

        return topWorkingSet(in: (last.session, last.sets), onOtherMachine: last.onOtherMachine)
    }

    static func topWorkingSet(
        in last: (session: Session, sets: [SetEntry]), onOtherMachine: Bool = false
    ) -> PreviousMatchingIntentHit? {
        // The sets come in workout order, then set order, and `max(by:)`
        // keeps the first of equal elements, so the earlier set wins a tie
        // in weight, inside one log as across logs.
        // The heaviest set; among timed sets of one load, the longest.
        func rank(_ set: SetEntry) -> (Double, Int) { (set.weight, set.isTimed ? set.durationSeconds ?? 0 : 0) }
        guard let topSet = last.sets.max(by: { rank($0) < rank($1) }) else { return nil }
        return PreviousMatchingIntentHit(
            weight: topSet.weight,
            reps: topSet.reps,
            rpe: topSet.rpe,
            sessionStartedAt: last.session.startedAt,
            durationSeconds: topSet.durationSeconds,
            distanceMeters: topSet.distanceMeters,
            level: topSet.level,
            onOtherMachine: onOtherMachine,
            machineName: topSet.sessionExercise?.machine?.displayName
        )
    }

    /// The working sets of the most recent matching-intent session that
    /// has any, read across every log of the exercise in it: in workout
    /// order, then set order (`orderIndex` both times), never in the order
    /// SwiftData returns them. A working set is non-warmup, logged
    /// (`hasResult`) and committed (`isComplete == true`). Returns nil when
    /// no such session exists.
    ///
    /// A session that logs the exercise more than once counts once, as in
    /// `PlateauDetector.finishedSessionLogs`. Only FINISHED sessions
    /// (`completedAt != nil`) of `intentRaw` count, never
    /// `excludingSessionID`. A session whose logs hold no working set is
    /// skipped, and the walk back stops after five sessions.
    ///
    /// `fetchTopWorkingSet` and `SessionFactory.prescription`
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
        return lastWorkingSets(
            in: logs(of: exerciseID, context: context),
            intentRaw: intentRaw,
            excludingSessionID: excludingSessionID
        )
    }

    /// Every log of the exercise, in any session, with each log's session
    /// and sets loaded in one fetch. `SessionFactory.prescription` reads
    /// these rows once for both `lastWorkingSets(in:)` and
    /// `SessionFactory.historyPoints(in:intentRaw:)`.
    static func logs(of exerciseID: UUID, context: ModelContext) -> [SessionExercise] {
        // RESEARCH §6 Pitfall 1 — local-let captures before #Predicate.
        // SortDescriptor on optional keypath (\.session?.startedAt)
        // also caused type-checking failures in the Swift 6 toolchain
        // — sort in Swift after fetch.
        let targetID = exerciseID
        var descriptor = FetchDescriptor<SessionExercise>(
            predicate: #Predicate { se in se.exercise?.id == targetID }
        )
        // Callers read every row's session and sets: load them in bulk
        // instead of one fault per row.
        descriptor.relationshipKeyPathsForPrefetching = [\.session, \.sets]
        return (try? context.fetch(descriptor)) ?? []
    }

    /// The last matching workout for a log on `machineID` (RM-066). Loads
    /// compare only within one machine, and logs without a machine are one
    /// group of their own, so the walk reads that machine's logs first.
    /// When they hold no matching workout, it reads every log and sets
    /// `onOtherMachine`: those sets are shown for reference, and nothing
    /// is progressed or offered from them.
    static func lastWorkingSets(
        in all: [SessionExercise],
        intentRaw: String,
        excludingSessionID: UUID? = nil,
        machineID: UUID?,
        counting: (SetEntry) -> Bool = { $0.hasResult }
    ) -> (session: Session, sets: [SetEntry], onOtherMachine: Bool)? {
        let sameMachine = all.filter { $0.machine?.id == machineID }
        if let last = lastWorkingSets(
            in: sameMachine, intentRaw: intentRaw, excludingSessionID: excludingSessionID, counting: counting
        ) {
            return (last.session, last.sets, false)
        }
        return lastWorkingSets(
            in: all, intentRaw: intentRaw, excludingSessionID: excludingSessionID, counting: counting
        ).map { ($0.session, $0.sets, true) }
    }

    /// `lastWorkingSets` over logs the caller already fetched with `logs(of:)`.
    /// `counting` says which logged sets count: any with a result for
    /// display, and for the next prescription only those in the shape the
    /// exercise tracks now.
    static func lastWorkingSets(
        in all: [SessionExercise],
        intentRaw: String,
        excludingSessionID: UUID? = nil,
        counting: (SetEntry) -> Bool = { $0.hasResult }
    ) -> (session: Session, sets: [SetEntry])? {
        let targetIntent = intentRaw

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
                        .filter { !$0.isWarmup && $0.isComplete && counting($0) }
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
