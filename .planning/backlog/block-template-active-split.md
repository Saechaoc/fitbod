---
status: backlog
created: 2026-05-28
origin_spec: .planning/quick/training-block-spec/spec.md
related_quick: 260528-cby-fix-new-block-screen-blockbuilderview-sw (UI delta — landed)
related_quick_next: TBD (UI-only restructure for presets section + Blank + CTA copy)
risk: high
scope: multi-phase
estimated_waves: 4–6
schema_migration: V6 → V7 (additive + entity split)
---

# Backlog: Block Template / Active / Attachment Split

## Why this is backlogged

The training-block spec (`.planning/quick/training-block-spec/spec.md`) asks for a clean three-entity split:

- `TrainingBlockTemplate` — reusable structure (no start date, no routines, no current week)
- `ActiveTrainingBlock` — an instance of a template that the user has started (has start date, current week, status, attached routines)
- `RoutineBlockAttachment` — connects a routine to an active block instance (not the template)

This is an architectural change, not a UI cleanup. The current `Block` SwiftData entity conflates all three concepts: it holds phases (template-y), `startDate` + `isActive` (instance-y), and a `routines` back-reference (attachment-y).

Splitting it touches: the SwiftData schema (V6 → V7 migration), `BlockBuilderView`, every Today-tab surface that reads "current block week / phase" (`MesocycleWeekContext`, `MesocycleWeekPage`, `DeloadWeekBanner`, `ConsiderDeloadBanner`, `BlockCard`, `BlockRow`, `BlockOverviewScreen`), the `Routine` model's back-reference, `PeriodizationEngine.advance`, the Program tab list, and probably the Phase 6 progress views that filter by active block. This is multi-day phase work, not a quick task.

## What's still pending (post 260528-cby UI work)

### Architectural

1. **New SwiftData entities** — `TrainingBlockTemplate`, `ActiveTrainingBlock`, `RoutineBlockAttachment`. Each is a separate `@Model` with its own primary key and relationships per the spec's data model section.
2. **Schema migration V6 → V7** — additive entity adds + a custom `MigrationStage.migrateV6toV7` that maps every existing `Block` row into a `TrainingBlockTemplate` + (if `isActive == true`) an `ActiveTrainingBlock` snapshot + (for each `routines` back-reference) a `RoutineBlockAttachment` row. The migration must preserve existing per-block state so currently-active users don't lose their week-1-of-5 progress.
3. **`saveIfValid` semantics change** — saving a template no longer activates it. The `isActive = true` line in `BlockBuilderView.saveIfValid` is removed; activation moves to the new Start Block flow's `START BLOCK` CTA.
4. **Routine→Block rewire** — the existing `Routine.block` relationship targets `TrainingBlockTemplate` (which is wrong per the spec — routines should attach to the active instance via `RoutineBlockAttachment`, not the reusable template). Rewriting this is a model-and-call-site refactor across `RoutineBuilder`, `SessionLogger`, and any volume/intensity multiplier consumer.
5. **PeriodizationEngine + advisory surfaces rewire** — `PeriodizationEngine.advance`, `DeloadAdvisor`, `MesocycleWeekContext`, and the Today-tab deload banners currently read `Block.currentWeek` / `Block.phases[currentWeek]`. After the split they read `ActiveTrainingBlock.currentWeek` joined to `TrainingBlockTemplate.phases`. Pure refactor with model dot-path swaps + one new join.

### UX

6. **Start Block flow (new screen)** — `StartBlockView` with: selected template summary (read-only template name + total weeks + days per week + phase preview), start-date picker, attached-routine list + Attach/Change/Remove actions, training-schedule confirmation (days per week + weekday selection), `START BLOCK` primary CTA. New `NavigationDestination` route from Program tab `+` action.
7. **Routine UI shows active-block context** — when a routine has an active `RoutineBlockAttachment`, the routine list row + detail view show "Attached to: {template name} • Week N of M • Current phase: {phase} • Vol +X% • Int Y%". This is a read-side surface that depends on the entity split.
8. **Preset templates populate phases/multipliers** — the spec asks that selecting a preset chip populate not just the name but also total weeks, days per week, the full phase list with volume + intensity multipliers. Today only `Hypertrophy Meso` has concrete values (5 weeks, 4 days, Accum 2w +20%/70% / Inten 2w hold/85% / Deload 1w -50%/60%); `Linear Strength`, `Powerbuilding`, `Off-Season`, `Pre-Meet` need real lifter-defined values before they can be wired up. This is a content/product decision, not implementation.
9. **CTA disabled state: `FIX PHASES ↑`** — requires phase-validity logic that doesn't exist today (every phase always has a name via `BlockPhaseKind` enum; no way to be "invalid"). Either add per-phase free-form names (model change) or define a different invariant (e.g., a phase with `weeks == 0`).
10. **CTA disabled state: `CHECK WEEKS ↑`** — requires decoupling `totalWeeks` from the sum of phase weeks. Today `BlockDraft.totalWeeks` is a computed property that returns the sum, so the two can never mismatch. Decoupling means making `totalWeeks` an editable stored field + validating the sum separately.

## Suggested phase shape (when this gets picked up)

```
/gsd-phase add 7 "Training Block Template/Active Split"
  → adds Phase 7 to ROADMAP (likely under a new v1.1 milestone — v1.0 is currently 100% complete)

/gsd-discuss-phase 7
  → CONTEXT.md locks decisions:
    - Block → split into 3 entities vs. rename + add 2 sister entities?
    - V7 migration: best-effort lossless mapping, or one-time "you'll re-create your active block" prompt?
    - Routine.block: nullable foreign key, or removed entirely in favor of RoutineBlockAttachment lookups?
    - Start Block flow: full-screen sheet vs. push from Program tab?
    - Preset-phase values: ship Hypertrophy Meso only, or wait for all 5 preset definitions?

/gsd-plan-phase 7
  → PLAN with ~4–6 waves:
    Wave 0  SchemaV7 + 3 new entities + RED migration test scaffold
    Wave 1  migrateV6toV7 implementation + 8–10 round-trip migration tests
    Wave 2  New Block UI strict-template restructure (saveIfValid no longer activates; CTA copy)
    Wave 3  Start Block screen + Program-tab nav rewire
    Wave 4  Routine model / RoutineBlockAttachment rewire (Routine.block → attachment lookup)
    Wave 5  Today tab + PeriodizationEngine + DeloadAdvisor + advisory banners rewire
    Wave 6  (optional) Preset-content fill — Linear Strength / Powerbuilding / Off-Season / Pre-Meet phase definitions

/gsd-execute-phase 7
  → multi-hour execution, atomic commits per wave
```

## Acceptance criteria when picked up

Lifted from the spec, frozen here for whoever schedules this:

- Saving a block from the New Block screen creates a `TrainingBlockTemplate` and does **not** create an `ActiveTrainingBlock`.
- The Start Block screen is the only path that creates an `ActiveTrainingBlock` row.
- A `Routine` attached via the Start Block flow gets its volume + intensity adjustments from the `ActiveTrainingBlock`'s current phase, never from the template.
- Editing a `TrainingBlockTemplate` does **not** retroactively rewrite the phase configuration of any `ActiveTrainingBlock` already started from it.
- The schema migration V6 → V7 is lossless for at least the `isActive == true` block + its `routines` back-reference.
- All Phase 1–6 + Phase 04.1 regression suites remain GREEN after the rewire.

## Pointer files (read these first)

- `.planning/quick/training-block-spec/spec.md` — authoritative spec
- `fitbod/Periodization/Block.swift` (or wherever the `@Model Block` lives — likely in `BlockDraft.swift` or `BlockPhaseDraft.swift`'s neighborhood)
- `fitbod/Periodization/BlockBuilderView.swift` — the screen this whole stream targets
- `fitbod/Periodization/PeriodizationEngine.swift` — `advance(...)` consumer of `Block.currentWeek`
- `fitbod/Sessions/SessionExerciseCard.swift` — reads block phase volume/intensity multipliers for prescription
- `.planning/STATE.md` — confirm milestone state before scheduling (v1.0 is marked 100% complete; this work likely starts a v1.1)
