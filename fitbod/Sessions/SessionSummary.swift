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
//  "Working set" here means a completed, non-warm-up set with reps > 0, so
//  drop / failure / rest-pause sets count toward set and volume totals.
//  PRs use PRDetector's stricter working-set rule against a table built
//  from finished sessions that started before this one.
//

import Foundation
import SwiftData

public struct SessionSummary: Sendable, Equatable {

    public struct BestSet: Sendable, Equatable {
        public let weight: Double
        public let reps: Int
        public let rpe: Double?
    }

    public struct ExerciseLine: Sendable, Equatable, Identifiable {
        public let id: UUID
        public let name: String
        public let workingSets: Int
        public let volume: Double
        public let best: BestSet?
        /// PR kinds this exercise set today, canonical order.
        public let prKinds: [PRKind]
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

        // PR check walks today's sets in the order they were logged, so a
        // second heavier set beats the first, not the other way round.
        let todaysSets = ordered
            .flatMap { $0.sets ?? [] }
            .filter { $0.isComplete && !$0.isWarmup }
            .sorted { $0.completedAt < $1.completedAt }
        var prsByExercise: [UUID: Set<PRKind>] = [:]
        for set in todaysSets {
            let hits = PRDetector.check(set: set, against: &table)
            guard !hits.isEmpty, let seID = set.sessionExercise?.id else { continue }
            prsByExercise[seID, default: []].formUnion(hits)
        }

        var lines: [ExerciseLine] = []
        for se in ordered {
            let working = (se.sets ?? []).filter(isCountedWorkingSet)
            let volume = working.reduce(0) { $0 + $1.weight * Double($1.reps) }
            let bestEntry = working.max { lhs, rhs in
                if lhs.weight != rhs.weight { return lhs.weight < rhs.weight }
                return lhs.reps < rhs.reps
            }
            let kinds = prsByExercise[se.id] ?? []
            let name = se.displayName
            lines.append(ExerciseLine(
                id: se.id,
                name: name.isEmpty ? "Exercise" : name,
                workingSets: working.count,
                volume: volume,
                best: bestEntry.map { BestSet(weight: $0.weight, reps: $0.reps, rpe: $0.rpe) },
                prKinds: PRKind.allCases.filter { kinds.contains($0) }
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
        var table = PRTable()
        var result: [UUID: SessionPRs] = [:]
        let finished = sessions
            .filter { $0.completedAt != nil }
            .sorted { $0.startedAt < $1.startedAt }
        for session in finished {
            let sets = (session.exercises ?? [])
                .flatMap { $0.sets ?? [] }
                .filter { $0.isComplete && !$0.isWarmup }
                .sorted { $0.completedAt < $1.completedAt }
            // Grouped by logged exercise, as in `make`, so the count is the
            // number of PR kinds the summary lists across its exercises.
            var kindsByExercise: [UUID: Set<PRKind>] = [:]
            for set in sets {
                let hits = PRDetector.check(set: set, against: &table)
                guard !hits.isEmpty, let seID = set.sessionExercise?.id else { continue }
                kindsByExercise[seID, default: []].formUnion(hits)
            }
            guard !kindsByExercise.isEmpty else { continue }
            let kinds = kindsByExercise.values.reduce(into: Set<PRKind>()) { $0.formUnion($1) }
            result[session.id] = SessionPRs(
                kinds: PRKind.allCases.filter { kinds.contains($0) },
                count: kindsByExercise.values.reduce(0) { $0 + $1.count }
            )
        }
        return result
    }

    private static func isCountedWorkingSet(_ set: SetEntry) -> Bool {
        set.isComplete && !set.isWarmup && set.reps > 0
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
