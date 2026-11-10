//
//  SessionSummary.swift
//  fitbod
//
//  Value-type roll-up of one logged workout, rendered by SessionDetailView
//  (the post-Finish summary and the history detail screen).
//
//  Everything is read from the logged rows: exercise names come from the
//  log-time snapshot (`SessionExercise.displayName`), and numbers come from
//  completed SetEntry rows only. Nothing is projected from the template.
//
//  "Working set" here means a completed, non-warm-up set with reps or a
//  time (`SetEntry.hasResult`), so drop / failure / rest-pause sets count
//  toward set and volume totals, and timed sets toward the set total.
//  PRs use PRDetector's stricter working-set rule against a table built
//  from finished sessions that started before this one.
//

import Foundation
import SwiftData

public struct SessionSummary: Sendable, Equatable {

    /// One counted working set, as the summary lists it.
    public struct LoggedSet: Sendable, Equatable {
        public let weight: Double
        public let reps: Int
        public let rpe: Double?
        public let isBest: Bool
        public var durationSeconds: Int? = nil
        public var distanceMeters: Double? = nil
        public var level: Double? = nil
    }

    public struct ExerciseLine: Sendable, Equatable, Identifiable {
        public let id: UUID
        public let name: String
        public let workingSets: Int
        public let volume: Double
        /// PR kinds this exercise set today, canonical order.
        public let prKinds: [PRKind]
        /// Every counted working set, in logged order.
        public let sets: [LoggedSet]
    }

    public let durationSeconds: Int
    public let workingSetCount: Int
    public let totalVolume: Double
    public let exercises: [ExerciseLine]

    /// Number of exercises with at least one PR.
    public var prExerciseCount: Int { exercises.filter { !$0.prKinds.isEmpty }.count }

    // MARK: - Builders

    /// Pure builder. `priorSets` is the history the PR check runs against;
    /// pass sets from finished sessions that started before `session`.
    public static func make(session: Session, priorSets: [SetEntry], now: Date = .now) -> SessionSummary {
        var table = PRDetector.buildTable(from: priorSets)

        let ordered = (session.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }

        // The replay walks today's sets in the order they were logged, so a
        // second heavier set beats the first, not the other way round.
        let todaysSets = ordered
            .flatMap { $0.sets ?? [] }
            .filter { $0.isComplete && !$0.isWarmup }
        var prsByExercise: [UUID: Set<PRKind>] = [:]
        for record in PRDetector.replay(todaysSets, into: &table) {
            guard let seID = record.set.sessionExercise?.id else { continue }
            prsByExercise[seID, default: []].formUnion(record.kinds)
        }

        var lines: [ExerciseLine] = []
        for se in ordered {
            let working = SessionSetActions.ordered(se).filter(isCountedWorkingSet)
            let volume = working.reduce(0) { $0 + $1.tonnage }
            // Heaviest, then most reps; among timed sets, the longest.
            func rank(_ set: SetEntry) -> (Double, Int, Int) {
                (set.weight, set.reps, set.isTimed ? set.durationSeconds ?? 0 : 0)
            }
            let bestEntry = working.max { rank($0) < rank($1) }
            let kinds = prsByExercise[se.id] ?? []
            let name = se.displayName
            lines.append(ExerciseLine(
                id: se.id,
                name: name.isEmpty ? "Exercise" : name,
                workingSets: working.count,
                volume: volume,
                prKinds: PRKind.allCases.filter { kinds.contains($0) },
                sets: working.map {
                    LoggedSet(
                        weight: $0.weight, reps: $0.reps, rpe: $0.rpe, isBest: $0.id == bestEntry?.id,
                        durationSeconds: $0.durationSeconds, distanceMeters: $0.distanceMeters, level: $0.level
                    )
                }
            ))
        }

        let duration: Int
        if let stored = session.totalDurationSeconds {
            duration = stored
        } else {
            duration = max(0, Int((session.completedAt ?? now).timeIntervalSince(session.startedAt)))
        }

        return SessionSummary(
            durationSeconds: duration,
            workingSetCount: lines.reduce(0) { $0 + $1.workingSets },
            totalVolume: lines.reduce(0) { $0 + $1.volume },
            exercises: lines
        )
    }

    /// Fetching builder: collects the prior history for this session's
    /// exercises (finished sessions that started earlier), then builds.
    /// Broad fetch + Swift filter, no multi-level optional chains inside
    /// #Predicate (project rule).
    @MainActor
    public static func make(session: Session, context: ModelContext) -> SessionSummary {
        let exerciseIDs = Set((session.exercises ?? []).compactMap { $0.exercise?.id })
        let sessionID = session.id
        let startedAt = session.startedAt
        let descriptor = FetchDescriptor<SetEntry>(
            predicate: #Predicate<SetEntry> { $0.isComplete && !$0.isWarmup },
            sortBy: [SortDescriptor(\.completedAt)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        let prior = all.filter { entry in
            guard let se = entry.sessionExercise,
                  let owner = se.session,
                  let exerciseID = se.exercise?.id
            else { return false }
            return owner.id != sessionID
                && owner.completedAt != nil
                && owner.startedAt < startedAt
                && exerciseIDs.contains(exerciseID)
        }
        return make(session: session, priorSets: prior)
    }

    /// The records each finished session set, keyed by session id. One
    /// chronological pass over every session, so each session is checked
    /// against the records of the sessions that started before it: the
    /// same rule `make` applies to one session. Sessions without a PR are
    /// left out.
    public static func prsBySession(_ sessions: [Session]) -> [UUID: SessionPRs] {
        let sets = sessions
            .filter { $0.completedAt != nil }
            .flatMap { ($0.exercises ?? []).flatMap { $0.sets ?? [] } }
            .filter { $0.isComplete && !$0.isWarmup }
        // Grouped by session, then by logged exercise, as in `make`, so the
        // count is the number of PR kinds the summary lists across its
        // exercises.
        var kindsBySession: [UUID: [UUID: Set<PRKind>]] = [:]
        var table = PRTable()
        for record in PRDetector.replay(sets, into: &table) {
            guard let se = record.set.sessionExercise, let sessionID = se.session?.id else { continue }
            kindsBySession[sessionID, default: [:]][se.id, default: []].formUnion(record.kinds)
        }
        return kindsBySession.mapValues { kindsByExercise in
            let kinds = kindsByExercise.values.reduce(into: Set<PRKind>()) { $0.formUnion($1) }
            return SessionPRs(
                kinds: PRKind.allCases.filter { kinds.contains($0) },
                count: kindsByExercise.values.reduce(0) { $0 + $1.count }
            )
        }
    }

    private static func isCountedWorkingSet(_ set: SetEntry) -> Bool {
        set.countsAsWork && set.hasResult
    }
}

/// The personal records one finished session set, as its history row
/// shows them.
public struct SessionPRs: Sendable, Equatable {
    /// Every kind of record the session set, canonical order.
    public let kinds: [PRKind]
    /// One per exercise and kind, so weight records on two lifts count as
    /// 2: the same total as the PR kinds the summary lists per exercise.
    public let count: Int
}
