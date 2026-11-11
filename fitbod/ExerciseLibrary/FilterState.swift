//
//  FilterState.swift
//  fitbod
//
//  Ephemeral, view-owned filter selection state for `ExerciseLibraryView`.
//  Holds multi-select sets for the four facets (muscle / equipment /
//  mechanic / pattern) plus the convenience methods the library view's
//  filter chip bar consumes (`applyPostFetchFilters(to:)`, `isEmpty`,
//  `clear()`). Search is not a facet: `ExerciseSearch` runs after the facets.
//
//  ## Why `@Observable`, not `@Model` or `ObservableObject`
//
//  This is purely ephemeral UI state — selections live for a single
//  visit to the Library tab and are intentionally reset when the user
//  leaves and re-enters (CONTEXT.md Area 2 — "filter persistence: per-
//  session only"). It must NEVER be persisted via SwiftData (it would
//  bloat the schema for no benefit), and it must NEVER wrap a `@Query`
//  (FOUND-06 anti-pattern). `@Observable` gives SwiftUI fine-grained
//  property-level reactivity without `@Published` ceremony.
//
//  ## Filter composition rules (CONTEXT.md Area 2 + RESEARCH § Pitfall 3)
//
//  - **AND across facets** - a row must match every facet with a selection, so
//    selecting "Muscle=chest" + "Equipment=barbell" filters to rows
//    matching BOTH.
//  - **OR within a facet** — multi-select facets use `Set.contains(...)`
//    against the row's value (Set membership semantically ORs).
//  - **Mechanic is single-select** — per UI-SPEC table the Mechanic chip
//    holds one value; modeled as `String?` rather than `Set<String>`.
//  - **Muscle filter — denormalized post-fetch token match (PITFALLS #3)** —
//    SwiftData's predicate translator cannot traverse the many-to-many
//    `ExerciseMuscleStimulus` join cleanly, and dynamic OR-over-token matching
//    is fragile inside `#Predicate`. Instead, `Exercise` carries a seed-time-
//    populated `primaryMuscleSlugsJoined: String` field shaped like
//    `"|chest|triceps|"`; the post-fetch muscle filter matches a selected slug
//    as the whole-token `"|slug|"`.
//
//  ## Everything runs in memory
//
//  `FilteredExerciseList` fetches every row, applies the facets with
//  `applyPostFetchFilters(to:)`, then searches what is left with
//  `ExerciseSearch`, which reads aliases and ranks its results (RM-022).
//  No facet or search goes into a `#Predicate`: the guarded multi-facet
//  shape pushes Swift's type checker past its budget and is a brittle SQL
//  translation, and a predicate cannot rank. The catalog is about 720 rows.
//

import Foundation
import Observation

/// View-owned filter state for `ExerciseLibraryView`.
///
/// Holds the four-facet selection sets (muscle / equipment / mechanic /
/// pattern) and applies them in memory to the fetched rows. Lifetime is
/// tied to the library view; selections reset per CONTEXT.md Area 2 when
/// the view is dismissed and re-appeared.
@Observable
public final class FilterState {
    /// Selected muscle slugs (e.g. `"chest"`). OR semantics within facet.
    public var selectedMuscleSlugs: Set<String> = []

    /// Selected equipment raw values (e.g. `"barbell"`). OR semantics within facet.
    public var selectedEquipmentRaw: Set<String> = []

    /// Selected mechanic raw value (e.g. `"compound"`). Single-select per
    /// UI-SPEC; `nil` means "any mechanic".
    public var selectedMechanicRaw: String? = nil

    /// Selected pattern raw values (e.g. `"horizontal_push"`). OR semantics
    /// within facet. Phase 1 nullable per Open Q #5 — chip is effectively
    /// empty until curation lands in a later phase.
    public var selectedPatternRaw: Set<String> = []

    public init() {}

    /// `true` when no facet has any selection. Drives the visibility of
    /// the "Clear filters" affordance in the chip bar.
    public var isEmpty: Bool {
        selectedMuscleSlugs.isEmpty
            && selectedEquipmentRaw.isEmpty
            && selectedMechanicRaw == nil
            && selectedPatternRaw.isEmpty
    }

    /// Clears every facet's selection in one call.
    public func clear() {
        selectedMuscleSlugs.removeAll()
        selectedEquipmentRaw.removeAll()
        selectedMechanicRaw = nil
        selectedPatternRaw.removeAll()
    }

    /// In-memory muscle facet filter.
    ///
    /// This preserves OR-within-muscle semantics without forcing SwiftData's
    /// predicate translator to handle dynamic token matching.
    public func matchesMuscleFacet(_ exercise: Exercise) -> Bool {
        guard !selectedMuscleSlugs.isEmpty else {
            return true
        }

        return selectedMuscleSlugs.contains { slug in
            exercise.primaryMuscleSlugsJoined.contains("|\(slug)|")
        }
    }

    /// In-memory facet filter for the selections intentionally kept out of
    /// SwiftData's predicate translator.
    public func matchesPostFetchFacets(_ exercise: Exercise) -> Bool {
        if !selectedEquipmentRaw.isEmpty,
           !selectedEquipmentRaw.contains(exercise.equipmentRaw) {
            return false
        }

        // Cardio has no mechanic; the default it stores must not match one.
        if let mechanic = selectedMechanicRaw,
           exercise.isCardio || exercise.mechanicRaw != mechanic {
            return false
        }

        if !selectedPatternRaw.isEmpty {
            guard let pattern = exercise.patternRaw,
                  selectedPatternRaw.contains(pattern) else {
                return false
            }
        }

        return matchesMuscleFacet(exercise)
    }

    /// Applies the facet filters to the fetched rows.
    public func applyPostFetchFilters(to exercises: [Exercise]) -> [Exercise] {
        guard !isEmpty else {
            return exercises
        }

        return exercises.filter { matchesPostFetchFacets($0) }
    }
}
