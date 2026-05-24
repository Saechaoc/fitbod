//
//  MuscleRegionPaths.swift
//  fitbod
//
//  Phase 5.1 plan 04 — Replaces anatomically-informed bezier/ellipse/
//  rounded-rect geometry (Phase 5 plan 05-05) with axis-aligned
//  rectangular block-anatomy on a fixed 10-column × 12-row grid.
//
//  Grid coordinates per bru-screens/heatmap.jsx lines 14–66 (locked).
//  Cell pitch: 14pt. Container: 140pt × 168pt (10 cols × 12 rows).
//
//  Public surface:
//    - `MuscleRegionPaths.front: [GridRegion]`
//    - `MuscleRegionPaths.back: [GridRegion]`
//    - `MuscleRegionPaths.regions(for: BodySide) -> [GridRegion]`
//
//  Coverage: combined front ∪ back covers all 17 free-exercise-db slugs.
//  Symmetrical pairs (CHEST L + CHEST R, BICEP × 2, etc.) share the
//  same canonical slug — they render the same zone fill color.
//
//  NECK is decorative-only (no zone lookup) per Phase 5 plan 05-05
//  precedent — slug = "neck-decorative", excluded from zoneByMuscleSlug
//  lookup at render time.
//
//  No bezier/ellipse/RoundedRectangle. No SwiftData coupling.
//  Implicitly Sendable via value types.
//

import SwiftUI

// MARK: - GridRegion

/// A single rectangular muscle region on the 10×12 block-anatomy grid.
/// Coordinates are in grid units; call `rect(cell:)` to get points.
public struct GridRegion: Sendable, Equatable {
    /// Canonical free-exercise-db muscle slug, or "neck-decorative" for
    /// the decorative NECK region that has no zone-data binding.
    public let slug: String
    /// Uppercase display label rendered centered inside the region rect
    /// per bru-screens/heatmap.jsx (e.g. "CHEST L", "LAT", "TRAPS").
    public let displayLabel: String
    /// Grid column origin (0-based, 0…9).
    public let gridX: Int
    /// Grid row origin (0-based, 0…11).
    public let gridY: Int
    /// Width in grid columns.
    public let gridW: Int
    /// Height in grid rows.
    public let gridH: Int

    public init(
        slug: String,
        displayLabel: String,
        gridX: Int, gridY: Int,
        gridW: Int, gridH: Int
    ) {
        self.slug = slug
        self.displayLabel = displayLabel
        self.gridX = gridX
        self.gridY = gridY
        self.gridW = gridW
        self.gridH = gridH
    }

    /// Returns the CGRect for this region at the given cell pitch.
    /// The −1 on width and height separates adjacent regions by a 1pt
    /// border gap (matching heatmap.jsx lines 87–88: `w * cell - 1`).
    public func rect(cell: CGFloat = 14) -> CGRect {
        CGRect(
            x: CGFloat(gridX) * cell,
            y: CGFloat(gridY) * cell,
            width: CGFloat(gridW) * cell - 1,
            height: CGFloat(gridH) * cell - 1
        )
    }

    /// Returns an axis-aligned `Path` for this region at the given cell pitch.
    public func path(cell: CGFloat = 14) -> Path {
        Path(rect(cell: cell))
    }
}

// MARK: - MuscleRegionPaths

/// Static registry of per-region `GridRegion` values for front and back
/// body views. Grid coordinates copied verbatim from
/// `bru-screens/heatmap.jsx` lines 14–66 (locked).
public enum MuscleRegionPaths {

    // MARK: Front view
    // Grid coordinates per bru-screens/heatmap.jsx lines 14–38 (locked)

    public static let front: [GridRegion] = [
        // Head + neck (decorative — no zone binding)
        GridRegion(slug: "neck-decorative", displayLabel: "NECK",
                   gridX: 4, gridY: 0, gridW: 2, gridH: 1),
        // Shoulders — left
        GridRegion(slug: "shoulders", displayLabel: "DELT",
                   gridX: 1, gridY: 1, gridW: 2, gridH: 1),
        // Shoulders — right
        GridRegion(slug: "shoulders", displayLabel: "DELT",
                   gridX: 7, gridY: 1, gridW: 2, gridH: 1),
        // Chest — left half
        GridRegion(slug: "chest", displayLabel: "CHEST L",
                   gridX: 3, gridY: 1, gridW: 2, gridH: 2),
        // Chest — right half
        GridRegion(slug: "chest", displayLabel: "CHEST R",
                   gridX: 5, gridY: 1, gridW: 2, gridH: 2),
        // Biceps — left
        GridRegion(slug: "biceps", displayLabel: "BICEP",
                   gridX: 1, gridY: 2, gridW: 2, gridH: 2),
        // Biceps — right
        GridRegion(slug: "biceps", displayLabel: "BICEP",
                   gridX: 7, gridY: 2, gridW: 2, gridH: 2),
        // Abs — left half
        GridRegion(slug: "abdominals", displayLabel: "ABS L",
                   gridX: 3, gridY: 3, gridW: 2, gridH: 3),
        // Abs — right half
        GridRegion(slug: "abdominals", displayLabel: "ABS R",
                   gridX: 5, gridY: 3, gridW: 2, gridH: 3),
        // Forearms — left
        GridRegion(slug: "forearms", displayLabel: "FORE",
                   gridX: 1, gridY: 4, gridW: 2, gridH: 2),
        // Forearms — right
        GridRegion(slug: "forearms", displayLabel: "FORE",
                   gridX: 7, gridY: 4, gridW: 2, gridH: 2),
        // Quadriceps — left
        GridRegion(slug: "quadriceps", displayLabel: "QUAD",
                   gridX: 3, gridY: 6, gridW: 2, gridH: 3),
        // Quadriceps — right
        GridRegion(slug: "quadriceps", displayLabel: "QUAD",
                   gridX: 5, gridY: 6, gridW: 2, gridH: 3),
        // Calves — left
        GridRegion(slug: "calves", displayLabel: "CALF",
                   gridX: 3, gridY: 9, gridW: 2, gridH: 2),
        // Calves — right
        GridRegion(slug: "calves", displayLabel: "CALF",
                   gridX: 5, gridY: 9, gridW: 2, gridH: 2),
    ]

    // MARK: Back view
    // Grid coordinates per bru-screens/heatmap.jsx lines 40–66 (locked)

    public static let back: [GridRegion] = [
        // Neck (decorative — no zone binding)
        GridRegion(slug: "neck-decorative", displayLabel: "NECK",
                   gridX: 4, gridY: 0, gridW: 2, gridH: 1),
        // Traps — central upper back
        GridRegion(slug: "traps", displayLabel: "TRAPS",
                   gridX: 3, gridY: 1, gridW: 4, gridH: 1),
        // Rear delts — left
        GridRegion(slug: "shoulders", displayLabel: "R.DELT",
                   gridX: 1, gridY: 1, gridW: 2, gridH: 1),
        // Rear delts — right
        GridRegion(slug: "shoulders", displayLabel: "R.DELT",
                   gridX: 7, gridY: 1, gridW: 2, gridH: 1),
        // Upper back (middle back)
        GridRegion(slug: "middle back", displayLabel: "UPPER BACK",
                   gridX: 3, gridY: 2, gridW: 4, gridH: 1),
        // Lats — left
        GridRegion(slug: "lats", displayLabel: "LAT",
                   gridX: 1, gridY: 2, gridW: 2, gridH: 3),
        // Lats — right
        GridRegion(slug: "lats", displayLabel: "LAT",
                   gridX: 7, gridY: 2, gridW: 2, gridH: 3),
        // Triceps — left (outer arm)
        GridRegion(slug: "triceps", displayLabel: "TRI",
                   gridX: 0, gridY: 2, gridW: 1, gridH: 2),
        // Triceps — right (outer arm)
        GridRegion(slug: "triceps", displayLabel: "TRI",
                   gridX: 9, gridY: 2, gridW: 1, gridH: 2),
        // Lower back
        GridRegion(slug: "lower back", displayLabel: "LOWER BACK",
                   gridX: 3, gridY: 5, gridW: 4, gridH: 1),
        // Glutes — left
        GridRegion(slug: "glutes", displayLabel: "GLUTE",
                   gridX: 3, gridY: 6, gridW: 2, gridH: 2),
        // Glutes — right
        GridRegion(slug: "glutes", displayLabel: "GLUTE",
                   gridX: 5, gridY: 6, gridW: 2, gridH: 2),
        // Hamstrings — left
        GridRegion(slug: "hamstrings", displayLabel: "HAM",
                   gridX: 3, gridY: 8, gridW: 2, gridH: 2),
        // Hamstrings — right
        GridRegion(slug: "hamstrings", displayLabel: "HAM",
                   gridX: 5, gridY: 8, gridW: 2, gridH: 2),
        // Calves — left
        GridRegion(slug: "calves", displayLabel: "CALF",
                   gridX: 3, gridY: 10, gridW: 2, gridH: 1),
        // Calves — right
        GridRegion(slug: "calves", displayLabel: "CALF",
                   gridX: 5, gridY: 10, gridW: 2, gridH: 1),
    ]

    // MARK: - Accessor

    /// Returns the `GridRegion` array for the given body side.
    public static func regions(for side: BodySide) -> [GridRegion] {
        side == .front ? front : back
    }
}
