# Phase 8: Scheduler Resolver & Block Lifecycle - Context

**Gathered:** 2026-06-11
**Status:** Ready for planning
**Mode:** Spec-derived (autonomous) — grey areas resolved in `.planning/quick/training-block-spec/program-graph-spec.md` (two adversarial review rounds). Spec wins on any disagreement with this file.

<domain>
## Phase Boundary

The engine layer on top of Phase 7's schema: today-session resolution from the block graph, block lifecycle transactions (start/end/swap), service-layer guards, and the archive write. No new screens — TodayView gets re-wired to the resolver; everything else UI-visible is Phase 9.

In scope: resolver (rotation + fixedWeekly), derived-status consumers, one-save start/end/swap, conditional deny enforcement (SplitDeletionGuard wiring), ArchivedBlockConfig write + decode-error surfacing contract, trainingDays sort-at-write, SessionFactory migration off the legacy `template.block` edge.

Out of scope: ProgramView rebuild, SplitDetailView, BlockOverviewScreen modes, builder band, live-edit banners (Phase 9); per-phase routine overrides, Progress charts (v2+).

</domain>

<decisions>
## Implementation Decisions

All locked by spec (§ refs to program-graph-spec.md):

### Resolver (§5)
- **Unified rotation predicate:** latest **completed** session in this block whose `slot` is non-nil AND `slot.split == block.split` → next slot = `(slot.position + 1) % slotCount` against current positions; no matching session → slot 0. Ad-hoc (nil slot), deleted-slot (nullified → reads ad-hoc), swapped-split sessions, and abandoned in-progress workouts all fall out of the scan identically. Tests assert the predicate, not enumerated cases.
- **Zero-slot guard:** resolver runs only when `slotCount >= 1`. Ready gate makes empty-at-start unrepresentable; mid-block-emptied split short-circuits to a "fix-it" resolution result (Phase 9 renders the surface; Phase 8 returns a distinguishable case — e.g. enum `TodayResolution { session(SplitSessionSlot), restDay, emptySplit, noBlock }`).
- **fixedWeekly:** today's weekday ∈ `trainingDays` (stored order canonical) → slot at `index(of: weekday in trainingDays as stored) % slotCount`; absent → rest day. Missed day = skipped, not shifted. Mod is the runtime guard for mid-block slot-count drift.
- **trainingDays sort-at-write:** the SERVICE sorts once via the user's `Calendar.firstWeekday` when writing trainingDays (Block accessor stores verbatim — Phase 7 decision). Region change later must NOT remap days to slots.

### Lifecycle (§4)
- **Start** (status == ready): `isActive = true`, `startDate = .now`. If another block active → the swap is ONE save: current.endDate + current.archivedConfigJSON + new.isActive/startDate atomically. No zero-or-two-actives window. (Confirm UI affordance in Phase 9; Phase 8 ships the service function + tests.)
- **End:** endDate + archive write in one save.
- **Split swap/attach gated to draft/ready** — service refuses on active (changing the split IS ending the block).
- **Split archive/delete conditional deny:** refuse while any non-completed block references the split. `SplitDeletionGuard` (exists from 07 review fix, with 5 passing tests) is the seam — wire it as THE enforcement point for both delete and archive paths.
- Status stays derived (Phase 7 `Block.derivedStatus`); transition-site assertions: `isActive ⇒ split != nil ∧ endDate == nil`.

### Archive (§6)
- `ArchivedBlockConfig` type + decoder shipped in 07. Phase 8 ships the WRITE: serialize at end-block inside the same save (block name, dates, mode, trainingDays, full phase mirror, split name, position-ordered slots with session names + full prescription mirrors, `"v": 1`).
- Decode failure → explicit error case surfaced to callers ("Archive unreadable"); never a live-template fallback. Phase 8 defines the typed error; Phase 9 renders it.

### Phase 7 carry-overs (MUST address)
- **CR-02 legacy edge:** `SessionTemplate.block` + `Block.legacyTemplates` (nullify inverse) survive only because `SessionFactory.swift:165,275` resolves the scheduled `BlockPhase` (volume/intensity multipliers) through `template.block`. Phase 8 must migrate SessionFactory to resolve the CURRENT BlockPhase from the ACTIVE block (via `Session.block` / the resolver context), not through the template. After migration, the legacy edge becomes write-orphaned: leave the field in place (removal = V8 migration, defer; document as deprecated) but nothing should read it for prescription resolution.
- **Stubs to replace:** `TodayView.todaysRoutine` (returns nil — wire to resolver), `MesocycleWeekPage.scheduledSlots` (empty — wire if cheap, else explicit Phase 9 deferral note), `BlockOverviewScreen` membership checks (already use `session.slot?.split?.id == block.split?.id` with TODO comments — confirm or refine).
- 3 device-only UAT items from Phase 7 remain deferred (not Phase 8 scope).

### Claude's Discretion
- Resolver/service file placement (suggest `fitbod/Periodization/` or `fitbod/Scheduling/` co-located with Block code), naming (`TodayResolver`, `BlockLifecycleService` or similar), whether resolution returns slot or (slot, sessionTemplate) pairs.
- Locale test mechanics (inject Calendar into the sort-at-write service for testability).

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 7 graph: `Split` (+`blocks` inverse), `SplitSessionSlot` (+`sessions` nullify inverse), `Block.split/schedulingMode/trainingDays/archivedConfigJSON/derivedStatus`, `Session.slot/template/templateName`, `ArchivedBlockConfig` DTO + decoder, `SplitDeletionGuard` + tests, `SchedulingMode` enum.
- `SessionFactory` — the snapshot-at-start seam; its `start(template:)` is where resolver output meets session creation. Also `SessionFactory.active(in:)` for the in-progress check (resume-state wins the CTA — resolver must consider only completed sessions).
- `BlockPeriodizedStrategy` (fitbod/Prescription/) — consumes block phase context; verify it resolves via active block, not template.block.
- Migration-test fixture patterns: `SchemaV7MigrationTests` combined-schema container; `@MainActor` + `.serialized`.

### Established Patterns
- Services as small structs/enums with static funcs or injected-dependency structs (SessionFactory precedent); clock/calendar injection as closure or value (`now: () -> Date` precedent from RestTimerEngine — D-2 Phase 2).
- One-save transactions: mutate then single `try ctx.save()`.
- Swift Testing, exclusive simulator use, xcodebuild output filtered.

### Integration Points
- `TodayView.swift` — `todaysRoutine` computed property + `dayIndexInBlock`/`totalDaysInBlock`; `BlockContextBand`, `BlackSlabCTA`, `StartBlockCTA`, rest-day empty state all stay.
- `BlockBuilderView.saveIfValid()` — currently saves draft with `isActive = false`; start flow lives elsewhere (service).
- 17 pre-existing UI-suite failures + 10 pre-existing unit failures (FatigueSurfaceViewBRUTests 4, SessionLoggerBRUCopyTests 4, PrescriptionEditorBlockCaseFilterTests 1, TodayViewBlockStackingTests 1) are status-quo baseline — do not chase them, do not worsen them.

</code_context>

<specifics>
## Specific Ideas

- Resolver output should be an exhaustive enum so Phase 9 surfaces map 1:1 to cases (session/restDay/emptySplit/noBlock + maybe archiveUnreadable for DONE-block reads).
- Tests per spec §9 Phase-8 slice: unified predicate across skip/repeat/reorder/ad-hoc/deleted-slot/swapped-split/abandoned-in-progress; fixedWeekly rest days, count drift, mid-block-emptied; locale test pinning canonical stored order across a simulated region change; one-save handover atomicity (crash-window assertion via no-save-between states); conditional-deny service tests (deny while draft/ready/active block references; allow when only completed).
- `dayIndexInBlock` math in TodayView predates the graph — keep behavior unless the spec contradicts it.

</specifics>

<deferred>
## Deferred Ideas

- All Phase 9 surfaces; legacy-edge field removal (V8); per-phase routine overrides; Progress-over-archives (v2+); device UAT items.

</deferred>
