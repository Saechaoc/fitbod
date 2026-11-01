//
//  ExerciseLibraryView.swift
//  fitbod
//
//  The exercise library: Library tab (browse) and exercise picker (routine
//  builder, logger add/swap).
//
//  Composition: BRUHeaderBar · search field · ExerciseFilterBar chip row ·
//  FilteredExerciseList (pinned letter sections of ExerciseRow).
//
//  Outer / inner split: the outer view owns filter + search state; the inner
//  FilteredExerciseList owns the @Query and is rebuilt with a new predicate
//  whenever that state changes (the @Query must live in the inner view so
//  SwiftUI keeps its subscription).
//
//  Search is debounced 150 ms through `.task(id: searchText)` so the query
//  does not re-run on every keystroke.
//
//  Filters persist for the process lifetime (the tab keeps this view alive)
//  and reset on relaunch or via "Clear filters".
//

import SwiftUI
import SwiftData

/// Library tab body and exercise picker: BRU-styled, searchable,
/// multi-facet-filterable list of every `Exercise` in the store.
///
/// Browse mode (`init()` / `init(path:)`) owns a NavigationStack and pushes
/// `ExerciseDetailView`. Picker mode (`init(onSelect:)`) renders inside the
/// caller's NavigationStack and fires `onSelect` on tap.
public struct ExerciseLibraryView: View {

    // MARK: - State

    @State private var filterState = FilterState()
    @State private var searchText: String = ""
    @State private var debouncedSearch: String = ""
    @State private var presentingFacet: ExerciseFilterBar.FilterFacet? = nil
    /// Draft for the custom exercise editor. Setting it presents the sheet,
    /// so the sheet keeps this one draft while it is up: a redraw of the
    /// library cannot swap in a fresh draft and wipe the user's input.
    @State private var newCustomDraft: CustomExerciseDraft? = nil
    @FocusState private var searchFocused: Bool

    /// Internal navigation path used when the caller does not provide
    /// one (previews, tests). When an external binding is supplied via
    /// `init(path:)`, `effectivePath` proxies through it so `RootView` can
    /// clear the stack on Library-tab re-tap.
    @State private var internalPath = NavigationPath()
    private var externalPath: Binding<NavigationPath>?

    /// Picker-mode closure. When non-nil, tapping an exercise row invokes
    /// this closure instead of pushing `ExerciseDetailView`.
    private var onSelect: ((Exercise) -> Void)?

    /// Picker mode only: whether to draw the CANCEL · ADD EXERCISE header.
    /// Hosts that draw their own header (swap sheet) pass false.
    private var showsPickerHeader: Bool = true

    public init() {
        self.externalPath = nil
        self.onSelect = nil
    }

    /// External-path variant: `RootView` constructs this so it can reset
    /// the path on tab re-tap.
    public init(path: Binding<NavigationPath>) {
        self.externalPath = path
        self.onSelect = nil
    }

    /// Picker init: tapping a row fires the closure rather than pushing
    /// the detail view. "+ New" still creates a custom exercise, which
    /// then appears in the list ready to pick.
    public init(onSelect: @escaping (Exercise) -> Void, showsPickerHeader: Bool = true) {
        self.externalPath = nil
        self.onSelect = onSelect
        self.showsPickerHeader = showsPickerHeader
    }

    private var effectivePath: Binding<NavigationPath> {
        externalPath ?? $internalPath
    }

    private var isPicker: Bool { onSelect != nil }

    // MARK: - Body

    public var body: some View {
        if isPicker {
            content
        } else {
            NavigationStack(path: effectivePath) {
                content
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            if !isPicker || showsPickerHeader {
                BRUHeaderBar.slots(
                    left: isPicker ? .cancel : nil,
                    center: isPicker ? "Add exercise" : "Library",
                    right: .action("+ New") { openNewCustom() }
                )
            }
            searchField
            ExerciseFilterBar(
                filterState: filterState,
                presentingSheet: $presentingFacet
            )
            FilteredExerciseList(
                predicate: filterState.swiftDataPredicate(with: debouncedSearch),
                filterState: filterState,
                activeQuery: debouncedSearch,
                hasActiveFilters: !filterState.isEmpty,
                clearFiltersAction: filterState.clear,
                createCustomAction: { openNewCustom(named: searchText) },
                onSelect: onSelect
            )
        }
        .background(Color.bruPaper.ignoresSafeArea())
        .navigationBarHidden(true)
        .task(id: searchText) {
            // Debounce: wait 150 ms, then propagate the searchText.
            // `.task(id:)` auto-cancels the prior task when `searchText`
            // changes, so only the last keystroke after a quiet 150 ms
            // window reaches `debouncedSearch` and re-runs the query.
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            debouncedSearch = searchText
        }
        .sheet(item: $presentingFacet) { facet in
            FilterPickerSheet(facet: facet, filterState: filterState)
        }
        .sheet(item: $newCustomDraft) { draft in
            // The editor saves and dismisses, and the inner @Query picks up
            // the new row.
            NavigationStack {
                CustomExerciseEditor(draft: draft)
            }
        }
    }

    // MARK: - New custom exercise

    /// Opens the custom exercise editor on a fresh draft. The no-match
    /// state passes the search text, so the name starts as what the user
    /// searched for.
    private func openNewCustom(named name: String = "") {
        let draft = CustomExerciseDraft()
        draft.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        newCustomDraft = draft
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 10) {
            Text("⌕")
                .font(BRUFont.condensedHeading)
                .foregroundStyle(Color.bruMuted)
                .accessibilityHidden(true)
            TextField(
                text: $searchText,
                // The system placeholder gray reads at 1.7:1 on paper;
                // bruMuted reads at 4.5:1 or more in light and dark mode.
                prompt: Text("Search exercises").foregroundStyle(Color.bruMuted)
            ) {
                Text("Search exercises")
            }
            .font(.bru(.mono, size: 17))
            .foregroundStyle(Color.bruInk)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .focused($searchFocused)
            .onSubmit {
                debouncedSearch = searchText
                searchFocused = false
            }
            .accessibilityLabel("Search exercises")
            .accessibilityIdentifier(isPicker ? "library.search.picker" : "library.search.browser")
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    debouncedSearch = ""
                } label: {
                    Text("×")
                        .font(BRUFont.condensedHeading)
                        .foregroundStyle(Color.bruInk)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .background(Color.bruPaper)
        .contentShape(Rectangle())
        .onTapGesture { searchFocused = true }
        .overlay(alignment: .bottom) { BRUDivider(.ink) }
    }
}

// MARK: - FilteredExerciseList

/// Predicate-driven inner view. Its `init(predicate:)` re-creates the
/// `@Query` whenever the outer view passes a new predicate, so the query
/// stays subscribed while filters and search change.
///
/// Sectioning happens in Swift over the already-fetched rows (sorted by
/// `canonicalName`), grouping by first letter, with names that start with
/// a digit or a symbol under "#" after Z. At ~700 rows this is
/// sub-millisecond.
private struct FilteredExerciseList: View {
    @Query private var exercises: [Exercise]

    /// Logged exercises from finished workouts, for the per-row "N×" count.
    /// Single-level optional chain only (deeper chains crash #Predicate).
    @Query(filter: #Predicate<SessionExercise> { $0.session?.completedAt != nil })
    private var loggedExercises: [SessionExercise]

    /// Owning filter state. Read by the facet post-filter that the
    /// SwiftData predicate leaves out.
    let filterState: FilterState

    /// The active debounced search text (empty-state copy variant).
    let activeQuery: String

    /// `true` when at least one facet has a selection.
    let hasActiveFilters: Bool

    let clearFiltersAction: () -> Void
    let createCustomAction: () -> Void

    /// Picker-mode closure; nil in browse mode.
    let onSelect: ((Exercise) -> Void)?

    init(
        predicate: Predicate<Exercise>,
        filterState: FilterState,
        activeQuery: String,
        hasActiveFilters: Bool,
        clearFiltersAction: @escaping () -> Void,
        createCustomAction: @escaping () -> Void,
        onSelect: ((Exercise) -> Void)? = nil
    ) {
        self._exercises = Query(
            filter: predicate,
            sort: \Exercise.canonicalName,
            order: .forward
        )
        self.filterState = filterState
        self.activeQuery = activeQuery
        self.hasActiveFilters = hasActiveFilters
        self.clearFiltersAction = clearFiltersAction
        self.createCustomAction = createCustomAction
        self.onSelect = onSelect
    }

    /// Post-fetch filter: facets, applied in Swift over the search-pruned
    /// @Query result.
    private var visibleExercises: [Exercise] {
        filterState.applyPostFetchFilters(to: exercises)
    }

    /// Number of finished workouts that included each exercise.
    private var loggedCounts: [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for item in loggedExercises {
            if let id = item.exercise?.id { counts[id, default: 0] += 1 }
        }
        return counts
    }

    var body: some View {
        let visible = visibleExercises
        Group {
            if visible.isEmpty {
                EmptyLibraryView(
                    searchText: activeQuery,
                    onClearFilters: clearFiltersAction,
                    onCreateCustom: createCustomAction
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let counts = loggedCounts
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        resultCount(visible.count)
                        ForEach(sectioned(visible), id: \.letter) { section in
                            Section {
                                ForEach(section.exercises) { ex in
                                    row(ex, loggedCount: counts[ex.id] ?? 0)
                                    BRUDivider(.hair)
                                }
                            } header: {
                                sectionHeader(section.letter)
                            }
                        }
                    }
                }
                .scrollDismissesKeyboard(.immediately)
                .navigationDestination(for: Exercise.self) { ex in
                    ExerciseDetailView(exercise: ex)
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ ex: Exercise, loggedCount: Int) -> some View {
        if let onSelect {
            Button {
                onSelect(ex)
            } label: {
                ExerciseRow(exercise: ex, accessory: .add)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Adds this exercise")
            .accessibilityIdentifier("exercise.pick.\(ex.id.uuidString)")
        } else {
            NavigationLink(value: ex) {
                ExerciseRow(exercise: ex, accessory: .loggedCount(loggedCount))
            }
            .buttonStyle(.plain)
        }
    }

    private func resultCount(_ count: Int) -> some View {
        let filtered = !activeQuery.isEmpty || hasActiveFilters
        return Text(filtered
                    ? BRUCountLabel.text(count, "match", plural: "matches")
                    : BRUCountLabel.text(count, "exercise"))
            .font(BRUFont.labelSmall)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Color.bruMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
    }

    private func sectionHeader(_ letter: String) -> some View {
        Text(letter)
            .font(BRUFont.condensedLabel)
            .foregroundStyle(Color.bruInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.bruBg2)
            .overlay(alignment: .top) { BRUDivider(.ink) }
            .accessibilityAddTraits(.isHeader)
    }

    /// Groups rows by the first letter of their name, A to Z, then one "#"
    /// section, after Z, for names that start with a digit or a symbol,
    /// such as "3/4 Sit-Up". Rows inside each section keep the @Query sort
    /// order.
    private func sectioned(_ rows: [Exercise]) -> [(letter: String, exercises: [Exercise])] {
        let groups = Dictionary(grouping: rows) { ex in
            Self.sectionLetter(for: ex.name)
        }
        let letters = groups.keys.sorted { a, b in
            if a == Self.otherSection { return false }
            if b == Self.otherSection { return true }
            return a < b
        }
        return letters.map { letter in
            (letter, groups[letter] ?? [])
        }
    }

    /// The section for names that do not start with a letter.
    private static let otherSection = "#"

    private static func sectionLetter(for name: String) -> String {
        guard let first = name.first, first.isLetter else { return otherSection }
        return String(first).uppercased()
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
// "+" toolbar button directly to a sheet presenting the real
// `CustomExerciseEditor` wrapped in a `NavigationStack`. Review item 19
// drives that sheet with `.sheet(item:)` on the draft itself.


#Preview("With fixture") {
    ExerciseLibraryView()
        .modelContainer(PreviewModelContainer.make())
}

#Preview("Empty state") {
    ExerciseLibraryView()
        .modelContainer(PreviewModelContainer.make(seedFixture: false))
}
