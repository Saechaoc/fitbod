//
//  EmptyLibraryView.swift
//  fitbod
//
//  Library empty state (UI-SPEC § Empty states, Chalkline styling).
//
//    - With a query:  NO MATCH FOR “ZERCHER GOOD MORNING”
//                     → Create “Zercher Good Morning” (pre-filled custom
//                       exercise) and, when filters are on, Clear filters.
//    - Without:       NO EXERCISES MATCH → Clear filters.
//
//  Whitespace-only queries fold to the no-query variant.
//

import SwiftUI

struct EmptyLibraryView: View {
    /// The active (debounced) search text.
    let searchText: String
    let onClearFilters: () -> Void
    let onCreateCustom: () -> Void
    var hasActiveFilters: Bool = true

    var body: some View {
        if hasQuery {
            ChalkEmptyState(
                systemImage: "magnifyingglass",
                title: "No match for “\(trimmed)”",
                message: "Check the spelling\(hasActiveFilters ? ", clear filters," : "") or add it as your own exercise.",
                primaryTitle: "Create “\(trimmed.capitalized)”",
                primaryAction: onCreateCustom,
                secondaryTitle: hasActiveFilters ? "Clear filters" : nil,
                secondaryAction: hasActiveFilters ? onClearFilters : nil
            )
            .accessibilityIdentifier("library.empty")
        } else {
            ChalkEmptyState(
                systemImage: "line.3.horizontal.decrease",
                title: "No exercises match",
                message: "Try fewer filters or a different name.",
                primaryTitle: "Clear filters",
                primaryAction: onClearFilters
            )
            .accessibilityIdentifier("library.empty")
        }
    }

    private var trimmed: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whitespace-only input is not a query.
    private var hasQuery: Bool {
        !trimmed.isEmpty
    }
}

#Preview("No filters / no query") {
    EmptyLibraryView(searchText: "", onClearFilters: {}, onCreateCustom: {})
        .padding()
}

#Preview("With query that has no matches") {
    EmptyLibraryView(searchText: "zercher good morning", onClearFilters: {}, onCreateCustom: {})
        .padding()
}
