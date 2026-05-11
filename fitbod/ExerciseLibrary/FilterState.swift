//
//  FilterState.swift
//  fitbod
//
//  Ephemeral, view-owned filter selection state for `ExerciseLibraryView`.
//  Holds multi-select sets for the four facets (muscle / equipment /
//  mechanic / pattern) plus the convenience methods the library view's
//  filter chip bar consumes (`predicate(with:)`, `isEmpty`, `clear()`).
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
//  ## Predicate composition rules (CONTEXT.md Area 2 + RESEARCH § Pitfall 3)
//
//  - **AND across facets** — `&&` joins the four facet sub-predicates so
//    selecting "Muscle=chest" + "Equipment=barbell" filters to rows
//    matching BOTH.
//  - **OR within a facet** — multi-select facets use `Set.contains(...)`
//    against the row's value (Set membership semantically ORs).
//  - **Mechanic is single-select** — per UI-SPEC table the Mechanic chip
//    holds one value; modeled as `String?` rather than `Set<String>`.
//  - **Muscle filter — denormalized predicate (PITFALLS #3)** — SwiftData's
//    predicate translator cannot traverse the many-to-many
//    `ExerciseMuscleStimulus` join cleanly. Instead, `Exercise` carries a
//    seed-time-populated `primaryMuscleSlugsJoined: String` field shaped
//    like `"|chest|triceps|"`, indexed via
//    `#Index<Exercise>([\.primaryMuscleSlugsJoined])`. The predicate
//    matches a selected slug as the whole-token `"|slug|"`.
//
//  ## Captures-by-value invariant (RESEARCH § Pitfall 12)
//
//  `predicate(with:)` copies every capture into a local `let` BEFORE
//  building the `#Predicate` literal. SwiftData's predicate translator
//  is sensitive to reference captures — a `self` or instance-property
//  reference in the predicate body silently breaks the indexed path or
//  crashes at fetch time. The locals (`muscles`, `equipment`, etc.) are
//  all value-typed primitives that the macro can encode into the
//  generated NSPredicate.
//

import Foundation
import Observation

/// View-owned filter state for `ExerciseLibraryView`.
///
/// Holds the four-facet selection sets (muscle / equipment / mechanic /
/// pattern) and composes a `Predicate<Exercise>` against a debounced
/// search term. Lifetime is tied to the library view; selections reset
/// per CONTEXT.md Area 2 when the view is dismissed and re-appeared.
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

    /// Composes a `Predicate<Exercise>` from the current selections plus
    /// the externally-debounced search term.
    ///
    /// All captures are copied to local `let` constants BEFORE the
    /// `#Predicate` literal — see Pitfall #12 explanation in the file
    /// header. Mutating `selectedMuscleSlugs` after this call returns
    /// does NOT affect the returned predicate (it captured the snapshot).
    ///
    /// - Parameter debouncedSearch: search term forwarded from the
    ///   library view's `.searchable` state after a 150 ms debounce
    ///   (RESEARCH § Pitfall 4).
    public func predicate(with debouncedSearch: String) -> Predicate<Exercise> {
        // Captures-by-value — every binding below is a primitive value type.
        let normalizedSearch = debouncedSearch
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
        let muscles = selectedMuscleSlugs
        let equipment = selectedEquipmentRaw
        let mechanic = selectedMechanicRaw
        let patterns = selectedPatternRaw

        return #Predicate<Exercise> { ex in
            // Text search — case- + diacritic-insensitive substring
            // match against `canonicalName` (the importer normalizes
            // `name` into `canonicalName` using the same fold).
            (normalizedSearch.isEmpty || ex.canonicalName.contains(normalizedSearch))
            &&
            // Equipment facet (multi-select within facet — OR semantics).
            (equipment.isEmpty || equipment.contains(ex.equipmentRaw))
            &&
            // Mechanic facet (single-select per UI-SPEC).
            (mechanic == nil || ex.mechanicRaw == mechanic!)
            &&
            // Muscle facet — denormalized predicate (PITFALLS #3).
            // `ex.primaryMuscleSlugsJoined` is shaped like "|chest|triceps|";
            // selecting "chest" matches against the whole-token "|chest|"
            // substring. `Set.contains { ... }` ORs within the facet.
            (muscles.isEmpty || muscles.contains { slug in
                ex.primaryMuscleSlugsJoined.contains("|\(slug)|")
            })
            &&
            // Pattern facet (multi-select; `patternRaw` is nullable per
            // Open Q #5, so guard against nil before set-membership check).
            (patterns.isEmpty || (ex.patternRaw != nil && patterns.contains(ex.patternRaw!)))
        }
    }
}
