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
//         - Action:  "Clear filters" (accent foreground text button)
//
//    2. Non-empty search (the user typed a query and zero rows match):
//         - Heading: "No exercises match \"{query}\""
//         - Body:    "Check spelling or create a custom exercise."
//         - Action:  "Create Custom Exercise" (accent foreground text
//                    button) — opens `CustomExerciseEditor` via the
//                    `onCreateCustom` closure dispatched by the parent.
//
//  Both variants share the same vertical hero layout (UI-SPEC § Spacing
//  Scale 2xl/3xl): 48pt top padding above the SF Symbol; 32pt horizontal
//  padding around the text block; centered.
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
//  ## Accent foreground vs `.tint`
//
//  `.foregroundStyle(Color.accentColor)` is the correct API for the
//  asset-catalog `AccentColor`. The view-level `.tint(_)` modifier
//  propagates to compatible system controls (Toggle, NavigationLink
//  chevron, etc.) but does not change the foreground style of a
//  `Text`/`Button` label — that requires `.foregroundStyle(.accentColor)`
//  or `Color.accentColor` explicitly. Same pattern as the "Copy as
//  Custom Exercise" button in `ExerciseDetailView` (plan 03-03 D-1).
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
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            heading
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            bodyCopy
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            actionButton
                .padding(.top, 8)
        }
        .padding(.horizontal, 32)
        .padding(.top, 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            Button("Create Custom Exercise", action: onCreateCustom)
                .font(.body)
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel("Create Custom Exercise")
        } else {
            Button("Clear filters", action: onClearFilters)
                .font(.body)
                .foregroundStyle(Color.accentColor)
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
