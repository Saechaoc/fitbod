# BRU Screens Wiring Checklist

> **Author:** Claude  •  **Created:** 2026-05-24  •  **Living document**
> Persisted across sessions. Read this first when resuming "BRU screen" work.
> Source of truth for what's done, what's next, and how to verify each step.

---

## How To Use This Doc

1. Open this doc when resuming "BRU screen" work.
2. Find the lowest-numbered unchecked item in the active Phase (A → F).
3. Read its sub-items, confirm dependencies (§0 Ground Rules), then execute.
4. Check the box when commit lands. Update "Last updated" line at the bottom.
5. Reference Appendices A–E for primitive lookup, verification protocol, navigation map.

**Editing this file is part of the work.** When you finish a slice, check the box. When you discover a new sub-task, add it. Treat the doc as living state.

---

## 0. Ground Rules (READ BEFORE TOUCHING CODE)

### Stack & Conventions
- iOS 18.0 target, Swift 6 strict concurrency, SwiftUI + SwiftData
- New views use `@Observable` + `@Query` directly. Never `ObservableObject` / `@StateObject` / `@Published` in new code.
- Files live in tab-based folders under `fitbod/`: `Today/`, `Routines/`, `Progress/`, `Settings/`, `Periodization/`, `Sessions/`, `ExerciseLibrary/`, `Fatigue/`
- BRU design tokens live in `fitbod/Design/`. Never re-roll an existing primitive — extend it.
- Persist multi-slice work via GSD plans (CLAUDE.md mandates it). See Appendix E for the bridge from this checklist into a `/gsd-plan-phase` flow.

### BRU Foundation Status (all shipped)
- **Colors** (`fitbod/Design/Color+BRU.swift`): bruInk, bruPaper, bruSignal, bruFaint, bruHair, bruMuted, bruBg, bruBg2, bruAmber, bruGreen
- **Fonts** (`fitbod/Design/BRUFont.swift`): 7 roles — displayHero / displayLarge / displayMedium / bodyEmphasis / bodyDefault / labelSmall / labelMicro — on SpaceGrotesk-Bold + SpaceGrotesk-SemiBold + JetBrainsMono-Regular + JetBrainsMono-Bold (all registered in Info.plist UIAppFonts)
- **Primitives** in `fitbod/Design/`: BRUButton, BRUChip, BRUCornerBadge, BRUDashedSlot, BRUDisplay, BRUDivider, BRUHeaderBar, BRUPhoneFrame, BRUPillButton, BRUReadout, BRUSectionHead, BRUSpark, BRUSupersetBracket, BRUTabBar, CalibratingProgressMeter, PlateStackViz, PlateTallyRow, SetCompletionGlyph

### Per-Screen Workflow (apply to every screen in Phases B–E)
1. **Inventory** — open `bru-screens/<name>.jsx` and read end-to-end. List every visual section.
2. **Map** — open the iOS target file(s). Identify which sections exist, which are placeholders, which are missing.
3. **Slice** — break into 4–7 verifiable slices, one commit each. Order: header → hero → primary content → secondary content → footer → tab bar.
4. **Implement** — TDD for math/logic; visual-only slices skip unit tests but require simulator verification.
5. **Verify** — capture simulator screenshot. A/B against the mock (Appendix C). Fix obvious discrepancies before moving on.
6. **Commit** — atomic per slice. Convention: `feat(<phase-id>-<screen>): BRU reskin <section>`.
7. **Update this doc** — check the box.

### Critical Patterns (don't re-derive — these were resolved already)
- **TabView pager preservation:** `BlockCard` uses `TabView(.page)` — keep it but wrap with reduced-motion gate (04.1-04 plan, revision iter 1 B4).
- **Real `@Query<Session>` for week carousel:** `BlockOverviewScreen.weekCarousel` binds to real Sessions, no hardcoded mocks (04.1-07 decision, revision iter 1 B5).
- **Drop `BlockPhaseColors.tint(for:)`:** delete or @available-deprecate the legacy method (04.1-08 cleanup, revision iter 1 W6).
- **Per-name colorset enumeration** in foundation guards (revision iter 2 B7) — the on-disk store has 10 colorsets (8 D-01 + bruAmber + bruGreen).
- **Forbidden patterns** (audit re-runs in 04.1-08): no `.form`, no `.list` / `.groupedList` / `.insetGrouped`, no `.system` fonts, no `Color(.systemX)`, no raw `RoundedRectangle` chrome on BRU-skinned surfaces. Full list lives in 04.1-08-PLAN.md audit task.
- **swipeActions exemption:** `Image(systemName: "trash")` is allowed only within 20 lines of `.swipeActions(edge:` in `BlockRow.swift` (04.1-08 proximity rule).

### CLAUDE.md Compliance
- This checklist macro-plans the work. Before doing any code edits, route via `/gsd-quick`, `/gsd-execute-phase`, or `/gsd-plan-phase` per the GSD enforcement clause in CLAUDE.md.
- When a Phase B–E screen is up next, run `/gsd-plan-phase <screen-key>` to materialize a per-screen plan that follows the writing-plans skill format, then `/gsd-execute-phase` to run it.

---

## Phase A — Finish active Phase 04.1 (Periodization BRU re-skin)

**Status:** 8 plans queued, 0 executed. **This phase blocks every Periodization-related mock** (today.jsx block sections, block-overview, block-builder, block-review).

**Reference:** `.planning/phases/04.1-bru-visual-rewrite-periodization-blocks/PLAN-INDEX.md`

**Mocks this completes:** block-overview.jsx (NEW screen), block-builder.jsx (rebuild), block-review.jsx (rebuild), today.jsx block-context-band, routine-builder.jsx block link chip.

**Execution mode:** `/gsd-execute-phase 04.1-bru-visual-rewrite-periodization-blocks` to run all 8 plans in wave order. Each plan is self-contained with TDD verify blocks.

- [ ] **A.0** Pre-flight: read `.planning/phases/04.1-bru-visual-rewrite-periodization-blocks/04.1-CONTEXT.md` and `PLAN-INDEX.md`. Confirm BRU foundation precondition guard passes (per-name colorset enumeration, fonts registered).
- [ ] **A.1** 04.1-01 — Foundation guard + Wave-0 primitives audit (primitives already shipped — should be verify-only)
- [ ] **A.2** 04.1-02 — `BlockPhaseColors` palette flip (Wave 1)
- [ ] **A.3** 04.1-03 — 5 small surfaces: `BlockRow`, `BlockPickerMenu`, `StartBlockCTA`, `DeloadWeekBanner`, `ConsiderDeloadBanner` (Wave 2)
- [ ] **A.4** 04.1-04 — 4 medium surfaces: `BlockCard`, `MesocycleWeekPage`, `BlockPhaseEditorRow`, `RoutinesListView.blocksSection` (Wave 3) — preserve TabView pager + reduced-motion gate
- [ ] **A.5** 04.1-05 — `BlockBuilderView` full rebuild (Wave 4) — `block-builder.jsx` parity target
- [ ] **A.6** 04.1-06 — `BlockReviewView` full rebuild (Wave 5) — `block-review.jsx` parity target
- [ ] **A.7** 04.1-07 — `BlockOverviewScreen` NEW + `BlockCard` tap rewire (Wave 6) — `block-overview.jsx` parity target
- [ ] **A.8** 04.1-08 — Snapshot tests + audit re-run + `tint(for:)` cleanup + ROADMAP write-back (Wave 7)

**Phase A exit criteria:**
- All 13 Phase-4 surfaces match BRU style — `BRUPeriodizationAuditTests` returns 0 forbidden patterns across 25 rules.
- `BlockOverviewScreen` exists and renders real Session data (no mocks).
- ROADMAP Phase 04.1 marked complete with date.
- Simulator A/B check passes for block-overview, block-builder, block-review.

---

## Phase B — Re-skin partial existing screens to BRU (Phase 1 + 2 surfaces)

**Goal:** Bring already-shipped functional screens up to BRU visual parity. These have data wired — we are swapping styling only.

**Approach:** One screen at a time. Each becomes a `/gsd-plan-phase` deliverable.

### B.1 — Settings (`bru-screens/settings.jsx`)
**Target:** `fitbod/Settings/SettingsView.swift` (exists, pre-BRU)
- [ ] B.1.1 Header — replace nav bar with `BRUHeaderBar(left: "‹", center: "Settings", right: "")`
- [ ] B.1.2 Profile slab — avatar (56pt square initial) + `BRUDisplay(.medium)` name "James M." + labelMicro mono metadata "42 SESSIONS · BLOCK 03 · WEEK 3"
- [ ] B.1.3 Section "Units & calibration" — replace `Form` row with `ScrollView` + `BRUSectionHead` + custom rows (label-left bodyDefault, mono-value-right, › on tap)
- [ ] B.1.4 Section "Training defaults" — same row pattern
- [ ] B.1.5 Section "Volume targets" — same row pattern
- [ ] B.1.6 Section "Export" — 2-col grid (CSV / JSON) as `BRUButton(.ghost)` pair
- [ ] B.1.7 Section "About" — backup card (iCloud sync state + CREATE/RESTORE buttons), reset-all row in alarm color
- [ ] B.1.8 `BRUTabBar(active: .settings)` bottom safe-area inset
- [ ] B.1.9 **Verify:** screenshot vs mock; row taps still open underlying pickers; export still triggers existing share flows.
- [ ] B.1.10 **Commit tag:** `feat(b1-settings): BRU reskin Settings screen complete`

### B.2 — Library (`bru-screens/library.jsx`)
**Target:** `fitbod/ExerciseLibrary/ExerciseLibraryView.swift` (exists, pre-BRU)
- [ ] B.2.1 Header — `BRUHeaderBar(left: "‹", center: "Library", right: "+ NEW")`
- [ ] B.2.2 Search bar — replace `.searchable` with custom row: `🔍︎` glyph + text input + mono "8 / 812" count chip
- [ ] B.2.3 Active filter chips row — `BRUChip` with × dismiss handler ("All", "Chest ×", "Barbell ×", "+ Equipment", "+ Pattern", "Custom")
- [ ] B.2.4 Facet quick-stats — 4-col grid (MUSCLE / EQUIP / MECH / PATTERN), each label-over-value `BRUReadout` + chevron
- [ ] B.2.5 Indexed list — section header = `BRUDisplay(.large)` letter ("B"), rows = star fill toggle + name (bodyEmphasis) + muscle/equip/mechanic chip row + mono usage count "247×"
- [ ] B.2.6 Empty-section state ("C — no chest exercises starting with C") bodyDefault muted
- [ ] B.2.7 `BRUTabBar(active: .routines)` (library nests under routines tab — confirm RootView routing)
- [ ] B.2.8 **Verify:** filter chip × removes filter; search counter updates live; star toggle persists; A/B against library.jsx
- [ ] B.2.9 **Commit tag:** `feat(b2-library): BRU reskin ExerciseLibraryView complete`

### B.3 — Exercise Detail (`bru-screens/exercise-detail.jsx`)
**Target:** `fitbod/ExerciseLibrary/ExerciseDetailView.swift` (exists, pre-BRU)
- [ ] B.3.1 Header — `BRUHeaderBar(left: "‹ Library", center: "", right: "EDIT")`
- [ ] B.3.2 Title slab — 3 `BRUChip(.outlined)` (muscle / equipment / mechanic) + `BRUDisplay(.hero)` 48pt name
- [ ] B.3.3 e1RM hero — `bruInk` bg, label "EST. 1 REP MAX" labelMicro mono, `BRUDisplay(.hero)` 72pt "248 LB", 12-week `BRUSpark`, labelMicro baseline "12 WK AGO · 222" → "NOW · 248"
- [ ] B.3.4 Intent split tabs — "ALL · 14 / STRENGTH · 5 / HYPER · 9" (custom tab with active underline + mono count)
- [ ] B.3.5 Session history rows — date + intent chip + PR badge + e1RM mono + top set notation + set-chip row
- [ ] B.3.6 PR footer strip — 3-col grid (TOP WEIGHT 225 / TOP REPS 12 @175 / VOL PR 4,610 signal)
- [ ] B.3.7 **Verify:** sparkline renders; intent tabs filter row list; A/B against exercise-detail.jsx
- [ ] B.3.8 **Commit tag:** `feat(b3-exercise-detail): BRU reskin ExerciseDetailView complete`

### B.4 — Session History (`bru-screens/session-history.jsx`)
**Target:** `fitbod/Sessions/SessionHistoryView.swift` (exists, pre-BRU)
- [ ] B.4.1 Header — `BRUHeaderBar(left: "‹", center: "History", right: "FILTER")`
- [ ] B.4.2 3-col stat strip — `BRUReadout × 3` (Sessions·30d / Tonnage / Adherence) with signal color on Tonnage
- [ ] B.4.3 8-week tonnage spark — bar chart with current week filled `bruSignal` (extend `BRUSpark` if needed)
- [ ] B.4.4 `BRUSectionHead("Past sessions", "14 sessions")`
- [ ] B.4.5 Session row — date + day label + routine name + sets/duration mono + tonnage `BRUDisplay(.medium)` + PR badge or › chevron
- [ ] B.4.6 `BRUTabBar(active: .progress)`
- [ ] B.4.7 **Verify:** rows tap into session detail; A/B against session-history.jsx
- [ ] B.4.8 **Commit tag:** `feat(b4-session-history): BRU reskin SessionHistoryView complete`

### B.5 — Today nav chrome polish (`bru-screens/today.jsx`)
**Target:** `fitbod/Today/TodayView.swift` (partial — prior sessions reskinned StartBlockCTA, FatigueSurfaceView, MuscleVolumeBar)
- [ ] B.5.1 Header — `BRUHeaderBar(left: "Fitbod / Today", center: "", right: "Wed · May 22")` (right is live date, format short)
- [ ] B.5.2 3-col stat strip — `BRUReadout × 3` ("Day streak" / "Sessions" / "W3 / 5") — wire to live streak + W-of-N from active block
- [ ] B.5.3 Block context band — phase chip + week ticker W1–W5 with current cell signal-filled + deload marker (likely lands via Phase A.4 BlockCard reskin)
- [ ] B.5.4 "Start workout ▸" — `BRUButton(.signal, "Start workout ▸")` full-width black slab
- [ ] B.5.5 Lift list — indexed rows (01–05), exercise name (bodyEmphasis), mono set/rep, intent chip
- [ ] B.5.6 `BRUTabBar(active: .today)` (already lands via past session)
- [ ] B.5.7 **Verify:** A/B against today.jsx with active block; "Start workout" navigates; tab bar present
- [ ] B.5.8 **Commit tag:** `feat(b5-today): BRU reskin TodayView nav chrome complete`

### B.6 — Routine Builder (`bru-screens/routine-builder.jsx`)
**Target:** `fitbod/Routines/RoutineBuilderView.swift` (exists, pre-BRU)
- [ ] B.6.1 Header — `BRUHeaderBar(left: "‹ Back", center: "Edit routine", right: "•••")`
- [ ] B.6.2 Title slab — 32pt `BRUDisplay(.large)` name input + 5 `BRUChip` metadata (hypertrophy intent / frequency / duration / block link / autoreg)
- [ ] B.6.3 Day tabs — "PUSH A / PULL A / PUSH B / PULL B / +" with active underline + plus tap to add day
- [ ] B.6.4 Exercise list — indexed (01–04), name (bodyEmphasis) + equipment/intent chip + custom set table (W/UP / WORK / TOP / BACK rows with mono kind+reps+RPE)
- [ ] B.6.5 Superset bracket — `BRUSupersetBracket` for paired exercises (SS indicator)
- [ ] B.6.6 `BRUDashedSlot("+ ADD EXERCISE")` placeholder row
- [ ] B.6.7 Footer — `BRUButton(.ghost, "Discard")` + `BRUButton(.signal, "Save routine ▸")`
- [ ] B.6.8 **Verify:** drag reorder works; day tab switch preserves state; A/B against routine-builder.jsx
- [ ] B.6.9 **Commit tag:** `feat(b6-routine-builder): BRU reskin RoutineBuilderView complete`

**Phase B exit criteria:**
- 6 partial screens visually pass A/B vs mocks
- Grep `fitbod/<tab>/` for `.form`/`.list`/`.groupedList`/`Font.system`/`Color(.system` → 0 hits across the 6 files
- All commits use the convention above

---

## Phase C — Build missing Phase 3 surfaces (set detail, custom exercise, plate calc shell)

### C.1 — Plate Calculator (`bru-screens/plate-calc.jsx`)
**Target:** `fitbod/Settings/PlateCalculatorSheet.swift` (already modified per git status — review first; consider renaming/moving to `fitbod/Today/PlateCalculatorView.swift` if it's not really a Settings concern). Reuses `PlateStackViz` + `PlateTallyRow` already in `Design/`.
- [ ] C.1.1 Decide file location — Settings vs Today vs Routines. Confirm callers in code (`grep -r PlateCalculator`).
- [ ] C.1.2 Header — `BRUHeaderBar(left: "‹ Push A", center: "Plate calculator", right: "•••")`
- [ ] C.1.3 Target display — 96pt `BRUDisplay(.hero)` "205 LB" with mono unit suffix
- [ ] C.1.4 Adjust chips — 4 buttons (−5 / −2.5 / +2.5 / +5) as `BRUChip(.filled)` taps mutating target weight
- [ ] C.1.5 Per-side stack viz — `PlateStackViz` (sleeve + plate stacks + end cap) bound to target weight
- [ ] C.1.6 Bar/inventory 2×1 — Olympic 45lb / Home gym selector cells
- [ ] C.1.7 Plate inventory list — 6 `PlateTallyRow` (weight + tally squares + count label)
- [ ] C.1.8 Footer — `BRUButton(.ghost, "Save inventory")` + `BRUButton(.signal, "Done ▸")`
- [ ] C.1.9 **Verify:** target weight adjust updates stack viz live; tally tap mutates inventory; A/B against plate-calc.jsx
- [ ] C.1.10 **Commit tag:** `feat(c1-plate-calc): BRU plate calculator sheet complete`

### C.2 — Why Weight (`bru-screens/why-weight.jsx`)
**Target:** NEW — `fitbod/Today/WhyWeightView.swift`. Reachable from set-row tap during active session.
- [ ] C.2.1 Verify file does not already exist (`find fitbod -iname "WhyWeight*"`)
- [ ] C.2.2 Create file with `@Observable` ViewModel + `@Query` for last-session lookup
- [ ] C.2.3 Header — `BRUHeaderBar(left: "‹ Push A", center: "Bench · Set 5", right: "EDIT")`
- [ ] C.2.4 Dark hero — `bruInk` bg, mono label "● RECOMMENDED · RPE AUTOREG", 128pt `BRUDisplay(.hero)` "205 LB", 2-row mono "×8" / "@9"
- [ ] C.2.5 "Why this weight" disclosure — 3 steps: step number (`BRUDisplay(.medium)`) + explanation (bodyDefault) + mono formula. Section head right action "−" toggles collapse.
- [ ] C.2.6 Calibration meter — `CalibratingProgressMeter` with "CALIBRATING · 8/10 SETS" label + 80% bar
- [ ] C.2.7 Warm-up ramp — 4 rows (W1–W4): % + weight + reps×RPE + mini stack viz
- [ ] C.2.8 "WORK SETS BEGIN AT 205 LB" mono divider label between warm-up and footer
- [ ] C.2.9 Footer — `BRUButton(.ghost, "Override")` + `BRUButton(.signal, "Use 205 ▸")`
- [ ] C.2.10 **Verify:** disclosure toggles; warm-up renders 4 rows; A/B against why-weight.jsx
- [ ] C.2.11 **Commit tag:** `feat(c2-why-weight): BRU why-weight detail view complete`

### C.3 — Custom Exercise editor (`bru-screens/custom-exercise.jsx`)
**Target:** confirm existence with `find fitbod -iname "CustomExercise*"`. Likely NEW — `fitbod/ExerciseLibrary/CustomExerciseEditorView.swift`. Reachable from Library "+ NEW".
- [ ] C.3.1 Check file existence; if missing, create with `@Observable` form model
- [ ] C.3.2 Header — `BRUHeaderBar(left: "CANCEL", center: "New exercise", right: "SAVE")` — SAVE disabled until valid
- [ ] C.3.3 Name input — 28pt `BRUDisplay(.medium)` editable
- [ ] C.3.4 2×3 classification grid — Equipment / Mechanic / Pattern / Tempo / Bar Wt / Increment cells; each label-over-value with › action to picker
- [ ] C.3.5 Primary muscle list — 2 rows (Lats 1.0 / Traps 0.8) with `BRUChip("PRIMARY")` + weight slider 0.25–1.0 step 0.05
- [ ] C.3.6 Secondary muscle list — 3 rows with `BRUChip("SECONDARY")` + slider
- [ ] C.3.7 `BRUDashedSlot("+ ADD MUSCLE")`
- [ ] C.3.8 Status footer — `bruSignal` bg, "VALID · 2 PRIMARY MAPPED" / "READY TO SAVE"
- [ ] C.3.9 **Verify:** save disabled until ≥1 primary mapped; sliders increment 0.05; A/B against custom-exercise.jsx
- [ ] C.3.10 **Commit tag:** `feat(c3-custom-exercise): BRU custom exercise editor complete`

**Phase C exit criteria:**
- 3 new/rebuilt screens functional and reachable from their entry points (set row tap, Library + NEW)
- All bind to real data (no hardcoded mocks)

---

## Phase D — Build missing Phase 5 surfaces (Fatigue / Volume)

### D.1 — Muscle Heatmap (`bru-screens/heatmap.jsx`)
**Target:** `fitbod/Fatigue/BodySilhouetteView.swift` (partial) + new container view. Body silhouette uses SwiftUI `Canvas` with SVG-derived paths (per CLAUDE.md charting guidance).
- [ ] D.1.1 Header — `BRUHeaderBar(left: "‹", center: "Muscle heatmap", right: "W3 / 5")`
- [ ] D.1.2 Dark hero — `bruInk` bg, mono "● WEEK · SUM STIMULUS" + 42pt `BRUDisplay(.large)` "85 SETS" + footer "8 muscles · 4 in MAV · 2 alerts"
- [ ] D.1.3 Front body grid — `Canvas` with derived SVG paths; 14–16 rect regions colored by set-count threshold (bruSignal / bruAmber / bruGreen / bruFaint)
- [ ] D.1.4 Back body grid — same; horizontal swipe between front/back
- [ ] D.1.5 `BRUSectionHead("By muscle", "TAP TO DRILL")`
- [ ] D.1.6 8-row muscle list — name + set count (`BRUDisplay(.medium)`) + freq mono "3/wk" + state chip ("NEAR MRV — DELOAD" / "IN MAV · ADD A SET" etc.) colored by threshold band
- [ ] D.1.7 `BRUTabBar(active: .progress)`
- [ ] D.1.8 **Verify:** body grid colors match `@Query<SessionExercise>` weekly aggregates; muscle row tap navigates to volume.jsx (D.2); A/B against heatmap.jsx
- [ ] D.1.9 **Commit tag:** `feat(d1-heatmap): BRU muscle heatmap complete`

### D.2 — Volume per muscle (`bru-screens/volume.jsx`)
**Target:** consider renaming `fitbod/Fatigue/PerMuscleDetailView.swift` (partial) → `VolumePerMuscleView.swift`, or create new.
- [ ] D.2.1 Decide rename or new file; update callers
- [ ] D.2.2 Header — `BRUHeaderBar(left: "‹", center: "Volume · W3", right: "•••")`
- [ ] D.2.3 Dark hero — mono "● WORKING SETS · 7 DAYS" + 56pt `BRUDisplay(.hero)` "85" + right "VS LAST WK" mono + "+12" `BRUDisplay(.medium)` signal
- [ ] D.2.4 Legend chip row — 3 `BRUChip` (UNDER MEV / MEV→MAV / MRV) colored by band
- [ ] D.2.5 8 muscle bar rows — name + current count (`BRUDisplay(.medium)`) + horizontal bar with MEV/MAV/MRV ruleMarks + verb chip (ADD A SET / HOLD / NEAR MRV — DELOAD) + mono threshold label "MEV 8 · MAV 18 · MRV 22"
- [ ] D.2.6 `BRUTabBar(active: .progress)`
- [ ] D.2.7 **Verify:** bar fill width = current / MRV; verb chip color matches band; A/B against volume.jsx
- [ ] D.2.8 **Commit tag:** `feat(d2-volume): BRU volume per muscle complete`

### D.3 — Plateau detector (`bru-screens/plateau.jsx`)
**Target:** NEW — `fitbod/Fatigue/PlateauDetectorView.swift`. Reachable from exercise-detail "PLATEAU" badge or from a Today nudge.
- [ ] D.3.1 Create file with `@Observable` model holding stall-detection state
- [ ] D.3.2 Header — `BRUHeaderBar(left: "‹", center: "Plateau · Bench", right: "•••")`
- [ ] D.3.3 Signal banner — `bruSignal` band, "▲ STALL DETECTED" mono + 36pt `BRUDisplay(.large)` "e1RM flat 4 sessions" + body description
- [ ] D.3.4 e1RM trend sparkline — `BRUSpark` 8 sessions + mono window label "APR 18 → MAY 22"
- [ ] D.3.5 `BRUSectionHead("Suggested actions", "PICK ONE")`
- [ ] D.3.6 4 action rows — numbered `BRUDisplay(.medium)` 01–04 + label (bodyEmphasis) + mono spec + body why + RECOMMENDED `BRUChip` on top + APPLY `BRUChip` per row
- [ ] D.3.7 Threshold tune row — "± 2% · 3 sessions" with TUNE action
- [ ] D.3.8 Footer — `BRUButton(.ghost, "Dismiss")` + `BRUButton(.signal, "Apply drop ▸")`
- [ ] D.3.9 **Verify:** APPLY chip shows selection state; A/B against plateau.jsx
- [ ] D.3.10 **Commit tag:** `feat(d3-plateau): BRU plateau detector complete`

**Phase D exit criteria:**
- 3 fatigue surfaces functional and reachable from Progress tab
- All bound to real `@Query<SessionExercise>` aggregates (no mocks)
- Cross-screen taps wired (heatmap → volume, plateau → routine-builder for adjustment)

---

## Phase E — Build missing Phase 6 surfaces (recap, progress chart, settings polish)

### E.1 — Weekly Recap (`bru-screens/weekly-recap.jsx`)
**Target:** NEW — `fitbod/Progress/WeeklyRecapView.swift`. Surfaces post-Friday session or via Progress tab.
- [ ] E.1.1 Create file with `@Observable` model aggregating week stats
- [ ] E.1.2 Header — `BRUHeaderBar(left: "‹", center: "Week 3 · recap", right: "SHARE")`
- [ ] E.1.3 Dark cover — `bruInk` bg, mono "MAY 15 → MAY 21 · INTENSIFICATION" + 68pt `BRUDisplay(.hero)` "A strong week." + 3 chips (★ 3 PRs / 4/4 sessions / 21,510 lb)
- [ ] E.1.4 2×2 metric grid — TONNAGE / WORKING SETS / AVG RPE / MUSCLES HIT, each `BRUReadout`
- [ ] E.1.5 Records broken section — `BRUSectionHead("Records broken", "3")` + 3 PR rows (exercise + type chip + value + signal highlight)
- [ ] E.1.6 Under-trained muscles — `bruAmber` bullet list with MEV thresholds
- [ ] E.1.7 Session note quote — body italic + mono date "WED MAY 17"
- [ ] E.1.8 Footer — `BRUButton(.ghost, "All recaps")` + `BRUButton(.signal, "Start W4 ▸")`
- [ ] E.1.9 **Verify:** stats bind to real week aggregates; A/B against weekly-recap.jsx
- [ ] E.1.10 **Commit tag:** `feat(e1-weekly-recap): BRU weekly recap complete`

### E.2 — Progress chart (`bru-screens/progress-chart.jsx`)
**Target:** `fitbod/Progress/ExerciseProgressView.swift` (partial — chart rendering present but pre-BRU)
- [ ] E.2.1 Header — `BRUHeaderBar(left: "‹", center: "Bench · Progress", right: "EXPORT")`
- [ ] E.2.2 Hero — 60pt `BRUDisplay(.hero)` "248 LB" + right `BRUChip(.filled, "+ 36 LB")` signal
- [ ] E.2.3 Series toggle — 4 tabs (e1RM / TOP SET / VOLUME / AVG RPE) with active chip background
- [ ] E.2.4 Swift Charts — Y 200–260, X W1–W12; hypertrophy = `AreaMark` filled, strength = `LineMark` dashed + `PointMark` circles, PR `PointMark` at 248; axis labels mono
- [ ] E.2.5 Legend strip — mono "HYPERTROPHY · 9 SESSIONS" / "STRENGTH · 5 SESSIONS"
- [ ] E.2.6 `BRUSectionHead("Personal records", "ALL TIME")`
- [ ] E.2.7 5 PR rows — type / value / delta / when label
- [ ] E.2.8 `BRUTabBar(active: .progress)`
- [ ] E.2.9 **Verify:** series toggle swaps chart data; A/B against progress-chart.jsx
- [ ] E.2.10 **Commit tag:** `feat(e2-progress-chart): BRU exercise progress chart complete`

**Phase E exit criteria:**
- Weekly recap reachable (Progress tab or post-session sheet)
- Progress chart reachable from exercise detail PROGRESS chip
- All Phase E screens pass A/B vs mocks

---

## Phase F — Wire-up, integration, polish

- [ ] **F.1** Navigation graph audit — confirm every cross-screen tap from mocks works:
  - today.jsx "Start workout" → active session view
  - today.jsx lift row tap → exercise detail
  - block-overview.jsx ‹ → routines list
  - routine-builder.jsx "+ ADD EXERCISE" → library picker
  - library.jsx exercise row → exercise-detail
  - exercise-detail.jsx PROGRESS chip → progress-chart
  - settings.jsx EXPORT → file share sheet
  - heatmap.jsx muscle row → volume (filtered)
  - volume.jsx muscle bar → exercise list filtered to that muscle
  - plateau.jsx APPLY action → routine-builder with adjustment pre-applied
- [ ] **F.2** Replace any remaining hardcoded mock data — grep `fitbod/` for `"sample"`, `"mock"`, `TODO`, `placeholder`. Wire to `@Query`.
- [ ] **F.3** Run all BRU audit tests — `BRUPeriodizationAuditTests`, `BRUGrepAuditPhase6Tests`, equivalents — 0 forbidden patterns.
- [ ] **F.4** Snapshot test pass — for the 17 mock-matched screens, add `*SnapshotTests.swift` (skip if outside current milestone scope; document the skip).
- [ ] **F.5** Accessibility audit — VoiceOver pass-through on every interactive element; reduced-motion gates verified on `TabView(.page)` (BlockCard) and any animated sparklines.
- [ ] **F.6** ROADMAP.md update — mark Phases 04.1, B, C, D, E complete with dates.
- [ ] **F.7** Memory update — write a project memory noting BRU rollout complete, supersede `project_bru_design_system_unimplemented.md`.

---

## Appendix A — Mock-to-iOS file map

| Mock file | iOS target | Phase | Status |
|-----------|------------|-------|--------|
| today.jsx | `fitbod/Today/TodayView.swift` | B.5 + A (block sections) | Partial |
| block-overview.jsx | `fitbod/Periodization/BlockOverviewScreen.swift` **(NEW)** | A.7 | Missing |
| block-builder.jsx | `fitbod/Periodization/BlockBuilderView.swift` | A.5 | Pre-BRU |
| block-review.jsx | `fitbod/Periodization/BlockReviewView.swift` | A.6 | Pre-BRU |
| weekly-recap.jsx | `fitbod/Progress/WeeklyRecapView.swift` **(NEW)** | E.1 | Missing |
| plateau.jsx | `fitbod/Fatigue/PlateauDetectorView.swift` **(NEW)** | D.3 | Missing |
| progress-chart.jsx | `fitbod/Progress/ExerciseProgressView.swift` | E.2 | Partial |
| heatmap.jsx | `fitbod/Fatigue/BodySilhouetteView.swift` + container | D.1 | Partial |
| session-history.jsx | `fitbod/Sessions/SessionHistoryView.swift` | B.4 | Partial |
| routine-builder.jsx | `fitbod/Routines/RoutineBuilderView.swift` | B.6 | Partial |
| exercise-detail.jsx | `fitbod/ExerciseLibrary/ExerciseDetailView.swift` | B.3 | Partial |
| custom-exercise.jsx | `fitbod/ExerciseLibrary/CustomExerciseEditorView.swift` (verify; likely NEW) | C.3 | Unknown |
| plate-calc.jsx | `fitbod/Settings/PlateCalculatorSheet.swift` (or move to `Today/`) | C.1 | Partial |
| volume.jsx | `fitbod/Fatigue/VolumePerMuscleView.swift` (rename or NEW) | D.2 | Partial |
| why-weight.jsx | `fitbod/Today/WhyWeightView.swift` **(NEW)** | C.2 | Missing |
| settings.jsx | `fitbod/Settings/SettingsView.swift` | B.1 | Partial |
| library.jsx | `fitbod/ExerciseLibrary/ExerciseLibraryView.swift` | B.2 | Partial |

---

## Appendix B — Primitive lookup (reach for these first)

| Need | Primitive |
|------|-----------|
| Top nav bar | `BRUHeaderBar(left:, center:, right:)` |
| Big number stat | `BRUDisplay(.hero / .large / .medium)` |
| Label-over-value cell | `BRUReadout(label:, value:)` |
| Section title row | `BRUSectionHead(title:, action:)` |
| Tag / pill (rect, sharp corners) | `BRUChip(.outlined / .filled, label:)` |
| Primary CTA | `BRUButton(.signal, label:)` |
| Ghost CTA | `BRUButton(.ghost, label:)` |
| Pill button | `BRUPillButton(label:)` |
| Empty-state slot | `BRUDashedSlot(label:)` |
| Hair divider (1pt) | `BRUDivider(.hair)` |
| Hard divider (2pt) | `BRUDivider(.ink)` |
| Top-right tag on a card | `BRUCornerBadge(label:)` |
| Bottom tab nav | `BRUTabBar(active:)` |
| Sparkline | `BRUSpark(values:)` |
| Superset bracket | `BRUSupersetBracket()` |
| Set complete glyph | `SetCompletionGlyph(state:)` |
| Plate stack viz | `PlateStackViz(weight:, perSide:)` |
| Plate tally row | `PlateTallyRow(weight:, count:)` |
| Calibration meter | `CalibratingProgressMeter(progress:)` |
| Phone-frame preview wrap | `BRUPhoneFrame { ... }` |

Fonts: `BRUFont.displayHero`, `.displayLarge`, `.displayMedium`, `.bodyEmphasis`, `.bodyDefault`, `.labelSmall`, `.labelMicro`.

Colors: `Color.bruInk`, `.bruPaper`, `.bruSignal`, `.bruFaint`, `.bruHair`, `.bruMuted`, `.bruBg`, `.bruBg2`, `.bruAmber`, `.bruGreen`.

---

## Appendix C — Per-screen verification protocol

For every screen in Phases B / C / D / E:

1. **Pre-build:** open `bru-screens/<name>.jsx`. Read in full. Note every distinct visual element.
2. **Build:** implement the slices in order. Commit after each.
3. **Capture:** boot simulator, navigate to screen.
   ```bash
   xcrun simctl io booted screenshot ~/Desktop/<screen>-actual.png
   ```
4. **A/B compare:** open mock JSX in a browser at 375×812 viewport; stack actual screenshot beside it. Walk through these 12 dimensions:
   1. Header chrome (height, divider, left/center/right slot styling)
   2. Hero typography (weight, size, line height)
   3. Color tokens (bruInk vs raw black, bruSignal vs raw yellow, etc.)
   4. Section header style (caps, weight, right action)
   5. List row padding + divider treatment
   6. Button states (signal vs ghost, fill, border)
   7. Chip outlines + corner radius (must be sharp / 0pt)
   8. Tab bar position + active indicator
   9. Mono font usage (axis labels, dates, counts)
   10. Spacing rhythm (8/16/24 grid)
   11. Empty / loading / error states
   12. Tab bar safe-area inset
5. **Fix:** address each discrepancy with file:line precision.
6. **Re-screenshot:** confirm fix.
7. **Commit polish:** `polish(<screen>): A/B parity adjustments`.

**If the build is broken or simulator unavailable: state that explicitly. Do NOT claim success without visual verification.**

---

## Appendix D — Useful references

- `MEMORY.md` entries:
  - `project_bru_design_system_unimplemented.md` — note: this memory is now superseded (BRU primitives are shipped). Update after Phase F completes.
  - `project_extension_infoplist_not_in_resources.md` — pbxproj wiring gotcha when adding new files
  - `project_sourcekit_stale_widget_diagnostics.md` — trust xcodebuild, not Xcode IDE phantom errors
- `.planning/phases/04.1-bru-visual-rewrite-periodization-blocks/PLAN-INDEX.md` — current Periodization re-skin context
- `.planning/ROADMAP.md` — overall project status
- `.planning/v1.0-MILESTONE-AUDIT.md` — milestone-level requirements
- `CLAUDE.md` — stack/conventions, GSD enforcement clause

---

## Appendix E — Bridging this checklist into GSD plans

This doc is the macro roadmap. **Do not** execute Phase B–E screens as one giant GSD plan — context-isolate each screen.

When a screen is up next:
1. `/gsd-plan-phase b<#>-<screen>` (e.g., `/gsd-plan-phase b1-settings`)
2. Plan agent reads this checklist's per-screen section, expands each slice into a writing-plans-style task with file paths + code blocks + verify commands.
3. `/gsd-execute-phase b<#>-<screen>` to run via wave runner with TDD checkpoints.
4. After verification + commit, check the box(es) in this doc and move to the next screen.

For Phase A, just `/gsd-execute-phase 04.1-bru-visual-rewrite-periodization-blocks` — plans already exist.

---

**Last updated:** 2026-05-24 by Claude (initial write)
**Next focus:** Phase A.0 (pre-flight) → A.1..A.8 sequential `/gsd-execute-phase 04.1-bru-visual-rewrite-periodization-blocks`
