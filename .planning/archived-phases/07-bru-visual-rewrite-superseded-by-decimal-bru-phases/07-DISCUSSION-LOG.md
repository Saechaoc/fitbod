# Phase 7: BRU Visual Rewrite (Final) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `07-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-05-23
**Phase:** 07-bru-visual-rewrite
**Areas discussed:** Scope, UI-REVIEW prerequisite, Foundation dependency, Fidelity bar, Phase 1 audit, Wave structure, Regression bar

---

## Pre-discussion observation

Phase 7 ROADMAP entry was a stub ("Goal: [To be planned]" / "Requirements: TBD" / "Depends on: Phase 6"). Sibling pattern: `02.1-bru-visual-rewrite/` ships 1 plan (foundation), `04.1-bru-visual-rewrite-periodization-blocks/` is empty stub. Existing UI artifacts inventoried:

- UI-SPEC + UI-REVIEW: Phases 2, 3, 4
- UI-SPEC only: Phases 1, 3.1, 5, 6
- `bru-screens/` mockups: 17 JSX files covering all 6 functional phases

Memory note loaded: "BRU is locked in 02-UI-SPEC.md but never shipped; phases 2-6 use Apple HIG defaults. UI-SPECs were retroactive design contracts."

Hypothesis going into discussion: Phase 7 = catch-all final BRU rewrite for whatever isn't covered by 02.1/04.1.

---

## Area 1 — Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Phase 5 surfaces | Fatigue surface, volume bars, body silhouette heatmap, per-muscle detail, plateau badges, deload advisory, weekly recap, MuscleVolumeTargetEditor. bru-screens: heatmap.jsx, volume.jsx, plateau.jsx, weekly-recap.jsx. | ✓ |
| Phase 6 surfaces | ProgressHomeView, ExerciseProgressView (charts), ExercisePRsView, SessionComparisonView, WeeklyTonnageView, InSessionPRBanner, Settings Data section. bru-screens: progress-chart.jsx, settings.jsx. | ✓ |
| Phase 3 surfaces | WhyThisWeightSheet, PlateStackViz, PlateCalcSheet, CalibratingMeter, BumpBanner, PlateInventoryEditor, WarmupRampRows. 03-UI-REVIEW exists (10/24). bru-screens: why-weight.jsx, plate-calc.jsx. | ✓ |
| Phase 1 surfaces | ExerciseLibrary, ExerciseDetailView, CustomExerciseForm. Library is highest-traffic surface. bru-screens: library.jsx, exercise-detail.jsx, custom-exercise.jsx. | ✓ |

**User's choice:** ALL four — Phase 7 absorbs every functional phase whose surfaces don't already belong to an X.1 rewrite phase.
**Notes:** This is a large scope but matches the "final BRU rewrite" framing. Phase 2 and Phase 4 BRU work stays in 02.1 / 04.1 (sequential dependency, not absorption). The user accepted the complexity rather than fragmenting into more X.1 phases.

---

## Area 2 — UI-REVIEW prerequisite

| Option | Description | Selected |
|--------|-------------|----------|
| Run `/gsd-ui-review 5` and `/gsd-ui-review 6` first, then plan | Generate audit scoring + per-pillar findings + Wave A-G migration backlog before planning. Mirrors how 02.1 and 04.1 sourced their plan backlogs. Cleanest, but adds 2 extra commands. | ✓ |
| Include audit as Wave 0 of Phase 7 | Phase 7 plan-01 = audit phases 5+6 against their UI-SPECs, produce UI-REVIEW.md files inline; subsequent waves consume them. Compresses into one workflow. | |
| Skip audit — use UI-SPEC + bru-screens directly | Plan straight from the locked UI-SPEC contracts and JSX mockups. Faster but no per-file gap inventory; planner must enumerate violations itself from grep. | |

**User's choice:** Audit-first via separate `/gsd-ui-review` runs.
**Notes:** Aligns with 02.1 / 04.1 precedent. Per-pillar scoring + Top 3 Priority Fixes + concrete `file:line` gap lists are the right input to planning. Plan-checker should hard-block on missing UI-REVIEWs per block.

---

## Area 3 — Foundation dependency

| Option | Description | Selected |
|--------|-------------|----------|
| Hard depend on Phase 02.1 | Phase 7 ROADMAP entry adds "Depends on: Phase 02.1" (and 04.1 if in scope). Phase 7 plans assume Color.bruInk / BRUFont / BRUChip / BRUHeaderBar etc. exist. Cleanest dep graph; matches existing 02.1 plan-01 ownership. | ✓ |
| Foundation-first wave, then independent | Phase 7 Wave A re-checks foundation exists; if 02.1 hasn't executed yet, Phase 7 ships it. Independent but risks duplicate foundation work. | |
| Phase 7 owns the foundation outright | Move foundation ownership from 02.1 to 7 (since Phase 7 is the catch-all). Renumber 02.1 to consume Phase 7's foundation. Bigger refactor. | |

**User's choice:** Hard depend on 02.1.
**Notes:** 02.1-01-PLAN.md already exists and ships foundation. Reordering ownership would be churn. The 15+ BRU primitives (not yet in any 02.1 plan beyond the foundation) need to land before Phase 7 surfaces can compose against them — flagged as a 02.1 follow-up plan that must be written and executed before Phase 7 begins.

---

## Area 4 — Fidelity bar to bru-screens

| Option | Description | Selected |
|--------|-------------|----------|
| Visual contract — token-strict, layout-faithful | Match bru-screens line-for-line on tokens (colors, fonts, spacing, no rounding, no SF Symbols, UPPERCASE labels) AND composition (header bands, grids, tick rows). Swift Charts / Canvas internals use BRU tokens but can use native chart marks rather than JSX-emulated divs. | ✓ |
| Pixel-near — emulate JSX visual structure exactly | Reproduce JSX visual structure verbatim including any non-standard chart visuals (e.g., custom Canvas bars instead of BarMark). Highest fidelity, most work, fights Swift Charts. | |
| Loose — BRU tokens only, native SwiftUI/Charts idioms preferred | Apply BRU palette + typography + sharp borders + no-rounding rule, but allow SwiftUI-native chart layouts and adaptive spacing. Fastest, lowest visual rigor. | |

**User's choice:** Token-strict + layout-faithful.
**Notes:** Right balance — preserves Swift Charts performance and idiom while enforcing the brutalist visual contract. `BarMark`/`LineMark`/`PointMark` get BRU-skinned, axes get BRU-styled, but they don't get re-implemented in Canvas. Heatmap stays Canvas (already the right tool per PROJECT.md "Charting Decision").

---

## Area 5 — Phase 1 audit (follow-up)

| Option | Description | Selected |
|--------|-------------|----------|
| Run `/gsd-ui-review 1` as well | Same treatment as 5 and 6 — produce audit-scored gap list before planning. Consistent across all 4 in-scope phases. Adds 1 more command. | ✓ |
| Use the existing 01-UI-SPEC + bru-screens directly | 01-UI-SPEC already locks Library / ExerciseDetail / CustomExercise BRU contract. Skip audit, let planner enumerate gaps. Faster but no per-pillar score. | |
| Drop Phase 1 from scope | Reverse the scope decision — leave Phase 1 surfaces on Apple HIG. Library is high-traffic but functional; rewrite later if needed. | |

**User's choice:** Run `/gsd-ui-review 1` too.
**Notes:** Consistency across the 4 blocks. All 4 source phases get the same audit treatment + scored gap lists.

---

## Area 6 — Wave structure (follow-up)

| Option | Description | Selected |
|--------|-------------|----------|
| Per-phase blocks: Phase 1 plans → Phase 3 plans → Phase 5 plans → Phase 6 plans | One sub-block per source phase. Each block = its own Wave A (audit purge) → Wave B (surfaces) → Wave C (snapshot tests + grep audit). Easier to ship + verify incrementally; aligns with how UI-REVIEWs are scoped. | ✓ |
| Per-pillar across all phases: Color purge → Type purge → Primitive swap → Layout rewrites | Sweep across all 30 screens by pillar. Foundation purge first, then all type swaps, etc. Maximizes parallelism per pillar but harder to ship partial value. | |
| Per-screen waves — each screen is its own plan | 30 plans, one per screen. Maximum atomic commits + reviewability. Heaviest planning overhead. | |

**User's choice:** Per-phase blocks (Block A = Phase 1, Block B = Phase 3, Block C = Phase 5, Block D = Phase 6).
**Notes:** Each block ships partial value (a fully BRU-styled functional phase) before the next block starts. Lower regression-bar risk. Aligns 1:1 with UI-REVIEW inputs per block.

---

## Area 7 — Regression bar (follow-up)

| Option | Description | Selected |
|--------|-------------|----------|
| Hard regression bar | Every Phase 7 plan must keep all prior unit + UI tests GREEN. Each plan adds new snapshot/contract tests for the BRU primitive (e.g., 'Color.bruInk resolves', 'WhyThisWeightSheet renders ink slab'). Matches 02.1-01 pattern (BRUFoundationsTests). | ✓ |
| Soft — functional tests green, UI tests may need updates | Functional unit tests (services, math, persistence) stay GREEN. Existing UI tests (XCUI) may be rewritten/replaced as surfaces change. Acknowledge UI tests are coupled to current Apple HIG component tree. | |
| No regression bar — ship new UI, retest after | Focus on visual rewrite; defer test repair to a follow-up. Fastest but defers verification debt. | |

**User's choice:** Hard regression bar.
**Notes:** All prior tests must stay GREEN. UI tests get updated as part of each surface plan, not deferred. Snapshot tests deferred (brittle); structural/contract tests preferred.

---

## Claude's Discretion (deferred to planner)

- Per-block plan splitting (one per surface vs cohesive pairs)
- Plan-internal wave ordering (audit-then-implement vs implement-then-verify)
- Snapshot test framework choice (recommended: structural assertions, defer `swift-snapshot-testing`)
- Whether to extract a shared `BRUChartStyle.swift` / `BRUAxisLabels.swift` module for chart skinning
- Order of Phase 5 surfaces within Block C (zone colorsets first, then bars, then heatmap, then drill-downs)
- Wave Z grep allowed-exception list specifics
- `accessibilityIdentifier` naming convention for BRU primitives
- Whether `BodySilhouetteView` refactor introduces a `BRUCanvasStyle` helper

---

## Deferred Ideas

- Phase 2 surfaces (02.1 territory)
- Phase 4 surfaces (04.1 territory)
- Launch screen / app icon / marketing screens / onboarding tour
- Watch app / widgets BRU
- Live Activity BRU restyling
- `swift-snapshot-testing` SPM dep
- iCloud / CloudKit sync
- Apple HIG fallback toggle / theme switcher
- Library grid layout alternative
- Cross-block parallelization
- Automatic dark-mode preview screenshots
- Reverting Phase 7 (no rollback hatch)

---

*Discussion conducted 2026-05-23 via /gsd-discuss-phase 7 default mode.*
