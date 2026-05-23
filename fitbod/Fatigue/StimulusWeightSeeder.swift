//
//  StimulusWeightSeeder.swift
//  fitbod
//
//  Phase 5 — VOL-01 curated stimulus-weighting seeder.
//
//  Idempotent: re-running overwrites curated rows WITHOUT touching
//  user-edited rows. User-edit preservation is tracked via
//  `ExerciseMuscleStimulus.userEditedWeight` (false → seeder writes;
//  true → seeder skips). No UserDefaults flag is used here — stimulus
//  weights may need re-seeding on app updates (e.g. when the curation
//  table grows), so a row-level guard is required (per RESEARCH §6.3).
//
//  T-05-01 mitigation: every weight is range-clamped to [0, 1] before
//  the persistence write. The static-literal `StimulusWeightTable.overrides`
//  values are all in range by construction, but the clamp is
//  defense-in-depth against future curation drift OR an unedited
//  in-memory mutation of the table during testing.
//
//  Find-or-update semantics (not delete-and-recreate): the seeder
//  preserves the SwiftData identity of existing
//  `ExerciseMuscleStimulus` rows. Other relationships (e.g. snapshot
//  tests) may hold references to those rows; mutating in place is
//  safe, deleting+reinserting would break them.
//
//  @MainActor because ModelContext is @MainActor-bound under Swift 6
//  strict concurrency.
//

import Foundation
import SwiftData

@MainActor
public enum StimulusWeightSeeder {

    /// Seed the curated stimulus weights from `StimulusWeightTable.overrides`
    /// onto matching `ExerciseMuscleStimulus` rows. Rows where
    /// `userEditedWeight == true` are skipped. Missing rows (curated
    /// triple has no existing stimulus on the Exercise) are inserted.
    ///
    /// Re-runs on every launch are safe: rows whose curated values
    /// already match the table are written-through with the same
    /// values (idempotent at the value level too).
    ///
    /// - Parameter context: The main ModelContext.
    public static func seedIfNeeded(in context: ModelContext) {
        for (canonicalName, triples) in StimulusWeightTable.overrides {
            // 1. Locate the matching Exercise by canonicalName.
            let target = canonicalName
            let descriptor = FetchDescriptor<Exercise>(
                predicate: #Predicate<Exercise> { $0.canonicalName == target }
            )
            guard let exercise = (try? context.fetch(descriptor))?.first else { continue }

            for triple in triples {
                // 2a. Locate the muscle by slug.
                let slug = triple.muscleSlug
                let muscleDescriptor = FetchDescriptor<MuscleGroup>(
                    predicate: #Predicate<MuscleGroup> { $0.slug == slug }
                )
                guard let muscle = (try? context.fetch(muscleDescriptor))?.first else { continue }

                // 2b. Find or create the ExerciseMuscleStimulus row.
                let stims = exercise.muscleStimuli ?? []
                let existing = stims.first { $0.muscle?.slug == slug }
                if let row = existing {
                    // 2c. Skip user-edited rows (idempotency anchor).
                    if row.userEditedWeight { continue }
                    row.role = triple.role
                    row.weight = clampedWeight(triple.weight)
                } else {
                    let newStim = ExerciseMuscleStimulus()
                    newStim.role = triple.role
                    newStim.weight = clampedWeight(triple.weight)
                    newStim.muscle = muscle
                    newStim.exercise = exercise
                    context.insert(newStim)
                }
            }
        }
        try? context.save()
    }

    /// T-05-01 mitigation: clamp any curated weight to [0, 1] before
    /// it crosses the persistence boundary. `internal` so unit tests
    /// can call directly without exposing the helper to other modules.
    internal static func clampedWeight(_ w: Double) -> Double {
        max(0.0, min(1.0, w))
    }
}
