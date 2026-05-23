//
//  SeriesBuilder.swift
//  fitbod
//
//  Wave-3 plan 06-05 — pure-function series builder consumed by
//  `ExerciseProgressView`. Turns a flat `[SessionExercise]` (Phase
//  1 cascade-loaded with their SetEntries) into a chartable
//  `[E1RMSeriesPoint]` array.
//
//  Per-session output (CONTEXT D-05 + D-06):
//
//    - Top set (D-05): among working+committed+non-warmup sets,
//      pick the SetEntry with the highest OneRepMax.estimate;
//      tiebreaker 1 highest weight, tiebreaker 2 latest completedAt.
//      Sets with reps > 10 contribute nil e1RM and are therefore
//      excluded from the top-set pick (PROG-02 suppression).
//
//    - All-set avg (D-06): arithmetic mean of non-nil e1RMs across
//      ALL working sets of the session. Sets with reps > 10 are
//      excluded from the mean (the same suppression rule).
//
//  Sessions whose working sets are ALL > 10 reps yield zero points
//  for that session; the chart's auto-scale handles empty-series
//  gracefully via `chartXScale(.automatic(includesZero: false))`.
//
//  Pure value-type — no `@MainActor`, no SwiftData fetch. Callers
//  pass the SwiftData-fetched `[SessionExercise]` already; this
//  function is testable in isolation by constructing
//  `SessionExercise()` + `SetEntry()` instances with property
//  assignment.
//
//  [CITED: REQUIREMENTS PROG-01 + PROG-03 + CONTEXT D-05/D-06/D-07
//   + RESEARCH Pattern 1]
//

import Foundation
import SwiftData

/// One point on the chart — either a top-set or all-set-avg sample
/// for a single session.
public struct E1RMSeriesPoint: Identifiable, Sendable, Equatable {
    public let id: String
    public let date: Date
    public let e1RM: Double
    public let intent: Intent
    public let kind: SeriesKind

    public init(
        id: String,
        date: Date,
        e1RM: Double,
        intent: Intent,
        kind: SeriesKind
    ) {
        self.id = id
        self.date = date
        self.e1RM = e1RM
        self.intent = intent
        self.kind = kind
    }
}

/// Pure-function chart-series builder.
public enum SeriesBuilder {

    /// Emit at most 2 points per `SessionExercise`: one `.topSet` and
    /// one `.allSetAvg`. Sessions whose working sets are all > 10 reps
    /// (e1RM nil) emit zero points; sessions with no working sets emit
    /// zero points.
    public static func buildPoints(from sessionExercises: [SessionExercise]) -> [E1RMSeriesPoint] {
        var out: [E1RMSeriesPoint] = []
        for se in sessionExercises {
            guard let session = se.session else { continue }
            let intent = Intent(rawValue: session.intentRaw) ?? .strength
            let date = session.startedAt

            let workingSets = (se.sets ?? []).filter { entry in
                entry.setType == .working
                    && !entry.isWarmup
                    && entry.isComplete
                    && entry.weight > 0
                    && entry.reps > 0
            }
            // Each set's e1RM — nil for reps > 10 per PROG-02 suppression.
            let scored: [(set: SetEntry, e1RM: Double?)] = workingSets.map { entry in
                (entry, OneRepMax.estimate(weight: entry.weight, reps: entry.reps))
            }
            let nonNil = scored.compactMap { pair -> (set: SetEntry, e1RM: Double)? in
                guard let v = pair.e1RM else { return nil }
                return (pair.set, v)
            }
            // Skip session entirely when no usable e1RM samples.
            guard !nonNil.isEmpty else { continue }

            // Top-set per D-05: highest e1RM → highest weight → latest completedAt.
            let topSorted = nonNil.sorted { (lhs, rhs) in
                if lhs.e1RM != rhs.e1RM { return lhs.e1RM > rhs.e1RM }
                if lhs.set.weight != rhs.set.weight { return lhs.set.weight > rhs.set.weight }
                return lhs.set.completedAt > rhs.set.completedAt
            }
            if let top = topSorted.first {
                out.append(E1RMSeriesPoint(
                    id: "\(top.set.id.uuidString)-\(SeriesKind.topSet.rawValue)",
                    date: date,
                    e1RM: top.e1RM,
                    intent: intent,
                    kind: .topSet
                ))
            }

            // All-set avg per D-06: arithmetic mean of non-nil e1RMs.
            let mean = nonNil.map(\.e1RM).reduce(0, +) / Double(nonNil.count)
            // Stable id derived from session + se identifiers so the
            // Chart can diff across rebuilds without confusing the
            // top-set point.
            out.append(E1RMSeriesPoint(
                id: "\(se.id.uuidString)-\(SeriesKind.allSetAvg.rawValue)",
                date: date,
                e1RM: mean,
                intent: intent,
                kind: .allSetAvg
            ))
        }
        return out.sorted { $0.date < $1.date }
    }
}
