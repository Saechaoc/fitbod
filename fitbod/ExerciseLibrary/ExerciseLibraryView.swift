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
//    - "+" toolbar button → custom-exercise editor (plan 03-04 fills in)
//    - row tap → exercise detail (plan 03-03 fills in)
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
//  ## Filter persistence (CONTEXT.md Area 2 — single-session reset)
//
//  `FilterState` is a `@State` inside this view. SwiftUI re-creates
//  `@State` storage when the view's identity goes away — leaving the
//  Library tab and re-entering creates a fresh `FilterState`, so the
//  filter selections reset per session. Cross-launch persistence is
//  deferred per CONTEXT.md.
//
//  ## Toolbar "+" affordance
//
//  Per UI-SPEC § Library screen "+" toolbar button: pushes a typed
//  navigation value (`NewCustomExerciseRequest`) onto the Library
//  tab's `NavigationStack`. Plan 03-04 swaps the placeholder destination
//  for the real `CustomExerciseEditor`.
//
//  ## Empty states
//
//  Per UI-SPEC § Empty states + execution-rules verbatim copy:
//
//    - Active search with no matches:
//      "No exercises match \"{query}\". Try fewer filters or a different name."
//    - No search but no matches:
//      "No exercises match. Try fewer filters."
//
//  A "Clear filters" text button (UI-SPEC accent) is shown when filters
//  are present so the user can recover from an over-restrictive
//  selection without leaving the screen.
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

    public init() {}

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            FilteredExerciseList(
                predicate: filterState.predicate(with: debouncedSearch),
                activeQuery: debouncedSearch,
                hasActiveFilters: !filterState.isEmpty,
                clearFiltersAction: filterState.clear
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
                    NavigationLink(value: NewCustomExerciseRequest()) {
                        Label("Create custom exercise", systemImage: "plus")
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityLabel("Create custom exercise")
                }
            }
            .navigationDestination(for: NewCustomExerciseRequest.self) { _ in
                // Plan 03-04 replaces this with the real
                // `CustomExerciseEditor` body.
                Text("Custom exercise editor — plan 03-04 fills this in")
                    .navigationTitle("New Exercise")
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
    /// to show the verbatim "{query}" the user typed.
    let activeQuery: String

    /// `true` when at least one facet has a selection — drives the
    /// "Clear filters" affordance in the empty state.
    let hasActiveFilters: Bool

    /// Closure that clears every facet's selection. Forwarded from the
    /// outer `FilterState.clear`.
    let clearFiltersAction: () -> Void

    init(
        predicate: Predicate<Exercise>,
        activeQuery: String,
        hasActiveFilters: Bool,
        clearFiltersAction: @escaping () -> Void
    ) {
        self._exercises = Query(
            filter: predicate,
            sort: \Exercise.canonicalName,
            order: .forward
        )
        self.activeQuery = activeQuery
        self.hasActiveFilters = hasActiveFilters
        self.clearFiltersAction = clearFiltersAction
    }

    var body: some View {
        Group {
            if exercises.isEmpty {
                EmptyLibraryView(
                    activeQuery: activeQuery,
                    hasActiveFilters: hasActiveFilters,
                    clearFiltersAction: clearFiltersAction
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
                    // Plan 03-03 replaces this placeholder with the real
                    // `ExerciseDetailView` body.
                    Text("Detail for \(ex.name) — plan 03-03 fills this in")
                        .navigationTitle(ex.name)
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

// MARK: - EmptyLibraryView

/// Empty-state surface shown when the active predicate + search match
/// zero rows. Per UI-SPEC § Empty states + execution-rules:
///
///   - If the user is actively searching ("query" is non-empty):
///     `No exercises match "{query}". Try fewer filters or a different name.`
///   - Otherwise (no query, just over-restrictive filters):
///     `No exercises match. Try fewer filters.`
///
/// A "Clear filters" text button appears when any filter is active so
/// the user can recover without leaving the screen.
private struct EmptyLibraryView: View {
    let activeQuery: String
    let hasActiveFilters: Bool
    let clearFiltersAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(headline)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(body_copy)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if hasActiveFilters {
                Button("Clear filters", action: clearFiltersAction)
                    .font(.body)
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 4)
                    .accessibilityLabel("Clear filters")
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var hasQuery: Bool {
        !activeQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var headline: String {
        hasQuery ? "No exercises match \"\(activeQuery)\"" : "No exercises match"
    }

    private var body_copy: String {
        hasQuery
            ? "Try fewer filters or a different name."
            : "Try fewer filters."
    }
}

// MARK: - NewCustomExerciseRequest

/// Typed navigation token for the "+" toolbar button. Plan 03-04 swaps
/// the destination for the real `CustomExerciseEditor`; keeping the
/// token as a `Hashable` value lets the toolbar wiring stay testable
/// and stable across the placeholder swap.
private struct NewCustomExerciseRequest: Hashable {}

// MARK: - Previews

#Preview("With fixture") {
    ExerciseLibraryView()
        .modelContainer(PreviewModelContainer.make())
}

#Preview("Empty state") {
    ExerciseLibraryView()
        .modelContainer(PreviewModelContainer.make(seedFixture: false))
}
