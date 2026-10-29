//
//  EmptyLibraryView.swift
//  fitbod
//
//  Wave-4 plan 04-01 — real UI-SPEC empty-state for the library. Replaces
//  the file-private `EmptyLibraryView` placeholder that plan 03-02 left
//  inside `ExerciseLibraryView.swift` (D-1 / D-5: deliberate single-file
//  edit-point for this polish pass).
//
//  ## Two copy variants (UI-SPEC § Empty states)
//
//    1. Empty search (no query, just over-restrictive filters or simply
//       no rows pass the active facets):
//         - Heading: "No exercises match"
//         - Body:    "Try fewer filters or a different name."
//         - Action:  "Clear filters" (ghost `BRUButton`)
//
//    2. Non-empty search (the user typed a query and zero rows match):
//         - Heading: "No exercises match \"{query}\""
//         - Body:    "Check spelling or create a custom exercise."
//         - Action:  "Create Custom Exercise" (signal `BRUButton`) -
//                    opens `CustomExerciseEditor` via the
//                    `onCreateCustom` closure dispatched by the parent.
//
//  Both variants share the same vertical hero layout: 48pt top padding
//  above a dashed-border "0" tile, 32pt horizontal padding around the
//  text block, centered.
//
//  ## Closure-driven dispatch (FOUND-06)
//
//  This view holds no `@State` and no `@Query` — it is a pure leaf view
//  that renders one of two copy variants based on its `searchText`
//  input and dispatches its action to one of two parent closures. The
//  parent (`FilteredExerciseList` in `ExerciseLibraryView.swift`)
//  decides whether the action means "clear filters" or "create custom
//  exercise" and provides the matching callback.
//
//  ## BRU tokens only
//
//  Every color comes from the BRU tokens (`bruInk`, `bruMuted`, and the
//  `BRUButton` kinds). The view never reads `Color.accentColor`: the
//  asset-catalog AccentColor is not a BRU token and must not stand in
//  for the signal color.
//

import SwiftUI

/// Empty-state surface shown when the active library predicate matches
/// zero rows. Distinguishes between "search returned nothing" (with-
/// query → suggests creating a custom exercise) vs. "filters too
/// restrictive" (without-query → suggests clearing filters).
struct EmptyLibraryView: View {
    /// The active (debounced) search text. Drives which copy variant
    /// renders. Empty / whitespace-only → the no-query variant.
    let searchText: String

    /// Invoked when the user taps "Clear filters" (no-query variant).
    let onClearFilters: () -> Void

    /// Invoked when the user taps "Create Custom Exercise" (with-query
    /// variant). The parent presents `CustomExerciseEditor` as a sheet.
    let onCreateCustom: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("0")
                .font(BRUFont.condensedTitle)
                .foregroundStyle(Color.bruMuted)
                .frame(width: 72, height: 72)
                .overlay(
                    Rectangle().strokeBorder(Color.bruInk, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                )
                .accessibilityHidden(true)

            heading
                .font(BRUFont.condensedHeading)
                .foregroundStyle(Color.bruInk)
                .multilineTextAlignment(.center)

            bodyCopy
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .multilineTextAlignment(.center)

            actionButton
                .frame(maxWidth: 280)
                .padding(.top, 8)
        }
        .padding(.horizontal, 32)
        .padding(.top, 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Variant predicate

    /// True when the user has an active query. Whitespace-only input
    /// folds to "no query" — the user has not actually typed anything
    /// meaningful, so the variant copy stays on the "Clear filters"
    /// path until real characters arrive.
    private var hasQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Headline

    @ViewBuilder
    private var heading: some View {
        if hasQuery {
            Text("No exercises match \"\(searchText)\"")
        } else {
            Text("No exercises match")
        }
    }

    // MARK: - Body copy

    @ViewBuilder
    private var bodyCopy: some View {
        if hasQuery {
            Text("Check spelling or create a custom exercise.")
        } else {
            Text("Try fewer filters or a different name.")
        }
    }

    // MARK: - Action button

    @ViewBuilder
    private var actionButton: some View {
        if hasQuery {
            BRUButton("Create Custom Exercise", kind: .signal, action: onCreateCustom)
                .accessibilityLabel("Create Custom Exercise")
        } else {
            BRUButton("Clear filters", kind: .ghost, action: onClearFilters)
                .accessibilityLabel("Clear filters")
        }
    }
}

// MARK: - Previews

#Preview("No filters / no query") {
    EmptyLibraryView(
        searchText: "",
        onClearFilters: {},
        onCreateCustom: {}
    )
}

#Preview("With query that has no matches") {
    EmptyLibraryView(
        searchText: "deadwood",
        onClearFilters: {},
        onCreateCustom: {}
    )
}
