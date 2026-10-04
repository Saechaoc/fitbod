//
//  ExerciseLibraryView.swift
//  fitbod
//
//  Exercise library (Chalkline redesign of plan 03-02). One view, three
//  modes:
//
//    - browse      Library tab. Owns a NavigationStack; rows push the
//                  exercise detail; "+" creates a custom exercise.
//    - pick one    `init(onSelect:)` — swap / quick add. Tapping a row
//                  fires the closure. No NavigationStack of its own (the
//                  presenting sheet provides one).
//    - pick many   `init(selection:)` — routine builder / add to workout.
//                  Rows toggle a check; order of taps is preserved.
//
//  Sticky header: search (150 ms debounce), filter chips (Muscle ▾,
//  Equipment ▾, Custom, Clear), and a result line that always states the
//  count and the active filters. Facets are multi-select within, AND
//  across (FilterState). Searching is a SwiftData predicate on the indexed
//  `canonicalName`; facets are applied in memory over that result
//  (FilterState header explains why).
//
//  Empty results offer the next step: with a query, "Create “query”"
//  (pre-filled custom exercise); with filters, "Clear filters".
//

import SwiftUI
import SwiftData

public struct ExerciseLibraryView: View {
    enum Mode {
        case browse
        case pickOne
        case pickMany
    }

    @Environment(\.modelContext) private var ctx
    @State private var filterState = FilterState()
    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var presentingFacet: ExerciseFilterBar.FilterFacet?
    @State private var newCustomDraft: CustomExerciseDraft?
    @State private var totalCount = 0
    @State private var internalPath = NavigationPath()

    private let mode: Mode
    private var externalPath: Binding<NavigationPath>?
    private var onSelect: ((Exercise) -> Void)?
    private var selection: Binding<[Exercise]>?

    /// Browse mode with an internal navigation path (previews, tests).
    public init() {
        self.mode = .browse
    }

    /// Browse mode; the path lives in `AppRouter` so a tab re-tap pops it.
    public init(path: Binding<NavigationPath>) {
        self.mode = .browse
        self.externalPath = path
    }

    /// Single pick (RESEARCH § Pattern 5).
    public init(onSelect: @escaping (Exercise) -> Void) {
        self.mode = .pickOne
        self.onSelect = onSelect
    }

    /// Multi pick; selection order is preserved.
    public init(selection: Binding<[Exercise]>) {
        self.mode = .pickMany
        self.selection = selection
    }

    public var body: some View {
        if mode == .browse {
            NavigationStack(path: externalPath ?? $internalPath) {
                content
                    .navigationTitle("EXERCISES")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                startCustom(named: "")
                            } label: {
                                Image(systemName: "plus")
                            }
                            .accessibilityLabel("Create custom exercise")
                            .accessibilityIdentifier("library.addCustom")
                        }
                    }
                    .appRouteDestinations()
            }
        } else {
            content
        }
    }

    private var content: some View {
        FilteredExerciseList(
            predicate: filterState.swiftDataPredicate(with: debouncedSearch),
            filterState: filterState,
            activeQuery: debouncedSearch,
            mode: mode,
            onSelect: onSelect,
            selection: selection,
            onCreateCustom: { startCustom(named: debouncedSearch) }
        )
        .chalkCanvasBackground()
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: Chalk.Space.sm) {
                ChalkSearchField(text: $searchText, prompt: totalCount > 0 ? "Search \(totalCount) exercises" : "Search exercises")
                ExerciseFilterBar(filterState: filterState, presentingSheet: $presentingFacet)
            }
            .padding(.horizontal, Chalk.Space.gutter)
            .padding(.top, Chalk.Space.xs)
            .padding(.bottom, Chalk.Space.sm)
            // Only behind the header itself: a background extending into the
            // top safe area (the default) paints over the large title.
            .background(Color.chalkCanvas, ignoresSafeAreaEdges: [])
        }
        .task(id: searchText) {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            debouncedSearch = searchText
        }
        .task {
            totalCount = (try? ctx.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        }
        .sheet(item: $presentingFacet) { facet in
            FilterPickerSheet(facet: facet, filterState: filterState)
        }
        .sheet(item: $newCustomDraft) { draft in
            NavigationStack {
                CustomExerciseEditor(draft: draft)
            }
        }
    }

    private func startCustom(named name: String) {
        let draft = CustomExerciseDraft()
        draft.name = name.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
        newCustomDraft = draft
    }
}

// MARK: - Filtered list

/// Owns the `@Query`; re-created whenever the outer view passes a new
/// predicate (RESEARCH § Pattern 3 / Code Example 4).
private struct FilteredExerciseList: View {
    @Query private var exercises: [Exercise]
    let filterState: FilterState
    let activeQuery: String
    let mode: ExerciseLibraryView.Mode
    let onSelect: ((Exercise) -> Void)?
    let selection: Binding<[Exercise]>?
    let onCreateCustom: () -> Void

    init(
        predicate: Predicate<Exercise>,
        filterState: FilterState,
        activeQuery: String,
        mode: ExerciseLibraryView.Mode,
        onSelect: ((Exercise) -> Void)?,
        selection: Binding<[Exercise]>?,
        onCreateCustom: @escaping () -> Void
    ) {
        self._exercises = Query(filter: predicate, sort: \Exercise.canonicalName, order: .forward)
        self.filterState = filterState
        self.activeQuery = activeQuery
        self.mode = mode
        self.onSelect = onSelect
        self.selection = selection
        self.onCreateCustom = onCreateCustom
    }

    private var visible: [Exercise] {
        filterState.applyPostFetchFilters(to: exercises)
    }

    var body: some View {
        let rows = visible
        if rows.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: Chalk.Space.md) {
                    resultLine(count: 0)
                    EmptyLibraryView(
                        searchText: activeQuery,
                        onClearFilters: filterState.clear,
                        onCreateCustom: onCreateCustom,
                        hasActiveFilters: !filterState.isEmpty
                    )
                }
                .padding(Chalk.Space.gutter)
            }
        } else {
            List {
                Section {
                    resultLine(count: rows.count)
                        .listRowInsets(EdgeInsets(top: 0, leading: Chalk.Space.xs, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                }
                ForEach(sections(of: rows), id: \.letter) { section in
                    Section {
                        ForEach(section.exercises) { exercise in
                            row(for: exercise)
                                .listRowBackground(Color.chalkSurface)
                        }
                    } header: {
                        Text(section.letter)
                            .chalkLabelStyle()
                            .accessibilityAddTraits(.isHeader)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.immediately)
        }
    }

    @ViewBuilder
    private func row(for exercise: Exercise) -> some View {
        switch mode {
        case .browse:
            NavigationLink(value: AppRoute.exercise(exercise)) {
                ExerciseRow(exercise: exercise)
            }
            .accessibilityIdentifier("exercise.row")
        case .pickOne:
            Button {
                onSelect?(exercise)
            } label: {
                ExerciseRow(exercise: exercise)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("exercise.row")
        case .pickMany:
            let isSelected = selection?.wrappedValue.contains { $0.id == exercise.id } ?? false
            Button {
                toggle(exercise)
            } label: {
                ExerciseRow(exercise: exercise, isSelected: isSelected)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityIdentifier("exercise.row")
        }
    }

    private func toggle(_ exercise: Exercise) {
        guard let selection else { return }
        if let index = selection.wrappedValue.firstIndex(where: { $0.id == exercise.id }) {
            selection.wrappedValue.remove(at: index)
        } else {
            selection.wrappedValue.append(exercise)
        }
    }

    private func resultLine(count: Int) -> some View {
        Text(resultText(count: count))
            .chalkLabelStyle()
            .accessibilityIdentifier("library.resultCount")
    }

    /// "48 exercises · Chest · Barbell, Dumbbell"
    private func resultText(count: Int) -> String {
        var parts = ["\(count) exercise\(count == 1 ? "" : "s")"]
        if !filterState.selectedMuscleSlugs.isEmpty {
            parts.append(filterState.selectedMuscleSlugs.sorted().map { MuscleRegionMap.displayName(for: $0) }.joined(separator: ", "))
        }
        if !filterState.selectedEquipmentRaw.isEmpty {
            parts.append(filterState.selectedEquipmentRaw.sorted().map { ExerciseRow.equipmentName($0) }.joined(separator: ", "))
        }
        if filterState.customOnly {
            parts.append("Custom")
        }
        return parts.joined(separator: " · ")
    }

    private func sections(of rows: [Exercise]) -> [(letter: String, exercises: [Exercise])] {
        let groups = Dictionary(grouping: rows) { exercise in
            String(exercise.name.prefix(1).uppercased())
        }
        return groups.keys.sorted().map { letter in
            (letter, groups[letter] ?? [])
        }
    }
}

// MARK: - Picker sheet

/// Library in a sheet for choosing exercises. Multi-select shows a
/// thumb-zone "Add N exercises" bar; single-select returns on tap.
struct ExercisePickerSheet: View {
    let title: String
    let allowsMultipleSelection: Bool
    let onPick: ([Exercise]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selection: [Exercise] = []

    var body: some View {
        NavigationStack {
            Group {
                if allowsMultipleSelection {
                    ExerciseLibraryView(selection: $selection)
                } else {
                    ExerciseLibraryView(onSelect: { exercise in
                        onPick([exercise])
                        dismiss()
                    })
                }
            }
            .navigationTitle(title.uppercased())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("picker.cancel")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if allowsMultipleSelection {
                    ChalkBottomBar {
                        Button(addTitle) {
                            onPick(selection)
                            dismiss()
                        }
                        .buttonStyle(.chalk(.primary, size: .large, fullWidth: true))
                        .disabled(selection.isEmpty)
                        .accessibilityIdentifier("picker.add")
                    }
                }
            }
        }
    }

    private var addTitle: String {
        switch selection.count {
        case 0: return "Select exercises"
        case 1: return "Add 1 exercise"
        default: return "Add \(selection.count) exercises"
        }
    }
}

#Preview("Library") {
    ExerciseLibraryView()
        .environment(AppRouter())
        .modelContainer(PreviewModelContainer.make())
}
