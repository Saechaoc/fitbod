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
//  Backed by Phase 1's `SessionExercise.intentRaw` #Index for O(log n)
//  lookup. RESEARCH §6 Pitfall 1 — extract `exerciseID`/`intentRaw`
//  to local vars before constructing the #Predicate (SwiftData
//  related-entity ID compare returns empty results without the
//  workaround on iOS 17/18).
//

import Foundation
import SwiftData

/// One hit from the previous-matching-intent query: the top working set
/// of the most recent matching `SessionExercise` for an (exerciseID,
/// intentRaw) tuple.
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
    /// The "matching-intent" half is the load-bearing piece of ROUTINE-08
    /// (`same routine recurring with different intent maintains separate
    /// per-intent histories per exercise`). A strength session's top
    /// working set MUST NOT seed a hypertrophy session and vice versa.
    ///
    /// Performance: backed by Phase 1's `SessionExercise.intentRaw` #Index.
    /// `fetchLimit = 5` caps the descriptor at five most-recent
    /// SessionExercise rows; the first one with a committed working set
    /// wins. Bounding the descriptor matters once a user has months of
    /// training data — without the limit the entire matching-intent
    /// history is materialized into memory per call.
    public static func fetchTopWorkingSet(
        exerciseID: UUID?,
        intentRaw: String,
        context: ModelContext
    ) -> PreviousMatchingIntentHit? {
        guard let exerciseID else { return nil }

        // RESEARCH §6 Pitfall 1 — extract to locals BEFORE the #Predicate.
        // Comparing `se.exercise?.id == exerciseID` directly inside the
        // predicate triggers a known SwiftData footgun on iOS 17/18 where
        // the related-entity-ID compare silently returns empty results.
        let targetID = exerciseID
        let targetIntent = intentRaw

        var descriptor = FetchDescriptor<SessionExercise>(
            predicate: #Predicate { se in
                se.intentRaw == targetIntent && se.exercise?.id == targetID
            },
            sortBy: [SortDescriptor(\.session?.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 5

        guard let recent = try? context.fetch(descriptor) else { return nil }

        for se in recent {
            let workingSets = (se.sets ?? []).filter { entry in
                !entry.isWarmup && entry.reps > 0 && entry.isComplete
            }
            guard let topSet = workingSets.max(by: { $0.weight < $1.weight }) else {
                // This SessionExercise was started but no working set was
                // committed (e.g., user discarded mid-session). Walk back
                // further until we find one with committed working sets.
                continue
            }
            return PreviousMatchingIntentHit(
                weight: topSet.weight,
                reps: topSet.reps,
                rpe: topSet.rpe,
                sessionStartedAt: se.session?.startedAt ?? .distantPast
            )
        }
        return nil
    }
}
