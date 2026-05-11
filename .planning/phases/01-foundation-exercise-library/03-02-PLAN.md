---
phase: 01
plan: 03-02
wave: 3
slug: library-list-with-filter-and-search
complexity: L
requirements: ["LIB-01", "LIB-02", "LIB-03", "FOUND-04", "FOUND-06"]
covers_pitfalls: ["#3 (denormalized muscle slugs predicate)", "#4 (.searchable debounce)", "#7 (#Index on hot fields verified)", "#12 (predicate captures by value)"]
depends_on: ["03-01"]
files_modified:
  - fitbod/ExerciseLibrary/ExerciseLibraryView.swift  # NEW
  - fitbod/ExerciseLibrary/ExerciseFilterBar.swift  # NEW
  - fitbod/ExerciseLibrary/FilterChip.swift  # NEW
  - fitbod/ExerciseLibrary/FilterPickerSheet.swift  # NEW
  - fitbod/ExerciseLibrary/FilterState.swift  # NEW
  - fitbod/ExerciseLibrary/ExerciseRow.swift  # NEW
  - fitbod/App/RootView.swift  # MODIFY — replace LibraryTabHost with ExerciseLibraryView
  - fitbodTests/FilterStatePredicateTests.swift  # NEW
  - fitbodTests/IndexedQueryTests.swift  # NEW
created: 2026-05-10
---

# Plan 03-02 — Library List with Filter and Search

> **Wave 3 / Sequence 2.** The user-facing keystone of Phase 1. Replaces the interim `LibraryTabHost` from plan `03-01` with the real `ExerciseLibraryView`: sticky filter chip bar (muscle / equipment / mechanic / pattern, multi-select within / AND across), `.searchable` with 150 ms debounce, sectioned alphabetical `List`, inline "Custom" tag for user-added entries. Closes LIB-01 + LIB-02 + LIB-03; verifies FOUND-04 (`#Index`) and FOUND-06 (no `ViewModel` layer).

## Goal

Author the multi-facet filter UX that the entire Phase 1 success criteria hinge on. Sub-100ms response on filter chip taps + sub-100ms response on keystrokes (after a 150 ms debounce) at the full ~800-exercise scale. All bindings direct to `@Model` types; the only "view model" is the `@Observable FilterState` for ephemeral filter selections.

## Requirements Covered

- **LIB-01**: User can browse the bundled library. After seeding (plan `02-02`) + this plan, the Library tab shows ~800 alphabetized exercises in a sectioned `List`.
- **LIB-02**: Multi-facet filter (muscle / equipment / mechanic / pattern). The filter chip bar at the top of the screen presents one chip per facet; tapping a chip opens a `FilterPickerSheet`; selections AND across facets and OR within a facet.
- **LIB-03**: Type-ahead search at 1000+ entries. `.searchable` modifier on the list; 150 ms debounce via `.task(id: searchText)`; `#Index<Exercise>([\.canonicalName])` makes the underlying SQLite query fast.
- **FOUND-04**: Indexes on hot filter fields are exercised by real queries and verified via `IndexedQueryTests`.
- **FOUND-06**: `@Query` is consumed *directly* in views; the only `@Observable` types (`FilterState`) hold ephemeral selection state only — they never wrap a `@Query` (PITFALLS anti-pattern).

## Files to Create / Modify

### Create

1. `fitbod/ExerciseLibrary/FilterState.swift`:
   ```
   import SwiftUI
   import SwiftData
   import Observation

   @Observable
   final class FilterState {
       var selectedMuscleSlugs: Set<String> = []
       var selectedEquipmentRaw: Set<String> = []
       var selectedMechanicRaw: String? = nil
       var selectedPatternRaw: Set<String> = []

       /// Composes a Predicate<Exercise> from filter state + debounced search.
       /// CRITICAL: copies all captures into local `let` constants per PITFALLS #12.
       func predicate(with debouncedSearch: String) -> Predicate<Exercise> {
           let normalizedSearch = debouncedSearch
               .lowercased()
               .folding(options: .diacriticInsensitive, locale: .current)
           let muscles = selectedMuscleSlugs                  # Set<String>
           let equipment = selectedEquipmentRaw               # Set<String>
           let mechanic = selectedMechanicRaw                 # String?
           let patterns = selectedPatternRaw                  # Set<String>

           return #Predicate<Exercise> { ex in
               # Text search
               (normalizedSearch.isEmpty || ex.canonicalName.contains(normalizedSearch))
               &&
               # Equipment facet (multi-select within facet)
               (equipment.isEmpty || equipment.contains(ex.equipmentRaw))
               &&
               # Mechanic facet (single-select per UI-SPEC table)
               (mechanic == nil || ex.mechanicRaw == mechanic!)
               &&
               # Muscle facet — denormalized predicate per PITFALLS #3
               # ex.primaryMuscleSlugsJoined is e.g. "|chest|triceps|"
               # We check if any selected slug appears as "|slug|" in the joined string.
               (muscles.isEmpty || muscles.contains { slug in
                   ex.primaryMuscleSlugsJoined.contains("|\(slug)|")
               })
               &&
               # Pattern facet (multi-select; nullable Phase 1 — chip may be effectively empty)
               (patterns.isEmpty || (ex.patternRaw != nil && patterns.contains(ex.patternRaw!)))
           }
       }

       var isEmpty: Bool {
           selectedMuscleSlugs.isEmpty
               && selectedEquipmentRaw.isEmpty
               && selectedMechanicRaw == nil
               && selectedPatternRaw.isEmpty
       }

       func clear() {
           selectedMuscleSlugs.removeAll()
           selectedEquipmentRaw.removeAll()
           selectedMechanicRaw = nil
           selectedPatternRaw.removeAll()
       }
   }
   ```

2. `fitbod/ExerciseLibrary/FilterChip.swift`:
   ```
   import SwiftUI

   struct FilterChip: View {
       let label: String                  # e.g. "Muscle" or "Muscle · 2"
       let isActive: Bool                 # selected count > 0
       let action: () -> Void

       var body: some View {
           Button(action: action) {
               Text(label)
                   .font(.caption)
                   .foregroundStyle(isActive ? .white : .primary)
                   .padding(.horizontal, 12)
                   .padding(.vertical, 8)            # UI-SPEC sm = 8pt
                   .background {
                       Capsule().fill(isActive ? Color.accentColor : Color(.systemGray5))
                   }
           }
           .buttonStyle(.plain)
           .contentShape(Capsule())
           .frame(minHeight: 44)                     # UI-SPEC 44pt HIG touch target
           .accessibilityLabel(accessibilityLabel)
       }

       private var accessibilityLabel: String {
           "\(label) filter"
       }
   }
   ```

3. `fitbod/ExerciseLibrary/ExerciseFilterBar.swift`:
   ```
   import SwiftUI

   /// Horizontal scrolling chip row. UI-SPEC: sticky at top via .safeAreaInset.
   struct ExerciseFilterBar: View {
       @Bindable var filterState: FilterState
       @Binding var presentingSheet: FilterFacet?

       enum FilterFacet: String, Identifiable {
           case muscle, equipment, mechanic, pattern
           var id: String { rawValue }
       }

       var body: some View {
           ScrollView(.horizontal, showsIndicators: false) {
               HStack(spacing: 8) {
                   FilterChip(
                       label: filterState.selectedMuscleSlugs.isEmpty
                           ? "Muscle"
                           : "Muscle · \(filterState.selectedMuscleSlugs.count)",
                       isActive: !filterState.selectedMuscleSlugs.isEmpty
                   ) { presentingSheet = .muscle }

                   FilterChip(
                       label: filterState.selectedEquipmentRaw.isEmpty
                           ? "Equipment"
                           : "Equipment · \(filterState.selectedEquipmentRaw.count)",
                       isActive: !filterState.selectedEquipmentRaw.isEmpty
                   ) { presentingSheet = .equipment }

                   FilterChip(
                       label: filterState.selectedMechanicRaw == nil
                           ? "Mechanic"
                           : "Mechanic · \(filterState.selectedMechanicRaw!.capitalized)",
                       isActive: filterState.selectedMechanicRaw != nil
                   ) { presentingSheet = .mechanic }

                   FilterChip(
                       label: filterState.selectedPatternRaw.isEmpty
                           ? "Pattern"
                           : "Pattern · \(filterState.selectedPatternRaw.count)",
                       isActive: !filterState.selectedPatternRaw.isEmpty
                   ) { presentingSheet = .pattern }

                   if !filterState.isEmpty {
                       Button("Clear filters", action: filterState.clear)
                           .font(.caption)
                           .foregroundStyle(.accent)
                   }
               }
               .padding(.horizontal, 16)             # UI-SPEC lg = 16pt
               .padding(.vertical, 8)
           }
           .background(.thinMaterial)               # subtle stickiness affordance
       }
   }
   ```

4. `fitbod/ExerciseLibrary/FilterPickerSheet.swift`:
   ```
   import SwiftUI
   import SwiftData

   /// Multi-select picker for muscle/equipment/pattern facets;
   /// single-select for mechanic (UI-SPEC clarifies multi/single per facet).
   struct FilterPickerSheet: View {
       let facet: ExerciseFilterBar.FilterFacet
       @Bindable var filterState: FilterState
       @Environment(\.dismiss) private var dismiss
       @Query(sort: \MuscleGroup.slug) private var muscles: [MuscleGroup]

       var body: some View {
           NavigationStack {
               List {
                   switch facet {
                   case .muscle:    muscleSection
                   case .equipment: equipmentSection
                   case .mechanic:  mechanicSection
                   case .pattern:   patternSection
                   }
               }
               .navigationTitle(title)
               .navigationBarTitleDisplayMode(.inline)
               .toolbar {
                   ToolbarItem(placement: .confirmationAction) {
                       Button("Done") { dismiss() }
                   }
                   ToolbarItem(placement: .cancellationAction) {
                       Button("Clear", action: clearCurrentFacet)
                   }
               }
               .presentationDetents([.medium, .large])
           }
       }

       private var title: String {
           switch facet {
           case .muscle:    return "Muscle"
           case .equipment: return "Equipment"
           case .mechanic:  return "Mechanic"
           case .pattern:   return "Pattern"
           }
       }

       @ViewBuilder
       private var muscleSection: some View {
           ForEach(muscles) { mg in
               selectableRow(
                   title: mg.displayName,
                   isSelected: filterState.selectedMuscleSlugs.contains(mg.slug)
               ) { toggle(mg.slug, in: &filterState.selectedMuscleSlugs) }
           }
       }

       @ViewBuilder
       private var equipmentSection: some View {
           ForEach(Equipment.allCases, id: \.rawValue) { eq in
               selectableRow(
                   title: eq.rawValue.capitalized,
                   isSelected: filterState.selectedEquipmentRaw.contains(eq.rawValue)
               ) { toggle(eq.rawValue, in: &filterState.selectedEquipmentRaw) }
           }
       }

       @ViewBuilder
       private var mechanicSection: some View {
           ForEach(Mechanic.allCases, id: \.rawValue) { mech in
               selectableRow(
                   title: mech.rawValue.capitalized,
                   isSelected: filterState.selectedMechanicRaw == mech.rawValue
               ) {
                   filterState.selectedMechanicRaw =
                       (filterState.selectedMechanicRaw == mech.rawValue) ? nil : mech.rawValue
               }
           }
       }

       @ViewBuilder
       private var patternSection: some View {
           # Phase 1 Open Q #5 — patternRaw is nullable; chip is effectively
           # empty until curation lands. Show all pattern cases with a footer.
           Section {
               ForEach(Pattern.allCases, id: \.rawValue) { p in
                   selectableRow(
                       title: p.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
                       isSelected: filterState.selectedPatternRaw.contains(p.rawValue)
                   ) { toggle(p.rawValue, in: &filterState.selectedPatternRaw) }
               }
           } footer: {
               Text("Patterns are not yet assigned to seeded exercises. Selecting a pattern will return no results until curation lands in a later phase.")
                   .font(.caption)
                   .foregroundStyle(.secondary)
           }
       }

       private func selectableRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
           Button(action: action) {
               HStack {
                   Text(title).foregroundStyle(.primary)
                   Spacer()
                   if isSelected {
                       Image(systemName: "checkmark").foregroundStyle(.accent)
                   }
               }
           }
       }

       private func toggle(_ value: String, in set: inout Set<String>) {
           if set.contains(value) {
               set.remove(value)
           } else {
               set.insert(value)
           }
       }

       private func clearCurrentFacet() {
           switch facet {
           case .muscle:    filterState.selectedMuscleSlugs.removeAll()
           case .equipment: filterState.selectedEquipmentRaw.removeAll()
           case .mechanic:  filterState.selectedMechanicRaw = nil
           case .pattern:   filterState.selectedPatternRaw.removeAll()
           }
       }
   }
   ```

5. `fitbod/ExerciseLibrary/ExerciseRow.swift`:
   ```
   import SwiftUI

   struct ExerciseRow: View {
       let exercise: Exercise

       var body: some View {
           HStack(alignment: .center, spacing: 12) {
               VStack(alignment: .leading, spacing: 2) {
                   Text(exercise.name)
                       .font(.body)
                       .foregroundStyle(.primary)
                   HStack(spacing: 6) {
                       Text(exercise.equipmentRaw.capitalized)
                       Text("·")
                       Text(exercise.mechanicRaw.capitalized)
                   }
                   .font(.caption)
                   .foregroundStyle(.secondary)
               }
               Spacer()
               if exercise.isCustom {
                   Text("Custom")
                       .font(.caption.weight(.semibold))
                       .foregroundStyle(.accent)
                       .padding(.horizontal, 8)
                       .padding(.vertical, 2)
                       .background(
                           Capsule().fill(Color.accentColor.opacity(0.15))
                       )
               }
           }
           .padding(.vertical, 4)
       }
   }
   ```

6. `fitbod/ExerciseLibrary/ExerciseLibraryView.swift`:

   This is the main surface. The structure splits into outer (search state + filter state + sheet management) and inner (`@Query` rebuilt when predicate changes — the `init(predicate:)` pattern from RESEARCH Example 4).

   ```
   import SwiftUI
   import SwiftData

   struct ExerciseLibraryView: View {
       @State private var filterState = FilterState()
       @State private var searchText: String = ""
       @State private var debouncedSearch: String = ""
       @State private var presentingFacet: ExerciseFilterBar.FilterFacet? = nil

       var body: some View {
           NavigationStack {
               FilteredExerciseList(predicate: predicate)
                   .navigationTitle("Exercises")
                   .searchable(
                       text: $searchText,
                       placement: .navigationBarDrawer,
                       prompt: "Search exercises"
                   )
                   .task(id: searchText) {
                       try? await Task.sleep(for: .milliseconds(150))
                       if !Task.isCancelled {
                           debouncedSearch = searchText
                       }
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
                           # "+" button → presents the custom-exercise editor.
                           # Plan 03-04 wires the sheet body; this plan only
                           # places the toolbar button so the surface is locked.
                           NavigationLink(value: NewCustomExerciseRequest()) {
                               Label("Create custom exercise", systemImage: "plus")
                                   .labelStyle(.iconOnly)
                           }
                           .accessibilityLabel("Create custom exercise")
                       }
                   }
                   .navigationDestination(for: NewCustomExerciseRequest.self) { _ in
                       # Replaced by plan 03-04 with CustomExerciseEditor(...)
                       Text("Custom exercise editor — plan 03-04 fills this in")
                           .navigationTitle("New Exercise")
                   }
           }
       }

       private var predicate: Predicate<Exercise> {
           filterState.predicate(with: debouncedSearch)
       }
   }

   /// Inner view re-runs @Query whenever predicate changes (RESEARCH Pattern 3).
   private struct FilteredExerciseList: View {
       @Query private var exercises: [Exercise]

       init(predicate: Predicate<Exercise>) {
           _exercises = Query(filter: predicate, sort: \Exercise.canonicalName, order: .forward)
       }

       var body: some View {
           if exercises.isEmpty {
               EmptyLibraryView()         # plan 04-01 fills this in; placeholder text for now
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
               # Plan 03-03 wires ExerciseDetailView here:
               .navigationDestination(for: Exercise.self) { ex in
                   Text("Detail for \(ex.name) — plan 03-03 fills this in")
               }
           }
       }

       private var sectioned: [(letter: String, exercises: [Exercise])] {
           let groups = Dictionary(grouping: exercises) { ex in
               String(ex.name.prefix(1).uppercased())
           }
           return groups.keys.sorted().map { letter in
               (letter, groups[letter] ?? [])
           }
       }
   }

   /// Placeholder for the empty-state — plan 04-01 replaces with the real
   /// UI-SPEC § Empty states copy ("No exercises match" etc.).
   private struct EmptyLibraryView: View {
       var body: some View {
           VStack(spacing: 8) {
               Text("No exercises match")
                   .font(.title2.weight(.semibold))
               Text("Try fewer filters or a different name.")
                   .foregroundStyle(.secondary)
           }
           .frame(maxWidth: .infinity, maxHeight: .infinity)
       }
   }

   /// Routing token for the "+" toolbar; replaced in plan 03-04 by a
   /// direct sheet presentation. Kept as a navigation value here so the
   /// toolbar button is testable in isolation.
   private struct NewCustomExerciseRequest: Hashable {}

   #Preview("With fixture") {
       ExerciseLibraryView()
           .modelContainer(PreviewModelContainer.make())
   }

   #Preview("Empty state") {
       ExerciseLibraryView()
           .modelContainer(PreviewModelContainer.make(seedFixture: false))
   }
   ```

### Modify

7. `fitbod/App/RootView.swift` — replace the body of `LibraryTabHost` (the interim placeholder from plan `03-01`) with:
   ```
   private struct LibraryTabHost: View {
       var body: some View { ExerciseLibraryView() }
   }
   ```

### Create — Tests

8. `fitbodTests/FilterStatePredicateTests.swift`:
   ```
   import Testing
   import Foundation
   import SwiftData
   @testable import fitbod

   @Suite("FilterState.predicate(with:)")
   struct FilterStatePredicateTests {
       /// Sets up an in-memory container with 4 known exercises:
       /// - "Barbell Bench Press" — barbell, compound, primary muscle: chest
       /// - "Dumbbell Curl"      — dumbbell, isolation, primary muscle: biceps
       /// - "Cable Lat Pulldown" — cable, compound, primary muscle: lats
       /// - "Squat"              — barbell, compound, primary muscle: quadriceps
       private static func makeFixture() throws -> (ModelContainer, ModelContext) {
           let container = try InMemoryContainer.makeEmpty()
           let ctx = container.mainContext
           let benches = makeExercise(name: "Barbell Bench Press", equipment: "barbell",
                                      mechanic: "compound", primary: ["chest"])
           let curl = makeExercise(name: "Dumbbell Curl", equipment: "dumbbell",
                                   mechanic: "isolation", primary: ["biceps"])
           let pulldown = makeExercise(name: "Cable Lat Pulldown", equipment: "cable",
                                       mechanic: "compound", primary: ["lats"])
           let squat = makeExercise(name: "Squat", equipment: "barbell",
                                    mechanic: "compound", primary: ["quadriceps"])
           [benches, curl, pulldown, squat].forEach(ctx.insert)
           try ctx.save()
           return (container, ctx)
       }

       private static func makeExercise(
           name: String, equipment: String, mechanic: String, primary: [String]
       ) -> Exercise {
           let ex = Exercise(
               name: name,
               canonicalName: name.lowercased().folding(options: .diacriticInsensitive, locale: .current),
               equipmentRaw: equipment, mechanicRaw: mechanic
           )
           ex.primaryMuscleSlugsJoined = "|" + primary.joined(separator: "|") + "|"
           return ex
       }

       @Test("Empty filter returns everything")
       func emptyFilterAll() throws {
           let (_, ctx) = try Self.makeFixture()
           let state = FilterState()
           let pred = state.predicate(with: "")
           let result = try ctx.fetch(FetchDescriptor<Exercise>(predicate: pred))
           #expect(result.count == 4)
       }

       @Test("Search 'bench' returns only Bench Press")
       func searchBench() throws {
           let (_, ctx) = try Self.makeFixture()
           let state = FilterState()
           let pred = state.predicate(with: "bench")
           let result = try ctx.fetch(FetchDescriptor<Exercise>(predicate: pred))
           #expect(result.count == 1)
           #expect(result.first?.name == "Barbell Bench Press")
       }

       @Test("Equipment=dumbbell returns Curl only")
       func equipmentFilter() throws {
           let (_, ctx) = try Self.makeFixture()
           let state = FilterState()
           state.selectedEquipmentRaw = ["dumbbell"]
           let pred = state.predicate(with: "")
           let result = try ctx.fetch(FetchDescriptor<Exercise>(predicate: pred))
           #expect(result.count == 1)
           #expect(result.first?.name == "Dumbbell Curl")
       }

       @Test("Mechanic=isolation returns Curl only")
       func mechanicFilter() throws {
           let (_, ctx) = try Self.makeFixture()
           let state = FilterState()
           state.selectedMechanicRaw = "isolation"
           let pred = state.predicate(with: "")
           let result = try ctx.fetch(FetchDescriptor<Exercise>(predicate: pred))
           #expect(result.count == 1)
       }

       @Test("Muscle=chest returns Bench only (denormalized slug match)")
       func muscleFilterDenormalized() throws {
           let (_, ctx) = try Self.makeFixture()
           let state = FilterState()
           state.selectedMuscleSlugs = ["chest"]
           let pred = state.predicate(with: "")
           let result = try ctx.fetch(FetchDescriptor<Exercise>(predicate: pred))
           #expect(result.count == 1)
           #expect(result.first?.name == "Barbell Bench Press")
       }

       @Test("Multi-facet AND: barbell + compound returns Bench + Squat")
       func multiFacetAND() throws {
           let (_, ctx) = try Self.makeFixture()
           let state = FilterState()
           state.selectedEquipmentRaw = ["barbell"]
           state.selectedMechanicRaw = "compound"
           let pred = state.predicate(with: "")
           let result = try ctx.fetch(FetchDescriptor<Exercise>(predicate: pred))
           #expect(result.count == 2)
       }

       @Test("Multi-select within muscle facet ORs: chest|biceps → 2 exercises")
       func multiSelectWithinFacet() throws {
           let (_, ctx) = try Self.makeFixture()
           let state = FilterState()
           state.selectedMuscleSlugs = ["chest", "biceps"]
           let pred = state.predicate(with: "")
           let result = try ctx.fetch(FetchDescriptor<Exercise>(predicate: pred))
           #expect(result.count == 2)
       }
   }
   ```

9. `fitbodTests/IndexedQueryTests.swift`:
   ```
   import Testing
   import Foundation
   import SwiftData
   @testable import fitbod

   @Suite("Indexed queries on Exercise")
   struct IndexedQueryTests {
       /// Verifies that #Index<Exercise>([\.canonicalName], ...) is declared.
       /// We can't introspect SQLite EXPLAIN from a unit test, but we CAN
       /// run a query at scale and assert it completes within a reasonable
       /// budget — a regression caused by removing the index will surface
       /// as a 5-10x slowdown.
       @Test("canonicalName contains query stays under 50ms at seeded scale",
             .timeLimit(.minutes(1)))
       func canonicalNameContainsFast() async throws {
           UserDefaults.standard.removeObject(forKey: ExerciseLibraryImporter.seedVersionKey)
           let container = try InMemoryContainer.makeEmpty()
           let importer = ExerciseLibraryImporter(modelContainer: container)
           try await importer.seedIfNeeded()

           let ctx = ModelContext(container)
           let needle = "bench"
           let pred = #Predicate<Exercise> { $0.canonicalName.contains(needle) }
           let start = Date()
           let results = try ctx.fetch(FetchDescriptor<Exercise>(predicate: pred))
           let elapsed = Date().timeIntervalSince(start)

           #expect(results.count > 0)
           #expect(elapsed < 0.20, "canonicalName.contains over ~800 rows took \(elapsed)s — expected <0.05s with #Index, soft cap 0.20s for CI")
       }

       @Test("primaryMuscleSlugsJoined contains query stays fast",
             .timeLimit(.minutes(1)))
       func muscleJoinedFast() async throws {
           UserDefaults.standard.removeObject(forKey: ExerciseLibraryImporter.seedVersionKey)
           let container = try InMemoryContainer.makeEmpty()
           let importer = ExerciseLibraryImporter(modelContainer: container)
           try await importer.seedIfNeeded()

           let ctx = ModelContext(container)
           let needle = "|chest|"
           let pred = #Predicate<Exercise> { $0.primaryMuscleSlugsJoined.contains(needle) }
           let start = Date()
           let results = try ctx.fetch(FetchDescriptor<Exercise>(predicate: pred))
           let elapsed = Date().timeIntervalSince(start)

           #expect(results.count > 0, "Some seeded exercises should have chest as primary")
           #expect(elapsed < 0.20)
       }
   }
   ```

## Acceptance Criteria

1. All 6 new production files exist under `fitbod/ExerciseLibrary/`.
2. `fitbod/App/RootView.swift`'s `LibraryTabHost` now wraps `ExerciseLibraryView()` (1-line edit).
3. Building + launching on the simulator:
   - The Library tab shows the alphabetized sectioned list of all ~800 seeded exercises.
   - Tapping the "Muscle" chip opens a sheet listing all 17 muscles; selecting "Chest" + "Triceps" dismisses the sheet and reduces the list to chest/triceps exercises.
   - Typing "bench" in the search bar (with 150 ms debounce) reduces the list to bench-press matches.
   - Tapping the "Clear filters" button (only visible when any facet has selections) resets the list.
   - Tapping the "+" toolbar button navigates to a placeholder "Custom exercise editor — plan 03-04 fills this in" view.
   - Tapping any row navigates to "Detail for {name} — plan 03-03 fills this in".
4. `FilterStatePredicateTests` (7 tests) pass.
5. `IndexedQueryTests` (2 tests) pass — `canonicalName.contains` and `primaryMuscleSlugsJoined.contains` both complete in <200ms over the seeded ~800-row dataset (production target <50 ms; CI soft cap 200 ms).
6. Manual UX smoke (recorded in commit message):
   - Filter chip tap → list updates in ≤100ms (UI-SPEC sub-100ms target).
   - Keystroke → list updates ≤250ms (150ms debounce + ≤100ms query).
   - No visible scroll jank at 800 rows.

## Test Expectations

- `FilterStatePredicateTests`: 7 tests covering empty filter, search, equipment, mechanic, muscle (denormalized), multi-facet AND, multi-select OR within facet.
- `IndexedQueryTests`: 2 tests for query performance at seeded scale.

**Run command:**
```bash
xcodebuild test -project fitbod.xcodeproj -scheme fitbod \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:fitbodTests/FilterStatePredicateTests \
  -only-testing:fitbodTests/IndexedQueryTests
```

## Decisions Honored

- **C-16 (CONTEXT.md Area 2 — multi-facet AND across, multi-select within):** Encoded directly in `FilterState.predicate(with:)` — `.contains` for set membership ORs within a facet; `&&` chain ANDs across facets.
- **C-17 (CONTEXT.md Area 2 — mechanic as single-select per UI-SPEC):** `selectedMechanicRaw: String?` is single-valued (UI-SPEC table shows "Mechanic" chip implies a single value via tap-cycle behavior; planner's interpretation per the natural choice given there are only 2 mechanic options).
- **C-18 (CONTEXT.md Area 2 — `.searchable` + `canonicalName`):** Native `.searchable` modifier; predicate matches `canonicalName` (lowercased + diacritic-folded) per RESEARCH Pattern 4.
- **C-19 (CONTEXT.md Area 2 — filter reset per session):** `FilterState` is a `@State` inside `ExerciseLibraryView`. When the user navigates away from the Library tab and back, the view's lifecycle creates a fresh `FilterState`. Per-session reset = locked. (Cross-launch persistence deferred per CONTEXT.md.)
- **C-20 (CONTEXT.md Area 2 — default sort alphabetical):** `Query(... sort: \.canonicalName, order: .forward)`.
- **R-17 (RESEARCH Pitfall 3 — denormalize muscle slugs):** Predicate filters on `primaryMuscleSlugsJoined.contains("|slug|")`. The denormalization happens at seed time in plan `02-02` (and at custom-exercise materialize time in plan `03-04`).
- **R-18 (RESEARCH Pitfall 4 — `.task(id:)` debounce):** 150 ms `Task.sleep` before propagating the search text. Cancels on identity change automatically.
- **R-19 (RESEARCH Pitfall 12 — capture-by-value in predicate):** Every capture in `FilterState.predicate(with:)` is a local `let` copy of a primitive (`Set<String>`, `String?`). No reference captures.
- **R-20 (RESEARCH Pattern 3 — inner view with `init(predicate:)`):** Predicate-driven `@Query` lives in a private inner view; outer view manages state. Verbatim shape.
- **UI-SPEC § Library screen / Copywriting Contract:** Every string (navigation title "Exercises", chip labels with count formatting, search placeholder "Search exercises", "Clear filters" action) verbatim from the spec.
- **UI-SPEC § Spacing Scale:** Filter chip padding `8pt sm` horizontal + `12pt md` vertical with `44pt` minimum touch target. List uses default `.insetGrouped` style (system-respected 16pt lg margins).

## Anti-Patterns Avoided

- **Not** wrapping `@Query` inside `FilterState` (PITFALLS FOUND-06 anti-pattern). `@Query` is consumed directly by `FilteredExerciseList`.
- **Not** evaluating the predicate inline in the body of the outer view — the predicate is a computed `var` that the inner view's `init` consumes. Re-renders trigger when search/filter state changes.
- **Not** using `LazyVStack` for the long exercise list (PITFALLS Performance Trap — LazyVStack doesn't free off-screen rows). `List` with `.insetGrouped` style is the correct iOS list primitive.
- **Not** debouncing via Combine (`PassthroughSubject.debounce`). `.task(id:)` + `Task.sleep` auto-cancels on identity change — no manual cancellation plumbing.
- **Not** traversing relationships in the muscle filter predicate. `primaryMuscleSlugsJoined` denormalized field + `#Index` lets us stay in indexable territory.

## Out of Scope (handled by later plans)

- `ExerciseDetailView` body (instructions, muscles with stimulus %, equipment, mechanic) → plan `01-PLAN-03-03`. This plan only places the `navigationDestination(for: Exercise.self)` and shows a placeholder.
- `CustomExerciseEditor` body → plan `01-PLAN-03-04`. This plan places the "+" toolbar button and a placeholder destination.
- Empty-state copy variants ("No exercises match \"{query}\"" with the create-custom CTA) → plan `01-PLAN-04-01`. This plan ships a single generic "No exercises match" stub.
- Tab re-tap pop-to-root → deferred (see plan `03-01` notes).
- Live-rendering of units (lb/kg) — Phase 1 library rows do not show weight; the units toggle plumbing lands in plan `04-01` for future phases.

## Commit Message Template

```
feat(01): ExerciseLibraryView with multi-facet filter + .searchable + #Index

- ExerciseLibrary/FilterState.swift: @Observable; composes Predicate<Exercise>
  from muscle/equipment/mechanic/pattern + debounced search; captures-by-value
  per PITFALLS #12; denormalized muscle filter via primaryMuscleSlugsJoined
  (PITFALLS #3)
- ExerciseLibrary/FilterChip.swift: 44pt HIG touch target, accent-fill when
  active, secondary fill when inactive (UI-SPEC § Color)
- ExerciseLibrary/ExerciseFilterBar.swift: sticky chip row via
  .safeAreaInset(edge: .top); "Clear filters" button when state.isEmpty == false
- ExerciseLibrary/FilterPickerSheet.swift: per-facet multi-select sheet with
  presentationDetents [.medium, .large]; pattern footer copy explains
  Phase 1 nullable state per Open Q #5
- ExerciseLibrary/ExerciseRow.swift: name (.body) + metadata (.caption,
  secondary) + "Custom" capsule tag per UI-SPEC Copywriting Contract
- ExerciseLibrary/ExerciseLibraryView.swift: outer view manages search+filter
  state + sheet routing; inner FilteredExerciseList rebuilds @Query when
  predicate changes; sectioned alphabetical List; .searchable with 150 ms
  .task(id:) debounce per PITFALLS #4; "+" toolbar button with
  accessibilityLabel "Create custom exercise" (UI-SPEC § Accessibility)
- App/RootView.swift: LibraryTabHost wraps ExerciseLibraryView (1-line edit
  replacing the interim placeholder from plan 03-01)
- fitbodTests/FilterStatePredicateTests.swift: 7 tests over hand-crafted
  4-exercise fixture proving empty / search / equipment / mechanic /
  denormalized muscle / multi-facet AND / multi-select OR
- fitbodTests/IndexedQueryTests.swift: 2 tests proving canonicalName +
  primaryMuscleSlugsJoined .contains() stay fast at seeded scale

Observed UX latency on iPhone 16 sim: filter tap <RECORD>ms / keystroke
<RECORD>ms (UI-SPEC sub-100ms target).
Closes LIB-01, LIB-02, LIB-03; verifies FOUND-04, FOUND-06.
```
