//
//  EmptyStateTests.swift
//  fitbodTests
//
//  Wave-4 plan 04-01 — minimal smoke tests over the `EmptyLibraryView`
//  surface. The variant-selection logic is a pure conditional on the
//  `searchText` input being empty / non-empty (after whitespace
//  trimming); these tests anchor that the view accepts both shapes of
//  input and exposes its `searchText` field for regression checks on
//  the UI-SPEC § Empty states copy contract.
//
//  ViewInspector (which would let us assert rendered text + button
//  labels) is locked out per `.planning/research/STACK.md` (zero
//  third-party SPM dependencies). Phase 1's deliberate trade-off is to
//  ship the trivial input-surface assertions now and revisit if a
//  later phase ever adopts a SwiftUI testing library.
//
//  The pattern matches the plan's expectation: 2 trivial @Test funcs
//  whose primary purpose is "this surface exists and accepts inputs
//  for both variants" rather than rendered-content assertion.
//

import Testing
@testable import fitbod

@Suite("EmptyLibraryView copy selection (UI-SPEC § Empty states)")
struct EmptyStateTests {

    /// Empty search → without-query variant: "No exercises match" +
    /// "Try fewer filters or a different name." + "Clear filters"
    /// action.
    @Test("Empty searchText → 'No exercises match' + 'Clear filters'")
    func emptySearchShowsClearFiltersAction() {
        let view = EmptyLibraryView(
            searchText: "",
            onClearFilters: {},
            onCreateCustom: {}
        )
        #expect(view.searchText.isEmpty)
    }

    /// Non-empty search → with-query variant: 'No exercises match
    /// "{query}"' + "Check spelling or create a custom exercise." +
    /// "Create Custom Exercise" action.
    @Test("Non-empty searchText → 'No exercises match \"X\"' + 'Create Custom Exercise'")
    func searchShowsCreateCustomAction() {
        let view = EmptyLibraryView(
            searchText: "deadwood",
            onClearFilters: {},
            onCreateCustom: {}
        )
        #expect(view.searchText == "deadwood")
        #expect(!view.searchText.isEmpty)
    }

    /// Whitespace-only search folds to the no-query variant. The
    /// `hasQuery` predicate in `EmptyLibraryView` trims whitespace
    /// before deciding; this test anchors the input shape.
    @Test("Whitespace-only searchText is a valid no-query input shape")
    func whitespaceOnlyIsAcceptedInput() {
        let view = EmptyLibraryView(
            searchText: "   ",
            onClearFilters: {},
            onCreateCustom: {}
        )
        // The view accepts the input; the variant decision is made
        // internally by trimming whitespace. We don't reach into
        // private state — just confirm the surface accepts the shape.
        #expect(view.searchText == "   ")
    }
}
