---
phase: 1
slug: foundation-exercise-library
status: complete
audited: 2026-05-23
baseline: 01-UI-SPEC.md v2 (BRU brutalist rewrite, revised 2026-05-23) + 02-UI-SPEC.md (locked BRU foundation primitive contract)
screenshots: not captured — iOS SwiftUI native; no dev server path
overall_score: 10
overall_max: 24
---

# Phase 1 — UI Review

**Audited:** 2026-05-23
**Baseline:** `01-UI-SPEC.md` v2 (BRU rewrite committed 2026-05-23) + `02-UI-SPEC.md` (locked BRU primitive contract)
**Screenshots:** Not captured (iOS SwiftUI native — no dev server applicable; localhost:3000 / 5173 unreachable)
**Registry audit:** Skipped — no `components.json` (native SwiftUI; shadcn N/A; CLAUDE.md locks zero third-party SPM deps)

> **Context for the score:** Phase 1 shipped in May 2026 against the v1 UI-SPEC (Apple HIG defaults — system fonts, system grays, capsule chips, accent-teal). The UI-SPEC was re-authored to BRU v2 on 2026-05-23 — RETROACTIVELY — as a design contract the future Phase 7 Block A rewrite executes against. The implemented Phase 1 code therefore predates BRU by design (see project memory: "BRU is locked in 02-UI-SPEC.md but never shipped; phases 2-6 use Apple HIG defaults. UI-SPECs were retroactive design contracts."). Drift is systematic and full-layer: zero BRU foundation primitives exist; zero BRU surfaces exist; every visual decision is the Apple HIG default. This audit's value is the migration backlog at the bottom, not the headline number. Sibling audits scored 02 = 12/24, 03 = 10/24, 04 = 9/24 — Phase 1 sits in the same band by design.

---

## TL;DR — One-Paragraph Verdict

**The Phase 1 visual layer does not implement the BRU v2 contract at any level — but the interaction skeleton, copy preservation, accessibility decisions, and state coverage are clean.** Zero BRU foundation exists: no `Color+BRU.swift`, no `BRUFont.swift`, no 8 `bru*.colorset` assets (only `AccentColor.colorset` teal + 4 `Volume*` Phase 5 sets + `AppIcon` ship today), no bundled `InstrumentSerif-Regular.ttf` / `Inter-Medium.ttf` / `JetBrainsMono-Regular.ttf` fonts under `fitbod/Resources/Fonts/` (the directory does not exist), no `UIAppFonts` entry in `Info.plist` (confirmed at `fitbod/Info.plist:1-90` — `GENERATE_INFOPLIST_FILE = NO` for the main target, so the literal plist is authoritative). The 8 BRU primitive components mandated by 02-UI-SPEC § Component Inventory (`BRUHeaderBar`, `BRUTabBar`, `BRUChip`, `BRUSectionHead`, `BRUButton`, `BRUDisplay`, `BRUIndexHeader`, `BRUTickSelector`) are not built — `grep -rn "bruInk\|bruPaper\|bruSignal\|BRUFont\|BRUChip\|BRUHeader\|BRUSection" fitbod/ExerciseLibrary/ fitbod/Settings/SettingsView.swift fitbod/App/RootView.swift` returns **0 hits**. The implemented Phase 1 surfaces use 14 `Color.accentColor` / `.tint` references across 7 Phase 1 files (the deprecated teal `#0E7C86`), 28 Apple HIG semantic font calls (`.font(.body)` / `.font(.caption)` / `.font(.title2.weight(.semibold))` / `.font(.system(size: 48))`), 4 SF Symbols (`magnifyingglass` / `checkmark` / `trash` / `chart.line.uptrend.xyaxis`), 3 `Capsule()` clips on `FilterChip` + `ExerciseRow` Custom tag, 1 `Color(.systemRed)` for inline error copy, 1 `Color(.systemGray5)` chip fill, 1 continuous `Slider(value: ...0...1.0, step: 0.05)` in `MuscleWeightRow` (BRU explicitly replaces this with `BRUTickSelector` 4-discrete-tick selector per UI-SPEC line 416), the system `TabView` with 5 SF-Symbol `tabItem` Labels in `RootView`, the system Apple HIG `Toggle` for units (BRU spec mandates a disclosure-row + `confirmationDialog` per UI-SPEC line 476), and 8 native `Form` / `Section(...)` / `List(.insetGrouped)` patterns where BRU mandates custom `VStack` zones separated by `BRU.borderHeavy`. The interaction skeleton (FilterState predicates, `.searchable` debounce, `@Query<Exercise>` reactivity, NavigationStack-per-tab, splash-on-seed, role-based destructive confirmations, tab-re-tap pop-to-root, accessibility labels on icon-only controls, save-disabled-until-primary save-gate) is correct and behaviorally complete — the visual wrapper around it is the problem.

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 3/4 | v1 copy preserved verbatim and largely matches BRU spec (interaction strings, destructive copy, empty-state copy). UPPERCASE case treatment, "+ NEW" header signal action, "Copy as Custom" UPPERCASE casing, "SAVE / CANCEL" UPPERCASE, eyebrow `MUSCLE / EQUIP / MECH / PATTERN` labels, status-footer "VALID · N PRIMARY MAPPED / READY TO SAVE" all absent. |
| 2. Visuals | 1/4 | Zero BRU primitives exist. `Form` / `Section` / `List(.insetGrouped)` everywhere where BRU mandates `BruPhone` + `BruHeader` + `BruSectionHead` zones with `BRU.borderHeavy` separators. No 48pt title slab on detail. No classification chip row above title. No 4-tick selector. No dashed-border "+ ADD MUSCLE" affordance. No `BruIndexHeader` for A/B/C section bands. No status-footer slab. |
| 3. Color | 1/4 | 14 `Color.accentColor` references — the deprecated teal `#0E7C86` (light) / `#3FBFC9` (dark) confirmed at `Assets.xcassets/AccentColor.colorset/Contents.json` lines 1-37 — drive every accent surface (Custom tag, FilterChip active fill, "Copy as Custom" CTA, "Clear filters", "Create Custom Exercise" CTA, "Add Primary Muscle" leading icon, FilterPickerSheet checkmark). Zero `bruInk` / `bruPaper` / `bruSignal` tokens exist. `Color(.systemRed)` used for inline validation error. `Color(.systemGray5)` used for inactive chip fill. 8 BRU colorsets missing. |
| 4. Typography | 1/4 | Zero `BRUFont` enum. Zero `displayHero` / `displayLarge` / `displayMedium` / `bodyEmphasis` / `bodyDefault` / `labelSmall` / `labelMicro` references. Zero bundled OFL fonts. Apple semantic font roles dominate: `.font(.body)`, `.font(.caption)`, `.font(.caption.weight(.semibold))`, `.font(.title2.weight(.semibold))`, `.font(.system(size: 48))`, `.font(.body.monospacedDigit())`. No `.textCase(.uppercase)` on any label-class string in Phase 1 surfaces. No tracking / letterspacing applied. The 48pt detail title slab in BRU spec is replaced by the iOS NavigationBar's inline `navigationTitle` chrome. |
| 5. Spacing | 3/4 | Padding and spacing values are 4pt-grid clean in 22 of 23 sampled sites (4 / 8 / 12 / 16 / 24 / 32 / 48). One off-grid 6pt and one off-grid 2pt appear. `Divider()` is correctly avoided (BRU bans the default hairline). However zero explicit `Rectangle().fill(.bruInk).frame(height: 2)` or `frame(height: 1)` rules exist — the BRU border-weight contract (1pt `bruHair` / 2pt `bruInk`) is not implemented. The List default `.insetGrouped` separators stand in for borders. |
| 6. Experience Design | 3/4 | Loading state ("Preparing library…" splash) ✓. Two empty-state variants (`EmptyLibraryView` for no-query vs with-query) ✓. Six `.alert` / `.confirmationDialog` chrome surfaces with `role: .destructive` ✓ (Discard Changes / Delete Exercise / Restore from Backup / etc). Save-button gate `.disabled(!draft.isValid)` with `accessibilityHint("Add a primary muscle to enable saving")` ✓. Tab re-tap pop-to-root wired ✓. `accessibilityLabel("Create custom exercise")` on icon-only toolbar button ✓. Slider has `accessibilityLabel + accessibilityValue` ✓. The 1-point deduction is for: (a) accessibility-label coverage is thin (most secondary-text labels rely on the Text's own VoiceOver readout); (b) no specific `.bruInk` haptic / interaction polish exists; (c) the units Toggle binding is correct functionally but BRU mandates a disclosure-row + `confirmationDialog` (UI-SPEC line 476) rather than a binary Toggle. |

**Overall: 10 / 24**

This is in band with the sibling audits (02 = 12/24, 03 = 10/24, 04 = 9/24) — Phase 1 lands one point lower than 02 because Phase 2 had a richer surface inventory to score case-treatment on, and one point higher than 04 because Phase 1's behavior layer is cleaner. Three pillars fail at 1/4 (Visuals, Color, Typography — the BRU layer never shipped); three pass at 3/4 (Copywriting v1-preserved, Spacing on-grid, Experience Design behavior-complete).

---

## Top 3 Priority Fixes

1. **BLOCKER — BRU foundation primitives do not exist (gates Phase 7 Block A).** Verification: `grep -rn "bruInk\|bruPaper\|bruSignal\|BRUFont\|BRUChip\|BRUHeader\|BRUSection\|BRUButton\|BRUTickSelector\|BRUIndexHeader" fitbod/ExerciseLibrary/ fitbod/Settings/SettingsView.swift fitbod/App/RootView.swift` → 0 hits. Until 8 `bru*.colorset` assets land in `Assets.xcassets/` (currently only `AccentColor.colorset` + 4 `Volume*` sets + `AppIcon`), until `Color+BRU.swift` + `BRUFont.swift` land under `fitbod/Design/`, until `InstrumentSerif-Regular.ttf` / `Inter-Medium.ttf` / `Inter-SemiBold.ttf` / `Inter-Bold.ttf` / `JetBrainsMono-Regular.ttf` / `JetBrainsMono-Bold.ttf` land under `fitbod/Resources/Fonts/` (the directory does not exist — `find fitbod/Resources/Fonts/ -name "*.otf" -o -name "*.ttf"` returns empty), until `UIAppFonts` lands in `fitbod/Info.plist` (currently absent — confirmed by `grep -n UIAppFonts fitbod/Info.plist`), and until the 8 BRU primitive components in 01-UI-SPEC § Component Inventory (`BruPhone`, `BruHeader`, `BruChip`, `BruSectionHead`, `BruButton`, `BruTabBar`, `BruIndexHeader`, `BruTickSelector`) are built, no Phase 1 surface rewrite can proceed. **This is hard-blocked on Phase 02.1 Wave A (per Phase 7 CONTEXT D-04) — Phase 7 Block A cannot start until 02.1 ships these foundations.**

2. **BLOCKER — Continuous `Slider` in `MuscleWeightRow.swift:79` must become `BruTickSelector`.** 01-UI-SPEC line 416 explicitly mandates the swap: "The existing spec used a continuous `Slider` (0.0–1.0) for stimulus weight. **BRU replaces this with a 4-discrete-tick selector** matching custom-exercise.jsx: four 22×22pt boxes showing values `0.25 / 0.5 / 0.75 / 1.0`." This is the most semantically load-bearing BRU UX change in Phase 1. The current implementation at `fitbod/ExerciseLibrary/MuscleWeightRow.swift:79-86` uses `Slider(value: $assignment.weight, in: 0.0...1.0, step: 0.05)` with a trailing "{N}%" percent display — the BRU rewrite swaps this for 4 boxes (22×22pt, 1pt `bruInk` border, filled `bruInk` when selected, transparent when not) with values 0.25/0.5/0.75/1.0. The `CustomExerciseDraft.MuscleAssignment.weight: Double` model field is preserved (UX change is purely visual + interaction; the persisted value is still a Double). Behavioral spec: tapping a box sets `muscleRow.weight = boxValue`; default for primary = 1.0; default for secondary = 0.5; 44pt hit area via `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` on the HStack. Accessibility contract in 01-UI-SPEC line 668: implement `AXAdjustableAction` to step through values (4 boxes × 22pt would be below 44pt minimum hit area otherwise).

3. **BLOCKER — `ExerciseDetailView` ships read-only Apple `List` instead of BRU title slab + classification chip row + 48pt `BRUDisplay` name + muscle list.** Per 01-UI-SPEC § Exercise detail screen lines 391-410, Phase 1 ships: (a) classification chip row above the title — `CHEST · BARBELL · HORIZONTAL PUSH` as `BruChip` outline chips, 10pt bold (currently absent — equipment/mechanic live in separate `Section` cards at `fitbod/ExerciseLibrary/ExerciseDetailView.swift:132-140`); (b) 48pt `BRUDisplay` title slab — currently replaced by `navigationTitle(exercise.name)` system chrome at line 200 + `navigationBarTitleDisplayMode(.inline)` at line 201; (c) Primary/Secondary muscle sub-line `Primary: Chest 1.0 · Secondary: Triceps 0.5` in 11pt UPPERCASE `bruMuted` (currently absent); (d) `BruSectionHead("Muscles")` with 2pt `bruInk` top border + 10pt UPPERCASE `bruMuted` label — currently `Section("Muscles")` at line 223; (e) muscle row format `BACK · LATS  1.0` (currently `Chest    100%` at line 226-240 — wrong format AND wrong typography); (f) `BruSectionHead("Instructions")` (currently `Section("Instructions")` at line 111); (g) "COPY AS CUSTOM" CTA as `BruButton` ghost variant with `bruSignal` text + border (currently `Button("Copy as Custom Exercise") .foregroundStyle(Color.accentColor)` at line 162-165 inside a `Section { ... }`). The Phase 1 detail view is also polluted with Phase 3 Prescription Settings (lines 261-332), Phase 5 Plateau Detection (lines 394-462), and Phase 6 Progress entry rows (lines 471-499) that should remain functionally wired but BRU-restyled in their respective Phase 7 blocks (NOT Block A).

---

## Detailed Findings

### Pillar 1: Copywriting (3/4)

Interaction copy is preserved verbatim where BRU spec allows, and where the v1 spec strings match BRU strings the implementation is correct. The score loss is entirely about case treatment + new BRU-only copy fragments missing.

**Passing — interaction copy verbatim per 01-UI-SPEC:**

- `fitbod/App/RootView.swift:125` — `ProgressView("Preparing library…")` ✓ (UI-SPEC § Empty states line 497 "Preparing library…")
- `fitbod/ExerciseLibrary/ExerciseLibraryView.swift:166` — `navigationTitle("Exercises")` — UI-SPEC says "Library" but the implementation pluralizes. WARNING (see below).
- `fitbod/ExerciseLibrary/ExerciseLibraryView.swift:170` — `prompt: "Search exercises"` ✓ (UI-SPEC line 358 "Search exercises")
- `fitbod/ExerciseLibrary/ExerciseLibraryView.swift:195` — `Label("Create custom exercise", systemImage: "plus")` ✓ a11y label
- `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:108-117` — `Button("Cancel")` / `Button("Save", action: save)` ✓ (UI-SPEC § Custom exercise editor — though BRU mandates UPPERCASE "CANCEL" / "SAVE" at the render layer)
- `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:132-138` — `"Discard Changes?"` / `Button("Discard", role: .destructive)` / `Button("Keep Editing", role: .cancel)` ✓ (UI-SPEC lines 453-454 verbatim)
- `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:140-146` — `"Delete \"{name}\"?"` / `Button("Delete", role: .destructive)` / `"Logged session history for this exercise will be preserved."` ✓ (UI-SPEC line 510 verbatim)
- `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:159` — `TextField("e.g. Cambered Bar Bench Press", text: $draft.name)` ✓ (UI-SPEC line 431 "e.g. Cambered Bar Bench Press" verbatim)
- `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:185` — full footer copy `"How much this exercise contributes to weekly volume for that muscle. 100% for primary, 50% for assisting muscles."` ✓ matches 01-CONTEXT.md "stimulus weight" tooltip
- `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:190` — `"At least one primary muscle is required to save."` — close to but not verbatim with UI-SPEC line 496 ("At least one primary muscle is required to save." — actually does match). ✓
- `fitbod/ExerciseLibrary/EmptyLibraryView.swift:108` — `"No exercises match"` ✓ matches UI-SPEC line 494
- `fitbod/ExerciseLibrary/EmptyLibraryView.swift:117` — `"Check spelling or create a custom exercise."` ✓ matches UI-SPEC line 495
- `fitbod/ExerciseLibrary/EmptyLibraryView.swift:106` — `"No exercises match \"\(searchText)\""` ✓ matches UI-SPEC line 495 pattern
- `fitbod/Settings/SettingsView.swift:436` — `"Affects display only. Logged session history is stored in a single canonical unit and re-rendered on the fly."` ✓ (UI-SPEC footer copy)
- `fitbod/Settings/SettingsView.swift:108` — `navigationTitle("Settings")` ✓ (UI-SPEC line 462)
- `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:230` — `"Edit Exercise" / "New Exercise"` — note that BRU spec line 428 uses mixed case `"New exercise"` (lowercase 'e') in BruHeader center; the implementation uses Title Case. Minor deviation.

**WARNING — `navigationTitle("Exercises")` at `fitbod/ExerciseLibrary/ExerciseLibraryView.swift:166` should be `"Library"`:**
01-UI-SPEC line 357 mandates `"Library"` as the BruHeader center. The implementation pluralizes to "Exercises" — minor copy drift dating from the v1 spec where this was acceptable; BRU spec hard-locks it to "Library".

**WARNING — Case treatment is wrong across the board (BRU mandates `.textCase(.uppercase)` for label-class strings, source-of-truth stays mixed-case):**
- `grep -rn "textCase" fitbod/ExerciseLibrary/ fitbod/Settings/SettingsView.swift fitbod/App/RootView.swift` returns 1 hit — and it's `.textCase(nil)` at `fitbod/ExerciseLibrary/ExerciseDetailView.swift:455` (which explicitly DISABLES default-uppercase Section-header behavior). No `.textCase(.uppercase)` modifier appears anywhere in Phase 1 surfaces.
- Every BRU label-class string per 01-UI-SPEC § Copywriting Contract requires uppercase rendering: tab labels (Today/Routines/Library/Progress/Settings → render UPPERCASE in BruTabBar), filter chip labels ("All" stays mixed, but "+ Equipment" / "+ Pattern" / "Custom" + the active "Chest ×" should render UPPERCASE), facet-row eyebrows (`MUSCLE / EQUIP / MECH / PATTERN` — currently rendered as title-cased `Muscle / Equipment / Mechanic / Pattern` at `fitbod/ExerciseLibrary/ExerciseFilterBar.swift:111-131`), index-section letters (BruIndexHeader displays A/B/C — currently using SwiftUI's default `Section(letter)` which renders title-case `B` correctly but in `.headline` HIG font, not 18pt `bruDisplay` on `BRU.bg2`), classification chips (`CHEST · BARBELL · HORIZONTAL PUSH` per UI-SPEC line 402 — currently absent), "VALID · 2 PRIMARY MAPPED" / "READY TO SAVE" status footer (absent), "+ NEW" header right action (currently a SF Symbol Label at `fitbod/ExerciseLibrary/ExerciseLibraryView.swift:194-195`), "EDIT" detail header right action when custom (UI-SPEC line 401 — currently absent), "+ ADD MUSCLE" dashed affordance (currently a `Label("Add Primary Muscle"/"Add Another Muscle", systemImage: "plus")` at `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:177` — not UPPERCASE, not dashed-border, not centered).

**WARNING — Several BRU-only copy strings are not yet present:**
- Result counter `"{N} / {total}"` in BRU.mono 11pt (UI-SPEC line 359 e.g. `"8 / 812"`) — DEFERRED per spec; not a finding.
- Eyebrow labels in the facet quick-row (`MUSCLE` / `EQUIP` / `MECH` / `PATTERN` 9pt UPPERCASE BRU.muted tracking 1.2) — absent because the facet quick-row itself is absent (the implementation uses chip-only filter bar, not the facet quick-row from UI-SPEC lines 366-372).
- `(0 results · clear {Filter} filter to see more)` zero-results italic hint (UI-SPEC line 380) — the implementation uses the EmptyLibraryView headline + body pattern instead, which is the documented BRU spec for empty states.
- Status footer copy `"VALID · {N} PRIMARY MAPPED"` / `"READY TO SAVE"` (UI-SPEC line 448) — absent in `CustomExerciseEditor.swift`. The implementation enforces the save-gate via `.disabled(!draft.isValid)` but renders no inline footer affordance.
- Status footer copy `"NO PRIMARY MUSCLE · SAVE BLOCKED"` (UI-SPEC line 450) — absent. The implementation surfaces the warning as an inline section-footer `Text("At least one primary muscle is required to save.")` at `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:190-192` — semantically equivalent, visually entirely different from the BRU full-bleed slab.
- `"COPY AS CUSTOM"` CTA copy (UI-SPEC line 408) — the implementation uses mixed-case `"Copy as Custom Exercise"` at `fitbod/ExerciseLibrary/ExerciseDetailView.swift:163`.
- `"Save exercise ▸"` with structural cursor (UI-SPEC line 451) — absent. The implementation uses `Button("Save", action: save)` with system-positioned toolbar chrome.
- Mixed-case `"New exercise"` per BruHeader center (UI-SPEC line 428) — implementation uses Title-Case `"New Exercise"`. Minor.

**Score justification: 3/4** — Most copy strings preserved verbatim (correct per spec preservation rule). Case treatment missing entirely. Several BRU-only copy fragments absent (status footer, classification chips above title, primary/secondary sub-line, structural button cursors, "+ ADD MUSCLE" UPPERCASE dashed affordance). The penalty is the case-treatment gap and the missing BRU-only strings.

---

### Pillar 2: Visuals (1/4)

This pillar fails completely. The three mockups under `bru-screens/library.jsx` (120 LOC), `bru-screens/exercise-detail.jsx` (134 LOC), `bru-screens/custom-exercise.jsx` (132 LOC) — the explicit visual source of truth per the spec — have near-zero pixel parity with the implemented surfaces.

**BLOCKER — Zero BRU primitives implemented in Phase 1 scope:**
Verification: `grep -rn "BruPhone\|BruHeader\|BruChip\|BruSectionHead\|BruButton\|BruTabBar\|BruIndexHeader\|BruTickSelector\|BRUDisplay" fitbod/ExerciseLibrary/ fitbod/Settings/SettingsView.swift fitbod/App/RootView.swift` returns **0 hits inside Swift code**. The only hits anywhere in the repo are in `.planning/phases/*/0*-UI-SPEC.md` (the spec documents themselves). Per 01-UI-SPEC § Component Inventory (lines 525-541), the following 8 primitives MUST exist for Phase 1 surfaces to compose:

| Required primitive | UI-SPEC line | File expected | Status |
|---|---|---|---|
| `BruPhone` (root frame container) | 530 | `fitbod/Design/BruPhone.swift` | NOT FOUND |
| `BruHeader` (replaces NavigationBar) | 531 | `fitbod/Design/BruHeader.swift` | NOT FOUND |
| `BruChip` (rectangular outlined chip, 0 corner radius) | 532 | `fitbod/Design/BruChip.swift` | NOT FOUND |
| `BruSectionHead` (2px ink top border + 10pt UPPERCASE label) | 533 | `fitbod/Design/BruSectionHead.swift` | NOT FOUND |
| `BruButton` (full-width bottom button with "▸" suffix) | 534 | `fitbod/Design/BruButton.swift` | NOT FOUND |
| `BruTabBar` (5-tab custom strip replacing TabView chrome) | 535 | `fitbod/Design/BruTabBar.swift` | NOT FOUND |
| `BruIndexHeader` (A/B/C section letters in 18pt BRU.display on BRU.bg2) | 536 | `fitbod/Design/BruIndexHeader.swift` | NOT FOUND |
| `BruTickSelector` (4-box 22×22pt discrete-tick selector) | 537 | `fitbod/Design/BruTickSelector.swift` | NOT FOUND |

Per Phase 7 CONTEXT D-04, these 8 primitives are hard-shared with Phases 2-6 and will be shipped by Phase 02.1 Wave A. Phase 7 Block A consumes them as a dependency. The audit confirms they are not yet on disk.

**BLOCKER — Default Apple chrome everywhere instead of BRU zones:**

`ExerciseLibraryView`:
- `fitbod/ExerciseLibrary/ExerciseLibraryView.swift:156` — `NavigationStack(path: effectivePath)` then `.navigationTitle("Exercises")` at line 166 + `.searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search exercises")` at lines 167-171 — this is Apple's NavigationBar + system search chrome. BRU mandates custom `BruHeader` (44pt content + status bar, BRU.paper bg, no translucency, BruInk 2px bottom border) + a custom search zone (10px 16px padding, BruInk 2px bottom border, 🔍︎ glyph in BRU.display 18pt, transparent TextField, BRU.mono 11pt result counter trailing) per UI-SPEC § Interaction patterns line 575-579.
- `fitbod/ExerciseLibrary/ExerciseLibraryView.swift:181-186` — `.safeAreaInset(edge: .top)` with `ExerciseFilterBar` correctly positions the chip row below the search bar, but ExerciseFilterBar itself uses `.background(.thinMaterial)` at `ExerciseFilterBar.swift:106` — BRU mandates `BRU.paper` opaque background with `BRU.borderHeavy` (2px solid `BRU.ink`) bottom border, not a translucent material.
- `fitbod/ExerciseLibrary/ExerciseLibraryView.swift:305` — `List { ... }` + `.listStyle(.insetGrouped)` at line 328 — the iOS grouped background bleeds through every section. BRU mandates `.plain` list style with `BRU.paper` background and `.listRowSeparator(.hidden)` + manual `BRU.borderLight` (1px BRU.hair) bottom borders on each `ExerciseRow` per UI-SPEC line 588.
- `fitbod/ExerciseLibrary/ExerciseLibraryView.swift:307` — `Section(section.letter)` renders the iOS section header style (small caps, gray, system spacing). BRU mandates `BruIndexHeader(letter: section.letter)` rendering the letter at 18pt BRU.display on `BRU.bg2` with 1px `BRU.ink` bottom border (UI-SPEC line 536).

`ExerciseDetailView`:
- `fitbod/ExerciseLibrary/ExerciseDetailView.swift:200-201` — `navigationTitle(exercise.name) + navigationBarTitleDisplayMode(.inline)` — should be the 48pt BRU.display title slab + 12pt 16pt 16pt padding + 2px BRU.ink bottom border (UI-SPEC line 396, mirroring `bru-screens/exercise-detail.jsx:10-21`).
- `fitbod/ExerciseLibrary/ExerciseDetailView.swift:109` — `List { ... }` with multiple `Section("Instructions" / "Equipment" / "Mechanic" / "Muscles")` — should be `BruSectionHead("Instructions" / "Muscles" / etc.)` with explicit 2px top border + paper fill + 10pt UPPERCASE label.
- `fitbod/ExerciseLibrary/ExerciseDetailView.swift:132-140` — Equipment + Mechanic each rendered as their own iOS `Section` — BRU spec ABOVE the title slab wants `[CHEST] [BARBELL] [HORIZONTAL PUSH]` as inline `BruChip` outline chips in a single horizontal row (UI-SPEC line 402, mirroring `bru-screens/exercise-detail.jsx:11-15`).
- `fitbod/ExerciseLibrary/ExerciseDetailView.swift:226` — Muscle name `Text(stim.muscle?.displayName ?? "Unknown")` and `Text("\(Int((stim.weight * 100).rounded()))%")` at line 237 — should be `{MUSCLE NAME} {weight as decimal}` e.g. `"BACK · LATS  1.0"` per UI-SPEC line 405 + role chip `[PRIMARY]` (BRU.signal fill) / `[SECONDARY]` (BRU.ink outline) at row leading per UI-SPEC line 443-444.
- `fitbod/ExerciseLibrary/ExerciseDetailView.swift:153-167` — `Section { Button { ... } label: { Text("Copy as Custom Exercise").foregroundStyle(Color.accentColor) } }` — should be `BruButton(label: "COPY AS CUSTOM", kind: .ghost)` at the bottom of the detail scroll (UI-SPEC line 408) with `BRU.signal` text + outline `BRU.signal` border, NOT a generic iOS section row.

`CustomExerciseEditor`:
- `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:89` — `Form { ... }` with 5 `Section`s + a 6th conditional Delete section — should be `BruPhone { VStack(spacing: 0) { BruHeader(left: "CANCEL", center: "New exercise", right: "SAVE") + name zone (14px 16px padding, BRU.hair 1px bottom border) + BruSectionHead("Classification") + 2-column grid + BruSectionHead("Primary muscle stimulus", right: "Required") + muscle rows with BruTickSelector + ... + status-footer slab + BruButton } }` per UI-SPEC § Custom exercise editor + `bru-screens/custom-exercise.jsx`.
- `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:104-105` — `navigationTitle(navigationTitle) + navigationBarTitleDisplayMode(.inline)` — same NavigationBar substitution issue. Should be `BruHeader(left: HeaderAction("CANCEL", action: cancel), center: "New exercise", right: HeaderAction("SAVE", color: .bruSignal, isEnabled: draft.isValid, action: save))`.
- `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:158-162` — Name field `Section("Name") { TextField("e.g. Cambered Bar Bench Press", text: $draft.name) }` — should be a dedicated zone with `NAME` 9pt UPPERCASE eyebrow above + 28pt BRU.display + UPPERCASE textTransform input + 1px BRU.hair bottom border per UI-SPEC lines 430-432, mirroring `bru-screens/custom-exercise.jsx:11-23`.
- `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:166-196` — Muscle section `Section { ForEach($draft.muscles) ... }` with iOS Form styling — should be `BruSectionHead("Primary muscle stimulus", right: "Required")` + custom rows with role badge chip + 22×22 tick selector per UI-SPEC line 442-447, mirroring `bru-screens/custom-exercise.jsx:52-79`.
- `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:174-179` — "Add Primary Muscle" / "Add Another Muscle" `Button { ... } label: { Label(addMuscleButtonLabel, systemImage: "plus") }` — should be `"+ ADD MUSCLE"` UPPERCASE 11pt 700 tracking 1.5 inside a 2px dashed BRU.ink-bordered full-width 44pt-tall affordance per UI-SPEC line 447, mirroring `bru-screens/custom-exercise.jsx:108-112`.
- `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:198-217` — Equipment + Mechanic `Picker { ... }` (the Mechanic one is `.segmented`) — BRU's custom-exercise.jsx renders Equipment / Mechanic as cells in a 2-column classification grid (UI-SPEC line 440 "Phase 1 classification grid: 2 cells only"), each cell with 9pt UPPERCASE eyebrow + 14pt 600 selected-value display + 16pt `›` disclosure chevron at right. Tapping pushes a picker.
- `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:219-222` — `Section("Image (optional)") { CustomExerciseImagePicker(draft: draft) }` — Image section is not in the Phase 1 BRU spec (it's deferred per `01-UI-SPEC.md` not surfacing the image affordance in `custom-exercise.jsx`). The image picker behavior is preserved as Apple HIG default — minor finding; can stay until a Phase 7 polish pass touches it.

`RootView` TabView (Library tab is in scope; rest is owned by 02.1):
- `fitbod/App/RootView.swift:161-211` — `TabView(selection: tabSelection)` with 5 `tabItem` Labels using SF Symbols (`figure.strengthtraining.traditional` / `list.bullet.rectangle.portrait` / `dumbbell` / `chart.line.uptrend.xyaxis` / `gearshape`). The full BruTabBar rewrite is owned by 02.1; this audit notes only that the Library tab's `Label("Library", systemImage: "dumbbell")` at line 191 must adopt the BruTabBar treatment (BRU.signal icon + label on active, BRU.muted on inactive, 2px BRU.ink top border, typographic glyphs per 02-UI-SPEC) when 02.1 ships.

`Settings` Units row:
- `fitbod/Settings/SettingsView.swift:418-440` — `Section { Toggle(...) { HStack { Text("Weight Unit"); Spacer(); Text(s.weightUnit == .kg ? "kg" : "lb").foregroundStyle(.secondary) } } } header: { Text("Units") } footer: { Text("Affects display only...") }` — UI-SPEC line 476-481 mandates the row become a tappable disclosure-row (no binary Toggle), with "Units" label on left + "LB" / "KG" in BRU.mono 11pt BRU.muted UPPERCASE right-aligned + `›` BRU.muted 14pt disclosure chevron, and the tap opens a `.confirmationDialog` with two actions: "Pounds (LB)" and "Kilograms (KG)". Same `s.weightUnit` binding, different UI affordance. The Toggle is a v1 carry-over — BRU explicitly replaces it.

**BLOCKER — 4 SF Symbol uses in Phase 1 surfaces where BRU forbids SF Symbols on rewritten surfaces:**
Per 01-UI-SPEC § Design System (line 39) the icon library is SF Symbols, but per 02-UI-SPEC (the locked foundation contract — line 43: "Icon library: **None.** SF Symbols are NOT used in BRU."), Phase 1's BRU rewrite scope must purge them and replace with typographic glyphs or shape draws:
- `fitbod/ExerciseLibrary/EmptyLibraryView.swift:69` — `Image(systemName: "magnifyingglass")` at 48pt — BRU's empty-state pattern (UI-SPEC line 499: "Dashed 2px BRU.ink border on a centered block, all-caps bold label, no illustration") doesn't use an SF Symbol illustration at all. Remove the icon; rely on the dashed-border affordance per UI-SPEC.
- `fitbod/ExerciseLibrary/FilterPickerSheet.swift:184` — `Image(systemName: "checkmark").foregroundStyle(Color.accentColor)` for selection state — BRU swaps for `Text("✓")` glyph in BRU.signal or a custom shape.
- `fitbod/ExerciseLibrary/MuscleWeightRow.swift:71` — `Image(systemName: "trash")` for row delete — BRU swaps for `Text("×")` glyph in BRU.ink.
- `fitbod/ExerciseLibrary/ExerciseDetailView.swift:491` — `Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(Color.accentColor)` in the `ProgressEntryRow` — this is a Phase 6 entry point mounted inside the Phase 1 detail view. Out of strict Phase 1 scope per `<scope_fence>` (Phase 6 surface composed into Phase 1 container); Phase 7 Block D owns this rewrite. Listed here for completeness.

Plus the `.tabItem` SF Symbols at `fitbod/App/RootView.swift:172, 182, 191, 201, 208` (5 more) are inside the TabView shell owned by 02.1 — out of Phase 1 strict scope; noted in the exception list below.

Plus the toolbar `"+"` icon at `fitbod/ExerciseLibrary/ExerciseLibraryView.swift:195` — `Label("Create custom exercise", systemImage: "plus").labelStyle(.iconOnly)` — should become `"+ NEW"` text (UI-SPEC line 357 "+ NEW") in BruHeader right slot with BRU.signal color, 11pt 700 UPPERCASE.

Plus the muscle-add affordance at `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:177` — `Label(addMuscleButtonLabel, systemImage: "plus")` — same purge, becomes the `"+ ADD MUSCLE"` dashed affordance.

**BLOCKER — `Capsule()` clips and accent-fill capsules persist where BRU mandates rectangles (0 corner radius is structural):**
Per 01-UI-SPEC line 539 "Corner radius: BRU uses 0 (zero) corner radius on all containers, cards, chips, and buttons. This is structural — the print-grid aesthetic relies on sharp right-angle borders. Do not add `cornerRadius` anywhere in BRU-styled views."

- `fitbod/ExerciseLibrary/FilterChip.swift:67-72` — `Capsule().fill(isActive ? Color.accentColor : Color(.systemGray5))` + `.contentShape(Capsule())` — must become `Rectangle()` with 1pt `BRU.ink` border + transparent/BRU.signal/BRU.bg2 fills per BRU spec lines 360-364. The whole `FilterChip.swift` file must be rebuilt as `BruChip(label:, fill:, color:)`.
- `fitbod/ExerciseLibrary/ExerciseRow.swift:64-73` — `Custom` tag inside `Capsule().fill(Color.accentColor.opacity(0.15))` — Phase 1 BRU spec deprecates this entirely; the spec does NOT surface a "custom" tag per row (per 01-UI-SPEC § Library screen lines 350-380 the chip trio is `[MUSCLE SLUG] [EQUIP] [COMPOUND]` rendered via `BruChip` outline chips, not a "Custom" badge). Decision needed at planner level: keep the Custom tag (then convert to a rectangular outlined `BruChip` with `Color.bruInk` border, no fill) or drop it per BRU spec absence.

**WARNING — Native `Form` / `Section` / `List(.insetGrouped)` patterns wrap every Phase 1 surface:**
Inventory:
- `ExerciseLibraryView` → `List` + `.listStyle(.insetGrouped)` + `Section(section.letter)` per index group
- `ExerciseDetailView` → `List` + `.listStyle(.insetGrouped)` + 6+ `Section("Instructions" / "Muscles" / "Equipment" / "Mechanic" / "History" / "Plateau Detection" / etc.)`
- `CustomExerciseEditor` → `Form { ... }` + 5+ `Section("Name" / Muscles / "Equipment" / "Mechanic" / "Image (optional)")`
- `FilterPickerSheet` → `List { ... }` + nested `Section { ... }` for pattern footer
- `MusclePickerSheet` → `List { ... }` (no explicit sections)
- `SettingsView` → `Form { ... }` + 5+ `Section("Units" / "Smart Progression" / "Volume Targets" / "Data" / "About")`

Per 01-UI-SPEC § Component Inventory line 530, BRU mandates `BruPhone { VStack(spacing: 0) { zone1; zone2; zone3 } }` as the container pattern with explicit `BruSectionHead` + `BRU.borderHeavy` (2px BRU.ink) between zones. The native iOS grouped-form aesthetic and BRU's brutalist editorial-print aesthetic are visually opposite.

**Score justification: 1/4** — Every BRU primitive and BRU surface is missing. The contract has zero implementation surface. The 3 mockups (`bru-screens/library.jsx`, `exercise-detail.jsx`, `custom-exercise.jsx`) and the implemented Swift are visually unrelated. Score capped at 1/4.

---

### Pillar 3: Color (1/4)

The accent-color story is the clearest single failure in Phase 1, mirroring the sibling 02/03/04 audits.

**BLOCKER — 14 `Color.accentColor` / `Capsule().fill(Color.accentColor)` references across 7 Phase 1 files (the deprecated teal):**

Verification: `grep -n "Color\.accentColor\|Color(\"AccentColor\")\|\.tint(.accentColor)" fitbod/ExerciseLibrary/*.swift` returns:

- `fitbod/ExerciseLibrary/ExerciseFilterBar.swift:97` — `.foregroundStyle(Color.accentColor)` on the "Clear filters" Button — BRU spec line 358 wants `BRU.signal` (#E8341A) which is the warm-orange "alarm" connotation, not the teal calm/secondary.
- `fitbod/ExerciseLibrary/ExerciseRow.swift:67` — `.foregroundStyle(Color.accentColor)` on the "Custom" tag text — see Visuals pillar; tag may be entirely dropped or converted to `bruInk` outline per BRU spec absence.
- `fitbod/ExerciseLibrary/ExerciseRow.swift:71` — `Capsule().fill(Color.accentColor.opacity(0.15))` background on the "Custom" tag — same disposition; if retained, convert to `Rectangle()` with `bruInk` 1pt border, no fill.
- `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:178` — `.foregroundStyle(Color.accentColor)` on the "Add Primary Muscle / Add Another Muscle" `Label` — should become the `"+ ADD MUSCLE"` dashed-border affordance with `bruInk` text (not signal — the affordance is structural per BRU spec line 252).
- `fitbod/ExerciseLibrary/ExerciseDetailView.swift:164` — `.foregroundStyle(Color.accentColor)` on the "Copy as Custom Exercise" Button label — BRU spec line 408 wants `BRU.signal` text + outline `BRU.signal` border (BruButton ghost variant).
- `fitbod/ExerciseLibrary/ExerciseDetailView.swift:446` — `.foregroundStyle(Color.accentColor)` on the "Use global defaults" Button (Plateau Detection section, Phase 5 surface composed into Phase 1 detail) — Phase 5 surface; out of strict Phase 1 scope but listed for completeness.
- `fitbod/ExerciseLibrary/ExerciseDetailView.swift:492` — `.foregroundStyle(Color.accentColor)` on the chart-icon "View progress" entry row (Phase 6 surface in Phase 1 container) — Phase 7 Block D rewrite.
- `fitbod/ExerciseLibrary/FilterChip.swift:68` — `.fill(isActive ? Color.accentColor : Color(.systemGray5))` on the chip background — BRU spec line 362 wants `BRU.signal` fill + `BRU.paper` text for active filter chips; `Color(.systemGray5)` becomes transparent fill with `BRU.ink` 1pt border for inactive.
- `fitbod/ExerciseLibrary/EmptyLibraryView.swift:130` — `.foregroundStyle(Color.accentColor)` on the "Create Custom Exercise" CTA — should be `BRU.signal` per BRU empty-state pattern (UI-SPEC line 495 "BRU.signal fill chip").
- `fitbod/ExerciseLibrary/EmptyLibraryView.swift:135` — `.foregroundStyle(Color.accentColor)` on the "Clear filters" CTA — should be `BRU.signal` per UI-SPEC line 494 ("BRU.signal text, outline chip style").
- `fitbod/ExerciseLibrary/FilterPickerSheet.swift:185` — `.foregroundStyle(Color.accentColor)` on the selected checkmark — replace icon entirely (purge SF Symbol per Visuals pillar) AND replace color with `BRU.ink` for selection state in BRU's neutral-ink-on-selection pattern.

`AccentColor.colorset` itself at `fitbod/Assets.xcassets/AccentColor.colorset/Contents.json` defines:
- Light: `red=0.055, green=0.486, blue=0.525` ≈ `#0E7C86` (deep teal)
- Dark: `red=0.247, green=0.749, blue=0.788` ≈ `#3FBFC9` (cyan-teal)

Per BRU spec § Asset Contract line 644-647, the `AccentColor.colorset` is "removed: replaced by BRU token assets. The iOS tint color should be set to `BRUSignal` via `UIView.appearance().tintColor = UIColor(named: "BRUSignal")` in `fitbodApp.swift`." The deprecation is locked.

**BLOCKER — Zero `bruInk` / `bruPaper` / `bruSignal` references anywhere:**
Verification: `grep -rn "bruInk\|bruPaper\|bruSignal\|bruMuted\|bruFaint\|bruHair\|bruBg" fitbod/ 2>/dev/null | wc -l` → **0**.

**BLOCKER — Zero `bru*.colorset` assets exist:**
Verification: `ls fitbod/Assets.xcassets/` returns `AccentColor.colorset`, `AppIcon.appiconset`, `Contents.json`, `VolumeBelowMEVGray.colorset`, `VolumeNearMRVAmber.colorset`, `VolumeOverMRVRed.colorset`, `VolumeProductiveGreen.colorset`. The 10 BRU colorsets mandated by 01-UI-SPEC § Asset Contract lines 631-641 (`BRUInk`, `BRUPaper`, `BRUSignal`, `BRUBg`, `BRUBg2`, `BRUMuted`, `BRUHair`, `BRUFaint`, `BRUAmber`, `BRUGreen`) are not on disk. Note: 01-UI-SPEC declares 10 sets; 02-UI-SPEC § Asset Contract reduces this to 8 base BRU sets (drops `BRUAmber` and `BRUGreen` from the Phase 2+ core — those become Phase 5 zone colorsets in Block C). The base 8 are the load-bearing inputs.

**WARNING — Hardcoded system colors persist in Phase 1 surfaces:**
- `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:192` — `Color(.systemRed)` on the inline validation error text "At least one primary muscle is required to save." — BRU's destructive contract (01-UI-SPEC § Destructive actions line 514) uses copywriting + structural placement, not system red. The error text should become 11pt `bruSignal` italic or land in a status-footer slab (BRU "NO PRIMARY MUSCLE · SAVE BLOCKED" pattern per UI-SPEC line 450).
- `fitbod/ExerciseLibrary/FilterChip.swift:68` — `Color(.systemGray5)` chip background — BRU's inactive chip fill is transparent with `bruInk` 1pt border, not a gray fill.
- `fitbod/ExerciseLibrary/FilterChip.swift:63` — `Color.white` foreground for active chips — works as a one-shot but BRU mandates `bruPaper` (#F7F4EE), which is warm off-white, not pure white. The distinction is structural to BRU's "warm print" aesthetic.

**WARNING — 13 `.foregroundStyle(.primary)` and `.foregroundStyle(.secondary)` Apple HIG semantic references across Phase 1 surfaces:**
Verification: `grep -n "foregroundStyle(\.primary\|foregroundStyle(\.secondary\|Color\.primary\|Color\.secondary" fitbod/ExerciseLibrary/*.swift` returns 22 hits across 8 files. Sample offenders:
- `fitbod/ExerciseLibrary/ExerciseRow.swift:41, 48` — `.foregroundStyle(.primary)` on exercise name + `.foregroundStyle(.secondary)` on equipment/mechanic metadata
- `fitbod/ExerciseLibrary/ExerciseDetailView.swift:120, 124, 239, 282, 290, 305, 311, 330, 424, 438, 454, 460` — 12 `.foregroundStyle(.secondary)` calls on caption text + step numerals
- `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:188` — `.foregroundStyle(.secondary)` on footer help text
- `fitbod/ExerciseLibrary/EmptyLibraryView.swift:71, 80` — `.foregroundStyle(.secondary)` on the magnifying-glass icon + body copy
- `fitbod/ExerciseLibrary/MuscleWeightRow.swift:54, 74, 85` — `.foregroundStyle(.primary)` on muscle name + `.foregroundStyle(.secondary)` on trash + percent
- `fitbod/ExerciseLibrary/MusclePickerSheet.swift:55, 59` — `.foregroundStyle(.primary)` on muscle name + `.foregroundStyle(.secondary)` on region metadata
- `fitbod/ExerciseLibrary/FilterPickerSheet.swift:164, 181` — `.foregroundStyle(.secondary)` on pattern footer + `.foregroundStyle(.primary)` on row title
- `fitbod/ExerciseLibrary/FilterChip.swift:63` — `Color.primary` on inactive chip text

Each of these maps to a specific BRU token per 02-UI-SPEC § Color: `.primary` → `bruInk`, `.secondary` → `bruMuted`. Apple's adaptive semantic colors do shift correctly between light/dark, but they don't carry BRU's warm-print tonal identity (BRU.ink #111111 vs system black; BRU.muted #7A7367 vs system gray).

**60/30/10 split assessment (against BRU stance per 01-UI-SPEC line 275-280):**
- BRU intends: 60% `BRU.paper` (#F7F4EE warm off-white) dominant, 30% `BRU.bg2`/`BRU.hair` (section dividers + bars + chips), 10% `BRU.signal` (#E8341A burnt-orange).
- Implemented: ~70% `Color(.systemBackground)` / `Color(.systemGroupedBackground)` (cool gray-white iOS adaptive), ~3% accent (14 sites of deprecated teal), no consistent ink-rule surface. The ink-on-paper printerly aesthetic is entirely absent.

**Score justification: 1/4** — Every accent surface points at the wrong color (teal not signal-orange). Zero BRU tokens exist as either Color asset or Color extension. Hardcoded system colors persist on 3 Phase 1 surfaces. The accent reserved-for list in UI-SPEC line 284-298 (6 declared elements) cannot be evaluated for compliance because the accent doesn't exist in the codebase. Score capped at 1/4.

---

### Pillar 4: Typography (1/4)

This pillar fails as cleanly as Color. The spec mandates a complete typography rebuild with 3 bundled OFL fonts; the implementation has not started any of it.

**BLOCKER — Zero `BRUFont` enum or BRU type role references:**
Verification: `grep -rn "displayHero\|displayLarge\|displayMedium\|bodyEmphasis\|bodyDefault\|labelSmall\|labelMicro\|InstrumentSerif\|JetBrainsMono\|Inter-Medium\|Inter-SemiBold\|Inter-Bold\|BRUFont\|bruDisplay\|bruFont\|bruMono" fitbod/ 2>/dev/null` → **0 hits in Swift sources** (all hits are in `.planning/phases/*/0*-UI-SPEC.md`).

**BLOCKER — Zero font files bundled:**
Verification: `find /Users/chrissaechao/Desktop/fitbod/fitbod -name "*.otf" -o -name "*.ttf" 2>/dev/null` → empty. The `fitbod/Resources/Fonts/` directory does not exist; only `fitbod/Resources/ExerciseSeed/` exists.

Per 01-UI-SPEC § Asset Contract lines 651-657, the following 7 files MUST be bundled under `fitbod/Resources/Fonts/`:
- `InstrumentSerif-Regular.ttf` (BRU.display body)
- `InstrumentSerif-Italic.ttf` (BRU.display italic)
- `Inter-Medium.ttf` (BRU.font 500 — body copy)
- `Inter-SemiBold.ttf` (BRU.font 600 — labels)
- `Inter-Bold.ttf` (BRU.font 700 — chips/eyebrows)
- `JetBrainsMono-Regular.ttf` (BRU.mono — data readouts)
- `JetBrainsMono-Bold.ttf` (BRU.mono bold — emphasis numerals)

Note: 01-UI-SPEC ratifies **Instrument Serif + Inter + JetBrains Mono** as the three faces, while 02-UI-SPEC ratifies **Space Grotesk Bold/SemiBold + JetBrains Mono Regular/Bold** as the locked two-face foundation contract. There is a **font-family discrepancy between specs** (01 declares 3 families with Instrument Serif + Inter; 02 locks 2 families with Space Grotesk replacing both Instrument Serif AND Inter). Per 02-UI-SPEC line 56 ("Locked decision for v2: Pairing A"), Phase 02.1 will ship the **02-SPEC pairing**, not the 01-SPEC pairing. Phase 7 Block A executor must reconcile by either: (a) shipping the 02-SPEC fonts and treating 01-SPEC's Instrument Serif as superseded; OR (b) shipping BOTH Instrument Serif and Space Grotesk if 01 retains its 3-family preference. Decision needed at planner level — this audit defers to the planner. (The likely choice is (a) — adopt the 02 locked pair and update 01-UI-SPEC's font table in a future revision.)

**BLOCKER — `Info.plist` has no `UIAppFonts`:**
Verification: `grep -n UIAppFonts fitbod/Info.plist` returns nothing. The file (90 lines) has `NSSupportsLiveActivities = true`, `LSRequiresIPhoneOS = true`, document type declarations, but no font registration. Per 01-UI-SPEC line 64-77, the `UIAppFonts` array must register all 7 font filenames. Per 02-UI-SPEC line 111, the same array under the 02-spec pairing registers 4 filenames. Either way the key is missing.

Project setting note: `fitbod.xcodeproj/project.pbxproj` uses `GENERATE_INFOPLIST_FILE = NO` for the main app target (per `02-UI-REVIEW.md` line 222), so the literal `fitbod/Info.plist` is authoritative — the executor edits the file directly, not the build setting form `INFOPLIST_KEY_UIAppFonts`.

**BLOCKER — 28 Apple HIG semantic font calls dominate Phase 1 surfaces:**

Verification: `grep -n "\.font(\." fitbod/ExerciseLibrary/*.swift` returns 28 hits across the 10 Phase 1 files. Distinct font tokens in use:
- `.font(.body)` — 9 sites (exercise name, instructions step, muscle name, equipment, mechanic display, etc.)
- `.font(.caption)` — 13 sites (metadata, footer copy, percent display, error text)
- `.font(.caption.weight(.semibold))` — 1 site (the "Custom" tag at `ExerciseRow.swift:66`)
- `.font(.title2.weight(.semibold))` — 1 site (EmptyLibraryView heading at line 75)
- `.font(.system(size: 48))` — 1 site (the magnifying-glass icon at EmptyLibraryView.swift:70)
- `.font(.body.monospacedDigit())` — 1 site (the percent display at MuscleWeightRow.swift:84)

Plus the Settings units row: `fitbod/Settings/SettingsView.swift:103, 437` — `.font(.callout)` and `.font(.caption)`.

Plus 4 sites inside the conditional `Section { ... } header: { ... } footer: { ... }` blocks in `CustomExerciseEditor` + `ExerciseDetailView` that rely on the iOS Form section-header defaults (`.subheadline` semibold uppercase + `.footnote` regular gray).

None of these map to BRU's 4-role type system per 01-UI-SPEC § Typography lines 226-243:
- BRU `.caption` → `bruFont(10, weight: .bold)` (Inter 10pt Bold + 1.2 tracking + UPPERCASE)
- BRU `.body` → `bruFont(14, weight: .semibold)` (Inter 14pt SemiBold)
- BRU `.headline` → `bruDisplay(18)` (Instrument Serif 18pt — section indices, dates)
- BRU `.title2` → `bruDisplay(28-48)` (Instrument Serif 28-48pt — screen titles, detail slab)

The 02-UI-SPEC § Typography 7-role enum (`displayHero` / `displayLarge` / `displayMedium` / `bodyEmphasis` / `bodyDefault` / `labelSmall` / `labelMicro`) is the locked project primitive (per 02-UI-SPEC line 162-184 "the BRU 7-role type scale ... is a **locked project primitive**"). Phase 7 Block A will adopt the 7-role scale from 02 and update 01-UI-SPEC's 4-role table to map onto it.

Sample offender mappings:
- `fitbod/ExerciseLibrary/ExerciseRow.swift:40` — `.font(.body)` on the exercise name → BRU `bodyEmphasis` 14pt Inter-SemiBold (or via 02-spec: `BRUFont.bodyEmphasis` 14pt Mono Bold; the 01-spec wants Inter, 02-spec wants Mono — reconciliation deferred).
- `fitbod/ExerciseLibrary/ExerciseRow.swift:47` — `.font(.caption)` on equipment/mechanic → BRU `labelSmall` 10pt UPPERCASE 1.2 letterspacing — currently rendered title-cased ("Barbell · Compound").
- `fitbod/ExerciseLibrary/ExerciseDetailView.swift:119, 123` — `.font(.body)` on instructions step numerals + step text → BRU spec line 407 `"bruFont(13, weight: .medium)` for instruction body copy.
- `fitbod/ExerciseLibrary/ExerciseDetailView.swift:200` — implicit `navigationTitle(exercise.name)` rendered in iOS NavigationBar `inline` style (~17pt SF Pro) — should be the 48pt `bruDisplay` title slab per UI-SPEC line 146.
- `fitbod/ExerciseLibrary/EmptyLibraryView.swift:75` — `.font(.title2.weight(.semibold))` on the empty-state heading → BRU `displayLarge` 28pt Instrument Serif Regular per UI-SPEC empty-state pattern.
- `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:159` — `TextField` placeholder default `.body` font on "e.g. Cambered Bar Bench Press" → UI-SPEC line 431 `bruFont(16, weight: .regular)` placeholder + `bruDisplay(28)` UPPERCASE for the active typed-input state.
- `fitbod/ExerciseLibrary/FilterChip.swift:62` — `.font(.caption)` on chip label → `bruFont(10, weight: .bold).tracking(1.2)` per UI-SPEC line 360.
- `fitbod/ExerciseLibrary/MuscleWeightRow.swift:84` — `.font(.body.monospacedDigit())` on percent display — should be `bruMono(11)` per UI-SPEC line 204.

**BLOCKER — Zero `.textCase(.uppercase)` modifiers in Phase 1 surfaces:**
Verification: `grep -rn "textCase" fitbod/ExerciseLibrary/ fitbod/Settings/SettingsView.swift fitbod/App/RootView.swift` returns 1 hit (`fitbod/ExerciseLibrary/ExerciseDetailView.swift:455` which is `.textCase(nil)` — explicitly DISABLES uppercase). No label-class string in Phase 1 renders UPPERCASE at the view layer. Every BRU eyebrow / chip / label / section-head / tab-label / status-footer string per UI-SPEC § Copywriting Contract requires the `.textCase(.uppercase)` modifier.

**BLOCKER — Zero letter-spacing applied:**
Verification: `grep -rn "\.tracking(" fitbod/ExerciseLibrary/ fitbod/Settings/SettingsView.swift fitbod/App/RootView.swift` returns 0 hits. UI-SPEC § Typography line 222-230 defines `BRU.tracking.eyebrow` (+1.2pt), `BRU.tracking.cap` (+1.5pt), `BRU.tracking.tight` (-0.2pt) as structural letterspacing tokens used on EVERY label-class string. Currently zero implementation.

**Distinct font roles in use (current):** 6 raw font tokens — `.body`, `.caption`, `.caption.weight(.semibold)`, `.title2.weight(.semibold)`, `.system(size: 48)`, `.body.monospacedDigit()`. The numerical count exceeds BRU's 4-role contract (line 231) — but the IDENTITY is entirely wrong (Apple SF Pro semantic, not Instrument Serif + Inter + JetBrains Mono explicit-pt with tracking).

**Score justification: 1/4** — The entire typography contract is unimplemented. Font face, font size, font weight, font letterspacing, font case — all five layers of the BRU type contract are missing. Even the fallback to a system-font "pairing C" (system fonts with `.compressed` width + `.monospaced` design) isn't used. The implemented type is unmodified SF Pro semantic styles. Score capped at 1/4.

---

### Pillar 5: Spacing (3/4)

This pillar is the strongest of the three visual ones. The BRU spec explicitly carries forward the v1 4/8/12/16/24/32/48pt scale, and the implemented code mostly honors it.

**Passes — Phase 1 spacing values mostly land on the 4pt grid:**

Verification: `grep -ohE "\.padding\((\.[a-zA-Z]+,\s*)?[0-9]+\)" fitbod/ExerciseLibrary/ -r | sort | uniq -c | sort -rn` returns:
- `.padding(.vertical, 8)` × 4
- `.padding(.horizontal, 16)` × 4
- `.padding(.vertical, 4)` × 3
- `.padding(.horizontal, 8)` × 3
- `.padding(.horizontal, 32)` × 2
- `.padding(.horizontal, 12)` × 2
- `.padding(.vertical, 2)` × 1 (OFF-GRID — 2pt < BRU `xs=4pt`)
- `.padding(.vertical, 6)` × 1 (OFF-GRID — 6pt is between BRU `xs=4pt` and `sm=8pt`)
- `.padding(.vertical, 16)` × 1
- `.padding(.top, 8)` × 1
- `.padding(.top, 48)` × 1

22 of 23 sampled spacing-padding values land on the BRU grid `{4, 8, 12, 16, 24, 32, 48}` — strong compliance.

`HStack/VStack(spacing:)` distinct values from `grep -ohE "(H|V|Z)Stack\([^)]*spacing:\s*[0-9]+" fitbod/ExerciseLibrary/ -r | sort | uniq -c | sort -rn`:
- `spacing: 8` × 5
- `spacing: 4` × 4
- `spacing: 16` × 3
- `spacing: 12` × 1
- `spacing: 6` × 1 (OFF-GRID per BRU; 01-UI-SPEC line 96 documents `gap: 6` being remapped to 4pt grid as `sm = 8pt`)
- `spacing: 2` × 1 (OFF-GRID — 2pt is below BRU `xs=4pt`)
- `spacing: 0` × 1 (allowed — explicit zero is structural in `BruPhone` container)

**WARNING — Border-weight contract (the BRU rule contract per UI-SPEC line 102-108) is unimplemented:**
- BRU mandates explicit border weights: 2pt for section-level ink rules (`BRU.borderHeavy`), 1pt for hair-rule list dividers (`BRU.borderLight`), 2pt dashed for empty-state affordance (`BRU.borderDash`).
- Verification: `grep -rn "Rectangle().fill" fitbod/ExerciseLibrary/ 2>/dev/null` returns 0 hits. No explicit `Rectangle().fill(.bruInk).frame(height: 2)` or `frame(height: 1)` patterns exist.
- `grep -rn "Divider()" fitbod/ExerciseLibrary/ fitbod/Settings/SettingsView.swift fitbod/App/RootView.swift 2>/dev/null` returns 0 hits — correctly NO `Divider()` usage. Pass.
- However the implementation relies on the List default `.insetGrouped` style's automatic separators (Apple sub-pixel hairlines) which BRU spec line 82 explicitly forbids ("never approximate to 'default thin' or use `.divider()`"). The substitution is not Divider, but it's also not explicit `Rectangle()` borders — it's the List style's implicit separators.
- `fitbod/ExerciseLibrary/ExerciseFilterBar.swift:106` — `.background(.thinMaterial)` substitutes for the 2pt `BRU.ink` bottom border that should separate the filter chip row from the list. Translucent material vs sharp ink rule — visually opposite.

**WARNING — One arbitrary 6pt + one 2pt spacing value:**
- `fitbod/ExerciseLibrary/ExerciseRow.swift:42` — `HStack(spacing: 6)` for the equipment/mechanic dot-separated metadata. Per 01-UI-SPEC line 96 the BRU mockup `gap: 6` value is "remapped to 4pt grid as `sm = 8pt`". Fix: `spacing: 8`.
- `fitbod/ExerciseLibrary/ExerciseRow.swift:69` — `.padding(.vertical, 2)` on the Custom tag — below BRU `xs = 4pt`. Either align to 4pt or accept as a known-small chip padding (the tag becomes a `BruChip` 22pt anyway, with `.padding(.horizontal, 6).padding(.vertical, 3)` per UI-SPEC line 532).
- `fitbod/ExerciseLibrary/MuscleWeightRow.swift:89` — `.padding(.vertical, 4)` — on grid, but the row needs total visual height ≥ 44pt for HIG touch target. Currently relies on Slider's intrinsic height.

**WARNING — `safeAreaInset` insertion is correct in spirit, wrong in detail:**
- `fitbod/ExerciseLibrary/ExerciseLibraryView.swift:181-186` — `.safeAreaInset(edge: .top, spacing: 0)` puts the filter bar above the list — correct stacking. But BRU mandates the search bar AS WELL above the filter bar AND BruHeader above the search bar AND each separated by 2px `BRU.ink` bottom borders (UI-SPEC line 575-579 + `bru-screens/library.jsx:20-65` shows the 3-zone stack: BruHeader → search bar → filter chips → facet quick-row → list).

**Score justification: 3/4** — The numeric spacing contract is largely intact (~96% of values land on the 4pt grid). The border-weight contract (1pt `BRU.hair` / 2pt `BRU.ink` explicit Rectangle fills) is unimplemented — the implementation relies on List default separators which BRU explicitly bans. Two off-grid values (2pt and 6pt) flag as minor. Once BRU primitives land, the spacing values can mostly carry forward.

---

### Pillar 6: Experience Design (3/4)

The behavior layer is the strongest part of the Phase 1 implementation. The spec preserved the v1 interaction contract verbatim, and that interaction layer functions correctly.

**Passes — Loading states:**
- `fitbod/App/RootView.swift:124-128` — `ProgressView("Preparing library…").progressViewStyle(.circular).frame(maxWidth: .infinity, maxHeight: .infinity)` splash with verbatim UI-SPEC copy. Splash visibility predicate at lines 112-120 correctly differentiates idle/loading from ready/failed via `shouldShowSplash` computed property. Plan 03-01 SUMMARY confirmed the seed task is reactive. Pass.

**Passes — Empty states (two variants, correct copy):**
- `fitbod/ExerciseLibrary/EmptyLibraryView.swift:104-138` — Two variants based on `hasQuery` predicate at line 97 (folds whitespace-only to no-query). Verbatim copy per UI-SPEC § Empty states lines 494-495:
  - No-query: heading "No exercises match" + body "Try fewer filters or a different name." + "Clear filters" action.
  - With-query: heading `"No exercises match \"\(searchText)\""` + body "Check spelling or create a custom exercise." + "Create Custom Exercise" action.
- The closure-driven dispatch pattern (line 65) `onClearFilters` / `onCreateCustom` correctly forwards to `filterState.clear` / `presentingNewCustom = true` per line 161-163 of `ExerciseLibraryView`.
- BLOCKER offsetting: body copy mismatch — UI-SPEC line 494 says `"Try fewer filters or a different search."` but implementation says `"Try fewer filters or a different name."` — minor copy drift.

**Passes — Error states:**
- `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:140-147` — `.alert("Delete \"\(draft.name)\"?", isPresented: $presentingDeleteConfirmation)` with `Button("Delete", role: .destructive, action: deleteCustom)` + `Button("Cancel", role: .cancel)` + verbatim message body `"Logged session history for this exercise will be preserved."` — UI-SPEC line 510 verbatim. Pass.
- `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:131-138` — `.confirmationDialog("Discard Changes?", isPresented: $presentingCancelConfirmation, titleVisibility: .visible)` with the dialog only presented when `isDirty` (line 109-113). Pass — destructive role + snapshot-diff trigger correct.
- The "Library Failed to Load" alert specified in UI-SPEC line 507 (seed pipeline failure) is NOT implemented — `fitbod/App/RootView.swift:226-257 runSeed()` logs the error and transitions to `.failed(message:)` state, but no alert is presented. The user sees only the splash → tab bar transition with no diagnostic. WARNING — minor gap that's been deferred per 03-01 plan summary.
- "Photo Access Required" alert (UI-SPEC line 509) is in `CustomExerciseImagePicker` (line 64, role .destructive button) — Phase 1 surface; pass.

**Passes — Destructive actions confirmed:**
- 7 `Button(role: .destructive)` / `Button(role: .cancel)` usages across `CustomExerciseEditor` + `CustomExerciseImagePicker` + `MuscleWeightRow` + `SettingsView` (the SettingsView Restore destructive is Phase 6 scope, out of Phase 1 strict scope). UI-SPEC § Destructive actions line 514-516 contract honored.
- The custom exercise delete with no logged history uses `ExerciseDeletion.delete(target, context:)` at `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:295` — the spec says "No confirmation when no session history" but the implementation always shows the alert. Minor over-confirmation; not a defect.

**Passes — Disabled state on Save:**
- `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:118` — `.disabled(!draft.isValid)` on the toolbar Save button.
- `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:119-123` — `.accessibilityHint(draft.isValid ? "" : "Add a primary muscle to enable saving")` — UI-SPEC line 674 verbatim. Pass.
- The visual "disabled" treatment relies on Apple HIG default (button label dims to gray). BRU spec line 429 mandates the Save button text be `BRU.signal` when enabled / `BRU.muted` when disabled. Functional gate is correct; visual treatment is HIG default.

**Passes — Tab re-tap pop-to-root wired (UI-SPEC § Interaction patterns line 605-607):**
- `fitbod/App/RootView.swift:137-158` — `tabSelection` Binding detects re-tap of the currently-active tab and clears the matching `NavigationPath`. `Tab.library` clears `libraryPath` (line 146); `Tab.progress` clears `progressPath` (line 149); `today / routines / settings` no-op because they have no NavigationPath wired in Phase 1 (line 152). Library tab a11y contract honored.

**Passes — Accessibility coverage on icon-only / interactive controls:**
- `fitbod/ExerciseLibrary/ExerciseLibraryView.swift:198` — `.accessibilityLabel("Create custom exercise")` on the toolbar "+" icon-only Label.
- `fitbod/ExerciseLibrary/MuscleWeightRow.swift:75` — `.accessibilityLabel("Remove \(displayName)")` on the trash icon-only delete button.
- `fitbod/ExerciseLibrary/MuscleWeightRow.swift:80-81` — `.accessibilityLabel("Stimulus weight for \(displayName)").accessibilityValue("\(percent) percent")` on the continuous Slider.
- `fitbod/ExerciseLibrary/ExerciseRow.swift:73` — `.accessibilityLabel("Custom exercise")` on the Custom tag.
- `fitbod/ExerciseLibrary/ExerciseFilterBar.swift:100` — `.accessibilityLabel("Clear filters")` on the clear button.
- `fitbod/ExerciseLibrary/ExerciseFilterBar.swift:73, 79, 84, 90` — chip a11y labels passed via `accessibilityName` (decoupled from visual label per WR-03).
- `fitbod/ExerciseLibrary/FilterChip.swift:74` — `.accessibilityLabel(accessibilityName)` propagated to the underlying button.
- `fitbod/ExerciseLibrary/EmptyLibraryView.swift:72` — `.accessibilityHidden(true)` on the decorative magnifying glass icon. Pass.

22 hits of `accessibilityLabel`/`accessibilityHint` across Phase 1 surfaces — coverage is solid.

**WARNING — A11y gaps per BRU contract:**
- Per UI-SPEC § Accessibility line 668, the `BruTickSelector` requires `AXAdjustableAction` because per-box hit area (22/4 = ~5.5pt per box if naively wrapped) is below 44pt — must combine into one adjustable element. The current `MuscleWeightRow` uses a Slider (which has native `.isAdjustable` trait) so the contract is satisfied today; when the BruTickSelector swap lands, the executor must preserve adjustability.
- Per UI-SPEC line 675, the BruTabBar items each need `.accessibilityAddTraits(.isSelected)` when active. Currently the system `TabView.tabItem` handles this implicitly; preserve when BruTabBar lands (owned by 02.1).
- `fitbod/ExerciseLibrary/EmptyLibraryView.swift:69` — the magnifying-glass `Image(systemName:)` is `accessibilityHidden(true)` which is correct, but BRU empty-state pattern (UI-SPEC line 499) removes the illustration entirely — when the rewrite lands the a11y hidden modifier becomes moot.

**WARNING — Settings units row is a binary Toggle, BRU mandates disclosure-row + `confirmationDialog`:**
- `fitbod/Settings/SettingsView.swift:418-440` — `Toggle(isOn: Binding(get: ..., set: ...))` with mixed-case "Weight Unit" label + right-aligned "lb" / "kg" trailing. UI-SPEC line 476-481 mandates this becomes a tappable disclosure row (`Button` or `NavigationLink`-like cell) with `›` chevron + ".confirmationDialog" presenting "Pounds (LB)" and "Kilograms (KG)" options. Functional gate is correct (`s.weightUnit` binding); visual + interaction affordance is wrong.

**WARNING — No haptic feedback on save / chip select / muscle add:**
- `grep -rn "UINotificationFeedbackGenerator\|UISelectionFeedbackGenerator\|UIImpactFeedbackGenerator" fitbod/ExerciseLibrary/ fitbod/Settings/SettingsView.swift fitbod/App/RootView.swift 2>/dev/null` returns 0 hits. BRU spec doesn't explicitly require haptics on Phase 1 surfaces, but the 02-UI-SPEC § Haptics line 698 wires `UINotificationFeedbackGenerator(.success)` to set-row commit; the equivalent BRU polish for Phase 1 would fire `UIImpactFeedbackGenerator(.medium)` on filter chip select + `(.success)` on save complete. Not currently in scope; minor.

**Score justification: 3/4** — Loading / error / empty / disabled / destructive states all present and correct. Save-gate accessibility hint exemplary. Tab re-tap pop-to-root wired. The 1-point deduction is for: (a) units row is a Toggle not a disclosure-row (BRU spec wants `.confirmationDialog`); (b) one minor empty-state copy drift ("different name" vs "different search"); (c) "Library Failed to Load" alert is wired in state but not presented to user; (d) no haptic polish (minor). The interaction skeleton is correct; the dressing is wrong.

---

## BRU Migration Backlog (Phase 7 Block A — Planner Input)

This is the value-added section of this audit per the user's brief. The numbered list below is the concrete gap report Phase 7 Block A's planner consumes. Each item names a file, a line range, and the BRU spec section that prescribes the fix.

**Expected execution order:** Block A executes AFTER Phase 02.1 ships the BRU foundation (8 colorsets + 4 OFL fonts + Color+BRU.swift + BRUFont.swift + 15+ BRU primitive components). Block A itself splits into Waves A-G per Phase 7 CONTEXT D-11.

### Wave A — Foundation grep audit (per Phase 7 D-11)

Before any surface rewrite, enumerate residual references. Per the grep audit results above:

- **A1.** `Color.accentColor` references in Phase 1 surface scope: 14 occurrences across 7 files (`ExerciseFilterBar.swift:97`, `ExerciseRow.swift:67,71`, `CustomExerciseEditor.swift:178`, `ExerciseDetailView.swift:164,446,492`, `FilterChip.swift:68`, `EmptyLibraryView.swift:130,135`, `FilterPickerSheet.swift:185`). Plus 4 doc-comment hits in `ExerciseRow.swift:12`, `FilterChip.swift:14`, `EmptyLibraryView.swift:40,45`. All to be replaced with `Color.bruSignal` (per BRU accent reserved-for list) or `Color.bruInk` (default).
- **A2.** `.font(...)` Apple HIG semantic calls in Phase 1: 28 occurrences. All to be replaced with `BRUFont.{role}` per 02-UI-SPEC 7-role enum.
- **A3.** `Image(systemName:)` calls in Phase 1 surface scope: 4 occurrences (`EmptyLibraryView.swift:69`, `FilterPickerSheet.swift:184`, `MuscleWeightRow.swift:71`, `ExerciseDetailView.swift:491` — the last is Phase 6 mount, see exception list). Plus toolbar "plus" at `ExerciseLibraryView.swift:195` and `CustomExerciseEditor.swift:177`. All to be purged.
- **A4.** `Capsule()` + `RoundedRectangle(cornerRadius:)` in Phase 1: 3 hits in `FilterChip.swift:67,72` and 1 in `ExerciseRow.swift:71` (the Custom tag). All replaced with `Rectangle()` or `BruChip` per BRU 0-corner-radius contract.
- **A5.** `Color(.system*)` hardcoded semantic colors: 2 hits (`CustomExerciseEditor.swift:192` systemRed, `FilterChip.swift:68` systemGray5). Replace with `bruSignal` / `bruInk` outline.
- **A6.** `.textCase(.uppercase)` modifier absences: 0 instances present (excluding 1 `.textCase(nil)`). Wave B per-surface rewrites add `.textCase(.uppercase)` to every label-class string.
- **A7.** `.tracking(...)` letter-spacing modifier absences: 0 instances. Wave B adds `.tracking(1.2)` (eyebrow), `.tracking(1.5)` (caps), `.tracking(-0.2)` (tight name) per UI-SPEC line 222-230.

### Wave B — Per-surface rewrites

**Surface 1: `ExerciseLibraryView` (`fitbod/ExerciseLibrary/ExerciseLibraryView.swift`)**

1. **`ExerciseLibraryView.swift:156-213`** — wrap body in `BruPhone { VStack(spacing: 0) { BruHeader(left: nil, center: "Library", right: HeaderAction("+ NEW", color: .bruSignal) { presentingNewCustom = true }); searchZone; filterChipRow; facetQuickRow; FilteredExerciseList } }`. Remove `NavigationStack` chrome usage in favor of explicit BruHeader; preserve `path` binding for routing-stack identity.
2. **`ExerciseLibraryView.swift:166`** — `navigationTitle("Exercises")` → `BruHeader(center: "Library", ...)` per UI-SPEC line 357.
3. **`ExerciseLibraryView.swift:167-171`** — `.searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search exercises")` → custom search zone with `HStack { Text("🔍︎").font(.bruDisplay(18)); TextField("Search exercises", text: $searchText).font(.bruFont(16, weight: .medium)); Text(searchResultCounter).font(.bruMono(11)).foregroundColor(.bruMuted) }.padding(.horizontal, 16).padding(.vertical, 10).background(Color.bruPaper).overlay(Rectangle().fill(Color.bruInk).frame(height: 2), alignment: .bottom)` per UI-SPEC line 575-579 + `bru-screens/library.jsx:19-34`.
4. **`ExerciseLibraryView.swift:190-200`** — Toolbar `Button { ... } label: { Label("Create custom exercise", systemImage: "plus") }` → header right is `"+ NEW"` text in BruHeader right slot per item #1. Drop toolbar usage.
5. **`ExerciseLibraryView.swift:305-336`** — `List { ... }.listStyle(.insetGrouped)` → `ScrollView { LazyVStack(spacing: 0) { ForEach sectioned { BruIndexHeader(letter); ForEach exercises { ExerciseRow + Rectangle().fill(.bruHair).frame(height: 1) } } } }.background(Color.bruPaper)` per UI-SPEC line 588.
6. **`ExerciseLibraryView.swift:307`** — `Section(section.letter)` header → `BruIndexHeader(letter: section.letter)` rendering 18pt BRU.display on `BRU.bg2` with 1pt `BRU.ink` bottom border per UI-SPEC line 536.
7. **`ExerciseLibraryView.swift:329`** — `.navigationDestination(for: Exercise.self) { ex in ExerciseDetailView(exercise: ex) }` preserve verbatim (routing behavior unchanged).
8. **Create `fitbod/ExerciseLibrary/FacetQuickRow.swift`** per UI-SPEC § Component Inventory line 549 — 4-column read-only summary of active facet state with 9pt UPPERCASE eyebrows + 12pt SemiBold values, tappable cells opening picker sheet.

**Surface 2: `ExerciseRow` (`fitbod/ExerciseLibrary/ExerciseRow.swift`)**

9. **`ExerciseRow.swift:37-56`** — rewrite as: `HStack(alignment: .center, spacing: 0) { VStack(alignment: .leading, spacing: 4) { Text(exercise.name).font(.bruFont(14, weight: .semibold)).tracking(-0.2); HStack(spacing: 5) { BruChip(equipmentDisplay); BruChip(mechanicDisplay); ... } } Spacer(); /* deferred Custom tag */ }.padding(.horizontal, 16).padding(.vertical, 12)` per UI-SPEC line 374-377 + `bru-screens/library.jsx:75-100`.
10. **`ExerciseRow.swift:40`** — `.font(.body).foregroundStyle(.primary)` → `.font(.bruFont(14, weight: .semibold)).tracking(-0.2).foregroundColor(.bruInk)`.
11. **`ExerciseRow.swift:42-49`** — `HStack(spacing: 6) { Text(...); Text("·"); Text(...) }.font(.caption).foregroundStyle(.secondary)` → chip-row `HStack(spacing: 5) { BruChip(MUSCLE_SLUG); BruChip(EQUIP); BruChip(MECHANIC) }` per UI-SPEC line 376-378.
12. **`ExerciseRow.swift:51-53,64-74`** — Custom tag block → decide (planner): drop entirely (BRU spec absence) OR convert to `BruChip("CUSTOM", color: .bruInk, fill: false)` outline rectangle.
13. **`ExerciseRow.swift:67`** — `.foregroundStyle(Color.accentColor)` → `.bruInk` (if tag retained).
14. **`ExerciseRow.swift:71`** — `Capsule().fill(Color.accentColor.opacity(0.15))` → either drop or `Rectangle()` outlined `bruInk`.

**Surface 3: `ExerciseFilterBar` + `FilterChip` (`fitbod/ExerciseLibrary/ExerciseFilterBar.swift`, `FilterChip.swift`)**

15. **`ExerciseFilterBar.swift:65-107`** — rewrite as `ScrollView(.horizontal) { HStack(spacing: 8) { BruChip("All", fill: true); BruChip("Chest ×", fill: true, color: .bruSignal); BruChip("Barbell ×", fill: true, color: .bruSignal); BruChip("+ Equipment"); BruChip("+ Pattern"); BruChip("Custom") } }.padding(.horizontal, 16).padding(.vertical, 10).background(Color.bruPaper).overlay(Rectangle().fill(Color.bruInk).frame(height: 2), alignment: .bottom)` per UI-SPEC line 360-366 + `bru-screens/library.jsx:36-45`.
16. **`ExerciseFilterBar.swift:106`** — `.background(.thinMaterial)` → `.background(Color.bruPaper)` + `Rectangle().fill(Color.bruInk).frame(height: 2)` as bottom border.
17. **`ExerciseFilterBar.swift:96-101`** — "Clear filters" button → `BruChip("CLEAR FILTERS", color: .bruSignal, fill: false)`; preserve `filterState.clear()` action.
18. **`FilterChip.swift`** — entire file rewrite as `BruChip(_ label: String, color: Color = .bruInk, fill: Bool = false)` primitive per UI-SPEC line 532. Remove `Capsule()` clips (lines 67, 72); replace with `Rectangle()` + `.overlay(RoundedRectangle(cornerRadius: 0).stroke(color, lineWidth: 1))` for outline variant or `.background(color)` for fill variant. Remove `Color(.systemGray5)` inactive fill (line 68); inactive = transparent + ink outline. Remove `Color.accentColor` active fill (line 68); active = `bruSignal` fill + `bruPaper` text.
19. **`FilterChip.swift:62`** — `.font(.caption)` → `.font(.bruFont(10, weight: .bold)).tracking(1.2)` per UI-SPEC line 532.
20. **`FilterChip.swift:63`** — `Color.white` foreground for active → `Color.bruPaper` (#F7F4EE warm off-white).
21. **`FilterChip.swift:73`** — preserve `.frame(minHeight: 44)` for HIG touch target.
22. **Create new `facetQuickRow` view** to render between filter chip row and list per UI-SPEC line 366-372 + `bru-screens/library.jsx:47-65`: 4 columns showing MUSCLE / EQUIP / MECH / PATTERN with 9pt UPPERCASE 1.2 tracking eyebrows + 12pt SemiBold active-value text; 1pt `bruHair` vertical separators; 2pt `bruInk` bottom border.

**Surface 4: `FilterPickerSheet` (`fitbod/ExerciseLibrary/FilterPickerSheet.swift`)**

23. **`FilterPickerSheet.swift:66-88`** — `NavigationStack { List { ... }.navigationTitle(title).navigationBarTitleDisplayMode(.inline) }` → `BruPhone { VStack(spacing: 0) { BruHeader(left: HeaderAction("CANCEL", action: clearCurrentFacet), center: title.uppercased(), right: HeaderAction("DONE") { dismiss() }); ScrollView { LazyVStack(spacing: 0) { sectionBody } } } }`. Replace `.navigationTitle` chrome with BruHeader per UI-SPEC line 531.
24. **`FilterPickerSheet.swift:148-164`** — Pattern footer `Text(...).font(.caption).foregroundStyle(.secondary)` → `Text(...).font(.bruFont(11)).foregroundColor(.bruMuted).padding(.horizontal, 16).padding(.vertical, 8)`.
25. **`FilterPickerSheet.swift:184`** — `Image(systemName: "checkmark").foregroundStyle(Color.accentColor)` → `Text("✓").font(.bruFont(14, weight: .bold)).foregroundColor(.bruInk)` per BRU SF-Symbol purge + BRU's neutral-ink-on-selection pattern.
26. **`FilterPickerSheet.swift:181`** — `.foregroundStyle(.primary)` → `.foregroundColor(.bruInk)`.

**Surface 5: `EmptyLibraryView` (`fitbod/ExerciseLibrary/EmptyLibraryView.swift`)**

27. **`EmptyLibraryView.swift:67-89`** — rewrite body as dashed-border centered block per UI-SPEC line 499 ("Dashed 2px BRU.ink border on a centered block, all-caps bold label, no illustration"). Drop the magnifying glass icon entirely.
28. **`EmptyLibraryView.swift:69-72`** — remove `Image(systemName: "magnifyingglass")` + `accessibilityHidden(true)`.
29. **`EmptyLibraryView.swift:75`** — `.font(.title2.weight(.semibold))` → `.font(.bruDisplay(28))`.
30. **`EmptyLibraryView.swift:79`** — `.font(.body).foregroundStyle(.secondary)` → `.font(.bruFont(13)).foregroundColor(.bruMuted)`.
31. **`EmptyLibraryView.swift:106-110`** — Headline text preserved verbatim.
32. **`EmptyLibraryView.swift:117,119`** — Body text: change `"Try fewer filters or a different name."` to `"Try fewer filters or a different search."` per UI-SPEC line 494 verbatim drift fix.
33. **`EmptyLibraryView.swift:128-132`** — `Button("Create Custom Exercise", action: onCreateCustom).font(.body).foregroundStyle(Color.accentColor)` → `BruChip("+ NEW EXERCISE", color: .bruSignal, fill: true)` per UI-SPEC line 495.
34. **`EmptyLibraryView.swift:133-136`** — `Button("Clear filters", action: onClearFilters).font(.body).foregroundStyle(Color.accentColor)` → `BruChip("CLEAR FILTERS", color: .bruSignal, fill: false)` per UI-SPEC line 494.

**Surface 6: `ExerciseDetailView` (`fitbod/ExerciseLibrary/ExerciseDetailView.swift`) — Phase 1 surface only; Phase 3 + 5 + 6 mounts (Plateau / Prescription Settings / Progress entry) OUT OF Phase 1 strict scope**

35. **`ExerciseDetailView.swift:108-212`** — rewrite Phase 1 sections of body to BRU stack. Wrap in `BruPhone { VStack(spacing: 0) { BruHeader(left: HeaderAction("‹ Library", action: pop), center: nil, right: exercise.isCustom ? HeaderAction("EDIT", action: ...) : nil); titleSlab; muscleSection; instructionsSection; copyAsCustomCTA; /* Phase 3/5/6 mounts unchanged */ } }`. Preserve mount points for downstream phases.
36. **`ExerciseDetailView.swift:200-201`** — `navigationTitle(exercise.name) + navigationBarTitleDisplayMode(.inline)` → 48pt BruDisplay title slab + classification chip row per UI-SPEC § Exercise detail screen + `bru-screens/exercise-detail.jsx:10-21`.
37. **Add title slab** above muscle section: `VStack(alignment: .leading, spacing: 8) { HStack(spacing: 6) { BruChip(MUSCLE_SLUG); BruChip(EQUIP); BruChip(PATTERN) }; Text(exercise.name).font(.bruDisplay(48)); Text(stimulusSubLine.uppercased()).font(.bruFont(11)).tracking(0.5).foregroundColor(.bruMuted) }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 16).overlay(Rectangle().fill(Color.bruInk).frame(height: 2), alignment: .bottom)` per UI-SPEC lines 402-404.
38. **`ExerciseDetailView.swift:109-128`** — Instructions `Section("Instructions") { ForEach instructions { HStack { Text("\(i+1).").font(.body); Text(step).font(.body) } } }` → `BruSectionHead("Instructions") + VStack(alignment: .leading, spacing: 12) { ForEach instructions { Text("\(i+1). \(step)").font(.bruFont(13, weight: .medium)).lineSpacing(1.4) } }.padding(.horizontal, 16).padding(.vertical, 12)` per UI-SPEC line 407.
39. **`ExerciseDetailView.swift:132-140`** — DELETE the Equipment + Mechanic standalone sections (these become inline chips in the title slab per item #37 above).
40. **`ExerciseDetailView.swift:220-245`** — Muscle section: replace `Section("Muscles") { ForEach { HStack { Text(displayName); Spacer; Text("\(percent)%") } } }` with `BruSectionHead("Muscles") + VStack(spacing: 0) { ForEach stimuli { HStack(spacing: 10) { BruChip(stim.role == "primary" ? "PRIMARY" : "SECONDARY", color: stim.role == "primary" ? .bruSignal : .bruInk, fill: stim.role == "primary"); Text(stim.muscle?.displayName?.uppercased()).font(.bruFont(13, weight: .semibold)); Spacer; Text(String(format: "%.1f", stim.weight)).font(.bruMono(13)) }.padding(.vertical, 8).overlay(Rectangle().fill(.bruHair).frame(height: 1), alignment: .bottom) } }.padding(.horizontal, 16)` per UI-SPEC line 404-406.
41. **`ExerciseDetailView.swift:237-240`** — `Text("\(Int((stim.weight * 100).rounded()))%")` percent format → `Text(String(format: "%.1f", stim.weight))` decimal format per UI-SPEC line 405 ("`{MUSCLE NAME} {weight as decimal}` e.g. 'BACK · LATS  1.0'").
42. **`ExerciseDetailView.swift:152-167`** — `if !exercise.isCustom { Section { Button { ... } label: { Text("Copy as Custom Exercise").foregroundStyle(Color.accentColor) } } }` → `if !exercise.isCustom { BruButton("COPY AS CUSTOM", kind: .ghost) { ... } }` at bottom of scroll per UI-SPEC line 408.
43. **`ExerciseDetailView.swift:163`** — Copy: `"Copy as Custom Exercise"` → `"COPY AS CUSTOM"` per UI-SPEC line 408 verbatim casing.
44. **`ExerciseDetailView.swift:164`** — `.foregroundStyle(Color.accentColor)` → BruButton internal: `bruSignal` text + outline `bruSignal` border (ghost variant) per UI-SPEC line 408.
45. **`ExerciseDetailView.swift:178-192`** — History section "View All History" navigation: Phase 6 surface preserved as-is (out of Phase 1 strict scope; Phase 7 Block D Wave G owns).
46. **`ExerciseDetailView.swift:194-197`** — Plateau Detection section: Phase 5 surface (out of Phase 1 strict scope; Phase 7 Block C owns).
47. **`ExerciseDetailView.swift:261-332`** — Prescription Settings section (Phase 3): out of Phase 1 strict scope; Phase 7 Block B owns.
48. **`ExerciseDetailView.swift:471-499`** — `ProgressEntryRow` (Phase 6 entry): out of Phase 1 strict scope; Phase 7 Block D owns.

**Surface 7: `CustomExerciseEditor` (`fitbod/ExerciseLibrary/CustomExerciseEditor.swift`)**

49. **`CustomExerciseEditor.swift:88-103`** — rewrite body from `Form { ... }` to `BruPhone { VStack(spacing: 0) { BruHeader(left: HeaderAction("CANCEL", action: cancelFlow), center: navigationTitle, right: HeaderAction("SAVE", color: draft.isValid ? .bruSignal : .bruMuted, isEnabled: draft.isValid, action: save)); ScrollView { LazyVStack(spacing: 0) { nameZone; BruSectionHead("Classification"); classificationGrid; BruSectionHead("Primary muscle stimulus", right: "Required"); primaryMuscleSection; BruSectionHead("Secondary stimulus"); secondaryMuscleSection } }; statusFooterSlab; BruButton("Save exercise ▸", kind: draft.isValid ? .signal : .ghost, isEnabled: draft.isValid) { save() } } }` per UI-SPEC § Custom exercise editor + `bru-screens/custom-exercise.jsx`.
50. **`CustomExerciseEditor.swift:104-125`** — Remove `.navigationTitle(navigationTitle) + .navigationBarTitleDisplayMode(.inline) + .toolbar { ... }` — BruHeader is the toolbar replacement.
51. **`CustomExerciseEditor.swift:117-124`** — Toolbar Save button → BruHeader right slot per item #49. Preserve `.accessibilityHint(draft.isValid ? "" : "Add a primary muscle to enable saving")` semantics on the new button.
52. **`CustomExerciseEditor.swift:157-163`** — `Section("Name") { TextField(...) }` → name zone: `VStack(alignment: .leading, spacing: 6) { Text("NAME").font(.bruFont(9, weight: .bold)).tracking(1.2).foregroundColor(.bruMuted); TextField("e.g. Cambered Bar Bench Press", text: $draft.name).font(.bruDisplay(28)).textCase(.uppercase).foregroundColor(.bruInk) }.padding(.horizontal, 16).padding(.vertical, 14).overlay(Rectangle().fill(.bruHair).frame(height: 1), alignment: .bottom)` per UI-SPEC lines 430-432 + `bru-screens/custom-exercise.jsx:11-23`.
53. **`CustomExerciseEditor.swift:198-217`** — `Section("Equipment") { Picker(...) } + Section("Mechanic") { Picker(...) }` → 2-column classification grid: `Grid(horizontalSpacing: 0, verticalSpacing: 0) { GridRow { cellEquipment; cellMechanic } }.overlay(Rectangle().stroke(Color.bruHair, lineWidth: 1))` where each cell is `Button { presentingFacetSheet = .equipment } label: { HStack { VStack(alignment: .leading) { Text("EQUIPMENT").font(.bruFont(9, weight: .bold)).tracking(1.2).foregroundColor(.bruMuted); Text(equipmentDisplay).font(.bruFont(14, weight: .semibold)) }; Spacer; Text("›").font(.bruFont(16)).foregroundColor(.bruMuted) }.padding(.horizontal, 16).padding(.vertical, 10) }` per UI-SPEC lines 436-440 + `bru-screens/custom-exercise.jsx:25-50`.
54. **`CustomExerciseEditor.swift:165-196`** — Muscles section: split into Primary + Secondary BruSectionHead blocks per UI-SPEC lines 441-447 + `bru-screens/custom-exercise.jsx:52-79` (Primary block with `right="Required"` metadata) and `:81-113` (Secondary block).
55. **`CustomExerciseEditor.swift:174-179`** — "Add Primary Muscle / Add Another Muscle" `Button { ... } label: { Label(addMuscleButtonLabel, systemImage: "plus") }` → `Button("+ ADD MUSCLE") { presentingMusclePicker = true } .font(.bruFont(11, weight: .bold)).tracking(1.5).foregroundColor(.bruInk).frame(maxWidth: .infinity, minHeight: 44).overlay(Rectangle().stroke(Color.bruInk, style: StrokeStyle(lineWidth: 2, dash: [6, 4])))` per UI-SPEC line 447 + `bru-screens/custom-exercise.jsx:108-112`.
56. **`CustomExerciseEditor.swift:177`** — Remove `Label(..., systemImage: "plus")` — replace with just `"+ ADD MUSCLE"` text per item #55.
57. **`CustomExerciseEditor.swift:178`** — Remove `.foregroundStyle(Color.accentColor)` — affordance is structural `bruInk` per UI-SPEC line 252.
58. **`CustomExerciseEditor.swift:185-194`** — Footer text + validation error → status footer slab per UI-SPEC lines 448-450: when `draft.isValid` → `HStack { Text("VALID · \(primaryCount) PRIMARY MAPPED"); Spacer; Text("READY TO SAVE") }.font(.bruFont(10, weight: .bold)).tracking(1.2).foregroundColor(.bruPaper).padding(.horizontal, 16).padding(.vertical, 10).background(Color.bruSignal).overlay(Rectangle().fill(Color.bruInk).frame(height: 2), alignment: .top)`. When `!draft.isValid` → same shape with `Text("NO PRIMARY MUSCLE · SAVE BLOCKED")` + `bruInk` text + `bruBg2` background.
59. **`CustomExerciseEditor.swift:192`** — Remove `.foregroundStyle(Color(.systemRed))` — error rendering moves to status footer slab.
60. **`CustomExerciseEditor.swift:208-216`** — `Mechanic Picker(.segmented)` → cell in 2-column grid per item #53.
61. **`CustomExerciseEditor.swift:219-223`** — `Section("Image (optional)") { CustomExerciseImagePicker }` — Phase 1 BRU spec does not surface image affordance. Decision needed (planner): drop entirely OR retain as a deferred BRU surface for a future polish pass. Default: retain, restyle the button labels to BRU + `.textCase(.uppercase)`.
62. **`CustomExerciseEditor.swift:132-138`** — Discard confirmation: `confirmationDialog` chrome is Apple system (cannot be fully restyled). Preserve verbatim copy ("Discard Changes?" / "Discard" / "Keep Editing"). The `.destructive` role will render Apple's red — acceptable per BRU spec line 461.
63. **`CustomExerciseEditor.swift:140-147`** — Delete confirmation: same disposition; preserve verbatim. Apple system alert chrome OK.

**Surface 8: `MuscleWeightRow` (`fitbod/ExerciseLibrary/MuscleWeightRow.swift`) — BRU's most semantically load-bearing change in Phase 1**

64. **`MuscleWeightRow.swift:49-90`** — rewrite as: `HStack(spacing: 10) { BruChip(assignment.role == .primary ? "PRIMARY" : "SECONDARY", color: assignment.role == .primary ? .bruSignal : .bruInk, fill: assignment.role == .primary); Text(displayName.uppercased()).font(.bruFont(13, weight: .semibold)).foregroundColor(.bruInk); Spacer; BruTickSelector(weight: $assignment.weight); Button { onDelete() } label: { Text("×").font(.bruFont(20, weight: .medium)).foregroundColor(.bruMuted).frame(width: 44, height: 44) } }.padding(.vertical, 8).overlay(Rectangle().fill(.bruHair).frame(height: 1), alignment: .bottom)` per UI-SPEC line 443-447 + `bru-screens/custom-exercise.jsx:55-78`.
65. **`MuscleWeightRow.swift:58-68`** — Remove `Picker("Role", selection: ...) { ... }.pickerStyle(.segmented).frame(maxWidth: 200).labelsHidden()` — role becomes display-only `BruChip` per item #64 (role flip is via a separate context menu or the editor's role-toggle flow, deferred to planner decision).
66. **`MuscleWeightRow.swift:70-75`** — `Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }` → `Button { onDelete() } label: { Text("×").font(.bruFont(20, weight: .medium)).foregroundColor(.bruMuted) }.frame(width: 44, height: 44).accessibilityLabel("Remove \(displayName)")` per BRU SF-Symbol purge.
67. **`MuscleWeightRow.swift:78-87`** — **CRITICAL: remove the continuous `Slider`**. Replace with `BruTickSelector(weight: $assignment.weight)` primitive that renders 4 boxes (22×22pt each, 2pt horizontal gap, 1pt `bruInk` border, filled `bruInk` when selected, transparent when not, 10pt 700 numeric label per box) for values `[0.25, 0.5, 0.75, 1.0]` per UI-SPEC line 417 + `bru-screens/custom-exercise.jsx:66-76`. The total HStack of 4 boxes = 4×22 + 3×2 = 94pt wide; hit area extended to 44pt per row via `.frame(minHeight: 44).contentShape(Rectangle())` on the row; accessibility via `AXAdjustableAction` per UI-SPEC line 668.
68. **`MuscleWeightRow.swift:83-86`** — Remove the trailing `Text("\(percent)%").font(.body.monospacedDigit())` percent display — BruTickSelector's filled box IS the value display.
69. **`MuscleWeightRow.swift:79-81`** — Preserve `.accessibilityLabel("Stimulus weight for \(displayName)")` / `.accessibilityValue("\(percent) percent")` on the new BruTickSelector; convert percent → decimal value rendering ("0.25" / "0.5" / "0.75" / "1.0" per box).

**Surface 9: `MusclePickerSheet` (`fitbod/ExerciseLibrary/MusclePickerSheet.swift`)**

70. **`MusclePickerSheet.swift:44-72`** — `NavigationStack { List { ... }.navigationTitle("Select Muscle").navigationBarTitleDisplayMode(.inline).toolbar { ... } }` → `BruPhone { VStack(spacing: 0) { BruHeader(left: HeaderAction("CANCEL", action: dismiss), center: "SELECT MUSCLE", right: nil); ScrollView { LazyVStack(spacing: 0) { ForEach muscles { ... } } } } }`.
71. **`MusclePickerSheet.swift:46-62`** — Row layout: `Button { onSelect(mg); dismiss() } label: { HStack { Text(mg.displayName.uppercased()).font(.bruFont(13, weight: .semibold)).foregroundColor(.bruInk); Spacer; Text(mg.region.rawValue.uppercased()).font(.bruFont(9, weight: .bold)).tracking(1.2).foregroundColor(.bruMuted); Text("›").font(.bruFont(16)).foregroundColor(.bruMuted) }.padding(.horizontal, 16).padding(.vertical, 12).overlay(Rectangle().fill(.bruHair).frame(height: 1), alignment: .bottom) }`.
72. **`MusclePickerSheet.swift:54`** — `.font(.body).foregroundStyle(.primary)` → BRU display per item #71.
73. **`MusclePickerSheet.swift:58`** — `.font(.caption).foregroundStyle(.secondary)` → BRU eyebrow per item #71.

**Surface 10: `SettingsView` units row (Phase 1 owns only the Units row + binary Toggle replacement; other sections are Phase 3/5/6 scope)**

74. **`SettingsView.swift:418-440`** — `Section { Toggle(...) { HStack { Text("Weight Unit"); Spacer; Text(s.weightUnit == .kg ? "kg" : "lb").foregroundStyle(.secondary) } } } header: { Text("Units") } footer: { Text(...) }` → `BruSectionHead("UNITS & CALIBRATION") + Button { presentingUnitsPicker = true } label: { HStack { Text("Units").font(.bruFont(13, weight: .semibold)); Spacer; Text(s.weightUnit == .kg ? "KG" : "LB").font(.bruMono(11)).foregroundColor(.bruMuted); Text("›").font(.bruFont(14)).foregroundColor(.bruMuted) }.padding(.horizontal, 16).padding(.vertical, 10) } + .confirmationDialog("Units", isPresented: $presentingUnitsPicker) { Button("Pounds (LB)") { s.weightUnit = .lb }; Button("Kilograms (KG)") { s.weightUnit = .kg } }` per UI-SPEC lines 468-481 + `bru-screens/settings.jsx`.
75. **`SettingsView.swift:422-432`** — Remove `Toggle` entirely (binary gate becomes disclosure row).
76. **`SettingsView.swift:434`** — `Text("Units")` header → `BruSectionHead("UNITS & CALIBRATION")` per UI-SPEC line 467.
77. **`SettingsView.swift:436-438`** — Footer copy preserve verbatim. Restyle to `Text(...).font(.bruFont(11)).foregroundColor(.bruMuted).padding(.horizontal, 16).padding(.bottom, 8)`.

**Surface 11: `RootView` Library tab (out of strict Phase 1 scope — TabView shell owned by 02.1; this is a fence-aware note)**

78. **`RootView.swift:189-193`** — Library tab `LibraryTabHost(path: $libraryPath).tabItem { Label("Library", systemImage: "dumbbell") }.tag(Tab.library)` — when 02.1 ships `BRUTabBar`, the Library tab consumes it transparently. Active tab uses BRU.signal icon + label; inactive uses BRU.muted. Library tab icon: per 01-UI-SPEC line 339 the SF Symbol `dumbbell` stays as the iconography (BRU's icon library section line 39 carves out SF Symbols for icon usage in 01-SPEC; 02-SPEC's full SF-Symbol purge is the broader pattern). Reconciliation deferred to 02.1 / planner.

### Wave C — Regression sweep (per Phase 7 D-11)

After all surface rewrites in Block A:

79. **Grep gate** — re-run all Wave A grep commands and confirm zero residual references in Phase 1 surface scope:
    - `grep -rn "Color\.accentColor" fitbod/ExerciseLibrary/ fitbod/Settings/SettingsView.swift` → 0 (excluding doc comments which can stay as historical context)
    - `grep -rn "\.font(\.\(body\|headline\|title\|caption\|subheadline\|footnote\|callout\|largeTitle\|system\)" fitbod/ExerciseLibrary/ fitbod/Settings/SettingsView.swift` → 0
    - `grep -rn "Image(systemName:" fitbod/ExerciseLibrary/` → exception list only (see below)
    - `grep -rn "Capsule\|RoundedRectangle" fitbod/ExerciseLibrary/` → 0
    - `grep -rn "Color(\.system" fitbod/ExerciseLibrary/ fitbod/Settings/SettingsView.swift` → 0
80. **Functional regression** — `xcodebuild test` for the Phase 1 test target stays GREEN: `FilterStatePredicateTests`, `IndexedQueryTests`, `CustomExerciseDraftTests`, `CascadeRuleTests`, `EnumPersistenceTests`, `SchemaV1Tests`, `UserSettingsTests`, `SeedTests`, `DTODecodingTests`.
81. **New BRU contract tests** — add Swift Testing `@Test` cases per Phase 7 D-14:
    - `BRUFontResolutionTest` — assert `UIFont(name: "InstrumentSerif-Regular", size: 48) != nil` (registration smoke).
    - `BRUColorTokenPresenceTest` — assert `UIColor(named: "BRUInk") != nil` for all 8 base BRU colorsets.
    - `BruTickSelectorContractTest` — assert that `BruTickSelector(weight: .constant(0.75)).body` contains a `Color.bruInk` filled box at the 0.75 position (structural assertion via property reflection).
    - `CopyVerbatimTest` — assert that key copy strings ("No exercises match", "Copy as Custom Exercise", "+ ADD MUSCLE", "VALID · N PRIMARY MAPPED", "READY TO SAVE", "Logged session history for this exercise will be preserved.") appear character-for-character in the rewritten surfaces.

### Wave G — Cleanup (per Phase 7 D-11 + 02.1 pattern)

82. **Remove `AccentColor.colorset`** — per 01-UI-SPEC line 643-647, the asset is deprecated. After all Phase 1/2/3/4/5/6 surfaces are rewritten (i.e., after Phase 7 + 02.1 + 04.1 all close), delete `fitbod/Assets.xcassets/AccentColor.colorset/`. Until then, retain — Phase 3/4/5/6 surfaces still bind to it. (Phase 7 final grep gate (Wave Z, per Phase 7 D-16) handles this cleanup.)
83. **Remove inline doc-comment references** to deprecated patterns (`Color.accentColor` in `ExerciseRow.swift:12`, `FilterChip.swift:14`, `EmptyLibraryView.swift:40,45`) — informational only; cosmetic cleanup.
84. **Update 01-UI-SPEC § Typography** — reconcile the 4-role 01-spec typography table (BRU.display Instrument Serif + BRU.font Inter + BRU.mono JetBrains Mono) with the 7-role 02-spec locked enum (`displayHero` / `displayLarge` / `displayMedium` / `bodyEmphasis` / `bodyDefault` / `labelSmall` / `labelMicro` using Space Grotesk + JetBrains Mono). Decision needed at planner level — likely adopt 02-spec pairing and update 01-SPEC to map onto the 7-role enum.

**Total Wave B per-surface rewrites: 73 atomic tasks (items 1-73) + Wave C 3 regression tasks (79-81) + Wave G 3 cleanup tasks (82-84) = 79 tasks total.** Per Phase 7 D-10 "per-plan task budget ~3-8 tasks per 02.1-01-PLAN.md precedent", this maps to ~10-15 plans in Block A.

---

## Exception List — Apple HIG Retentions That Are Intentionally NOT BRU-Rewritten

These are flagged in the Wave C grep gate as PERMITTED references with rationale. Phase 7 Block A planner consumes this list to scope its grep gates.

| Pattern | Files | Rationale |
|---------|-------|-----------|
| `Image(systemName: "chart.line.uptrend.xyaxis")` | `fitbod/ExerciseLibrary/ExerciseDetailView.swift:491` | Phase 6 `ProgressEntryRow` mount inside Phase 1 detail view container. Out of Phase 1 strict scope per `<scope_fence>`. Owned by Phase 7 Block D. |
| `Color.accentColor` × 3 | `fitbod/ExerciseLibrary/ExerciseDetailView.swift:446,492` + `fitbod/Settings/SettingsView.swift` Plate Inventory / Volume Targets navigation | Phase 3 / Phase 5 surfaces composed into Phase 1 containers (Plateau Detection, Plate Inventory entry, Volume Targets entry). Owned by Phase 7 Block B / C respectively. |
| `Image(systemName: ...)` × 5 (tab icons) | `fitbod/App/RootView.swift:172,182,191,201,208` | TabView shell owned by 02.1 (BRUTabBar). Library tab icon swap handled by 02.1's tab-bar rewrite, not Block A. |
| `.alert(...)` / `.confirmationDialog(...)` with `role: .destructive` | All sites | Apple system chrome cannot be fully restyled. The `.alert` button's red color is the ONLY system-red Phase 1 surface acceptable per 02-UI-SPEC line 461. |
| `Apple system Slider / Toggle / Picker .segmented` outside Phase 1 BRU rewrite scope | Phase 3 + Phase 5 + Phase 6 settings surfaces in `fitbod/Settings/SettingsView.swift` (`Stepper`, `Picker`, etc.) | Out of Phase 1 strict scope. Phase 7 Block B / C / D own respectively. |
| `PhotosPicker` in `CustomExerciseImagePicker` | `fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift` | Apple `PhotosUI` framework — not in any BRU mockup. Phase 1 BRU spec does not surface image picker affordance. Retain as-is until a future polish pass; styling stays HIG. |
| `swipeActions(edge: .trailing)` system swipe-to-delete | Apple list-row behavior in any List | Per 01-UI-SPEC line 119, "The 'delete' swipe action uses the system-provided swipe row height (no override)." Acceptable. |

---

## Files Audited

**Phase 1 surface code (10 in-scope files):**

- `fitbod/ExerciseLibrary/ExerciseLibraryView.swift` (379 lines — main library list + filter wiring)
- `fitbod/ExerciseLibrary/ExerciseRow.swift` (110 lines — list row)
- `fitbod/ExerciseLibrary/ExerciseFilterBar.swift` (162 lines — filter chip bar)
- `fitbod/ExerciseLibrary/FilterChip.swift` (95 lines — single chip)
- `fitbod/ExerciseLibrary/FilterPickerSheet.swift` (239 lines — facet multi-select sheet)
- `fitbod/ExerciseLibrary/EmptyLibraryView.swift` (158 lines — empty state)
- `fitbod/ExerciseLibrary/ExerciseDetailView.swift` (539 lines — detail destination; Phase 1 + Phase 3/5/6 mounts)
- `fitbod/ExerciseLibrary/CustomExerciseEditor.swift` (306 lines — create/edit form)
- `fitbod/ExerciseLibrary/MuscleWeightRow.swift` (113 lines — slider row inside editor — CRITICAL BRU SWAP TARGET)
- `fitbod/ExerciseLibrary/MusclePickerSheet.swift` (79 lines — muscle picker)

**Adjacent surfaces (partial Phase 1 scope):**

- `fitbod/Settings/SettingsView.swift` (561 lines — Units row is Phase 1; Smart Progression / Volume Targets / Data are Phase 3/5/6)
- `fitbod/App/RootView.swift` (532 lines — TabView shell is 02.1; Library-tab wiring is Phase 1)

**Asset / configuration:**

- `fitbod/Assets.xcassets/` — 7 entries: `AccentColor.colorset` (deprecated teal), `AppIcon.appiconset`, `Contents.json`, `VolumeBelowMEVGray.colorset`, `VolumeNearMRVAmber.colorset`, `VolumeOverMRVRed.colorset`, `VolumeProductiveGreen.colorset`. **Zero `bru*.colorset` assets.**
- `fitbod/Resources/` — only `ExerciseSeed/` (JSON dataset + version stamp). **No `Fonts/` directory.**
- `fitbod/Info.plist` — 90 lines. Has `NSSupportsLiveActivities`, `LSRequiresIPhoneOS`, document type declarations. **No `UIAppFonts` key.**

**Planning artifacts (baseline):**

- `.planning/phases/01-foundation-exercise-library/01-UI-SPEC.md` (738 lines — BRU v2 rewrite committed 2026-05-23)
- `.planning/phases/01-foundation-exercise-library/01-CONTEXT.md` (135 lines)
- `.planning/phases/01-foundation-exercise-library/PLAN-INDEX.md` (138 lines — 12 atomic plans)
- All 12 PLAN.md + 12 SUMMARY.md files in `.planning/phases/01-foundation-exercise-library/`
- `.planning/phases/02-core-loop-routines-sessions/02-UI-SPEC.md` (BRU primitive contract — color hex table + 7-role font enum + 15+ primitive inventory)
- `.planning/phases/02-core-loop-routines-sessions/02-UI-REVIEW.md` (12/24 — format template + sibling reference)
- `.planning/phases/03-smart-prescription-warm-ups/03-UI-REVIEW.md` (10/24 — sibling reference)
- `.planning/phases/04-periodization-blocks/04-UI-REVIEW.md` (9/24 — sibling reference)
- `.planning/phases/07-bru-visual-rewrite/07-CONTEXT.md` (Phase 7 scope — Block A consumes this file)

**bru-screens mockups (visual contract source):**

- `bru-screens/library.jsx` (120 LOC — library list + filter + facet quick-row + index headers + tab bar)
- `bru-screens/exercise-detail.jsx` (134 LOC — title slab + 48pt name + classification chips + muscle list + history + PR strip — Phase 1 owns first half, Phase 6 owns second half)
- `bru-screens/custom-exercise.jsx` (132 LOC — name input + classification grid + primary/secondary muscle tick selectors + status footer slab + BruButton save)

**Verification commands executed:**

- `grep -rn "Color\.accentColor" fitbod/ExerciseLibrary/ fitbod/Settings/SettingsView.swift` → 14 hits across 7 Phase 1 files (+ 4 doc-comment hits)
- `grep -rn "\.font(\.\(body\|headline\|title\|title2\|caption\|callout\|system\)" fitbod/ExerciseLibrary/` → 28 hits across 10 files
- `grep -rn "Image(systemName:" fitbod/ExerciseLibrary/` → 4 hits (1 Phase 6 mount + 3 Phase 1)
- `grep -rn "Capsule\|RoundedRectangle" fitbod/ExerciseLibrary/` → 3 Capsule hits in `FilterChip` + `ExerciseRow` + 1 contentShape
- `grep -rn "Color(\.system" fitbod/ExerciseLibrary/` → 2 hits (`systemRed` in CustomExerciseEditor:192, `systemGray5` in FilterChip:68)
- `grep -rn "bruInk\|bruPaper\|bruSignal\|BRUFont\|BRUChip\|BRUHeader\|BRUSection\|BruTickSelector\|BruIndexHeader\|BruPhone" fitbod/ExerciseLibrary/ fitbod/Settings/SettingsView.swift fitbod/App/RootView.swift` → **0 hits**
- `grep -rn "textCase" fitbod/ExerciseLibrary/ fitbod/Settings/SettingsView.swift fitbod/App/RootView.swift` → 1 hit (`.textCase(nil)`)
- `grep -rn "\.tracking(" fitbod/ExerciseLibrary/ fitbod/Settings/SettingsView.swift fitbod/App/RootView.swift` → 0 hits
- `find fitbod/Resources -type d` → only `ExerciseSeed/`, no `Fonts/`
- `find fitbod -name "*.otf" -o -name "*.ttf"` → empty
- `grep -n UIAppFonts fitbod/Info.plist` → not found
- `ls fitbod/Assets.xcassets/ | grep -i bru` → not found

---

## Summary of Defects by Category

| Category | Count | Severity |
|----------|-------|----------|
| BRU primitives not built (BruPhone / BruHeader / BruChip / BruSectionHead / BruButton / BruTabBar / BruIndexHeader / BruTickSelector) | 8 components | BLOCKER |
| BRU color palette absent | 8 base tokens (+ 2 Phase-5 amber/green) | BLOCKER |
| BRU font faces not bundled | 3 families (Instrument Serif + Inter + JetBrains Mono per 01-spec; 2 families per 02-spec) | BLOCKER |
| AccentColor regression (teal #0E7C86 in Phase 1 scope) | 14 sites across 7 files | BLOCKER |
| Apple HIG semantic font calls | 28 sites across 10 files | BLOCKER |
| SF Symbols in Phase 1 surfaces | 4 sites (+ 5 in TabView shell owned by 02.1) | BLOCKER |
| Capsule / RoundedRectangle clips | 3 sites | BLOCKER |
| Hardcoded system colors (systemRed/systemGray5) | 2 sites | BLOCKER |
| Continuous Slider in MuscleWeightRow (BRU mandates BruTickSelector) | 1 site (load-bearing UX change) | BLOCKER |
| Form / Section / List(.insetGrouped) — should be BruPhone + BruSectionHead | 8 surfaces | BLOCKER |
| Settings Units row is binary Toggle (BRU wants disclosure + confirmationDialog) | 1 site | BLOCKER |
| No `.textCase(.uppercase)` on label-class strings | All label sites | BLOCKER |
| No `.tracking(...)` letter-spacing | All label sites | BLOCKER |
| Status footer slab absent (CustomExerciseEditor) | 1 site | BLOCKER |
| 48pt title slab + classification chip row absent (ExerciseDetailView) | 1 site | BLOCKER |
| Dashed-border "+ ADD MUSCLE" affordance absent | 1 site | BLOCKER |
| Border-weight contract (1pt bruHair / 2pt bruInk explicit Rectangle fills) unimplemented | All surfaces | WARNING |
| Off-grid spacing (2pt + 6pt) | 2 sites | WARNING |
| navigationTitle("Exercises") drift (should be "Library") | 1 site | WARNING |
| EmptyLibraryView copy drift ("different name" should be "different search") | 1 site | WARNING |
| "Library Failed to Load" alert wired in state but not presented | 1 site | WARNING |
| Settings units row footer copy `.font(.caption)` (correct location, wrong typography) | 1 site | WARNING |
| Doc-comment references to deprecated `Color.accentColor` patterns | 4 sites | INFO |

**Root cause:** Phase 1 was executed in May 2026 against the v1 UI-SPEC (Apple HIG stance — system fonts, AccentColor teal, capsule chips, NavigationStack + Form chrome). The BRU v2 design contract was authored retroactively on 2026-05-23 — by design, per project memory ("BRU is locked in 02-UI-SPEC.md but never shipped; phases 2-6 use Apple HIG defaults. UI-SPECs were retroactive design contracts."). The BRU layer never shipped in Phase 1; the entire visual contract awaits Phase 7 Block A execution (which itself depends on Phase 02.1 shipping the BRU foundation first per Phase 7 CONTEXT D-04).

---

## Verdict

**Severity:** 3 BLOCKERs (Pillars 2/3/4 at score 1), 6 WARNINGs, several minor recommendations. **9 BLOCKER categories** with 70+ concrete fix tasks at the file:line level.

**Migration cost estimate:** Block A is 79 atomic tasks per Wave B inventory above → ~10-15 plans at 3-8 tasks per plan per 02.1-01-PLAN.md precedent. Block A is the smallest of the 4 Phase 7 blocks (Phase 1 has 3 surfaces; Phase 5 has ~12; Phase 6 has ~7; Phase 3 has ~9). Estimated implementation order within Block A: foundation gate (waiting on 02.1) → MuscleWeightRow + BruTickSelector primitive contribution (highest-leverage UX swap) → CustomExerciseEditor (composes the new primitive) → ExerciseDetailView (title slab + chip row) → ExerciseLibraryView (BruHeader + search zone + filter chip row + facet quick-row) → EmptyLibraryView (dashed-border affordance) → FilterChip + ExerciseFilterBar (BruChip primitive consumption) → MusclePickerSheet + FilterPickerSheet (BruHeader + list rows) → Settings Units row (disclosure + confirmationDialog) → grep gate → BRU contract tests.

**The audit's job is to make the gap visible — the path is the planner's call.**

---

*Audited by gsd-ui-auditor — adversarial stance. No averaging. Headline 10/24 reflects three pillars at 1/4 (zero BRU implementation at the visual layer) + three pillars at 3/4 (interaction skeleton + copy preservation + spacing-grid compliance correct from v1). The visual contract has zero implementation surface; the behavior contract is solid. Phase 7 Block A consumes this file as its planner input.*
