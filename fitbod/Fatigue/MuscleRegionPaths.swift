//
//  MuscleRegionPaths.swift
//  fitbod
//
//  Per-muscle silhouette `Path` registry per RESEARCH §8.2. Paths are
//  normalized to a 0...1 unit square; callers render inside a
//  `GeometryReader` to scale to the device.
//
//  Wave 0 (this plan): STUB Rectangle paths at approximate body-region
//  positions per UI-SPEC §BodySilhouetteView wave strategy. The point
//  of the stubs is to get hit-testing wiring and registry coverage
//  validated NOW so downstream Phase 5 plans 03 (volume bars) and 05
//  (heatmap) can compose without waiting for anatomical refinement.
//  Wave 3 (Phase 5 plan 05) replaces these Rectangles with
//  anatomically-correct bezier curves.
//
//  Coverage: every muscle slug appears in `front`, `back`, or both.
//  Combined `front ∪ back` MUST cover all 17 free-exercise-db slugs
//  (pinned by MuscleRegionPathsTests.combinedRegistryCoversAllSeventeenMuscleSlugs).
//
//  Why both sides for shoulders and calves: front delts are visible
//  front-view, rear delts visible back-view; calves wrap around the
//  lower leg and are visible both sides. Tapping either path
//  navigates to the same per-muscle detail view (single slug bucket
//  per the Phase 5 shoulders-aggregation decision).
//
//  No SwiftData coupling. Implicitly Sendable via SwiftUI.Path which
//  is a value type.
//

import SwiftUI

/// Per-muscle silhouette path registry. Wave 0 ships stub Rectangle
/// paths; Wave 3 refines to anatomically-correct bezier curves.
public enum MuscleRegionPaths {

    /// Front-view paths keyed by muscle slug. Front-visible muscles:
    /// chest, abs, quads, calves, front delts, biceps, forearms, neck,
    /// abductors, adductors.
    public static let front: [String: Path] = [
        "chest":      Path(CGRect(x: 0.25, y: 0.20, width: 0.50, height: 0.10)),
        "shoulders":  Path(CGRect(x: 0.10, y: 0.18, width: 0.80, height: 0.06)),
        "biceps":     Path(CGRect(x: 0.10, y: 0.26, width: 0.18, height: 0.10)),
        "forearms":   Path(CGRect(x: 0.08, y: 0.36, width: 0.20, height: 0.08)),
        "abdominals": Path(CGRect(x: 0.30, y: 0.30, width: 0.40, height: 0.15)),
        "quadriceps": Path(CGRect(x: 0.25, y: 0.55, width: 0.50, height: 0.20)),
        "calves":     Path(CGRect(x: 0.27, y: 0.78, width: 0.46, height: 0.10)),
        "neck":       Path(CGRect(x: 0.40, y: 0.10, width: 0.20, height: 0.05)),
        "abductors":  Path(CGRect(x: 0.22, y: 0.52, width: 0.10, height: 0.06)),
        "adductors":  Path(CGRect(x: 0.40, y: 0.55, width: 0.20, height: 0.06)),
    ]

    /// Back-view paths keyed by muscle slug. Back-visible muscles:
    /// traps, lats, middle back, lower back, rear delts, triceps,
    /// glutes, hamstrings, calves.
    public static let back: [String: Path] = [
        "traps":       Path(CGRect(x: 0.32, y: 0.12, width: 0.36, height: 0.08)),
        "lats":        Path(CGRect(x: 0.20, y: 0.25, width: 0.60, height: 0.20)),
        "middle back": Path(CGRect(x: 0.30, y: 0.22, width: 0.40, height: 0.10)),
        "lower back":  Path(CGRect(x: 0.30, y: 0.40, width: 0.40, height: 0.10)),
        "shoulders":   Path(CGRect(x: 0.10, y: 0.16, width: 0.80, height: 0.06)),
        "triceps":     Path(CGRect(x: 0.05, y: 0.26, width: 0.18, height: 0.12)),
        "glutes":      Path(CGRect(x: 0.27, y: 0.48, width: 0.46, height: 0.12)),
        "hamstrings":  Path(CGRect(x: 0.25, y: 0.60, width: 0.50, height: 0.18)),
        "calves":      Path(CGRect(x: 0.27, y: 0.78, width: 0.46, height: 0.10)),
    ]
}
