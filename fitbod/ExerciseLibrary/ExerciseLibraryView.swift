//
//  ExerciseLibraryView.swift
//  fitbod
//
//  Wave-3 plan 03-02 — the user-facing keystone of Phase 1. Replaces
//  the interim `LibraryTabHost` placeholder from plan 03-01 with the
//  real library surface:
//
//    - sticky filter chip bar (muscle / equipment / mechanic / pattern,
//      multi-select within / AND across)
//    - `.searchable` with a 150 ms debounce via `.task(id: searchText)`
//    - sectioned alphabetical `List`
//    - inline "Custom" tag on user-authored rows
//    - "+" toolbar button → presents `CustomExerciseEditor` as a
//      `.sheet` wrapped in a `NavigationStack` (plan 03-04)
//    - row tap → ExerciseDetailView (plan 03-03)
//
//  ## Outer / inner view split (RESEARCH § Pattern 3)
//
//  The outer `ExerciseLibraryView` owns the ephemeral state:
//
//    - `@State filterState` — facet selections
//    - `@State searchText` — live searchable text (every keystroke)
//    - `@State debouncedSearch` — searchText forwarded after 150 ms
//      via `.task(id: searchText)` (RESEARCH § Pitfall 4)
//    - `@State presentingFacet` — which `FilterPickerSheet` is presented
//
//  The inner `FilteredExerciseList` owns the `@Query<Exercise>`. Its
//  `init(predicate:)` re-runs the query whenever the outer view passes
//  a new predicate (which it does whenever any of the above state
//  changes). This is the load-bearing pattern in RESEARCH §
//  Code Example 4 — the `@Query` lives in a private inner view so the
//  outer view's body can rebuild the inner view (and thus the @Query)
//  reactively without dropping the `@Query`'s subscription side effects.
//
//  ## Search debounce (RESEARCH § Pitfall 4)
//
//  `.searchable` writes to `searchText` on every keystroke. A naive
//  binding into the predicate would re-run `@Query` against 800 rows on
//  every keystroke (visibly janky in tests). Instead `.task(id:)` runs
//  a 150 ms sleep keyed to `searchText` — the prior task is auto-cancelled
//  when `searchText` changes, so only the LAST keystroke after a quiet
//  150 ms actually propagates to `debouncedSearch` and triggers a query.
//
//  ## Filter persistence (corrected per review WR-04)
//
//  `FilterState` is a `@State` inside this view. `TabView` preserves
//  the identity of its hidden tab children — switching tabs does NOT
//  deallocate or re-instantiate this view, so the `@State`-backed
//  `FilterState` survives every tab switch and lives for the entire
//  app process lifetime. Filters reset only when:
//    1. The app is killed and relaunched (`@State` storage is gone), or
//    2. The user explicitly taps "Clear filters" (`filterState.clear()`).
//
//  This contradicts the older CONTEXT.md Area 2 phrasing ("filters
//  reset when the user leaves the library tab") — that phrasing
//  assumed tab teardown, which is not how SwiftUI's `TabView` works.
//  The persisted-for-process behavior is the iOS-native convention
//  and is what users actually expect; forcing teardown would require
//  a SwiftUI anti-pattern. The UI-SPEC has been updated to match.
//
//  ## Toolbar "+" affordance
//
//  Per UI-SPEC § Library screen "+" toolbar button: presents the
//  `CustomExerciseEditor` as a `.sheet` wrapped in a `NavigationStack`.
//  The editor owns its own toolbar (Save / Cancel) and dismisses
//  itself via `@Environment(\.dismiss)` on save / discard. A fresh
//  `CustomExerciseDraft()` is constructed per sheet presentation so
//  the editor opens with empty fields each time.
//
//  ## Empty states (plan 04-01 polish)
//
//  Empty state rendering is delegated to the top-level
//  `EmptyLibraryView` view (file: `EmptyLibraryView.swift`). It picks
//  between two UI-SPEC § Empty states copy variants based on whether
//  the active search text is empty:
//
//    - Empty `searchText` (filters-only / no rows):
//      "No exercises match"
//      "Try fewer filters or a different name."
//      → "Clear filters" (accent text button)
//
//    - Non-empty `searchText` (no rows for the typed query):
//      "No exercises match \"{query}\""
//      "Check spelling or create a custom exercise."
//      → "Create Custom Exercise" (accent text button)
//
//  Both actions dispatch to closures supplied by the outer view —
//  `filterState.clear` for the no-query path; `presentingNewCustom =
//  true` for the with-query CTA, which opens `CustomExerciseEditor` via
//  the existing `.sheet(isPresented: $presentingNewCustom)` modifier.
//

import SwiftUI
import SwiftData

/// Library tab body — sectioned, searchable, multi-facet-filterable
/// list of every `Exercise` in the store.
public struct ExerciseLibraryView: View {

    // MARK: - State

    @State private var filterState = FilterState()
    @State private var searchText: String = ""
    @State private var debouncedSearch: String = ""
    @State private var presentingFacet: ExerciseFilterBar.FilterFacet? = nil
    @State private var presentingNewCustom = false

    public init() {}

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            FilteredExerciseList(
                predicate: filterState.predicate(with: debouncedSearch),
                activeQuery: debouncedSearch,
                hasActiveFilters: !filterState.isEmpty,
                clearFiltersAction: filterState.clear,
                createCustomAction: { presentingNewCustom = true }
            )
            .navigationTitle("Exercises")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer,
                prompt: "Search exercises"
            )
            .task(id: searchText) {
                // Debounce: wait 150 ms, then propagate the searchText.
                // `.task(id:)` auto-cancels the prior task when `searchText`
                // changes — only the last keystroke after a 150 ms quiet
                // window survives to set `debouncedSearch`.
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                debouncedSearch = searchText
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                ExerciseFilterBar(
                    filterState: filterState,
                    presentingSheet: $presentingFacet
                )
            }
            .sheet(item: $presentingFacet) { facet in
                FilterPickerSheet(facet: facet, filterState: filterState)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        presentingNewCustom = true
                    } label: {
                        Label("Create custom exercise", systemImage: "plus")
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityLabel("Create custom exercise")
                }
            }
            .sheet(isPresented: $presentingNewCustom) {
                // Plan 03-04 wire — fresh CustomExerciseDraft per
                // sheet presentation. The editor owns the save flow
                // (`materialize(into: modelContext, ...)` + `ctx.save()`
                // + dismiss); the new row appears in the library list
                // via the outer @Query<Exercise> re-running on the
                // insert.
                NavigationStack {
                    CustomExerciseEditor(draft: CustomExerciseDraft())
                }
            }
        }
    }
}

// MARK: - FilteredExerciseList

/// Predicate-driven inner view. Its `init(predicate:)` re-creates the
/// `@Query` whenever the outer view passes a new predicate — the
/// load-bearing pattern from RESEARCH § Pattern 3 / Code Example 4.
///
/// Sectioning happens in-Swift over the already-fetched rows (the
/// `@Query` returns them sorted by `canonicalName`, so grouping by the
/// first letter of `name` yields stable alphabetical sections). At ~800
/// rows this is a sub-millisecond operation on iPhone 16 sim.
private struct FilteredExerciseList: View {
    @Query private var exercises: [Exercise]

    /// The active debounced search text, used by the empty-state copy
    /// to show the verbatim "{query}" the user typed AND to select the
    /// with-query vs without-query variant in `EmptyLibraryView`.
    let activeQuery: String

    /// `true` when at least one facet has a selection. Plan 04-01: the
    /// new `EmptyLibraryView` does not currently consume this — it
    /// picks its variant on `searchText.isEmpty` alone per UI-SPEC §
    /// Empty states. The flag is preserved on the inner view because
    /// the outer view still uses it for chip-bar rendering and a later
    /// polish may want it to disambiguate "filters-only" from "no
    /// rows" at the empty surface.
    let hasActiveFilters: Bool

    /// Closure that clears every facet's selection. Forwarded from the
    /// outer `FilterState.clear`. Wired to the empty state's no-query
    /// "Clear filters" button.
    let clearFiltersAction: () -> Void

    /// Closure that presents the `CustomExerciseEditor` sheet. Wired to
    /// the empty state's with-query "Create Custom Exercise" button —
    /// the plan-04-01 UI-SPEC § Empty states CTA that was deferred by
    /// plan 03-02 D-1 until plan 03-04's editor existed.
    let createCustomAction: () -> Void

    init(
        predicate: Predicate<Exercise>,
        activeQuery: String,
        hasActiveFilters: Bool,
        clearFiltersAction: @escaping () -> Void,
        createCustomAction: @escaping () -> Void
    ) {
        self._exercises = Query(
            filter: predicate,
            sort: \Exercise.canonicalName,
            order: .forward
        )
        self.activeQuery = activeQuery
        self.hasActiveFilters = hasActiveFilters
        self.clearFiltersAction = clearFiltersAction
        self.createCustomAction = createCustomAction
    }

    var body: some View {
        Group {
            if exercises.isEmpty {
                EmptyLibraryView(
                    searchText: activeQuery,
                    onClearFilters: clearFiltersAction,
                    onCreateCustom: createCustomAction
                )
            } else {
                List {
                    ForEach(sectioned, id: \.letter) { section in
                        Section(section.letter) {
                            ForEach(section.exercises) { ex in
                                NavigationLink(value: ex) {
                                    ExerciseRow(exercise: ex)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .navigationDestination(for: Exercise.self) { ex in
                    // Plan 03-03 wire — real ExerciseDetailView replaces
                    // the prior placeholder. The detail view owns its own
                    // navigation title (inline) + toolbar (none for
                    // built-in; "Copy as Custom Exercise" CTA section)
                    // and presents its own sheet for the Copy flow.
                    ExerciseDetailView(exercise: ex)
                }
            }
        }
    }

    /// Groups the fetched `exercises` by the first letter of their
    /// `name`, returning the sections in alphabetical order. The inner
    /// list is already sorted by `canonicalName` thanks to the
    /// `@Query(sort:)`, so per-section order is stable.
    private var sectioned: [(letter: String, exercises: [Exercise])] {
        let groups = Dictionary(grouping: exercises) { ex in
            String(ex.name.prefix(1).uppercased())
        }
        return groups.keys.sorted().map { letter in
            (letter, groups[letter] ?? [])
        }
    }
}

// MARK: - Previews
//
// NOTE 1: The inline `EmptyLibraryView` private struct (plan 03-02 D-5)
// has been promoted to its own top-level file
// (`EmptyLibraryView.swift`) by plan 04-01. The new version selects
// its copy variant on `searchText.isEmpty` alone (per UI-SPEC § Empty
// states) and adds the "Create Custom Exercise" CTA on the with-query
// variant.
//
// NOTE 2: The interim `NewCustomExerciseRequest` navigation token
// (plan 03-02 D-5) was removed by plan 03-04. Plan 03-04 wired the
// "+" toolbar button directly to a `.sheet(isPresented:)` presenting
// the real `CustomExerciseEditor` wrapped in a `NavigationStack`.


#Preview("With fixture") {
    ExerciseLibraryView()
        .modelContainer(PreviewModelContainer.make())
}

#Preview("Empty state") {
    ExerciseLibraryView()
        .modelContainer(PreviewModelContainer.make(seedFixture: false))
}
