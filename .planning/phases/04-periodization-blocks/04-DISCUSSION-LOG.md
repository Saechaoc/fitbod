# Phase 4: Periodization & Blocks - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-22
**Phase:** 4-periodization-blocks
**Mode:** `--power max` (27 questions across 8 sections; offline answering via `04-QUESTIONS.html`)
**Areas discussed:** Block Builder UX · Block Timeline & Home · Phase Multipliers & Deload Mechanics · PeriodizationEngine & Strategies · Routine ↔ Block Linkage · Phase-End Review · Fatigue-Triggered Deload Advisory · Schema Evolution

---

## Block Builder UX (BLOCK-01)

### Q-01: Block builder screen layout

| Option | Description | Selected |
|--------|-------------|----------|
| Single-screen builder (RoutineBuilderView precedent) | Block name + start date top, ordered phase list below with inline editors, drag-handle reorder, @Observable BlockDraft + three-way merge | ✓ |
| Two-step modal (Create → Edit Phases) | Sheet 1 = metadata, Sheet 2 = phase list. Slower flow, clearer separation. Breaks Phase 2 precedent. | |
| Form-style screen with disclosure rows per phase | iOS Settings-style List with DisclosureGroup per phase. Lower-density than Phase 2 builder. | |

**User's choice:** a — Single-screen builder
**Rationale:** Phase 2 established the precedent; reusing it keeps the codebase coherent.

### Q-02: Where do blocks live in navigation?

| Option | Description | Selected |
|--------|-------------|----------|
| Routines tab — top section above routine folders | Add "Blocks" section above folders. No new tab. | ✓ |
| New "Plan" tab | Promote periodization to a top-level surface. | |
| Today tab — secondary disclosure under active block card | Block list lives nested under Today. | |
| Settings tab — under "Periodization" section | Cleanest if "set and forget" but under-promoted. | |

**User's choice:** a — Routines tab
**Rationale:** Adding a tab is heavier than needed; blocks and routines are tightly coupled conceptually.

### Q-03: Block templates / quick-start

| Option | Description | Selected |
|--------|-------------|----------|
| 2-3 stock templates (Generic Strength, Hypertrophy Meso, Powerlifting Peak) + Blank | "+ Block" menu shows templates + "Blank" | ✓ |
| Blank only | User defines every phase. Aligned with transparent-over-magic but more friction. | |
| One stock template + Blank | Lightweight onboarding without committing to a library. | |

**User's choice:** a — 2-3 stock templates
**Rationale:** Fastest path to a usable block; matches what serious lifters expect.

### Q-04: Phase reorder + add/remove rules

| Option | Description | Selected |
|--------|-------------|----------|
| No constraints — user is in charge | Any sequence allowed | ✓ |
| Soft warnings — flag unusual orderings | Non-blocking advisory | |
| Hard validation — deload terminal, only one realization | Block can't save invalid sequence | |

**User's choice:** a — No constraints
**Rationale:** Transparent over magic; user is the discipline, not the app.

### Q-05: Multi-active vs single-active blocks

| Option | Description | Selected |
|--------|-------------|----------|
| Single active block at a time | Activating X deactivates all others | ✓ |
| Multiple concurrent active blocks | Each routine has its own block context | |
| Single active block; routines outside it use Phase 3 strategies only | Clean partition | |

**User's choice:** a — Single active block
**Rationale:** Matches RP/RTS convention of running one meso at a time; avoids "which deload is this week" ambiguity.

---

## Block Timeline & Home Screen (BLOCK-02, BLOCK-03)

### Q-06: Active block card placement on Today tab

| Option | Description | Selected |
|--------|-------------|----------|
| Above ResumeWorkoutBanner | Block card is topmost when active | ✓ |
| Replaces empty state; ResumeBanner stays on top | Less visual weight | |
| Compact strip above tab bar (always visible) | Invades all tabs | |

**User's choice:** a — Above ResumeWorkoutBanner
**Rationale:** Live mesocycle outranks "resume in-progress session" as the framing for the day.

### Q-07: Phase color coding

| Option | Description | Selected |
|--------|-------------|----------|
| Heat-map progression — teal/amber/orange/gray | Visual intensity matches training intensity; deload reads as rest | ✓ |
| Semantic categorical — blue/purple/red/green | No progression metaphor, just clear categorization | |
| Monochrome with accent on current phase | Minimal palette | |

**User's choice:** a — Heat-map
**Rationale:** Visual intensity matches training intensity; accumulation reuses existing accent token.

### Q-08: Mesocycle week navigation gesture

| Option | Description | Selected |
|--------|-------------|----------|
| Horizontal swipe on block card (TabView + PageTabViewStyle) | Each page = one week, inline | ✓ |
| Dedicated mesocycle screen via tap | More screen real estate but extra tap | |
| Calendar-style month view | Better overview but denser, more design work | |

**User's choice:** a — Horizontal swipe on the block card
**Rationale:** Familiar iOS pattern; no extra tap to reach mesocycle context.

### Q-09: What "Week N of M" counts

| Option | Description | Selected |
|--------|-------------|----------|
| Linear block week (Week 5 of 8) | Simple counter spanning the entire block | ✓ |
| Per-phase week (Week 2 of 4 in Accumulation) | Resets at phase boundaries | |
| Both — "Week 2/4 (Accumulation) · Week 5/8 overall" | Dual readout, busiest | |

**User's choice:** a — Linear block week
**Rationale:** Simpler mental model; phase chip already carries "which phase" signal.

---

## Phase Multipliers & Deload Mechanics (BLOCK-04, BLOCK-05)

### Q-10: Default multipliers per phase

| Option | Description | Selected |
|--------|-------------|----------|
| RP-style defaults (research-confirmed) | Accum 1.0/0.75 · Intens 0.85/0.88 · Realiz 0.6/0.97 · Deload 0.5/0.75 | ✓ |
| Conservative (everything 1.0 except deload) | All 1.0/1.0 except deload | |
| RTS-style with steeper realization | Accum 1.0/0.7 · Realiz 0.4/1.0 (heavy singles) | |

**User's choice:** a — RP-style defaults
**Rationale:** RP-published values are the strongest published baseline; user can tune from there. Researcher confirms at plan-phase.

### Q-11: How multipliers apply to prescription

| Option | Description | Selected |
|--------|-------------|----------|
| Multiplicative against routine baseline (sets × prescribedWeight) | Simplest, no schema change | ✓ |
| Multiplicative against e1RM (intensity = % of 1RM) | Requires e1RM tracking inline | |
| Multiplicative against ProgressionStrategy's output | Block as wrapper strategy | |

**User's choice:** a — Multiplicative against routine baseline
**Rationale:** No Phase 6 e1RM dependency; Phase 4 stays self-contained.

### Q-12: Volume-multiplier semantics for sets

| Option | Description | Selected |
|--------|-------------|----------|
| Halve working sets, keep reps and weight | 3×8 @ 100kg → 2×8 @ 100kg | ✓ |
| Halve both sets and weight | 3×8 @ 100kg → 2×8 @ 75kg | |
| Keep sets, halve reps | 3×8 → 3×4 same weight | |

**User's choice:** a — Halve working sets, keep weight
**Rationale:** RP "load taper" pattern; clear cut without weight drop confusing the prescription.

### Q-13: Deload week visual treatment

| Option | Description | Selected |
|--------|-------------|----------|
| Banner on Today + tinted block card | Top banner + ambient tint | ✓ |
| Modal alert at session start | One-time modal, higher friction | |
| Subtle chip + greyed prescriptions | Less intrusive | |

**User's choice:** a — Banner + tinted block card
**Rationale:** Banner unmissable; tint ambient. Both honored without modal interruption.

---

## PeriodizationEngine & Strategies (PRES-05, PRES-06)

### Q-14: PeriodizationEngine API shape

| Option | Description | Selected |
|--------|-------------|----------|
| Static facade: `PeriodizationEngine.phase(for:on:)` | Pure function, testable without ModelContainer | ✓ |
| Method on Block itself: `block.phase(on:)` | Couples model to logic | |
| Resolved by SessionFactory, passed as context | Snapshot pattern extended | |

**User's choice:** a — Static facade
**Rationale:** Matches Phase 3's pure-function strategy pattern (FOUND-07).

### Q-15: Where do new strategies live?

| Option | Description | Selected |
|--------|-------------|----------|
| Same directory: fitbod/Prescription/ | All 4 strategies + engine together | ✓ |
| New directory: fitbod/Periodization/ for all block-aware code | Block math separated from prescription math | |
| Hybrid — strategies in Prescription/, engine + UI in Periodization/ | "Algorithm vs feature" split | |

**User's choice:** a — Same directory
**Rationale:** All 4 strategies + engine in one directory is more discoverable. (CONTEXT.md D-15a clarifies: block-feature UI surfaces still live in `fitbod/Periodization/`; only engine + strategies stay in Prescription/.)

### Q-16: Hybrid strategy formula

| Option | Description | Selected |
|--------|-------------|----------|
| Block sets ceiling; RPE pulls down: target = min(blockTarget, rpeTarget) | Conservative — autoregulates only downward | ✓ |
| Weighted average: 0.6 × blockTarget + 0.4 × rpeTarget | Smooth, responsive, user-tunable | |
| Block target with RPE-bounded ±5% window | Block-dominant with safety valve | |

**User's choice:** a — min(blockTarget, rpeTarget)
**Rationale:** Avoids "RPE says I'm fresh, push past planned phase intensity" failure mode. Block schedule remains canonical (BLOCK-08 spirit).

### Q-17: Block-periodized strategy when no calibration data

| Option | Description | Selected |
|--------|-------------|----------|
| Fall back to RoutineExercise.prescribedWeight | User-entered baseline | ✓ |
| Estimate 1RM from last logged set | Reuses Phase 3 e1RM helper | |
| Show "Set baseline" UI prompt blocking session start | Explicit but adds friction | |

**User's choice:** a — Routine baseline
**Rationale:** No Phase 6 e1RM dependency; routine creation already lets user enter a realistic baseline.

---

## Routine ↔ Block Linkage

### Q-18: Routine-to-block assignment UX

| Option | Description | Selected |
|--------|-------------|----------|
| Picker in RoutineBuilderView header | "Block: None ▾" menu at top | ✓ |
| From BlockBuilderView side ("Add Routine to Block") | Routine doesn't know it's in a block until viewed in BlockBuilder | |
| Both — symmetric | Most flexible, more UI surface | |

**User's choice:** a — Picker in RoutineBuilderView header
**Rationale:** Discoverable; user sets block context while building the routine.

### Q-19: Routines outside a block

| Option | Description | Selected |
|--------|-------------|----------|
| Disallow .block / .hybrid progression unless in block | Picker hides those cases when routine.block == nil | ✓ |
| Allow but degrade gracefully (multiplier 1.0 / fall back to RPEAutoreg) | No UI restriction | |
| Allow + show warning | Inline transparency | |

**User's choice:** a — Disallow when no block
**Rationale:** Prevents degenerate prescription state where `.block` strategy is selected but no block context exists.

### Q-20: Session inherits block at start

| Option | Description | Selected |
|--------|-------------|----------|
| Snapshot routine.block onto Session.block at session start | Matches snapshot pattern (PITFALLS #1) | ✓ |
| Session.block stays nil; resolve at query time | Less data, slight indirection | |
| Snapshot block + active BlockPhase ID too | Heaviest snapshot, most historically accurate | |

**User's choice:** a — Snapshot block
**Rationale:** Honors snapshot pattern; makes block-filtered history queries trivial in Phase 6.

---

## Phase-End Review (BLOCK-07)

### Q-21: When does the phase-end review surface?

| Option | Description | Selected |
|--------|-------------|----------|
| End of block only (single review when block.endDate passes) | One comprehensive review per block | ✓ |
| End of each phase (4 reviews per block) | More granular, more interruption | |
| Manual — "View Block Review" button, no auto-surface | User opts in | |

**User's choice:** a — End of block only
**Rationale:** One review per block; not interrupting every phase transition.

### Q-22: Metrics shown in phase-end review

| Option | Description | Selected |
|--------|-------------|----------|
| Scaffold all 4 sections, placeholders for Phase 5/6 deliverables | Visual contract solid for downstream | ✓ |
| Defer review to Phase 5 — "block complete" acknowledgment only | Smaller Phase 4 scope | |
| Inline computations only — sets, tonnage, sessions, days | Honest scope, useful but limited | |

**User's choice:** a — Scaffold all 4 sections
**Rationale:** Phase 4 honors BLOCK-07 with a real, useful review on the data it has; Phase 6 fills the PR slot without restructuring.

### Q-23: "Recommended next phase" source

| Option | Description | Selected |
|--------|-------------|----------|
| Static rules (after deload → accumulation, after realization → deload) | Deterministic, transparent | ✓ |
| Block template-based ("Repeat the block template") | User-driven, not auto-suggested | |
| Defer to v1.x — show only "Block complete" | No prescriptive next step | |

**User's choice:** a — Static rules
**Rationale:** Matches RP convention. No "smart" recommendation engine in v1.

---

## Fatigue-Triggered Deload Advisory (BLOCK-06, BLOCK-08)

### Q-24: Phase 4's scope on BLOCK-06

| Option | Description | Selected |
|--------|-------------|----------|
| UI scaffold only — Banner component + stubbed signal | Phase 5 fills real signal without touching UI | ✓ |
| Full UX + simple rule-based advisory ("5 sessions in 5 days") | Working from Phase 4 onward | |
| Defer entirely to Phase 5 — Phase 4 only closes BLOCK-08 | Cleaner phase separation | |

**User's choice:** a — UI scaffold + stubbed signal
**Rationale:** UI contract locks now; Phase 5 fills `FatigueAdvisory.shouldSuggest()` with real signal.

### Q-25: Canonicality enforcement (BLOCK-08)

| Option | Description | Selected |
|--------|-------------|----------|
| Type-level — FatigueAdvisory returns only Suggestion, never DeloadMutation | Compile-time safety; single writer | ✓ |
| Runtime guard — every setter checks source: DeloadSource enum | Less compile-time safety | |
| Tested invariant — unit test locks the contract | Belt-and-suspenders | |

**User's choice:** a — Type-level
**Rationale:** BLOCK-08 becomes impossible to violate accidentally — compiler refuses.

---

## Schema Evolution

### Q-26: New schema fields needed

| Option | Description | Selected |
|--------|-------------|----------|
| None — Phase 1 schema is sufficient | All Phase 4 data computed at read time | ✓ |
| Add SessionContext fields to Session (active BlockPhase ID) | Better historical accuracy, lightweight migration | |
| Add BlockReview entity (caches phase-end totals) | Materialized view, lightweight migration | |

**User's choice:** a — No new fields (note: one minor exception emerged from Q-21 — `Block.reviewedAt: Date?`)
**Rationale:** Most conservative path. The single review-tracking field is small enough to fit lightweight migration.

### Q-27: Migration timing

| Option | Description | Selected |
|--------|-------------|----------|
| Bundle Phase 4 fields into SchemaV3 (during Phase 3) | Saves a migration step | ✓ |
| SchemaV4 in Phase 4 — own migration cycle | Cleaner phase boundary | |
| No new schema — confirmed by Q-26 | Moot if Q-26 selected (a) | |

**User's choice:** a — Bundle into SchemaV3
**Rationale:** Phase 3 is the next migration anyway; adding `Block.reviewedAt: Date?` (the one exception from D-26) costs ~10 minutes. Planner verifies Phase 3 hasn't sealed SchemaV3; if it has, fall back to SchemaV4.

---

## Claude's Discretion

Locked decisions deferred to UI-SPEC / planner per CONTEXT.md "Claude's Discretion" section:
- Exact heat-map color hex values for intensification (`#F59E0B`?) and realization (`#EA580C`?)
- Modal vs sheet form factor for `BlockReviewView` (recommend `.sheet(isPresented:)` `.large` detent)
- Block card swipe-pager dot indicators on/off (recommend off)
- Verbatim copy for deload banner, canonicality contract, next-phase recommendation
- `BlockTemplates.swift` storage shape (static Swift literal recommended over JSON resource)
- Whether `BlockDraft.blockID` is wired via RoutineDraft extension or new picker param

## Deferred Ideas

Noted for future phases (full list in CONTEXT.md `<deferred>` section):
- Per-day routine assignment within mesocycle — v1.x
- Multiple concurrent active blocks — future feature once single-active proven
- Real fatigue/plateau signal — Phase 5
- Block-aware progress charting — Phase 6
- PRs / volume aggregation in BlockReviewView — Phases 5 + 6 fill placeholders
- Block templates marketplace / shareable mesos — out of scope (no social features)
- "Smart" next-phase recommendation engine — future version
- Block carryover — out of scope
- Per-phase-kind warm-up scaling beyond deload — future
- Block-aware intent overrides — out of scope
- Adherence tracking (% sessions completed) — Phase 5 or 6
