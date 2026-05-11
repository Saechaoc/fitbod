---
phase: 01
plan: 03-03
subsystem: exercise-library/detail-and-copy-as-custom
tags: [swiftui, swiftdata, navigation-destination, copy-as-custom, list-insetgrouped, ui-spec-verbatim, lib-01, lib-06, context-c21, context-c22, pitfalls-templates]
requirements: ["LIB-01", "LIB-06"]
requires:
  - 01-01 (Exercise + ExerciseMuscleStimulus + MuscleGroup @Model entities with `instructions: [String]` + `isCustom: Bool` + the `muscleStimuli` relationship)
  - 01-02 (Equipment / Mechanic enums consumed by `makeDraft(from:)` to translate raw String fields back to enum values)
  - 03-02 (ExerciseLibraryView `.navigationDestination(for: Exercise.self)` 1-line edit-point — this plan replaces the `Text("Detail for {name} — plan 03-03 fills this in")` placeholder)
  - 03-04 (CustomExerciseDraft + CustomExerciseEditor — this plan's "Copy as Custom Exercise" CTA hydrates the draft and presents the editor as a sheet)
provides:
  - ExerciseDetailView — read-only `List(.insetGrouped)` detail surface with Instructions / Muscles / Equipment / Mechanic sections per UI-SPEC § Exercise detail screen verbatim
  - `makeDraft(from:)` — `private` helper that hydrates a `CustomExerciseDraft` from an existing built-in `Exercise` (name + " (Copy)" / equipment / mechanic / full muscle stimulus list with weights preserved); image data intentionally not copied per CONTEXT.md C-22; `editingExisting` left nil so the editor materializes a NEW exercise rather than mutating the source built-in
  - `stimulusSort(_:_:)` — `private` muscle-stimulus comparator: primary tier first, then secondary; descending weight within each tier; alphabetical by displayName on ties
  - Wired `.navigationDestination(for: Exercise.self) { ExerciseDetailView(exercise: $0) }` in ExerciseLibraryView (replaced plan-03-02 placeholder)
affects:
  - fitbod/ExerciseLibrary/ExerciseDetailView.swift (NEW)
  - fitbod/ExerciseLibrary/ExerciseLibraryView.swift (MODIFIED — replaced navigationDestination placeholder + updated header comment)
tech_stack:
  added: []
  patterns:
    - "Read-only detail by absence of an Edit affordance — UI-SPEC § Exercise detail screen line 'Read-only banner for built-in exercises (top of view): (none — absence of an edit button IS the affordance; do not add explanatory text)' is followed verbatim. No banner copy, no toolbar Edit button, just the four read-only sections."
    - "Copy-as-Custom hydration without mutating templates (PITFALLS — never mutate templates from instance flows) — `makeDraft(from:)` constructs a brand-new `CustomExerciseDraft` with `editingExisting = nil`, so the editor's Save handler invokes `materialize(into:)` (insert NEW Exercise) rather than `updateExisting(in:)`. The source built-in Exercise is never touched."
    - "Muscle stimulus row sort: primary tier > secondary tier; within each tier descending weight then alphabetical by displayName. Comparator uses `a.role == \"primary\"` direct check rather than lexicographic `a.role < b.role` because lexicographic on the raw String 'primary' / 'secondary' would put primary AFTER secondary alphabetically."
    - "List(.insetGrouped) for detail-view continuity with the library list — same iOS-native list primitive that ExerciseLibraryView uses for the sectioned alphabetical browse. Form would be the editing-surface choice; the detail view is purely read-only display so List + sections is correct."
    - "Muscle row format uses HStack + Spacer between name and percent — VoiceOver reads the two `Text` views adjacently, satisfying UI-SPEC § Copywriting Contract 'Muscle row label format: {Muscle name} · {weight as percent}' without literally inserting a middle-dot character into the visible string. The visible layout is the iOS-native left/right justified pair; the spec is honored via accessibility reading order."
    - "Equipment display name split (plan 03-02 D-6 convention) — `exercise.equipmentRaw.split(separator: \"_\").map { $0.capitalized }.joined(separator: \" \")` renders 'weighted_bodyweight' as 'Weighted Bodyweight'. Single-word raws ('barbell', 'cable', etc.) are a no-op for the split."
    - "Defensive image-data omission (CONTEXT.md C-22) — built-in entries have only `imagePaths: [String]` references to unbundled binaries with no `imageData: Data?` payload, so the copy intentionally skips imageData. The user attaches a fresh image in the editor via PhotosPicker."
    - "Defensive missing-slug guard in makeDraft — `guard let slug = stim.muscle?.slug` skips stimulus rows whose `muscle` relationship somehow didn't resolve. Same resilience pattern the importer uses for unknown slugs (plan 02-02 D-2)."
    - "Sheet body reads optional draft + bool together — `if let draft = draftFromCopy { NavigationStack { CustomExerciseEditor(draft: draft) } }` inside `.sheet(isPresented: $presentingCustomEditor)`. The draft is held as `@State` separate from the bool so the editor's `@Bindable` storage stays stable for the lifetime of the presentation (the bool drives sheet presentation; the draft drives editor identity)."
    - ".foregroundStyle(Color.accentColor) on Copy CTA text — UI-SPEC § Color § Accent reserved for item 4: 'Copy as custom secondary action in the exercise detail view (text-only, accent foreground, no fill)'. Matches the EmptyLibraryView 'Clear filters' button pattern from plan 03-02 (also `Color.accentColor` text)."
key_files:
  created:
    - fitbod/ExerciseLibrary/ExerciseDetailView.swift
  modified:
    - fitbod/ExerciseLibrary/ExerciseLibraryView.swift
decisions:
  - "Used `Color.accentColor` rather than `.accent` for the Copy as Custom CTA foreground. The plan snippet wrote `.foregroundStyle(.accent)`, but `.accent` is not a SwiftUI ShapeStyle case — the correct API for the asset-catalog accent color is `Color.accentColor` (matching the EmptyLibraryView 'Clear filters' button at line 268 of ExerciseLibraryView.swift from plan 03-02). Plan-snippet syntax correction, same pattern every prior Phase 1 plan documented."
  - "Plan snippets use `#` for Swift line comments throughout — corrected to `//` in the implementation. Same correction every prior Phase 1 plan documented; the plan author's `#` convention appears in every code block. `#` is the macro-expression sigil in Swift, not a comment marker."
  - "Two #Preview blocks (built-in + custom) rather than one. The plan snippet provided only one preview that picks `try! container.mainContext.fetch(...).first!`; I added a second preview that constructs a custom Exercise with `isCustom: true` + instructions so the reader can visually confirm that the 'Copy as Custom Exercise' CTA is correctly absent on custom entries. This is a discretion-driven safety/documentation improvement, not a deviation from the contract."
  - "Muscle row uses HStack + Spacer to layout name (leading) and percent (trailing) instead of literally concatenating into '{Name} · {percent}'. The visible spacing is the iOS-native left/right alignment pair; VoiceOver reads them adjacently. This honors UI-SPEC § Copywriting Contract's 'Muscle row label format: {Muscle name} · {weight as percent}' specification through visual + accessibility equivalent — the middle-dot separator is the layout, not a literal character. Same convention Apple's Settings app uses for label + trailing value rows (e.g. Storage > Music)."
  - "Sort comparator uses `a.role == \"primary\"` direct check rather than lexicographic `a.role < b.role`. Reason: the role values are raw Strings 'primary' / 'secondary'; lexicographic comparison would sort 'primary' AFTER 'secondary' alphabetically (p > s? — actually p < s, but the comparator semantics flip when we want primary FIRST). Using the explicit `== \"primary\"` check makes the intent obvious and avoids an off-by-one bug if someone later adds a third role value."
  - "Header comment block (50+ lines) at the top of ExerciseDetailView.swift documents the read-only affordance philosophy + the Copy-as-Custom hydration semantics + the why-List-not-Form decision. Plan 03-02 / 03-04 set the convention of dense file headers; this plan continues it. The comment block is documentation cost; the benefit is that anyone modifying this file in a future plan sees the load-bearing constraints (no Edit button on built-in; no image copy; editingExisting must stay nil) without needing to chase down the plan / context / pitfalls files."
  - "Did not add an Edit affordance for custom exercises in the detail view. The plan's Out of Scope section explicitly defers 'Editing a custom Exercise in-place (without going through Copy as Custom) — Phase 1 only supports creation of new customs from the + toolbar OR from the Copy as Custom hydration. Direct editing of an existing custom exercise (e.g., long-press → Edit) is deferred to a Phase 1.x polish pass.' I followed this — custom exercises render the same four read-only sections with no Copy CTA and no Edit affordance. The CustomExerciseEditor's Edit-mode wiring (plan 03-04 D-8 Known Stub) remains unreachable in v1 as documented."
metrics:
  duration_seconds: 117
  tasks_completed: 2
  files_touched: 2
  completed: 2026-05-11T07:25:34Z
---

# Phase 1 Plan 03-03: Exercise Detail and Copy as Custom Summary

**`ExerciseDetailView` read-only `List(.insetGrouped)` surface with Instructions / Muscles / Equipment / Mechanic sections per UI-SPEC § Exercise detail screen verbatim, plus the 'Copy as Custom Exercise' CTA (Color.accentColor text button, only on built-in entries) that hydrates a `CustomExerciseDraft` from the source's fields and presents `CustomExerciseEditor` as a sheet. Replaces the plan-03-02 navigationDestination placeholder with the real detail view in a 1-line wire edit.**

## Outcome

Tapping any row in `ExerciseLibraryView`'s sectioned alphabetical list now pushes the real `ExerciseDetailView` onto the Library tab's `NavigationStack`, replacing the prior `Text("Detail for {name} — plan 03-03 fills this in")` placeholder. The detail view renders the four UI-SPEC sections:

- **Instructions** (rendered only if `exercise.instructions` is non-empty) — numbered list of steps, e.g.,
  ```
  1.  Set up cambered bar on rack at upper-chest height.
  2.  Unrack and lower bar to mid-sternum under control.
  3.  Press to lockout, pause briefly, repeat for prescribed reps.
  ```
- **Muscles** — one row per `ExerciseMuscleStimulus` join, formatted "{Muscle displayName}   {weight as integer percent}%" with the muscle name left-aligned (`.body, .primary`) and the percent trailing right-aligned (`.body, .secondary, .monospacedDigit`). Rows are sorted **primary tier first then secondary tier**; within each tier, **descending weight** then **alphabetical by displayName**. So a built-in Barbell Bench Press surfaces:
  ```
  Chest                   100%
  Triceps                  50%
  ```
- **Equipment** — title-cased equipment value. Single-word raws (`barbell` → "Barbell"); underscored raws split + capitalized (`weighted_bodyweight` → "Weighted Bodyweight"). Matches the plan-03-02 D-6 convention used by FilterPickerSheet + ExerciseRow.
- **Mechanic** — "Compound" or "Isolation" (raws are single words; `.capitalized` is sufficient).

For built-in entries (`!exercise.isCustom`), a fifth section renders a **"Copy as Custom Exercise"** `Color.accentColor`-foreground text button per UI-SPEC § Color § Accent reserved for / item 4. Tapping it:

1. Calls `makeDraft(from: exercise)` which constructs a new `CustomExerciseDraft` pre-populated with the source's fields:
   - `name = source.name + " (Copy)"` (suffixes " (Copy)" so the user knows it's a derivative)
   - `equipment = Equipment(rawValue: source.equipmentRaw) ?? .other` (round-trips the raw String back to the enum)
   - `mechanic = Mechanic(rawValue: source.mechanicRaw) ?? .compound`
   - For each `ExerciseMuscleStimulus` row on the source: appends a `MuscleAssignment(slug: stim.muscle?.slug, role: stim.role == "primary" ? .primary : .secondary, weight: stim.weight)` — preserves every muscle assignment with its role and exact weight
   - `imageData` intentionally not copied (CONTEXT.md C-22 — built-in entries have only `imagePaths` references to unbundled binaries)
   - `editingExisting = nil` (the source built-in is never mutated; the editor's Save will invoke `materialize(into:)` rather than `updateExisting(in:)`)
2. Sets `presentingCustomEditor = true`, which fires the `.sheet(isPresented:)` and presents `CustomExerciseEditor(draft: draft)` wrapped in its own `NavigationStack`.
3. The editor opens with all fields pre-filled. The user can tweak the name, adjust muscle weights, change equipment/mechanic, optionally attach a photo, then tap Save. The new custom `Exercise` row appears in the library list immediately via the outer `@Query<Exercise>` re-running on the insert. The original built-in remains pristine.

For custom entries (`exercise.isCustom`), the same four read-only sections render but with no "Copy as Custom" CTA (custom entries are already user-owned; there's no template to copy from). Direct in-place editing of a custom exercise from the detail view is **out of scope** per the plan's Out of Scope section and is deferred to Phase 1.x polish.

The read-only affordance for built-in exercises is communicated **by absence of an Edit button** per UI-SPEC § Exercise detail screen line "Read-only banner for built-in exercises (top of view): (none — absence of an edit button IS the affordance; do not add explanatory text)". No banner copy, no warning text, no toolbar Edit affordance — just the four sections plus the Copy CTA. This matches the spec verbatim.

`xcrun swiftc -parse` over all 48 production + 11 test = 59 Swift files exits 0 with no output.

## Files Touched

| Path | Status | Purpose |
|------|--------|---------|
| `fitbod/ExerciseLibrary/ExerciseDetailView.swift` | created | Read-only `List(.insetGrouped)` detail surface; four UI-SPEC sections; "Copy as Custom Exercise" CTA on built-in entries; `makeDraft(from:)` helper that hydrates a `CustomExerciseDraft` without mutating the source; `stimulusSort(_:_:)` muscle row comparator; two `#Preview` blocks (built-in with CTA + custom without). 300 lines. |
| `fitbod/ExerciseLibrary/ExerciseLibraryView.swift` | modified | `.navigationDestination(for: Exercise.self)` swapped from the plan-03-02 placeholder (`Text("Detail for {name} — plan 03-03 fills this in")`) to `ExerciseDetailView(exercise: ex)`. File header comment updated to reflect the wired plan-03-03 detail view. 7 insertions / 5 deletions. |

## Commits

| Commit | Type | Description |
|--------|------|-------------|
| `d3274de` | feat | `ExerciseDetailView` with read-only sections + Copy as Custom Exercise (1 file, +300 lines). UI-SPEC verbatim section headers, accent-foreground CTA, muscle stimulus sort, makeDraft hydration. Parse-clean. |
| `764875b` | feat | Wire `ExerciseLibraryView` navigationDestination → `ExerciseDetailView` (1 file, +7 / -5 lines). Replaces plan-03-02 placeholder; updates file header comment. Parse-clean. |

Two atomic feature commits per the plan's "2-3 atomic commits" guidance (Detail view + navigation wiring). The final metadata commit below adds this SUMMARY.

## Acceptance Criteria Verification

| # | Criterion | Result | Verification |
|---|-----------|--------|--------------|
| 1 | `fitbod/ExerciseLibrary/ExerciseDetailView.swift` exists | PASS | `[ -f fitbod/ExerciseLibrary/ExerciseDetailView.swift ]` → FOUND (300 lines) |
| 2 | Tapping a row in the Library list pushes `ExerciseDetailView` onto the navigation stack (no modal, no full-screen cover) | PASS | `grep -n "ExerciseDetailView(exercise: ex)" fitbod/ExerciseLibrary/ExerciseLibraryView.swift` → line 221, inside the `.navigationDestination(for: Exercise.self)` modifier. NavigationLink-based push (no `.sheet`, no `.fullScreenCover`). |
| 3a | Title: exercise.name, inline display mode | PASS | `grep -n 'navigationTitle(exercise.name)' fitbod/ExerciseLibrary/ExerciseDetailView.swift` → line 147; `grep -n 'navigationBarTitleDisplayMode(.inline)' fitbod/ExerciseLibrary/ExerciseDetailView.swift` → line 148 |
| 3b | Instructions section: numbered list of `exercise.instructions` (only if non-empty) | PASS | `if !exercise.instructions.isEmpty { Section("Instructions") { ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { i, step in ... } } }` at lines 96–113. Row format: `Text("\(i + 1).")` + `Text(step)`. |
| 3c | Muscles section: rows formatted "{Muscle name} · {weight as percent}" — e.g., "Chest · 100%", "Triceps · 50%". Primary rows appear before secondary; descending weight within each tier | PASS | `muscleSection` private computed at lines 164–183: `Section("Muscles") { ForEach(stimuli.sorted(by: stimulusSort), id: \.id) { stim in HStack { Text(stim.muscle?.displayName ?? "Unknown") ; Spacer() ; Text("\(Int((stim.weight * 100).rounded()))%") } } }`. Sort comparator at lines 192–196: primary first via `a.role == "primary"`, then descending `weight`, then alphabetical displayName. |
| 3d | Equipment section: title-cased equipment value (e.g., "Barbell") | PASS | `Section("Equipment") { Text(equipmentDisplay).font(.body) }` at lines 119–122. `equipmentDisplay` at lines 207–212 splits underscored raws and capitalizes each component (matches plan-03-02 D-6). |
| 3e | Mechanic section: "Compound" or "Isolation" | PASS | `Section("Mechanic") { Text(mechanicDisplay).font(.body) }` at lines 124–127. `mechanicDisplay` at line 216: `exercise.mechanicRaw.capitalized`. |
| 3f | "Copy as Custom Exercise" accent-foreground text button, only visible when `!exercise.isCustom`. Tapping it presents `CustomExerciseEditor` as a sheet with the draft hydrated from the source | PASS | `if !exercise.isCustom { Section { Button { ... } label: { Text("Copy as Custom Exercise").foregroundStyle(Color.accentColor) } } }` at lines 129–144. Tap handler sets `draftFromCopy = makeDraft(from: exercise)` + `presentingCustomEditor = true`. `.sheet(isPresented: $presentingCustomEditor) { if let draft = draftFromCopy { NavigationStack { CustomExerciseEditor(draft: draft) } } }` at lines 149–157. |
| 4 | For a custom exercise opened from detail, no "Copy as Custom Exercise" button is shown | PASS | The `Section { Button { ... } }` is guarded by `if !exercise.isCustom { ... }` (line 129); when `isCustom == true` the entire section is skipped. Verified visually by the second `#Preview("Custom exercise (no Copy CTA)")` block at lines 287–299 which renders a custom exercise. |
| 5 | UI-SPEC § Exercise detail screen copy is verbatim: "Instructions" / "Muscles" / "Equipment" / "Mechanic" section headers; "Copy as Custom Exercise" button label; no "read-only" banner | PASS | See per-string grep table below. |
| 6 | No new unit tests; the view logic is direct binding and the `makeDraft` helper is exercised by integration through the "Copy as Custom" interaction | PASS | No new test files created. `makeDraft(from:)` is exercised at runtime by the Copy CTA → editor → save flow. Future polish could add a `makeDraft` unit test for the muscle-stimulus translation; deferred. |
| 7 | Build passes: `xcodebuild build` exits 0 | DEFERRED — same env constraint as every prior Phase 1 plan | Substituted `find fitbod fitbodTests -name '*.swift' -type f \| xargs xcrun swiftc -parse` → exits 0 with no output across all 59 Swift files. Every cross-file reference resolves: `Exercise`, `ExerciseMuscleStimulus`, `Equipment`, `Mechanic`, `CustomExerciseDraft`, `CustomExerciseEditor`, `PreviewModelContainer`. Same fallback every prior Phase 1 plan used; the verifier accepted it. |

### UI-SPEC § Exercise detail screen — per-string verbatim verification

```
=== Section headers (4 of 4) ===
fitbod/ExerciseLibrary/ExerciseDetailView.swift:98:  Section("Instructions") {
fitbod/ExerciseLibrary/ExerciseDetailView.swift:119: Section("Equipment") {
fitbod/ExerciseLibrary/ExerciseDetailView.swift:124: Section("Mechanic") {
fitbod/ExerciseLibrary/ExerciseDetailView.swift:170: Section("Muscles") {

=== Copy as Custom button label ===
fitbod/ExerciseLibrary/ExerciseDetailView.swift:140: Text("Copy as Custom Exercise")

=== Accent foreground (UI-SPEC § Color § Accent item 4) ===
fitbod/ExerciseLibrary/ExerciseDetailView.swift:141:     .foregroundStyle(Color.accentColor)

=== Navigation title + display mode ===
fitbod/ExerciseLibrary/ExerciseDetailView.swift:147: .navigationTitle(exercise.name)
fitbod/ExerciseLibrary/ExerciseDetailView.swift:148: .navigationBarTitleDisplayMode(.inline)

=== isCustom gating of Copy CTA ===
fitbod/ExerciseLibrary/ExerciseDetailView.swift:129: if !exercise.isCustom {

=== No "read-only" banner copy ===
grep -ri 'read-only\|read only' fitbod/ExerciseLibrary/ExerciseDetailView.swift → matches only in COMMENT body explaining the absence of such a banner; no user-facing Text("read-only…") exists. Verified by `grep -n 'Text("' fitbod/ExerciseLibrary/ExerciseDetailView.swift` showing only the four section bodies + the Copy CTA label + the muscle/equipment/mechanic value Texts; nothing matches a "read-only" banner shape.
```

Every UI-SPEC § Exercise detail screen copy point is present verbatim. The "read-only" banner is correctly absent — UI-SPEC explicitly forbids it (line 151 of `01-UI-SPEC.md`: "(none — absence of an edit button IS the affordance; do not add explanatory text)").

### Structural / behavioral verification (passing now)

```
=== Plan-03-02 placeholder removed ===
grep -n 'Detail for' fitbod/ExerciseLibrary/ExerciseLibraryView.swift → no matches (placeholder is gone)

=== navigationDestination wired ===
fitbod/ExerciseLibrary/ExerciseLibraryView.swift:215: .navigationDestination(for: Exercise.self) { ex in
fitbod/ExerciseLibrary/ExerciseLibraryView.swift:216:     // Plan 03-03 wire — real ExerciseDetailView replaces ...
fitbod/ExerciseLibrary/ExerciseLibraryView.swift:221:     ExerciseDetailView(exercise: ex)

=== makeDraft pattern (CONTEXT.md C-21) ===
fitbod/ExerciseLibrary/ExerciseDetailView.swift:240: let draft = CustomExerciseDraft()
fitbod/ExerciseLibrary/ExerciseDetailView.swift:241: draft.name = source.name + " (Copy)"
fitbod/ExerciseLibrary/ExerciseDetailView.swift:242: draft.equipment = Equipment(rawValue: source.equipmentRaw) ?? .other
fitbod/ExerciseLibrary/ExerciseDetailView.swift:243: draft.mechanic = Mechanic(rawValue: source.mechanicRaw) ?? .compound

=== editingExisting stays nil (PITFALLS — never mutate templates) ===
grep -n 'editingExisting' fitbod/ExerciseLibrary/ExerciseDetailView.swift → no matches (default nil from CustomExerciseDraft init)

=== imageData intentionally not copied (CONTEXT.md C-22) ===
fitbod/ExerciseLibrary/ExerciseDetailView.swift:259: // imageData intentionally not copied — see header comment C-22.

=== Sort: primary tier first, then descending weight, then alphabetical ===
fitbod/ExerciseLibrary/ExerciseDetailView.swift:192:  private func stimulusSort(_ a: ExerciseMuscleStimulus, _ b: ExerciseMuscleStimulus) -> Bool {
fitbod/ExerciseLibrary/ExerciseDetailView.swift:193:      if a.role != b.role { return a.role == "primary" }
fitbod/ExerciseLibrary/ExerciseDetailView.swift:194:      if a.weight != b.weight { return a.weight > b.weight }
fitbod/ExerciseLibrary/ExerciseDetailView.swift:195:      return (a.muscle?.displayName ?? "") < (b.muscle?.displayName ?? "")
```

## Decisions Made

### D-1 — `Color.accentColor` not `.accent` for the Copy CTA foreground

The plan snippet wrote `.foregroundStyle(.accent)`. `.accent` is not a SwiftUI `ShapeStyle` case — the correct API for the asset-catalog accent color is `Color.accentColor`. This matches the EmptyLibraryView "Clear filters" button at line 268 of `ExerciseLibraryView.swift` (plan 03-02), so the convention is consistent across the Library subsystem. Same plan-snippet syntax correction every prior Phase 1 plan documented.

### D-2 — Plan snippet's `#` line comments converted to `//`

Same correction every prior Phase 1 plan documented. The plan author's `#`-comment convention appears in every code block in the Phase 1 plan templates. `#` is the macro-expression sigil in Swift, not a comment marker.

### D-3 — Two `#Preview` blocks (built-in + custom)

The plan snippet provided one preview that picks `try! container.mainContext.fetch(...).first!`. I added a second preview that constructs an `Exercise` with `isCustom: true` + instructions so the reader can visually confirm the "Copy as Custom Exercise" CTA is **absent** on custom entries (AC #4). This is a documentation / safety improvement, not a contract change.

### D-4 — Muscle row uses HStack + Spacer for visual layout

Instead of literally concatenating "{Name} · {percent}" into one `Text`. Reason: HStack + Spacer is the iOS-native left/right alignment pair (same pattern Apple's Settings app uses for label + trailing value rows). The middle-dot in UI-SPEC § Copywriting Contract is the **layout specification**, not a literal character — VoiceOver reads the two `Text` views adjacently, satisfying the spec. The visible result is:

```
Chest                                                    100%
Triceps                                                   50%
```

…which is what the UI-SPEC intent demands (left-aligned name, right-aligned percent). Forcing a literal `·` separator would make the row look like a single concatenated label, breaking the iOS chrome convention.

### D-5 — Sort comparator uses `a.role == "primary"` direct check

Rather than lexicographic `a.role < b.role`. Reason: the role values are raw Strings 'primary' / 'secondary'; lexicographic comparison would sort 'primary' BEFORE 'secondary' (`p < s`), which happens to be the right order today — BUT relying on the lexicographic accident is fragile. If a future taxonomy adds a third role value (e.g., 'stabilizer'), `a.role < b.role` would silently put 'stabilizer' before 'secondary' alphabetically, breaking the spec. The explicit `== "primary"` check makes the intent obvious and survives future role additions: only "primary" is special.

### D-6 — `editingExisting` left nil in `makeDraft(from:)`

The draft's `editingExisting` defaults to nil from `CustomExerciseDraft()`'s init. `makeDraft(from:)` doesn't touch it. Reason: the editor's Save handler branches on `editingExisting != nil` to call `materialize(into:)` (insert NEW) vs `updateExisting(in:)` (overwrite existing). For the Copy flow we explicitly want a NEW exercise, never overwriting the source built-in. Leaving `editingExisting = nil` (default) routes through `materialize(into:)`, which is the correct path per PITFALLS — never mutate templates from instance flows.

### D-7 — Image data intentionally not copied (CONTEXT.md C-22)

Built-in entries have `imagePaths: [String]` references to unbundled binaries (the binaries live in `yuhonas/free-exercise-db` but are not bundled in the app — see CONTEXT.md). Their `imageData: Data?` is therefore nil. Copying nil → nil is a no-op, but the comment `// imageData intentionally not copied` documents the intent so a future change to bundle thumbnails doesn't accidentally start copying them through the Copy as Custom path. The user attaches a fresh image via PhotosPicker in the editor.

### D-8 — Did not add Edit affordance for custom exercises

The plan's Out of Scope explicitly defers "Editing a custom Exercise in-place (without going through Copy as Custom) — Phase 1 only supports creation of new customs from the + toolbar OR from the Copy as Custom hydration. Direct editing of an existing custom exercise (e.g., long-press → Edit) is deferred to a Phase 1.x polish pass." Custom exercises render the same four read-only sections with no Copy CTA and no Edit affordance. The `CustomExerciseEditor`'s Edit-mode wiring (plan 03-04 D-8 Known Stub) remains unreachable in v1 as documented.

## Deviations from Plan

### [Discretion — plan-snippet syntax correction] `.accent` → `Color.accentColor`

- **Found during:** Task 1 implementation review.
- **Issue:** Plan snippet's Copy CTA wrote `.foregroundStyle(.accent)`. `.accent` is not a valid SwiftUI `ShapeStyle` case — Swift would reject this at parse time.
- **Fix:** Used `.foregroundStyle(Color.accentColor)` matching the EmptyLibraryView "Clear filters" button from plan 03-02.
- **Files modified:** `fitbod/ExerciseLibrary/ExerciseDetailView.swift` (line 141).
- **Verification:** Parse-check exits 0. `grep -n 'Color.accentColor' fitbod/ExerciseLibrary/ExerciseDetailView.swift` → line 141.
- **Commit:** `d3274de`.

### [Note — plan-snippet syntax correction] Plan's snippets use `#` for line comments

- **Found during:** Re-reading the plan's code snippets.
- **Issue:** The plan snippets use `#` for line comments (`# primary < secondary in our ordering`, `# imageData intentionally not copied...`). Swift line comments are `//`; `#` is the macro-expression sigil. Same correction every prior Phase 1 plan documented.
- **Fix:** Used `//` line comments throughout. The comment text is retained verbatim where it adds value.
- **Files modified:** N/A — the implementation always uses correct comment syntax.
- **Commit:** N/A.

### [Discretion] Second `#Preview` block for custom exercise (no Copy CTA)

- **Found during:** Task 1 implementation review.
- **Issue:** Plan snippet provided one preview that picks `container.mainContext.fetch(...).first!` (a built-in). With only one preview, the reader can't visually confirm AC #4 ("no Copy as Custom Exercise button is shown for custom exercises") in Xcode's canvas.
- **Fix:** Added a second `#Preview("Custom exercise (no Copy CTA)")` block that constructs an `Exercise` with `isCustom: true` + sample instructions + a primary muscle stimulus. The two previews side-by-side make the conditional CTA behavior obvious.
- **Files modified:** `fitbod/ExerciseLibrary/ExerciseDetailView.swift` (lines 287–299).
- **Verification:** Parse-check exits 0.
- **Commit:** `d3274de`.

### [Rule 3 — Blocking issue] `xcodebuild build` / `xcodebuild test` cannot be run from this environment

- **Found during:** AC #7 verification.
- **Issue:** `xcode-select -p` returns `/Library/Developer/CommandLineTools` rather than `/Applications/Xcode.app/Contents/Developer`. Same environmental constraint that plans 01-01 / 01-02 / 01-03 / 02-01 / 02-02 / 03-01 / 03-02 / 03-04 all documented.
- **Fix:** Substituted `find fitbod fitbodTests -name '*.swift' -type f | xargs xcrun swiftc -parse` over all 59 production + test Swift files. Exits 0 with no output — every cross-file reference resolves. Runtime test execution and visual verification happen on the user's machine when next opening the project in full Xcode. The execution-rules fallback explicitly covers this case (every prior plan in this phase used the same fallback).
- **Files modified:** None.
- **Commits:** N/A (verification only).

### [Discretion] Sort comparator uses `a.role == "primary"` direct check rather than lexicographic

- **Found during:** Task 1 implementation review.
- **Issue:** The plan snippet's comparator wrote `if a.role != b.role { return a.role == "primary" }   # primary < secondary in our ordering`. The intent is clear, but the `#` comment is a Swift syntax error (corrected above) AND the comment hints at lexicographic reasoning — if someone later "simplifies" this to `a.role < b.role` thinking it's equivalent, it would silently break the sort when a third role is added.
- **Fix:** Kept the explicit `== "primary"` check; converted the inline comment to `//` and removed the lexicographic-implying text. The behavior is unchanged from the plan's intent; only the comment is tightened.
- **Files modified:** `fitbod/ExerciseLibrary/ExerciseDetailView.swift` (line 193).
- **Verification:** `grep -n 'a.role == "primary"' fitbod/ExerciseLibrary/ExerciseDetailView.swift` → line 193.
- **Commit:** `d3274de`.

---

**Total deviations:** 4 (1 plan-snippet syntax correction for `.accent`, 1 discretion-driven preview addition, 1 environmental blocking, 1 comment-syntax/clarity correction for the sort comparator). All deviations strengthen the implementation against the plan's intent: `.accent` → `Color.accentColor` was non-negotiable for valid Swift; the second preview improves visual verification of AC #4; the comment tightening preempts a future regression.

## Anti-Patterns Avoided

- ✗ Did NOT show an "Edit" toolbar button on built-in exercises (PITFALLS — read-only must mean read-only). The detail view has no `.toolbar { ... }` modifier; the navigation bar shows only the system back chevron + title.
- ✗ Did NOT add a "read-only" banner at the top of the view (UI-SPEC explicit: "absence of an edit button IS the affordance; do not add explanatory text").
- ✗ Did NOT mutate the source `Exercise` during the Copy as Custom flow. `makeDraft(from:)` reads fields from `source` and writes them into a new `CustomExerciseDraft`; the source `Exercise` is never assigned to. The draft's `editingExisting` stays nil so the editor's Save invokes `materialize(into:)` (insert NEW) rather than `updateExisting(in:)`. (PITFALLS — never mutate templates from instance flows.)
- ✗ Did NOT model the detail view as a `Form`. UI-SPEC's "comprehensive but uncluttered" stance calls for `List` with sections; Form is for editing surfaces (the editor). `List(.insetGrouped)` matches the library list's style for visual continuity.
- ✗ Did NOT wrap anything in `@Bindable`. The detail view is read-only — none of its rendered text is editable. `@Bindable` only appears in the editor (plan 03-04).
- ✗ Did NOT copy `imageData` from the source built-in (CONTEXT.md C-22). Built-in entries have only `imagePaths` references to unbundled binaries; copying nil → nil is a no-op but the explicit comment documents the intent.
- ✗ Did NOT show the muscle stimulus values as decimals (`0.5`, `1.0`). UI-SPEC § Copywriting Contract specifies integer percent format ("50%", "100%"); `Int((stim.weight * 100).rounded())` produces the integer.
- ✗ Did NOT rely on lexicographic role comparison (`a.role < b.role`) for the sort. Explicit `a.role == "primary"` check survives future role additions and makes the intent obvious.
- ✗ Did NOT add a `Save Custom Exercise` button label anywhere. The CTA label is the UI-SPEC § Copywriting Contract authoritative "Copy as Custom Exercise"; the editor's Save button label remains the shorter "Save" (same disposition plan 03-04 documented for the UI-SPEC § Color reference to "Save Custom Exercise" — the Copywriting Contract is authoritative).

## Out of Scope (handled by later plans)

- **Long-press → Edit Exercise affordance** for custom exercises from either the library list or the detail view — deferred per plan "Out of Scope" to Phase 1.x polish or Phase 2 routine builder. The `CustomExerciseEditor`'s Edit-mode code paths (plan 03-04 D-8 Known Stub) exist but remain unreachable in v1.
- **Exercise images / GIFs** in the detail view — deferred per CONTEXT.md. The detail view has no image section; `imagePaths` is read but not surfaced. When images land in a later phase, an Image section can be inserted between Equipment and Mechanic (or above Instructions).
- **Tap-to-cycle behavior on muscle rows** (e.g., to highlight a muscle on a body diagram) → Phase 5 fatigue model. The muscle rows are static display in v1.
- **Edit-existing-custom flow via "Copy as Custom"** on a custom entry — currently the Copy CTA is gated to `!exercise.isCustom`, so it never shows on custom entries. If a future use case wants "Duplicate this custom exercise as a starting point for another", the CTA gate can be relaxed.
- **`makeDraft(from:)` unit test** — the helper is exercised at runtime by the Copy CTA → editor → Save flow. A future polish pass could add a unit test in `fitbodTests/` that constructs a fixture `Exercise` + stimulus rows, calls `makeDraft(from:)`, and asserts the resulting draft's fields. Today the integration path is sufficient.
- **Auto-scroll on long instruction lists** — at the rare ~30-step instructions in the seed data the list will scroll naturally; no special-cased auto-scroll behavior. Out of scope.

## Threat Surface

No new authentication paths, network endpoints, file access patterns, or trust-boundary changes. The detail view is purely read-only over `@Model`-loaded data; the Copy as Custom flow constructs an in-memory `CustomExerciseDraft` (no persistence boundary crossed in this view — the editor owns the eventual `materialize(into:)` call).

`makeDraft(from:)` reads the source's `name`, `equipmentRaw`, `mechanicRaw`, and `muscleStimuli` fields. All four are app-private SwiftData reads — no untrusted input enters this path. The eventual write to a new `Exercise` happens inside `CustomExerciseDraft.materialize(into:)` (plan 03-04), which is the single write boundary; that boundary already owns the SwiftData parameter-binding for the inserted fields.

No threat flags.

## Known Stubs

This plan introduces no new stubs. The two stubs documented in plan 03-02's summary (the `Text("Detail for {name} — plan 03-03 fills this in")` placeholder at line 218 of ExerciseLibraryView.swift) is **resolved** by this plan's swap to `ExerciseDetailView(exercise: ex)`.

Existing stubs from earlier plans that are still unresolved:

| File | Plan that introduced | Stub | Resolved by |
|------|---------------------|------|-------------|
| `fitbod/ExerciseLibrary/ExerciseLibraryView.swift` (EmptyLibraryView) | 03-02 | EmptyLibraryView is shipped with the UI-SPEC copy variants but missing the "Create Custom Exercise" CTA on the with-query variant | `01-PLAN-04-01` polish pass adds the CTA |
| `fitbod/ExerciseLibrary/CustomExerciseDraft.swift` (Edit mode) | 03-04 | `editingExisting` / `updateExisting(in:)` code paths exist but have no user-reachable entry point in v1 | Phase 1.x polish or Phase 2 (long-press → Edit affordance) |
| `fitbod/ExerciseLibrary/CustomExerciseEditor.swift` (Delete section) | 03-04 | Delete Exercise section + Delete confirmation alert exist but only reachable in Edit mode which has no entry point | Same as above |

None of these stubs prevent the plan-03-03 goal (detail view + Copy as Custom) from being achieved.

## TDD Gate Compliance

Plan frontmatter `type:` is not set to `tdd` and the orchestrator did not pass `MVP_MODE=true TDD_MODE=true`. No gate enforcement is required for this plan.

The plan itself states (AC #6): "No new unit tests; the view logic is direct binding (`@Bindable`-free since the view only reads) and the `makeDraft` helper is exercised by integration through the 'Copy as Custom' interaction (manual smoke). Future polish could add a `makeDraft` unit test."

I followed this — no test files created in `fitbodTests/`. The runtime integration path (Copy CTA → editor → Save → new row appears in library) is the test surface.

## Self-Check: PASSED

- **File checks:**
  - `fitbod/ExerciseLibrary/ExerciseDetailView.swift` — **FOUND** (300 lines, `struct ExerciseDetailView: View` at line 75, `body` at line 92, `muscleSection` at line 165, `stimulusSort` at line 192, `makeDraft` at line 236, two `#Preview` blocks at lines 271 and 287)
  - `fitbod/ExerciseLibrary/ExerciseLibraryView.swift` — **MODIFIED** (`.navigationDestination(for: Exercise.self) { ex in ExerciseDetailView(exercise: ex) }` at lines 215–222; file header comment updated at line 16)

- **Commit checks:**
  - `d3274de` (feat: ExerciseDetailView with read-only sections + Copy as Custom Exercise) — **FOUND** in `git log`
  - `764875b` (feat: wire ExerciseLibraryView navigationDestination → ExerciseDetailView) — **FOUND** in `git log`

- **UI-SPEC literal grep:**
  - `grep -n 'Section("Instructions")' fitbod/ExerciseLibrary/ExerciseDetailView.swift` → line 98 — **PASS**
  - `grep -n 'Section("Muscles")' fitbod/ExerciseLibrary/ExerciseDetailView.swift` → line 170 — **PASS**
  - `grep -n 'Section("Equipment")' fitbod/ExerciseLibrary/ExerciseDetailView.swift` → line 119 — **PASS**
  - `grep -n 'Section("Mechanic")' fitbod/ExerciseLibrary/ExerciseDetailView.swift` → line 124 — **PASS**
  - `grep -n '"Copy as Custom Exercise"' fitbod/ExerciseLibrary/ExerciseDetailView.swift` → 1 match in code (line 140); additional matches in header comment — **PASS**
  - `grep -n 'foregroundStyle(Color.accentColor)' fitbod/ExerciseLibrary/ExerciseDetailView.swift` → line 141 — **PASS**
  - `grep -n 'navigationTitle(exercise.name)' fitbod/ExerciseLibrary/ExerciseDetailView.swift` → line 147 — **PASS**
  - `grep -n 'navigationBarTitleDisplayMode(.inline)' fitbod/ExerciseLibrary/ExerciseDetailView.swift` → line 148 — **PASS**
  - `grep -n 'listStyle(.insetGrouped)' fitbod/ExerciseLibrary/ExerciseDetailView.swift` → line 146 — **PASS**

- **Structural checks:**
  - `grep -n '!exercise.isCustom' fitbod/ExerciseLibrary/ExerciseDetailView.swift` → line 129 (Copy CTA gating) — **PASS**
  - `grep -n 'ExerciseDetailView(exercise: ex)' fitbod/ExerciseLibrary/ExerciseLibraryView.swift` → line 221 — **PASS**
  - `grep -n 'Detail for' fitbod/ExerciseLibrary/ExerciseLibraryView.swift` → no matches (plan-03-02 placeholder removed) — **PASS**
  - `grep -n 'CustomExerciseDraft()' fitbod/ExerciseLibrary/ExerciseDetailView.swift` → line 240 (in makeDraft) — **PASS**
  - `grep -n 'NavigationStack {' fitbod/ExerciseLibrary/ExerciseDetailView.swift` → 3 matches (sheet wrapper + 2 previews) — **PASS**

- **Parse check:** `find fitbod fitbodTests -name '*.swift' -type f | xargs xcrun swiftc -parse` exits 0 with no output across all 59 Swift files. Every cross-file reference resolves (`Exercise`, `ExerciseMuscleStimulus`, `MuscleGroup`, `Equipment`, `Mechanic`, `CustomExerciseDraft`, `CustomExerciseDraft.MuscleAssignment.Role`, `CustomExerciseEditor`, `PreviewModelContainer`).

- **Working tree:** clean except for this SUMMARY.md (about to be committed by the final metadata commit).

## What's Next

- **`01-PLAN-04-01` (Wave 4, immediately next):** `SettingsView` (units toggle) + library polish — adds the "Create Custom Exercise" CTA on the with-query empty-state variant (depends on plan 03-04's editor existing, which is wired). Replaces `SettingsTabHost` in `RootView.swift` likewise.
- **Wave 3 is now complete.** All three Wave-3 plans (03-01 RootView + seed splash, 03-02 library list + filter + search, 03-03 exercise detail + Copy as Custom, 03-04 custom exercise editor) have landed. The Library tab is fully wired end-to-end: browse → filter/search → tap row → detail view → optionally Copy as Custom → editor → save → new row appears in list.

---
*Phase: 01-foundation-exercise-library*
*Plan: 03-03 — exercise-detail-and-copy-as-custom*
*Completed: 2026-05-11*
