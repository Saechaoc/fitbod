---
phase: 01
plan: 03-04
wave: 3
slug: custom-exercise-editor
complexity: L
requirements: ["LIB-04", "LIB-05", "LIB-06", "FOUND-06", "FOUND-07"]
covers_pitfalls: ["#5 (custom muscle mapping required)", "#8 (Exercise→SessionExercise nullify on delete)"]
depends_on: ["03-02"]
files_modified:
  - fitbod/ExerciseLibrary/CustomExerciseDraft.swift  # NEW
  - fitbod/ExerciseLibrary/CustomExerciseEditor.swift  # NEW
  - fitbod/ExerciseLibrary/MusclePickerSheet.swift  # NEW
  - fitbod/ExerciseLibrary/MuscleWeightRow.swift  # NEW
  - fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift  # NEW (PhotosUI wrapper)
  - fitbod/ExerciseLibrary/ExerciseLibraryView.swift  # MODIFY — wire "+" toolbar destination
  - fitbodTests/CustomExerciseDraftTests.swift  # NEW
created: 2026-05-10
---

# Plan 03-04 — Custom Exercise Editor

> **Wave 3 / Sequence 4.** Ships the custom-exercise creation surface — the one place where Pitfall #5 (silent volume corruption from optional muscle mapping) gets enforced via a `CustomExerciseDraft.isValid` guard on the Save button. Pure value-type validation (FOUND-07 in microcosm), `@Observable` form state (FOUND-06), `PhotosPicker` for optional image (no permission entitlement needed).

## Goal

Author the `CustomExerciseEditor` `Form` view, its `CustomExerciseDraft` `@Observable` backing state, the muscle picker sheet, the per-muscle stimulus-weight slider row, the `PhotosPicker` image attachment surface, and the validation guard that blocks Save until ≥1 primary muscle with stimulus ≥0.5 is mapped. Wire the "+" toolbar button from plan `03-02` to present this editor as a `.sheet`.

## Requirements Covered

- **LIB-04**: Custom exercise creation with required primary muscle (with stimulus weight), equipment, mechanic, optional image. Form gates Save until valid.
- **LIB-05**: Delete behavior — the cascade rule `Exercise → SessionExercise: nullify` is already in the schema (plan `01-01`); this plan exposes a delete affordance from the editor toolbar (`Edit Exercise` mode only — `New Exercise` has no delete button since nothing exists to delete yet). Includes the UI-SPEC § Error states confirmation alert for "logged history will be preserved" (cosmetic in Phase 1 since no sessions exist yet — but the wiring is in place).
- **LIB-06**: Equipment + mechanic pickers expose all 9 `Equipment` cases (including `weightedBodyweight`) and both `Mechanic` cases.
- **FOUND-06**: The editor binds to a `@Observable` `CustomExerciseDraft` (ephemeral state) and never wraps a `@Query`. Materialization (`draft.materialize(into:)`) writes a new `@Model Exercise` directly through `modelContext.insert(_)`.
- **FOUND-07** (in microcosm): `CustomExerciseDraft.isValid` is a pure-value-type computed property, testable in `CustomExerciseDraftTests` without a `ModelContainer`.

## Files to Create / Modify

### Create

1. `fitbod/ExerciseLibrary/CustomExerciseDraft.swift`:
   ```
   import Observation
   import SwiftData
   import Foundation

   @Observable
   final class CustomExerciseDraft {
       var name: String = ""
       var equipment: Equipment = .barbell
       var mechanic: Mechanic = .compound
       var muscles: [MuscleAssignment] = []
       var imageData: Data? = nil

       /// Set by the editor when "Edit Exercise" mode is opened with an existing
       /// custom Exercise; nil for "New Exercise" mode. Drives the navigation
       /// title and gates the delete button.
       var editingExisting: Exercise? = nil

       struct MuscleAssignment: Identifiable, Equatable {
           var id = UUID()
           var slug: String
           var role: Role
           var weight: Double            # 0.0..1.0

           enum Role: String, Equatable, CaseIterable, Sendable {
               case primary, secondary
           }
       }

       /// Validation: name non-empty AND at least one primary muscle with weight >= 0.5.
       /// Pure value-type — no ModelContainer required (FOUND-07).
       var isValid: Bool {
           !name.trimmingCharacters(in: .whitespaces).isEmpty
               && muscles.contains { $0.role == .primary && $0.weight >= 0.5 }
       }

       /// Snapshot at view-appear used to detect unsaved changes.
       func snapshot() -> Snapshot {
           Snapshot(
               name: name,
               equipment: equipment,
               mechanic: mechanic,
               muscles: muscles,
               imageDataHash: imageData?.hashValue
           )
       }

       struct Snapshot: Equatable {
           let name: String
           let equipment: Equipment
           let mechanic: Mechanic
           let muscles: [MuscleAssignment]
           let imageDataHash: Int?
       }

       /// Insert a new Exercise + ExerciseMuscleStimulus rows into the context.
       /// Returns the newly created Exercise. CRITICAL: insert FIRST, then assign
       /// relationships (RESEARCH Pitfall 7).
       @discardableResult
       func materialize(into ctx: ModelContext, allMuscles: [MuscleGroup]) -> Exercise {
           let canonical = name
               .lowercased()
               .folding(options: .diacriticInsensitive, locale: .current)

           let primarySlugs = muscles.filter { $0.role == .primary }.map(\.slug)
           let joined = primarySlugs.isEmpty
               ? ""
               : "|" + primarySlugs.joined(separator: "|") + "|"

           let ex = Exercise(
               name: name,
               canonicalName: canonical,
               equipmentRaw: equipment.rawValue,
               mechanicRaw: mechanic.rawValue,
               category: "strength",
               isCustom: true
           )
           ex.primaryMuscleSlugsJoined = joined
           ex.imageData = imageData
           ctx.insert(ex)

           let muscleBySlug = Dictionary(uniqueKeysWithValues: allMuscles.map { ($0.slug, $0) })
           for assignment in muscles {
               guard let mg = muscleBySlug[assignment.slug] else { continue }
               let stim = ExerciseMuscleStimulus(
                   exercise: ex, muscle: mg,
                   role: assignment.role.rawValue, weight: assignment.weight
               )
               ctx.insert(stim)
           }
           return ex
       }

       /// Update an existing custom Exercise rather than creating a new one.
       /// Used by Edit Exercise mode (out of Phase 1 scope but the wiring is here).
       func updateExisting(in ctx: ModelContext, allMuscles: [MuscleGroup]) {
           guard let target = editingExisting else { return }
           target.name = name
           target.canonicalName = name.lowercased()
               .folding(options: .diacriticInsensitive, locale: .current)
           target.equipmentRaw = equipment.rawValue
           target.mechanicRaw = mechanic.rawValue
           target.imageData = imageData
           # Replace stimulus rows wholesale: drop existing, insert from draft.
           for old in target.muscleStimuli ?? [] {
               ctx.delete(old)
           }
           let muscleBySlug = Dictionary(uniqueKeysWithValues: allMuscles.map { ($0.slug, $0) })
           for assignment in muscles {
               guard let mg = muscleBySlug[assignment.slug] else { continue }
               let stim = ExerciseMuscleStimulus(
                   exercise: target, muscle: mg,
                   role: assignment.role.rawValue, weight: assignment.weight
               )
               ctx.insert(stim)
           }
           let primarySlugs = muscles.filter { $0.role == .primary }.map(\.slug)
           target.primaryMuscleSlugsJoined = primarySlugs.isEmpty
               ? ""
               : "|" + primarySlugs.joined(separator: "|") + "|"
       }
   }
   ```

2. `fitbod/ExerciseLibrary/MusclePickerSheet.swift`:
   ```
   import SwiftUI
   import SwiftData

   struct MusclePickerSheet: View {
       let onSelect: (MuscleGroup) -> Void
       @Environment(\.dismiss) private var dismiss
       @Query(sort: \MuscleGroup.slug) private var muscles: [MuscleGroup]

       var body: some View {
           NavigationStack {
               List {
                   ForEach(muscles) { mg in
                       Button {
                           onSelect(mg)
                           dismiss()
                       } label: {
                           HStack {
                               Text(mg.displayName).foregroundStyle(.primary)
                               Spacer()
                               Text(mg.region.rawValue.capitalized)
                                   .foregroundStyle(.secondary)
                                   .font(.caption)
                           }
                       }
                   }
               }
               .navigationTitle("Select Muscle")
               .navigationBarTitleDisplayMode(.inline)
               .toolbar {
                   ToolbarItem(placement: .cancellationAction) {
                       Button("Cancel") { dismiss() }
                   }
               }
           }
       }
   }
   ```

3. `fitbod/ExerciseLibrary/MuscleWeightRow.swift`:
   ```
   import SwiftUI

   struct MuscleWeightRow: View {
       @Binding var assignment: CustomExerciseDraft.MuscleAssignment
       let displayName: String          # resolved from the slug → MuscleGroup
       let onDelete: () -> Void

       var body: some View {
           VStack(alignment: .leading, spacing: 8) {
               HStack {
                   Text(displayName)
                       .font(.body)
                   Spacer()
                   Picker("Role", selection: $assignment.role) {
                       ForEach(CustomExerciseDraft.MuscleAssignment.Role.allCases, id: \.self) { role in
                           Text(role.rawValue.capitalized).tag(role)
                       }
                   }
                   .pickerStyle(.segmented)
                   .frame(maxWidth: 200)
                   Button(role: .destructive, action: onDelete) {
                       Image(systemName: "trash")
                   }
                   .buttonStyle(.plain)
                   .foregroundStyle(.secondary)
               }
               HStack {
                   Slider(value: $assignment.weight, in: 0.0...1.0, step: 0.05)
                       .accessibilityLabel("Stimulus weight for \(displayName)")
                       .accessibilityValue("\(Int((assignment.weight * 100).rounded())) percent")
                   Text("\(Int((assignment.weight * 100).rounded()))%")
                       .font(.body.monospacedDigit())
                       .foregroundStyle(.secondary)
                       .frame(width: 48, alignment: .trailing)
               }
           }
           .padding(.vertical, 4)
       }
   }
   ```

4. `fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift`:
   ```
   import SwiftUI
   import PhotosUI

   /// Native PhotosPicker — no permission entitlement required (RESEARCH Pattern 7).
   /// Uses the iOS-sandboxed PHPickerViewController under the hood.
   struct CustomExerciseImagePicker: View {
       @Bindable var draft: CustomExerciseDraft
       @State private var selection: PhotosPickerItem?

       var body: some View {
           VStack(alignment: .leading, spacing: 8) {
               if let data = draft.imageData, let ui = UIImage(data: data) {
                   Image(uiImage: ui)
                       .resizable()
                       .scaledToFit()
                       .frame(maxHeight: 200)
                       .clipShape(RoundedRectangle(cornerRadius: 8))
                       .overlay(alignment: .topTrailing) {
                           Button(role: .destructive) {
                               draft.imageData = nil
                               selection = nil
                           } label: {
                               Image(systemName: "xmark.circle.fill")
                                   .symbolRenderingMode(.palette)
                                   .foregroundStyle(.white, .black.opacity(0.6))
                                   .font(.title2)
                                   .padding(8)
                           }
                       }
               }
               PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
                   Label(draft.imageData == nil ? "Add Photo" : "Change Photo",
                         systemImage: "photo")
               }
           }
           .onChange(of: selection) { _, newValue in
               Task {
                   if let data = try? await newValue?.loadTransferable(type: Data.self) {
                       draft.imageData = data
                   }
               }
           }
       }
   }
   ```

5. `fitbod/ExerciseLibrary/CustomExerciseEditor.swift`:
   ```
   import SwiftUI
   import SwiftData

   struct CustomExerciseEditor: View {
       @Bindable var draft: CustomExerciseDraft
       @Environment(\.modelContext) private var modelContext
       @Environment(\.dismiss) private var dismiss
       @Query private var allMuscles: [MuscleGroup]

       @State private var initialSnapshot: CustomExerciseDraft.Snapshot? = nil
       @State private var presentingMusclePicker = false
       @State private var presentingCancelConfirmation = false
       @State private var presentingDeleteConfirmation = false

       private var isEditing: Bool { draft.editingExisting != nil }
       private var navigationTitle: String { isEditing ? "Edit Exercise" : "New Exercise" }

       var body: some View {
           Form {
               Section("Name") {
                   TextField("e.g. Cambered Bar Bench Press", text: $draft.name)
                       .textInputAutocapitalization(.words)
               }

               Section {
                   ForEach($draft.muscles) { $assignment in
                       MuscleWeightRow(
                           assignment: $assignment,
                           displayName: displayName(for: assignment.slug),
                           onDelete: { remove(assignment) }
                       )
                   }
                   Button(action: { presentingMusclePicker = true }) {
                       Label(addMuscleButtonLabel, systemImage: "plus")
                           .foregroundStyle(.accent)
                   }
               } header: {
                   Text("Muscles")
               } footer: {
                   Text("How much this exercise contributes to weekly volume for that muscle. 100% for primary, 50% for assisting muscles.")
                       .font(.caption)
                       .foregroundStyle(.secondary)
                   if !draft.isValid {
                       Text("At least one primary muscle is required to save.")
                           .font(.caption)
                           .foregroundStyle(Color(.systemRed))
                   }
               }

               Section("Equipment") {
                   Picker("Equipment", selection: $draft.equipment) {
                       ForEach(Equipment.allCases, id: \.self) { eq in
                           Text(eq.rawValue.replacingOccurrences(of: "_", with: " ").capitalized).tag(eq)
                       }
                   }
               }

               Section("Mechanic") {
                   Picker("Mechanic", selection: $draft.mechanic) {
                       ForEach(Mechanic.allCases, id: \.self) { mech in
                           Text(mech.rawValue.capitalized).tag(mech)
                       }
                   }
                   .pickerStyle(.segmented)
               }

               Section("Image (optional)") {
                   CustomExerciseImagePicker(draft: draft)
               }

               if isEditing {
                   Section {
                       Button("Delete Exercise", role: .destructive) {
                           presentingDeleteConfirmation = true
                       }
                   }
               }
           }
           .navigationTitle(navigationTitle)
           .navigationBarTitleDisplayMode(.inline)
           .toolbar {
               ToolbarItem(placement: .cancellationAction) {
                   Button("Cancel") {
                       if isDirty { presentingCancelConfirmation = true }
                       else { dismiss() }
                   }
               }
               ToolbarItem(placement: .confirmationAction) {
                   Button("Save", action: save)
                       .disabled(!draft.isValid)
                       .accessibilityHint(draft.isValid ? "" : "Add a primary muscle to enable saving")
               }
           }
           .sheet(isPresented: $presentingMusclePicker) {
               MusclePickerSheet { mg in
                   appendMuscle(mg)
               }
           }
           .confirmationDialog(
               "Discard Changes?",
               isPresented: $presentingCancelConfirmation,
               titleVisibility: .visible
           ) {
               Button("Discard", role: .destructive) { dismiss() }
               Button("Keep Editing", role: .cancel) {}
           }
           .alert(
               "Delete \"\(draft.name)\"?",
               isPresented: $presentingDeleteConfirmation
           ) {
               Button("Delete", role: .destructive, action: deleteCustom)
               Button("Cancel", role: .cancel) {}
           } message: {
               Text("Logged session history for this exercise will be preserved.")
           }
           .onAppear {
               if initialSnapshot == nil {
                   initialSnapshot = draft.snapshot()
               }
           }
       }

       private var addMuscleButtonLabel: String {
           draft.muscles.contains(where: { $0.role == .primary })
               ? "Add Another Muscle"
               : "Add Primary Muscle"
       }

       private var isDirty: Bool {
           guard let initial = initialSnapshot else { return false }
           return initial != draft.snapshot()
       }

       private func displayName(for slug: String) -> String {
           allMuscles.first(where: { $0.slug == slug })?.displayName ?? slug.capitalized
       }

       private func appendMuscle(_ mg: MuscleGroup) {
           let hasPrimary = draft.muscles.contains { $0.role == .primary }
           let role: CustomExerciseDraft.MuscleAssignment.Role = hasPrimary ? .secondary : .primary
           let weight: Double = role == .primary ? 1.0 : 0.5
           draft.muscles.append(.init(slug: mg.slug, role: role, weight: weight))
       }

       private func remove(_ assignment: CustomExerciseDraft.MuscleAssignment) {
           draft.muscles.removeAll { $0.id == assignment.id }
       }

       private func save() {
           if isEditing {
               draft.updateExisting(in: modelContext, allMuscles: allMuscles)
           } else {
               draft.materialize(into: modelContext, allMuscles: allMuscles)
           }
           try? modelContext.save()
           dismiss()
       }

       private func deleteCustom() {
           guard let target = draft.editingExisting else { return }
           modelContext.delete(target)
           try? modelContext.save()
           dismiss()
       }
   }

   #Preview("New Exercise") {
       NavigationStack {
           CustomExerciseEditor(draft: CustomExerciseDraft())
       }
       .modelContainer(PreviewModelContainer.make())
   }
   ```

### Modify

6. `fitbod/ExerciseLibrary/ExerciseLibraryView.swift` — replace the `NavigationLink(value: NewCustomExerciseRequest())` toolbar wiring with a sheet:
   ```
   # OLD (from plan 03-02):
   ToolbarItem(placement: .topBarTrailing) {
       NavigationLink(value: NewCustomExerciseRequest()) {
           Label("Create custom exercise", systemImage: "plus")
               .labelStyle(.iconOnly)
       }
       .accessibilityLabel("Create custom exercise")
   }
   ...
   .navigationDestination(for: NewCustomExerciseRequest.self) { _ in
       Text("Custom exercise editor — plan 03-04 fills this in")
           .navigationTitle("New Exercise")
   }

   # NEW:
   ToolbarItem(placement: .topBarTrailing) {
       Button {
           presentingNewCustom = true
       } label: {
           Label("Create custom exercise", systemImage: "plus")
               .labelStyle(.iconOnly)
       }
       .accessibilityLabel("Create custom exercise")
   }
   ...
   .sheet(isPresented: $presentingNewCustom) {
       NavigationStack {
           CustomExerciseEditor(draft: CustomExerciseDraft())
       }
   }
   ```
   And add `@State private var presentingNewCustom = false` to `ExerciseLibraryView`. The `navigationDestination(for: NewCustomExerciseRequest.self)` and `NewCustomExerciseRequest` type can be removed.

### Create — Tests

7. `fitbodTests/CustomExerciseDraftTests.swift`:
   ```
   import Testing
   import Foundation
   import SwiftData
   @testable import fitbod

   @Suite("CustomExerciseDraft validation (LIB-04 / FOUND-07)")
   struct CustomExerciseDraftTests {
       @Test("Empty name → invalid")
       func emptyName() {
           let d = CustomExerciseDraft()
           d.name = ""
           d.muscles = [.init(slug: "chest", role: .primary, weight: 1.0)]
           #expect(!d.isValid)
       }

       @Test("Whitespace-only name → invalid")
       func whitespaceName() {
           let d = CustomExerciseDraft()
           d.name = "   "
           d.muscles = [.init(slug: "chest", role: .primary, weight: 1.0)]
           #expect(!d.isValid)
       }

       @Test("No muscles → invalid")
       func noMuscles() {
           let d = CustomExerciseDraft()
           d.name = "Pec Deck"
           #expect(!d.isValid)
       }

       @Test("Only secondary muscle → invalid (PITFALLS #5)")
       func onlySecondary() {
           let d = CustomExerciseDraft()
           d.name = "Pec Deck"
           d.muscles = [.init(slug: "chest", role: .secondary, weight: 0.5)]
           #expect(!d.isValid)
       }

       @Test("Primary muscle with weight < 0.5 → invalid")
       func primaryUnderHalf() {
           let d = CustomExerciseDraft()
           d.name = "Pec Deck"
           d.muscles = [.init(slug: "chest", role: .primary, weight: 0.4)]
           #expect(!d.isValid)
       }

       @Test("Name + primary muscle (weight=0.5) → valid")
       func validAtThreshold() {
           let d = CustomExerciseDraft()
           d.name = "Pec Deck"
           d.muscles = [.init(slug: "chest", role: .primary, weight: 0.5)]
           #expect(d.isValid)
       }

       @Test("Name + primary muscle (weight=1.0) → valid")
       func validFull() {
           let d = CustomExerciseDraft()
           d.name = "Pec Deck"
           d.muscles = [.init(slug: "chest", role: .primary, weight: 1.0)]
           #expect(d.isValid)
       }

       @Test("Multiple primaries → still valid")
       func multiplePrimaries() {
           let d = CustomExerciseDraft()
           d.name = "Compound Move"
           d.muscles = [
               .init(slug: "chest", role: .primary, weight: 1.0),
               .init(slug: "triceps", role: .primary, weight: 0.8),
           ]
           #expect(d.isValid)
       }

       @Test("Materialize inserts Exercise + stimulus rows with isCustom=true")
       func materialize() throws {
           let container = try InMemoryContainer.makeEmpty()
           let ctx = container.mainContext
           # Pre-create the muscle row the materializer will reference
           let chest = MuscleGroup(slug: "chest", displayName: "Chest", region: .upper)
           ctx.insert(chest)
           try ctx.save()

           let d = CustomExerciseDraft()
           d.name = "Cambered Bar Bench"
           d.equipment = .barbell
           d.mechanic = .compound
           d.muscles = [.init(slug: "chest", role: .primary, weight: 1.0)]
           d.materialize(into: ctx, allMuscles: [chest])
           try ctx.save()

           let exercises = try ctx.fetch(FetchDescriptor<Exercise>())
           #expect(exercises.count == 1)
           let ex = exercises[0]
           #expect(ex.name == "Cambered Bar Bench")
           #expect(ex.isCustom == true)
           #expect(ex.equipmentRaw == "barbell")
           #expect(ex.canonicalName == "cambered bar bench")
           #expect(ex.primaryMuscleSlugsJoined == "|chest|")

           let stimuli = try ctx.fetch(FetchDescriptor<ExerciseMuscleStimulus>())
           #expect(stimuli.count == 1)
           #expect(stimuli.first?.role == "primary")
           #expect(stimuli.first?.weight == 1.0)
       }

       @Test("Snapshot equality detects dirty state")
       func snapshotDirtyDetection() {
           let d = CustomExerciseDraft()
           d.name = "Initial"
           let snap = d.snapshot()
           #expect(snap == d.snapshot())
           d.name = "Changed"
           #expect(snap != d.snapshot())
       }
   }

   @Suite("Exercise → SessionExercise nullify on delete (LIB-05)")
   struct CustomExerciseDeleteCascadeTests {
       @Test("Deleting custom Exercise nullifies any SessionExercise reference")
       func nullifyOnDelete() throws {
           let container = try InMemoryContainer.makeEmpty()
           let ctx = container.mainContext

           let chest = MuscleGroup(slug: "chest", displayName: "Chest", region: .upper)
           ctx.insert(chest)
           let custom = Exercise(
               name: "Custom Bench",
               canonicalName: "custom bench",
               equipmentRaw: "barbell",
               mechanicRaw: "compound",
               isCustom: true
           )
           ctx.insert(custom)

           let session = Session()
           session.routineSnapshotName = "Test"
           ctx.insert(session)

           let se = SessionExercise()
           se.session = session
           se.exercise = custom
           se.intentRaw = "strength"
           ctx.insert(se)
           try ctx.save()

           # Delete the custom exercise
           ctx.delete(custom)
           try ctx.save()

           # SessionExercise should still exist but with exercise == nil
           let allSE = try ctx.fetch(FetchDescriptor<SessionExercise>())
           #expect(allSE.count == 1, "SessionExercise should NOT be cascade-deleted")
           #expect(allSE.first?.exercise == nil, "Exercise reference should be nullified")
       }
   }
   ```

## Acceptance Criteria

1. All 5 new production files exist under `fitbod/ExerciseLibrary/`.
2. The "+" toolbar button on `ExerciseLibraryView` opens a sheet containing `CustomExerciseEditor` wrapped in a `NavigationStack`.
3. The editor's Save button is disabled until the user has both:
   - A non-whitespace name in the Name field.
   - At least one primary muscle assignment with weight ≥ 0.5.
4. Adding a muscle:
   - First muscle added defaults to `role = .primary` with weight `1.0`.
   - Subsequent muscles added default to `role = .secondary` with weight `0.5`.
   - The role-picker segmented control lets the user override.
   - The slider 0.0–1.0 with `step = 0.05` controls the weight; the percent display updates live.
5. UI-SPEC § Custom exercise editor copy is verbatim:
   - Navigation title "New Exercise" (create) / "Edit Exercise" (edit).
   - Name placeholder "e.g. Cambered Bar Bench Press".
   - Section headers "Name", "Muscles", "Equipment", "Mechanic", "Image (optional)".
   - "Add Primary Muscle" / "Add Another Muscle" button label (state-dependent).
   - Muscles section footer text verbatim.
   - "Stimulus weight for {muscle}" accessibility label.
   - "{integer percent}%" value display.
   - "Save" / "Cancel" toolbar labels.
   - "Discard Changes?" / "Discard" / "Keep Editing" confirmation dialog.
   - "Delete \"{name}\"?" alert + "Logged session history for this exercise will be preserved." body.
6. The save flow calls `draft.materialize(into: modelContext, ...)` then `modelContext.save()` then `dismiss()`. The new custom exercise appears in the library list (verified via the seeded `@Query` reactivity).
7. `CustomExerciseDraftTests` (10 tests) pass.
8. `CustomExerciseDeleteCascadeTests/nullifyOnDelete` (1 test) passes, proving LIB-05.
9. Build passes: `xcodebuild build` exits 0.

## Test Expectations

- `CustomExerciseDraftTests`: 10 tests covering empty name, whitespace name, no muscles, only-secondary, primary-under-0.5, primary-at-0.5, primary-at-1.0, multiple primaries, materialize-end-to-end, snapshot dirty detection.
- `CustomExerciseDeleteCascadeTests`: 1 test proving the nullify cascade for LIB-05.

**Run command:**
```bash
xcodebuild test -project fitbod.xcodeproj -scheme fitbod \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:fitbodTests/CustomExerciseDraftTests \
  -only-testing:fitbodTests/CustomExerciseDeleteCascadeTests
```

## Decisions Honored

- **C-23 (CONTEXT.md Area 3 — required fields):** Save button is disabled until name + ≥1 primary muscle with weight ≥0.5. Equipment + mechanic have non-nil defaults (`.barbell` / `.compound`). Image is genuinely optional via `PhotosPicker`.
- **C-24 (CONTEXT.md Area 3 — stimulus weight UI defaults):** First muscle = 1.0 primary; subsequent = 0.5 secondary. User can override either via the role picker + slider.
- **C-25 (CONTEXT.md Area 3 — validation lives in `CustomExerciseDraft`):** Pure value-type, testable without ModelContainer. FOUND-07 in microcosm.
- **C-26 (CONTEXT.md Area 3 — `isCustom: Bool` indexed):** `Exercise.isCustom = true` set by `materialize`; the `#Index<Exercise>([..., \.isCustom])` declaration is in plan `01-01`.
- **C-27 (CONTEXT.md Area 3 — nullify cascade on delete):** Schema rule from plan `01-01`; UI proves it via `CustomExerciseDeleteCascadeTests`.
- **C-28 (CONTEXT.md Area 3 — image via PhotosUI):** `PhotosPicker(selection:matching:photoLibrary:)` native SwiftUI; no `NSPhotoLibraryUsageDescription` Info.plist entry needed (RESEARCH Pattern 7 + Assumption A6).
- **R-21 (RESEARCH Example 5 — CustomExerciseDraft shape):** Verbatim. `isValid` checks name + primary muscle.
- **R-22 (RESEARCH § Pattern 7 — PhotosPicker):** No representable boilerplate; selection → `loadTransferable(type: Data.self)` populates `draft.imageData`.
- **UI-SPEC § Custom exercise editor / Copywriting Contract:** Every string verbatim.
- **UI-SPEC § Accessibility Contract:**
  - Custom-exercise "Save" button disabled hint: `accessibilityHint = "Add a primary muscle to enable saving"`.
  - Stimulus-weight slider: `accessibilityLabel = "Stimulus weight for {muscle}"`, `accessibilityValue = "{percent}"`.
  - All icon-only actions have explicit accessibility labels.

## Anti-Patterns Avoided

- **Not** making muscle mapping optional (PITFALLS #5 — silent volume corruption).
- **Not** using a `@StateObject`-wrapped class for the draft (PITFALLS State of the Art — `@Observable` macro replaces `ObservableObject`).
- **Not** wrapping `@Query<MuscleGroup>` in the draft itself — the draft is a pure value-type; the editor view consumes `@Query` directly.
- **Not** decoding `PhotosPickerItem` synchronously — the `.onChange(of: selection)` handler runs an async `Task` that calls `loadTransferable(type: Data.self)`.
- **Not** writing through to SwiftData on every field change — the draft holds the data in memory; `materialize` is the single write boundary on Save.
- **Not** using `PHPickerViewController` directly via `UIViewControllerRepresentable` — `PhotosPicker` is the iOS 16+ native SwiftUI replacement.
- **Not** showing the "Photo Access Required" alert from UI-SPEC § Error states — `PhotosPicker` is sandbox-permission-free per RESEARCH Assumption A6, so the alert is dead code in v1. (UI-SPEC notes this is future-proofing copy; we acknowledge it but do not wire a permission check.)

## Out of Scope (handled by later plans)

- The interim placeholder destination from plan `03-02` is replaced in this plan's `ExerciseLibraryView` edit.
- Editing an *existing* custom exercise (long-press → Edit affordance from the library list) → deferred to Phase 1.x polish or Phase 2 routine builder where edit affordances become relevant.
- Camera capture (vs. photo library) — UI-SPEC notes "Take Photo / Choose from Library" action sheet, but `PhotosPicker` only surfaces the library. Camera path would require `AVFoundation`; deferred since the library-only path satisfies LIB-04's "optional image" requirement.
- Per-equipment input field adaptation (LIB-06 second half) — Phase 1 ships the picker; field-by-field adaptation (e.g., bodyweight hides "added weight") is a *logger*-side concern in Phase 2.

## Commit Message Template

```
feat(01): CustomExerciseEditor + PhotosPicker + LIB-04 validation guard

- ExerciseLibrary/CustomExerciseDraft.swift: @Observable form state with
  isValid (name non-empty AND ≥1 primary muscle weight ≥0.5) per PITFALLS #5;
  pure value-type tested without ModelContainer (FOUND-07); materialize()
  inserts Exercise + ExerciseMuscleStimulus rows with isCustom=true and
  populates primaryMuscleSlugsJoined for filter predicate
- ExerciseLibrary/CustomExerciseEditor.swift: Form-based editor; Save disabled
  until draft.isValid; "Discard Changes?" confirmationDialog when dirty;
  "Delete \"{name}\"?" alert in Edit mode with "Logged session history will
  be preserved." body (UI-SPEC § Error states); accent-foreground "Add
  Primary/Another Muscle" buttons; segmented Mechanic picker
- ExerciseLibrary/MusclePickerSheet.swift: @Query-driven muscle list with
  region badges
- ExerciseLibrary/MuscleWeightRow.swift: per-muscle row with role picker +
  0.0–1.0 slider (step 0.05) + percent display; accessibilityLabel
  "Stimulus weight for {muscle}" per UI-SPEC § Accessibility
- ExerciseLibrary/CustomExerciseImagePicker.swift: PhotosPicker native SwiftUI
  (RESEARCH Pattern 7 — no NSPhotoLibraryUsageDescription required); async
  loadTransferable(type: Data.self) populates draft.imageData
- ExerciseLibraryView.swift: replace placeholder NavigationLink with
  Button → .sheet(isPresented:) presenting CustomExerciseEditor wrapped in
  NavigationStack
- fitbodTests/CustomExerciseDraftTests.swift: 10 tests covering all validation
  paths + materialize end-to-end
- fitbodTests/CustomExerciseDeleteCascadeTests.swift: 1 test proving LIB-05
  (Exercise→SessionExercise: nullify, NOT cascade)

Closes LIB-04, LIB-05, LIB-06 (equipment + mechanic pickers).
```
