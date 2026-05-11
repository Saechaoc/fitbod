---
phase: 01
plan: 03-03
wave: 3
slug: exercise-detail-and-copy-as-custom
complexity: M
requirements: ["LIB-01", "LIB-06"]
covers_pitfalls: []
depends_on: ["03-02"]
files_modified:
  - fitbod/ExerciseLibrary/ExerciseDetailView.swift  # NEW
  - fitbod/ExerciseLibrary/ExerciseLibraryView.swift  # MODIFY — wire navigationDestination
created: 2026-05-10
---

# Plan 03-03 — Exercise Detail and Copy as Custom

> **Wave 3 / Sequence 3.** Replaces the "Detail for {name} — plan 03-03 fills this in" placeholder from plan `03-02` with a real `ExerciseDetailView`: read-only for built-in entries (instructions, muscles with stimulus %, equipment, mechanic) and a "Copy as Custom Exercise" action that hydrates a `CustomExerciseDraft` (defined in plan `03-04`) and presents the editor over the detail view.

> **Sibling-of-03-04 note:** This plan and plan `03-04` are both children of plan `03-02`. They touch DIFFERENT files (`ExerciseDetailView.swift` here, `CustomExerciseEditor.swift` + `CustomExerciseDraft.swift` there) so they can be commit-ordered either way for a solo developer. **For execution simplicity, plan `03-04` lands first** because `03-03`'s "Copy as Custom" action depends on `CustomExerciseDraft` and `CustomExerciseEditor` existing. The `depends_on` field reflects that.

**Revised dependency:** `depends_on: ["03-02", "03-04"]` — the executor should sequence 03-04 → 03-03 to avoid forward-referencing types.

## Goal

Stand up `ExerciseDetailView` for the read-only library row click target. Show every detail UI-SPEC.md locks in (instructions, muscles with weight as percent, equipment, mechanic, "Copy as Custom Exercise" action). Built-in exercises are read-only by absence of an edit affordance.

## Requirements Covered

- **LIB-01** (detail surface): The library list is browsable + drillable. Tapping a row pushes `ExerciseDetailView` onto the `NavigationStack` (no modal).
- **LIB-06** (equipment + mechanic display): The detail view surfaces `equipment` and `mechanic` in dedicated sections. The display is purely informational in Phase 1; per-equipment UI input adaptation lives on the *editor* side (plan `03-04`).

## Files to Create / Modify

### Create

1. `fitbod/ExerciseLibrary/ExerciseDetailView.swift`:
   ```
   import SwiftUI
   import SwiftData

   struct ExerciseDetailView: View {
       let exercise: Exercise
       @State private var draftFromCopy: CustomExerciseDraft? = nil
       @State private var presentingCustomEditor = false

       var body: some View {
           List {
               if !exercise.instructions.isEmpty {
                   Section("Instructions") {
                       ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { i, step in
                           HStack(alignment: .top, spacing: 8) {
                               Text("\(i + 1).")
                                   .font(.body)
                                   .foregroundStyle(.secondary)
                                   .frame(width: 24, alignment: .leading)
                               Text(step)
                                   .font(.body)
                                   .foregroundStyle(.primary)
                           }
                       }
                   }
               }

               muscleSection

               Section("Equipment") {
                   Text(exercise.equipmentRaw.capitalized)
                       .font(.body)
               }

               Section("Mechanic") {
                   Text(exercise.mechanicRaw.capitalized)
                       .font(.body)
               }

               if !exercise.isCustom {
                   Section {
                       Button {
                           draftFromCopy = makeDraft(from: exercise)
                           presentingCustomEditor = true
                       } label: {
                           Text("Copy as Custom Exercise")
                               .foregroundStyle(.accent)
                       }
                   }
               }
           }
           .listStyle(.insetGrouped)
           .navigationTitle(exercise.name)
           .navigationBarTitleDisplayMode(.inline)
           .sheet(isPresented: $presentingCustomEditor) {
               if let draft = draftFromCopy {
                   NavigationStack {
                       CustomExerciseEditor(draft: draft)
                   }
               }
           }
       }

       /// Render the muscle stimulus rows, sorted: primary first then secondary,
       /// each side sorted by descending weight.
       @ViewBuilder
       private var muscleSection: some View {
           let stimuli = exercise.muscleStimuli ?? []
           if !stimuli.isEmpty {
               Section("Muscles") {
                   ForEach(stimuli.sorted(by: stimulusSort), id: \.id) { stim in
                       HStack {
                           Text(stim.muscle?.displayName ?? "Unknown")
                               .font(.body)
                           Spacer()
                           Text("\(Int((stim.weight * 100).rounded()))%")
                               .font(.body)
                               .foregroundStyle(.secondary)
                               .monospacedDigit()
                       }
                   }
               }
           }
       }

       /// Primary (role="primary") first, then secondary; within each tier,
       /// descending weight then alphabetical by display name.
       private func stimulusSort(_ a: ExerciseMuscleStimulus, _ b: ExerciseMuscleStimulus) -> Bool {
           if a.role != b.role { return a.role == "primary" }   # primary < secondary in our ordering
           if a.weight != b.weight { return a.weight > b.weight }
           return (a.muscle?.displayName ?? "") < (b.muscle?.displayName ?? "")
       }

       /// Initialize a custom-exercise draft from an existing built-in entry.
       /// Used by "Copy as Custom Exercise" action.
       private func makeDraft(from source: Exercise) -> CustomExerciseDraft {
           let draft = CustomExerciseDraft()
           draft.name = source.name + " (Copy)"
           draft.equipment = Equipment(rawValue: source.equipmentRaw) ?? .other
           draft.mechanic = Mechanic(rawValue: source.mechanicRaw) ?? .compound
           for stim in (source.muscleStimuli ?? []) {
               guard let slug = stim.muscle?.slug else { continue }
               let role: CustomExerciseDraft.MuscleAssignment.Role =
                   stim.role == "primary" ? .primary : .secondary
               draft.muscles.append(.init(slug: slug, role: role, weight: stim.weight))
           }
           # imageData intentionally not copied — built-in entries have no
           # imageData payload, only imagePaths references.
           return draft
       }
   }

   #Preview {
       NavigationStack {
           let container = PreviewModelContainer.make()
           let ex = try! container.mainContext.fetch(FetchDescriptor<Exercise>()).first!
           ExerciseDetailView(exercise: ex)
               .modelContainer(container)
       }
   }
   ```

### Modify

2. `fitbod/ExerciseLibrary/ExerciseLibraryView.swift` — replace the placeholder destination:
   ```
   # OLD (from plan 03-02):
   .navigationDestination(for: Exercise.self) { ex in
       Text("Detail for \(ex.name) — plan 03-03 fills this in")
   }

   # NEW:
   .navigationDestination(for: Exercise.self) { ex in
       ExerciseDetailView(exercise: ex)
   }
   ```

## Acceptance Criteria

1. `fitbod/ExerciseLibrary/ExerciseDetailView.swift` exists.
2. Tapping a row in the Library list pushes `ExerciseDetailView` onto the navigation stack (no modal, no full-screen cover).
3. The detail view shows:
   - **Title:** the exercise's `name` (inline display mode per UI-SPEC).
   - **Instructions section:** numbered list of `exercise.instructions` (only if non-empty).
   - **Muscles section:** rows formatted "{Muscle name} · {weight as percent}" — e.g., "Chest · 100%", "Triceps · 50%". Primary rows appear before secondary; descending weight within each tier.
   - **Equipment section:** title-cased equipment value (e.g., "Barbell").
   - **Mechanic section:** "Compound" or "Isolation".
   - **Copy as Custom Exercise:** accent-foreground text button, only visible when `!exercise.isCustom`. Tapping it presents `CustomExerciseEditor` as a sheet with the draft hydrated from the source.
4. For a *custom* exercise opened from detail, no "Copy as Custom Exercise" button is shown (custom entries are already editable directly; the editor opens from the library "+" button or via a planned future "Edit" affordance which is out of scope this phase).
5. UI-SPEC § Exercise detail screen copy is verbatim:
   - "Instructions" / "Muscles" / "Equipment" / "Mechanic" section headers.
   - "Copy as Custom Exercise" button label.
   - No "read-only" banner (UI-SPEC: absence of an edit button IS the affordance).
6. No new unit tests; the view logic is direct binding (`@Bindable`-free since the view only reads) and the `makeDraft` helper is exercised by integration through the "Copy as Custom" interaction (manual smoke). Future polish could add a `makeDraft` unit test.
7. Build passes: `xcodebuild build` exits 0.

## Test Expectations

No new unit tests. Validation:
- Manual smoke: open a built-in exercise, see all 4 sections + the "Copy as Custom Exercise" action. Tap it → editor sheet opens with the source data pre-filled.
- Open a custom exercise (after plan `03-04` lets you create one) → no "Copy as Custom" button.

**Sanity build check:**
```bash
xcodebuild -project fitbod.xcodeproj -scheme fitbod \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 \
  | grep -E 'error:' || echo "BUILD OK"
```

## Decisions Honored

- **UI-SPEC § Exercise detail screen / Copywriting Contract:** Every string verbatim. Muscle row format "{Muscle name} · {weight as percent}" with integer percent and middle-dot separator.
- **UI-SPEC § Color § Accent reserved for / item 4:** "Copy as Custom Exercise" is text-only with `.foregroundStyle(.accent)`. No background fill on this action.
- **UI-SPEC § Destructive actions / Read-only banner:** "(none — absence of an edit button IS the affordance; do not add explanatory text)." No banner is rendered.
- **C-21 (CONTEXT.md Area 3 — "Copy as Custom" hydrates draft):** Built-in entries are read-only; the "Copy as custom" action creates an editable user-owned duplicate. Implementation: `makeDraft(from:)` populates a `CustomExerciseDraft` with the source's name (suffixed " (Copy)"), equipment, mechanic, and full muscle stimulus list.
- **C-22 (CONTEXT.md Area 3 — no image copy):** Image data is not copied from built-in entries (they have only `imagePaths` references to unbundled binaries). User can attach a fresh image in the editor.

## Anti-Patterns Avoided

- **Not** showing an "Edit" toolbar button on built-in exercises (PITFALLS — read-only must mean read-only).
- **Not** mutating the source `Exercise` during "Copy as Custom" — the draft is a separate `CustomExerciseDraft` instance; the source remains untouched. (PITFALLS #3 in domain — never mutate templates from instance flows.)
- **Not** modeling the detail view as a `Form` — UI-SPEC's "comprehensive but uncluttered" stance calls for `List` with sections (matching the library list's `.insetGrouped` style for visual continuity).
- **Not** wrapping anything in `@Bindable` — the detail view is read-only. `@Bindable` only appears in the editor (plan `03-04`).

## Out of Scope (handled by later plans)

- The actual `CustomExerciseEditor` view → plan `01-PLAN-03-04` (this plan presents it as a `.sheet` and depends on its existence).
- Editing a custom `Exercise` in-place (without going through `Copy as Custom`) — Phase 1 only supports creation of new customs from the "+" toolbar OR from the "Copy as Custom" hydration. Direct editing of an existing custom exercise (e.g., long-press → Edit) is deferred to a Phase 1.x polish pass.
- Showing exercise images / GIFs → deferred per CONTEXT.md.
- Tap-to-cycle behavior on muscle rows (e.g., to highlight a muscle on a body diagram) → Phase 5 fatigue model.

## Commit Message Template

```
feat(01): ExerciseDetailView with read-only sections + Copy as Custom Exercise

- ExerciseLibrary/ExerciseDetailView.swift: List-based detail surface with
  Instructions / Muscles / Equipment / Mechanic sections per UI-SPEC §
  Exercise detail screen
- muscle rows format "{Name} · {percent}" sorted primary > secondary then
  descending weight (UI-SPEC Copywriting Contract)
- "Copy as Custom Exercise" accent-foreground button visible only on built-in
  entries (UI-SPEC § Color § Accent item 4); hydrates a CustomExerciseDraft
  with name "(Copy)" suffix and presents CustomExerciseEditor as a sheet
- absence of an Edit button IS the read-only affordance — no banner copy
  (UI-SPEC explicit)
- ExerciseLibraryView.swift: replace navigationDestination placeholder with
  ExerciseDetailView(exercise:) (1-line edit)

Closes the LIB-01 / LIB-06 detail surface requirements.
```
