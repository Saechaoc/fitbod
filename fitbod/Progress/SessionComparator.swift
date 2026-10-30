//
//  SessionComparator.swift
//  fitbod
//
//  Wave-3 plan 06-04 — pure-function-with-one-fetch kernel that
//  powers `SessionComparisonView` (Wave 4 plan 06-07).
//  REQUIREMENTS PROG-07 + CONTEXT D-22..D-24 + D-05.
//
//  ## D-22 CORRECTION — load-bearing
//
//  CONTEXT D-22 literally states "session.intent" / "session.routine"
//  match per-session. RESEARCH §"Schema reality vs CONTEXT" overrides
//  this — the comparator must match PER-SessionExercise on the triple
//  `(sourceRoutineID, exerciseID, intentRaw)`. The reason has shifted
//  again since RESEARCH was written: Phase 3.1 PIVOT-02 moved
//  `intentRaw` from `SessionExercise` to `Session`. So the triple is
//  satisfied via:
//
//    1. prior.exercise?.id          == current.exercise?.id
//    2. prior.session?.intentRaw    == current.session?.intentRaw
//    3. prior.session?.sourceRoutineID == current.session?.sourceRoutineID
//    4. currentSession.startedAt - prior.session.startedAt ∈ (0, 14d)
//
//  Per exercise (not per session) so multi-exercise sessions surface
//  row-by-row diffs even when a single exercise pair lacks a comparable
//  prior. A workout that logs an exercise more than once gives one row,
//  in the order of its first log, read across every log of it; the
//  prior side reads every log of it in the most recent matching workout.
//
//  ## D-05 Top working set
//
//  Among the working sets of one workout's logs of the exercise (filtered
//  to setType==.working && !isWarmup && isComplete && reps > 0 && weight > 0),
//  pick the entry with the highest `OneRepMax.estimate(weight:reps:)`.
//  Tiebreaker 1: highest weight. Tiebreaker 2: latest completedAt.
//  The sets are read in log order, then set order (`orderIndex` both
//  times), so on a full tie the earlier set wins.
//  This matters for high-volume hypertrophy sessions where a higher-
//  rep lighter set produces a higher e1RM than a heavier single —
//  D-05 wants the chart series to reflect the actual training stimulus,
//  not the bar load.
//
//  ## Performance
//
//  One #Predicate fetch per exercise in the current session. For a
//  6-exercise session that's six fetches at view-appear. Phase 1's
//  `#Index<SessionExercise>([\.intentRaw])` doesn't help much here
//  (Phase 3.1 moved intent off SessionExercise) but Phase 1's
//  `#Index<Session>([\.sourceRoutineID])` is the index that the
//  Session-side filter reaches through.
//
//  [CITED: REQUIREMENTS PROG-07 + CONTEXT D-05/D-22/D-23 + RESEARCH
//   §Schema reality vs CONTEXT + Phase 3.1 PIVOT-02]
//

import Foundation
import SwiftData

/// One side of a per-exercise comparison row — the top working set
/// of a SessionExercise plus the e1RM estimate that drives the chart.
public struct TopSetSummary: Sendable, Equatable {
    public let weight: Double
    public let reps: Int
    public let rpe: Double?
    public let e1RM: Double?
    public let setEntryID: UUID
    public let sessionStartedAt: Date

    public init(
        weight: Double,
        reps: Int,
        rpe: Double?,
        e1RM: Double?,
        setEntryID: UUID,
        sessionStartedAt: Date
    ) {
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.e1RM = e1RM
        self.setEntryID = setEntryID
        self.sessionStartedAt = sessionStartedAt
    }
}

/// One row of the SessionComparisonView — diffs for one exercise
/// between the current session and the most recent matching prior.
public struct SessionComparisonRow: Sendable, Equatable {
    public let exerciseID: UUID
    public let exerciseName: String
    public let thisWeekTopSet: TopSetSummary?
    public let lastWeekTopSet: TopSetSummary?
    public let deltaWeight: Double?
    public let deltaReps: Int?
    public let deltaE1RM: Double?

    public init(
        exerciseID: UUID,
        exerciseName: String,
        thisWeekTopSet: TopSetSummary?,
        lastWeekTopSet: TopSetSummary?,
        deltaWeight: Double?,
        deltaReps: Int?,
        deltaE1RM: Double?
    ) {
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.thisWeekTopSet = thisWeekTopSet
        self.lastWeekTopSet = lastWeekTopSet
        self.deltaWeight = deltaWeight
        self.deltaReps = deltaReps
        self.deltaE1RM = deltaE1RM
    }
}

/// Pure-function-with-one-fetch session comparator.
public enum SessionComparator {

    // MARK: - Public API

    /// Compare every exercise in `current` against its most-recent
    /// matching prior workout per the corrected D-22 rule.
    /// Returns one row per exercise in `current`, in the order of its
    /// first log (`orderIndex` asc). Each side reads every log of the
    /// exercise in its workout.
    public static func compare(
        current: Session,
        context: ModelContext,
        windowDays: Int = 14
    ) -> [SessionComparisonRow] {
        // Each exercise's logs, in the order of its first log. A log whose
        // exercise was deleted from the library stays a row of its own.
        var groups: [(exercise: Exercise?, logs: [SessionExercise])] = []
        var groupIndex: [UUID: Int] = [:]
        for se in (current.exercises ?? []).sorted(by: { $0.orderIndex < $1.orderIndex }) {
            guard let exercise = se.exercise else {
                groups.append((nil, [se]))
                continue
            }
            if let index = groupIndex[exercise.id] {
                groups[index].logs.append(se)
            } else {
                groupIndex[exercise.id] = groups.count
                groups.append((exercise, [se]))
            }
        }

        var rows: [SessionComparisonRow] = []
        rows.reserveCapacity(groups.count)

        for (exercise, logs) in groups {
            let exerciseID = exercise?.id ?? UUID()
            let exerciseName = exercise?.name ?? ""
            let thisTop = topWorkingSet(in: logs)
            let priorLogs = findPriorMatch(
                exerciseID: exercise?.id,
                currentSession: current,
                context: context,
                windowDays: windowDays
            )
            let lastTop = topWorkingSet(in: priorLogs)

            let dWeight: Double? = (thisTop != nil && lastTop != nil)
                ? thisTop!.weight - lastTop!.weight
                : nil
            let dReps: Int? = (thisTop != nil && lastTop != nil)
                ? thisTop!.reps - lastTop!.reps
                : nil
            let dE1RM: Double? = {
                guard let t = thisTop, let l = lastTop,
                      let te = t.e1RM, let le = l.e1RM else { return nil }
                return te - le
            }()

            rows.append(SessionComparisonRow(
                exerciseID: exerciseID,
                exerciseName: exerciseName,
                thisWeekTopSet: thisTop,
                lastWeekTopSet: lastTop,
                deltaWeight: dWeight,
                deltaReps: dReps,
                deltaE1RM: dE1RM
            ))
        }

        return rows
    }

    /// Find the most-recent prior workout matching the
    /// `(sourceRoutineID, exerciseID, intent)` triple within the
    /// strict 14-day window (> 0 days, < windowDays days), and return
    /// every log of the exercise in it, in workout order (`orderIndex`).
    ///
    /// Returns no logs for any freestanding session (nil sourceRoutineID)
    /// because there's no template to match against, nor when no prior
    /// workout matches.
    public static func findPriorMatch(
        exerciseID: UUID?,
        currentSession: Session,
        context: ModelContext,
        windowDays: Int = 14
    ) -> [SessionExercise] {
        // Local-let captures for the #Predicate (RESEARCH Pitfall 3).
        guard let targetExerciseID = exerciseID else { return [] }
        guard let targetRoutineID = currentSession.sourceRoutineID else { return [] }
        let targetIntent = currentSession.intentRaw
        let upper = currentSession.startedAt
        let lower = currentSession.startedAt.addingTimeInterval(-Double(windowDays) * 86_400)

        // RESEARCH Pitfall #1 (multi-hop optional chains in #Predicate +
        // Swift 6 type-checker timeout): split the filter into a SIMPLE
        // single-hop predicate over Session (the cheap gate), then walk
        // each session's exercises in Swift to apply the multi-property
        // match. This is the same pattern Phase 5 FatigueModel uses.
        var sessionDescriptor = FetchDescriptor<Session>(
            predicate: #Predicate { sess in
                sess.sourceRoutineID == targetRoutineID
                    && sess.intentRaw == targetIntent
                    && sess.startedAt >= lower
                    && sess.startedAt < upper
            }
        )
        sessionDescriptor.fetchLimit = 50
        let candidateSessions = (try? context.fetch(sessionDescriptor)) ?? []
        let sorted = candidateSessions.sorted { $0.startedAt > $1.startedAt }

        for session in sorted {
            // Walk the session's exercises in Swift — Phase 1 cascade
            // rule keeps these eager-loaded with the parent Session.
            let logs = (session.exercises ?? [])
                .filter { $0.exercise?.id == targetExerciseID }
                .sorted { $0.orderIndex < $1.orderIndex }
            if !logs.isEmpty {
                return logs
            }
        }
        return []
    }

    // MARK: - Top set selection (D-05)

    /// Pick the top working set across one workout's `logs` of an
    /// exercise per CONTEXT D-05: highest `OneRepMax.estimate` → highest
    /// weight → latest completedAt. The logs are read in workout order and
    /// each log's sets in set order (`orderIndex` both times), whatever
    /// order SwiftData returns them in, so on a full tie the earlier set
    /// wins.
    private static func topWorkingSet(in logs: [SessionExercise]) -> TopSetSummary? {
        let workingSets = logs
            .sorted { $0.orderIndex < $1.orderIndex }
            .flatMap { se in
                (se.sets ?? [])
                    .filter { entry in
                        entry.setType == .working
                            && !entry.isWarmup
                            && entry.isComplete
                            && entry.weight > 0
                            && entry.reps > 0
                    }
                    .sorted { $0.orderIndex < $1.orderIndex }
            }

        // Rank by e1RM, then weight, then completedAt. `max(by:)` keeps
        // the first of equal elements, so a full tie goes to the earlier set.
        let top = workingSets.max { (lhs, rhs) in
            let lhsE = OneRepMax.estimate(weight: lhs.weight, reps: lhs.reps) ?? 0
            let rhsE = OneRepMax.estimate(weight: rhs.weight, reps: rhs.reps) ?? 0
            if lhsE != rhsE { return lhsE < rhsE }
            if lhs.weight != rhs.weight { return lhs.weight < rhs.weight }
            return lhs.completedAt < rhs.completedAt
        }
        guard let top else { return nil }
        return TopSetSummary(
            weight: top.weight,
            reps: top.reps,
            rpe: top.rpe,
            e1RM: OneRepMax.estimate(weight: top.weight, reps: top.reps),
            setEntryID: top.id,
            sessionStartedAt: logs.first?.session?.startedAt ?? top.completedAt
        )
    }
}
