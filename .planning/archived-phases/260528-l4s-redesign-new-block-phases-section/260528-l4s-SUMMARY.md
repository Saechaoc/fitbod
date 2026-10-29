---
status: complete
quick_id: 260528-l4s
date: 2026-05-28
---

# Quick Task 260528-l4s — New Block Phases section redesign

**Scope (user chose "everything"):** full visual redesign + List refactor + gestures, all in
`fitbod/Periodization/BlockBuilderView.swift` (+ one test assertion). SwiftUI/BRU.

## Result
- **BUILD SUCCEEDED + TEST SUCCEEDED** on iPhone 17 simulator (Swift 6 strict concurrency).
- Guard suites green: NewBlockBuilderFidelityTests, BlockBuilderViewCopyTests, BlockBuilderViewActivationTests.
- Executed as 6 atomic commits across 4 chunked sequential executors (single file → no parallelism).

## Commits (base: bbfc78b — a concurrent fast task shifted the base off c5b692e; linear, no conflict)
| SHA | Decision | What |
|-----|----------|------|
| `15cb5d9` | D1 | Local 5-slot ordered phase palette (index-keyed); same color on timeline segment + card number chip; deload solid muted; `NewBlockDeloadStripes` retired |
| `c7fe46b` | D4 | Lighter timeline (no 1.5pt ink box), cumulative W{n} boundary ticks, narrow-segment label drop |
| `97661b3` | D3+D2 | Cards decluttered (boxes→hair dividers) + inline-editable Weeks/Vol/Int steppers; signed-% Volume w/ Hold@0; baseline legend |
| `c2c1d2b` | D5+D6 | Header stateful `Preset: {Custom\|name} ▾` Menu (routes existing Apply Preset? confirm); single full-width bottom `+ ADD PHASE` → add-phase type picker (4 kinds, swatches); deleted the one `↘ PRESETS` test assertion |
| `cb88325` | D7a | Body → SwiftUI `List(.plain)` with pinned PHASES section header; bottom action bar kept as ZStack overlay + 104pt clear-spacer clearance |
| `faa2677` | D7b | `.onMove` reorder via EditMode toggle in pinned header (native handle; decorative `⋮⋮` removed); `.swipeActions` delete + "Phase deleted · UNDO" toast (`@MainActor Task.sleep(4s)`, prior-task cancel, `isCancelled` guard) |

## The two key decisions (as requested)

**1. Phase color scheme** — a New-Block-LOCAL ordered palette keyed by phase **order index** (not kind),
5 muted BRU-faithful slots cycling on `index % 5`:

| Slot | Color | On-color label |
|------|-------|----------------|
| 0 | ink (10,10,10) | white |
| 1 | signal coral (255,77,46) | white |
| 2 | ink @ 55% | white |
| 3 | ink @ 30% | ink |
| 4 | slate companion (90,87,80) | white |

Deload always renders a solid warm-gray (`muted`), never a slot, never hatching. The two Accumulations land
on different slots → distinguishable. The same color paints the timeline segment AND the card's filled number
chip, so a segment maps to its card at a glance. Color is **always** paired with the `01/02` number + phase
name (never color-alone) → colorblind-safe. The public `BlockPhaseColors` (used by 5 other screens) was left
untouched — the palette is fileprivate to the New Block screen.

**2. Volume metric convention** — **signed % vs base volume**: `+20%` / `-15%`, with exactly-base rendered as
`Hold`; Intensity stays a plain `%` (% of training max). A one-line legend states the baseline:
`VOL Δ vs base · INT % of training max`. This replaces the old `HOLD`/`-15%` mix and makes the reference explicit.

## ⚠️ Flags for your review (deferred)
1. **Volume "Hold@0"** (your guidance) partially re-creates the "HOLD vs −15%" mix that brief #3 wanted gone.
   Trivial to switch the zero case to `0%` for pure signed-% consistency — say the word.
2. **Weeks is now editable in two places**: inline on each card (this task) AND via the `Edit Block Duration`
   sheet (last task, opened by tapping TOTAL WEEKS). Redundant — consider dropping the sheet.
3. **Timeline sum-vs-total "mismatch" is impossible**: `totalWeeks` is the computed sum of phase weeks, so no
   divergence warning was built (documented no-op; empty/0-week states are already gated by `draft.isValid`).
4. **Reorder uses an edit-mode toggle** (`.onMove`), not always-on drag (`.draggable`/`.dropDestination`) — the
   latter was deferred as "more work" per your note.

## Needs your eyes (xcodebuild proves it compiles + source guards pass — NOT visual/interaction fidelity)
Run on iPhone 17 (`cmd+R`) → New Block:
- Phase colors: two Accumulations visibly different; each timeline segment matches its card's number chip; deload solid (no stripes).
- Timeline: lighter than the title; W{n} ticks at boundaries; labels drop on narrow segments.
- Cards: no boxes; Weeks/Vol/Int adjust via −/+; Volume reads +X%/−X%/Hold; legend present.
- Header: `Preset: Custom ▾` opens a menu; picking one shows "Apply Preset?" confirm; header pins on scroll.
- Bottom `+ ADD PHASE` (full width) opens the 4-kind type picker with swatches.
- Tap REORDER → drag to reorder; swipe a card left → Delete → "Phase deleted · UNDO" toast; UNDO restores it.
