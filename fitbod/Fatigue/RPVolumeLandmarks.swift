//
//  RPVolumeLandmarks.swift
//  fitbod
//
//  RP-anchored MEV / MAV / MRV / MV per muscle per RESEARCH §7.1.
//  Sourced from arvo.guru/tools/volume-calculator's aggregation of
//  Renaissance Periodization's per-muscle hypertrophy guides.
//
//  Confidence:
//    HIGH (cited): chest, lats, middle back, traps, lower back, shoulders
//                  (aggregate), biceps, triceps, quadriceps, hamstrings,
//                  glutes, calves, forearms, abdominals (MEV/MAV).
//    [ASSUMED]:    neck, abductors, adductors, abdominals MRV — no
//                  canonical RP table; derived from glutes/hamstrings
//                  convention.
//
//  Coverage: all 17 free-exercise-db muscle slugs.
//
//  All values are working sets per week (integer per RP convention).
//
//  Phase 5 plan 06 wires `MuscleVolumeTargetSeeder` to consume this
//  table at first launch + on update, writing onto `MuscleVolumeTarget`
//  rows that have `userEdited == false` (idempotent — never stomps
//  user-tuned values per VOL-03 / SET-05).
//
//  No SwiftData coupling. No @MainActor. Implicitly Sendable.
//

import Foundation

/// RP-anchored MEV / MAV / MRV / MV per muscle, all 17 muscle slugs.
public enum RPVolumeLandmarks {

    /// Per-muscle weekly working-set landmarks. Integer values per RP
    /// convention.
    public struct Landmark: Sendable, Equatable {
        public let mv: Int
        public let mev: Int
        public let mav: Int
        public let mrv: Int

        public init(mv: Int, mev: Int, mav: Int, mrv: Int) {
            self.mv = mv
            self.mev = mev
            self.mav = mav
            self.mrv = mrv
        }
    }

    /// Curated landmarks keyed by free-exercise-db muscle slug. RESEARCH
    /// §7.1 verbatim. All 17 slugs present.
    public static let landmarks: [String: Landmark] = [
        "chest":       Landmark(mv: 6, mev: 8,  mav: 16, mrv: 22),
        "lats":        Landmark(mv: 6, mev: 8,  mav: 18, mrv: 25),
        "middle back": Landmark(mv: 6, mev: 10, mav: 16, mrv: 20),
        "traps":       Landmark(mv: 4, mev: 6,  mav: 12, mrv: 16),
        "lower back":  Landmark(mv: 4, mev: 6,  mav: 10, mrv: 14),
        "shoulders":   Landmark(mv: 6, mev: 8,  mav: 18, mrv: 25),
        "biceps":      Landmark(mv: 4, mev: 6,  mav: 14, mrv: 20),
        "triceps":     Landmark(mv: 4, mev: 4,  mav: 12, mrv: 18),
        "quadriceps":  Landmark(mv: 6, mev: 6,  mav: 16, mrv: 20),
        "hamstrings":  Landmark(mv: 4, mev: 4,  mav: 12, mrv: 16),
        "glutes":      Landmark(mv: 4, mev: 4,  mav: 14, mrv: 20),
        "calves":      Landmark(mv: 6, mev: 6,  mav: 14, mrv: 20),
        "abdominals":  Landmark(mv: 4, mev: 6,  mav: 16, mrv: 25),
        "forearms":    Landmark(mv: 2, mev: 4,  mav: 10, mrv: 16),
        // [ASSUMED] — no canonical RP table for neck in hypertrophy
        // literature. Conservative starting values.
        "neck":        Landmark(mv: 2, mev: 4,  mav:  8, mrv: 12),
        // [ASSUMED] — derived from glutes/hamstrings convention.
        "abductors":   Landmark(mv: 2, mev: 4,  mav: 10, mrv: 14),
        "adductors":   Landmark(mv: 2, mev: 4,  mav: 10, mrv: 14),
    ]

    /// Conservative fallback for unknown slugs. Returns mv=4 / mev=6 /
    /// mav=12 / mrv=18 — a middle-of-the-road volume zone for any
    /// muscle the curated table doesn't cover (defensive against future
    /// dataset bumps).
    public static func landmark(for slug: String) -> Landmark {
        landmarks[slug.lowercased()] ?? Landmark(mv: 4, mev: 6, mav: 12, mrv: 18)
    }
}
