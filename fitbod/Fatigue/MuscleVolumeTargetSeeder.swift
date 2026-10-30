//
//  MuscleVolumeTargetSeeder.swift
//  fitbod
//
//  Phase 5 VOL-03 + SET-05 — RP MEV/MAV/MRV seeder per RESEARCH §7.3.
//
//  Idempotent: re-running overwrites rows where `userEdited == false`;
//  user-edited rows are skipped (preservation of user customization).
//  NO UserDefaults flag — RP landmarks may be updated on app updates,
//  so a row-level guard is the right contract.
//
//  Threat T-05-02 mitigation (monotonic invariant): the seeder writes
//  values directly from `RPVolumeLandmarks.landmarks` which is
//  pre-validated as monotonic (MV ≤ MEV < MAV < MRV). The
//  MuscleVolumeTargetStepper editor enforces the invariant at edit
//  time; the seeder cannot introduce a non-monotonic row because it
//  never modifies a single field in isolation.
//
//  @MainActor because ModelContext is @MainActor-bound under Swift 6.
//

import Foundation
import SwiftData

@MainActor
public enum MuscleVolumeTargetSeeder {

    /// Seed or refresh MuscleVolumeTarget rows from RP landmarks. For
    /// each `MuscleGroup` seeded by the Phase 1 importer, locate (or
    /// create) the matching MuscleVolumeTarget and write the RP
    /// values when `userEdited == false`. Idempotent — safe to call
    /// on every launch.
    public static func seedIfNeeded(in context: ModelContext) {
        let muscleDescriptor = FetchDescriptor<MuscleGroup>()
        let muscles = (try? context.fetch(muscleDescriptor)) ?? []

        for muscle in muscles {
            let slug = muscle.slug
            let landmark = RPVolumeLandmarks.landmark(for: slug)

            let targetDescriptor = FetchDescriptor<MuscleVolumeTarget>(
                predicate: #Predicate<MuscleVolumeTarget> { $0.muscle?.slug == slug }
            )
            let existing = (try? context.fetch(targetDescriptor))?.first

            if let target = existing {
                // Skip user-edited rows — VOL-03 / SET-05 preservation.
                if target.userEdited { continue }
                // Write only what differs: an equal assignment still marks
                // the row changed, so every launch saved all 17 rows.
                if target.mv != landmark.mv { target.mv = landmark.mv }
                if target.mev != landmark.mev { target.mev = landmark.mev }
                if target.mav != landmark.mav { target.mav = landmark.mav }
                if target.mrv != landmark.mrv { target.mrv = landmark.mrv }
            } else {
                let newTarget = MuscleVolumeTarget()
                newTarget.muscle = muscle
                newTarget.mv = landmark.mv
                newTarget.mev = landmark.mev
                newTarget.mav = landmark.mav
                newTarget.mrv = landmark.mrv
                newTarget.userEdited = false
                context.insert(newTarget)
            }
        }

        try? context.save()
    }
}
