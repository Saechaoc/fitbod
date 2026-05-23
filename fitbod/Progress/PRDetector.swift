//
//  PRDetector.swift
//  fitbod
//
//  Wave-2 plan 06-02 — pure-function PR table builder + single-set
//  detector (CONTEXT D-10..D-17, REQUIREMENTS PROG-05 + PROG-08).
//
//  Two surfaces consume the same kernel:
//    1. ExercisePRsView (Wave 2 list)         — calls buildTable once
//                                                  at view appear, reads
//                                                  PRTable.record(...)
//                                                  for display rows.
//    2. InSessionPRBanner (Wave 2 banner)     — calls buildTable once
//                                                  at SessionFactory.start,
//                                                  then check(set:against:)
//                                                  on every commit. The
//                                                  table mutates in place
//                                                  so D-16 stacking works
//                                                  ("Weight PR · Volume PR ·
//                                                   e1RM PR" on one banner)
//                                                  without re-queries.
//
//  PR table is keyed by `(exerciseID, Intent, PRKind, RepBucket)` —
//  CONTEXT D-10 partitions per exercise + intent so a strength PR
//  doesn't compete with a hypertrophy PR; D-11 partitions per rep
//  bucket so a 5RM PR doesn't compete with an 8RM PR.
//
//  Schema reality (verified 2026-05-23 against fitbod/Models/):
//    - SetEntry.weight: Double
//    - SetEntry.reps: Int
//    - SetEntry.rpe: Double?
//    - SetEntry.completedAt: Date
//    - SetEntry.setType (computed from setTypeRaw)
//    - SetEntry.isWarmup: Bool
//    - SetEntry.isComplete: Bool
//    - SetEntry.wasManualOverride: Bool — REAL Phase 1 field. Per
//      CONTEXT D-17, this does NOT suppress PR detection: an honest
//      higher-weight set is a real PR regardless of how the user
//      entered the weight.
//    - Intent lives on Session.intentRaw (Phase 3.1 PIVOT-02 moved
//      it off SessionExercise). Reach via
//      set.sessionExercise?.session?.intentRaw.
//
//  Working-set filter (defense in depth, matching
//  WeeklyTonnageAggregator + FatigueModel):
//    set.setType == .working
//      && !set.isWarmup
//      && set.isComplete
//      && set.weight > 0
//      && set.reps > 0
//
//  e1RM suppression (PROG-02 + D-04): OneRepMax.estimate returns nil
//  for reps > 10. PRDetector treats this as "no e1RM PR slot in the
//  highRep bucket" — check(set:) never returns .e1RM for an 11+ rep
//  set, even when it newly tops the other PR kinds.
//
//  No SwiftData coupling beyond reading published `@Model` properties.
//  Pure value-type API; PRTable is a Sendable struct that callers
//  can hold in `@Observable` session state without actor friction.
//
//  [CITED: CONTEXT D-10/D-11/D-14/D-16/D-17 + RESEARCH Pitfall 1
//   (wasManualOverride is real) + Pitfall 6 (cache table once at
//   session start, never per-set re-query)]
//

import Foundation
import SwiftData

/// A single PR record — the source set that established the record
/// for one `(exerciseID, intent, kind, bucket)` slot.
public struct PRRecord: Sendable, Equatable {
    public let weight: Double
    public let reps: Int
    public let rpe: Double?
    public let setEntryID: UUID
    public let sessionStartedAt: Date

    public init(
        weight: Double,
        reps: Int,
        rpe: Double?,
        setEntryID: UUID,
        sessionStartedAt: Date
    ) {
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.setEntryID = setEntryID
        self.sessionStartedAt = sessionStartedAt
    }
}

/// In-memory PR table built from a flat `[SetEntry]`. Read via
/// `record(exerciseID:intent:kind:bucket:)` for display; mutated
/// in place by `PRDetector.check(set:against:)` during a live
/// session so the banner can stack multiple PRs from one set.
public struct PRTable: Sendable {

    /// Composite key — value type so it can live inside Sendable dicts.
    fileprivate struct Key: Hashable, Sendable {
        let exerciseID: UUID
        let intent: Intent
        let kind: PRKind
        let bucket: RepBucket
    }

    fileprivate var storage: [Key: PRRecord] = [:]

    public init() {}

    /// Look up the current PR record (if any) for the given slot.
    public func record(
        exerciseID: UUID,
        intent: Intent,
        kind: PRKind,
        bucket: RepBucket
    ) -> PRRecord? {
        storage[Key(exerciseID: exerciseID, intent: intent, kind: kind, bucket: bucket)]
    }

    /// Total number of recorded slots — useful for tests + analytics.
    public var recordedSlotCount: Int { storage.count }

    /// All records keyed by `(exerciseID, intent)` for ExercisePRsView
    /// grouped-list rendering. Sorted for stable iteration.
    public func allRecords(
        forExerciseID exerciseID: UUID,
        intent: Intent
    ) -> [(kind: PRKind, bucket: RepBucket, record: PRRecord)] {
        var rows: [(kind: PRKind, bucket: RepBucket, record: PRRecord)] = []
        for kind in PRKind.allCases {
            for bucket in RepBucket.allCases {
                if let rec = record(exerciseID: exerciseID, intent: intent, kind: kind, bucket: bucket) {
                    rows.append((kind: kind, bucket: bucket, record: rec))
                }
            }
        }
        return rows
    }

    // MARK: - Mutating helpers (internal to PRDetector)

    fileprivate mutating func upsertIfTops(
        candidate: PRRecord,
        forKey key: Key,
        comparator: (PRRecord, PRRecord) -> Bool
    ) -> Bool {
        if let existing = storage[key] {
            // Strictly beats — equal does NOT count as a new PR (CONTEXT D-16 tie rule).
            if comparator(candidate, existing) {
                storage[key] = candidate
                return true
            }
            return false
        } else {
            // First record in this slot is automatically the PR.
            storage[key] = candidate
            return true
        }
    }
}

/// Pure-function PR table builder + single-set detector.
public enum PRDetector {

    // MARK: - Public API

    /// Build the full PR table from a flat `[SetEntry]` history.
    /// Filters to working+committed+non-warmup+positive sets and
    /// partitions by `(exerciseID, intent, PRKind, RepBucket)`.
    public static func buildTable(from sets: [SetEntry]) -> PRTable {
        var table = PRTable()
        for entry in sets {
            // Mutating call must use the existing var.
            _ = check(set: entry, against: &table)
        }
        return table
    }

    /// Evaluate a single set against the live table. Returns the set
    /// of `PRKind`s the set newly tops (in canonical UI order via the
    /// caller's choice of iteration), and mutates the table in place
    /// so subsequent sets see the new records.
    ///
    /// Returns an empty set when:
    ///   - the set is not a working/committed/non-warmup/positive set
    ///   - the set is a tie or worse on every PR kind
    public static func check(set: SetEntry, against table: inout PRTable) -> Set<PRKind> {
        guard isWorkingSet(set),
              let exercise = set.sessionExercise?.exercise,
              let session = set.sessionExercise?.session,
              let bucket = RepBucket.bucket(for: set.reps) else {
            return []
        }
        let intent = Intent(rawValue: session.intentRaw) ?? .strength
        let exerciseID = exercise.id

        let candidate = PRRecord(
            weight: set.weight,
            reps: set.reps,
            rpe: set.rpe,
            setEntryID: set.id,
            sessionStartedAt: session.startedAt
        )

        var topped: Set<PRKind> = []

        // Weight PR — strictly heavier load wins (matches plate-rounded reality).
        let weightKey = PRTable.Key(
            exerciseID: exerciseID, intent: intent, kind: .weight, bucket: bucket
        )
        if table.upsertIfTops(candidate: candidate, forKey: weightKey, comparator: { new, old in
            new.weight > old.weight
        }) {
            topped.insert(.weight)
        }

        // Reps PR — strictly more reps wins.
        let repsKey = PRTable.Key(
            exerciseID: exerciseID, intent: intent, kind: .reps, bucket: bucket
        )
        if table.upsertIfTops(candidate: candidate, forKey: repsKey, comparator: { new, old in
            new.reps > old.reps
        }) {
            topped.insert(.reps)
        }

        // Volume PR — strictly more (weight × reps) wins.
        let volumeKey = PRTable.Key(
            exerciseID: exerciseID, intent: intent, kind: .volume, bucket: bucket
        )
        if table.upsertIfTops(candidate: candidate, forKey: volumeKey, comparator: { new, old in
            (new.weight * Double(new.reps)) > (old.weight * Double(old.reps))
        }) {
            topped.insert(.volume)
        }

        // e1RM PR — only meaningful for non-highRep buckets per D-04 suppression.
        if bucket != .highRep, let newE1RM = OneRepMax.estimate(weight: set.weight, reps: set.reps) {
            let e1RMKey = PRTable.Key(
                exerciseID: exerciseID, intent: intent, kind: .e1RM, bucket: bucket
            )
            if table.upsertIfTops(candidate: candidate, forKey: e1RMKey, comparator: { new, old in
                // Compute both sides on demand — the candidate's e1RM is newE1RM,
                // the incumbent's e1RM is recomputed from its stored weight/reps.
                let oldE1RM = OneRepMax.estimate(weight: old.weight, reps: old.reps) ?? 0
                return newE1RM > oldE1RM
            }) {
                topped.insert(.e1RM)
            }
        }

        return topped
    }

    // MARK: - Internal helpers

    /// Working-set predicate shared with WeeklyTonnageAggregator and
    /// the in-session detector banner. Returns false for warmups,
    /// drop sets, incompletes, or non-positive inputs.
    @inlinable
    public static func isWorkingSet(_ set: SetEntry) -> Bool {
        set.setType == .working
            && !set.isWarmup
            && set.isComplete
            && set.weight > 0
            && set.reps > 0
    }
}
