# Phase 9: Program Surfaces - Context

**Gathered:** 2026-06-11
**Status:** Ready for planning
**Mode:** Spec-derived (autonomous) — `.planning/quick/training-block-spec/program-graph-spec.md` §1 §5 §8 is the contract; spec wins on disagreement.

<domain>
## Phase Boundary

The program graph becomes visible and operable: ProgramView rebuilt (BLOCKS + ROUTINES sections, preserved empty state), new SplitDetailView, BlockOverviewScreen live + archived modes, block-builder split band, live-edit banners, Today empty-split fix-it surface. Pure UI/wiring over Phase 7 schema + Phase 8 services — no new engine logic, no schema change.

Out of scope: per-phase routine overrides, Progress-over-archives, top-level session-template library (v2+), legacy-edge field removal (V8).

</domain>

<decisions>
## Implementation Decisions

All locked by spec §8 (+ §1 glossary, §5 edge surfaces):

### UI terminology (§1 — pinned by user)
- UI "Session" = code `SessionTemplate`. UI "Routine" = code `Split`. UI "Block" = `Block`. Never leak code names into UI copy.

### ProgramView rebuild (§8)
- Empty state (current template design — protected by 3 copy-guardrail suites) ONLY when zero blocks AND zero splits. Otherwise two flat sections:
- **BLOCKS** — status-badged cards from `Block.derivedStatus` (ACTIVE / READY / DRAFT / DONE). Active card shows week + phase progress. DONE: 3 most recent + collapse ("ALL HISTORY" disclosure). Tap → BlockOverviewScreen. "+ NEW BLOCK" keeps the existing choice/template/builder flow untouched.
- **ROUTINES** — rows "Upper / Lower · 4 sessions" + usage tags listing **non-completed** blocks only (live edges only). Tap → SplitDetailView. "+ NEW ROUTINE" → name + compose.
- No top-level session-template list — templates live inside split detail + slot picker.

### SplitDetailView (new, §8)
- Ordered slot list, drag-reorder with **reindex-on-write** (positions contiguous — test invariant from Phase 7), add slot via picker over all SessionTemplates or "new session" → existing builder (RoutineBuilderView), remove slot, usage section (non-completed blocks).
- Live-edit banner when the split sits on the active block (reorder is schedule-affecting).
- Delete/archive actions route through `BlockLifecycleService.assertSplitDeletable` (conditional deny — Phase 8 seam, MUST be the enforcement point). Split archive = UI-level delete (archive-only from UI).

### BlockOverviewScreen modes (§8)
- Live modes (draft/ready/active): split attach/swap (draft/ready ONLY — hidden on active), mode picker, trainingDays day-chips (fixedWeekly; soft mismatch hint "5 days / 4 sessions"; writes via `TrainingDaysWriter.sort`), Start CTA (ready), End action (active).
- Start while another block active → confirm sheet ("Ends *{current}* — its config freezes to history") → `BlockLifecycleService.start` (one-save swap already implemented).
- Archived mode (completed): rendered from `BlockLifecycleService.decodeArchive`; attach/swap/mode/Start hidden; decode failure → explicit "Archive unreadable" error state (typed `ArchiveUnreadableError` exists), never live-template fallback.

### Block builder split band (§8)
- Existing conditional linked-routines band becomes: ONE split picker + mode picker + day-chips. Optional — save without = draft. Any New Block edit → run all 3 copy-guardrail suites.

### Session template editor + Today (§5, §8)
- Live-edit banner in template editor when template reachable via slots → split → active block: "Part of active block — edits apply to upcoming workouts." Non-blocking.
- TodayView `.emptySplit`: replace Phase 8's minimal copy with the real fix-it pointer navigating to SplitDetailView ("Routine has no sessions"). Rest-day branch copy untouched (pinned).

### Phase 8 service contracts (consume, don't reimplement)
- `TodayResolver.resolve` → TodayResolution{session(slot)/restDay/emptySplit/noBlock}.
- `BlockLifecycleService.{start,end,attachSplit,swapSplit,assertSplitDeletable,decodeArchive}` + `BlockLifecycleError`/`ArchiveUnreadableError`.
- `TrainingDaysWriter.sort(weekdays:using:)` — the ONLY way trainingDays get written.
- `SessionFactory.start(template:slot:activeBlock:...)` — Today already wired.

### Claude's Discretion
- BRU component composition for new surfaces (reuse BRUHeaderBar, BRUSectionHead, BRURow, BRUDivider, BRUActionPopover, BlockCard, etc.), exact badge styling, collapse animation, day-chip layout.
- Drag-reorder implementation (note: New Block phase cards already shipped a hysteresis-gated row-local drag — reuse that pattern, NOT List .onMove, unless List fits BRU styling).

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- BRU design system fully shipped (Color+BRU, BRUFont, primitives across Phases 2.1–06.1). `BRUActionPopover` (now tracked). `BlockCard`, `BlockRow`, `BlockPickerMenu`, `StartBlockCTA`, `BlockContextBand`, `MesocycleWeekPage` (already split-wired), `BlockReviewView`.
- ProgramView currently: always-empty-state + ProgramTemplateSection + NewBlockStartChoiceSheet/PresetPickerSheet + RoutineBuilderView sheet + active-session conflict alert — all preserved; the rebuild ADDS the two list sections and the conditional empty-state gate.
- `RoutineBuilderView` = the "Session" (template) builder; `BlockBuilderView` = New Block screen (hotspot, ~960 lines, guardrail-pinned copy).
- Drag-reorder precedent: New Block phase cards (hysteresis-gated, row-local drag state, boundary-crossing updates — June 10 perf work).

### Established Patterns
- @Query directly in views, predicates composed in #Predicate (but NO multi-level optional chains — post-filter in Swift).
- One NavigationStack per tab; ProgramView owns its stack.
- Copy-guardrail suites: 3 source-introspection suites pin BlockBuilderView struct names + copy verbatim — run all 3 on ANY New Block edit. Never rename pinned SwiftUI structs.
- Device floor: iPhone 15+ — verify layouts at 390–393pt width; flexible over fixed widths.
- Swift Testing for logic; XCTest UI tests exist for Program/New Block flows (NewBlockModalUITests etc.).

### Integration Points
- Tab enum: today/program/progress/settings (RootView custom tab bar, not TabView).
- TodayView `.emptySplit` TODO comment marks the fix-it integration point; navigationPath exists for BlockOverviewRoute — SplitDetail needs a route.
- Baseline test failures: 11 documented pre-existing (do not chase, do not worsen). 2 manual smoke items from Phase 8 fold into this phase's UAT (rotation advance, emptySplit copy → superseded by the real fix-it surface).

</code_context>

<specifics>
## Specific Ideas

- bru-screens/New-block/ and bru-screens/New-modal/ hold design reference PNGs for the New Block surface (already implemented); no Program-page redesign brief exists — derive BLOCKS/ROUTINES section styling from the BRU system + existing section patterns (ProgressHomeView's BRUSectionHead sections are the closest analog). Memory: UI briefs lag committed code — committed source is the truth for current visuals.
- Spec §8 wording for usage tags and DONE collapse is normative; copy strings for NEW surfaces should follow BRU editorial voice (condensed uppercase labels) but are NOT pinned until written — once written, add guardrail-style copy tests only if cheap.

</specifics>

<deferred>
## Deferred Ideas

- Per-phase routine overrides; Progress charts over archives; top-level session-template library; V8 legacy-edge removal; device UAT items (Phase 7's 3 + any new) collected for end-of-run report.

</deferred>
