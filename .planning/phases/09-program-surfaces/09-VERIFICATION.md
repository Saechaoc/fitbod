---
phase: 09-program-surfaces
verified: 2026-06-11T22:06:37Z
status: human_needed
score: 36/36 must-haves verified
overrides_applied: 0
human_verification:
  - test: "DONE-blocks collapse animation: with >3 completed blocks, tap 'ALL HISTORY ▸' and watch the remaining DONE cards reveal."
    expected: "Remaining DONE cards expand smoothly (withAnimation), the 'ALL HISTORY ▸' disclosure row disappears, no layout jump."
    why_human: "Animation timing/feel and absence of layout jank are visual; grep confirms showAllDone state + prefix(3) logic but not the rendered animation."
  - test: "SplitDetailView slot reorder feel: in a routine with 3+ sessions, use the up/down move controls to reorder slots."
    expected: "Slots visibly reorder, positions stay contiguous 1..N after each move, the single ctx.save() persists across re-open. (Implementation is up/down move buttons, NOT List drag — BRU no-chrome contract, see SplitDetailView.swift:19.)"
    why_human: "Reindex contiguity is unit-tested (reorderKeepsPositionsContiguous), but the interactive move-control feel and visual reordering require a running app."
  - test: "390pt overflow check on Program tab + SplitDetailView + BlockOverviewScreen at iPhone 15/16/17 base width (390-393pt)."
    expected: "BLOCKS status-badged cards, ROUTINES rows with usage tag chips, SplitDetailView slot rows, and BlockOverviewScreen day-chip grid all fit without horizontal clipping or truncation at the 390pt device floor."
    why_human: "Per MEMORY device-support-floor note — flexible-vs-fixed-width overflow must be checked visually at the narrow device floor, not just 17 Pro Max."
  - test: "Rotation-advance device smoke (carried from Phase 8): on a fixedWeekly active block, log a session, advance the day, confirm TodayView resolves the next slot; on a rotation block confirm next slot = (lastSlot+1) % slotCount."
    expected: "TodayView shows the correct next session per the §5 resolver; empty-split short-circuits to the 'ROUTINE HAS NO SESSIONS' fix-it surface."
    why_human: "Resolver predicate is unit-tested but real day-rollover + region/firstWeekday behavior on a physical device is carried forward from Phase 8 as a device smoke."
  - test: "Program tab New Block flow launch smoke (NewBlockModalUITests env-blocked)."
    expected: "Tapping '+ NEW BLOCK' on the rebuilt ProgramView opens the choice/template/builder flow; '+ NEW ROUTINE' opens the routine builder; tapping a block card opens BlockOverviewScreen and a routine row opens SplitDetailView."
    why_human: "fitbodUITests/NewBlockModalUITests hit the documented xctrunner environment launch failure (FBSOpenApplicationServiceErrorDomain Code=1, RequestDenied by SBMainWorkspace) — env-blocked, not a code failure. Navigation wiring is source-verified (navigationDestination registrations present) but the live launch needs manual confirmation."
  - test: "Swap-confirm sheet bold rendering: on a ready block while another block is active, tap 'START BLOCK ▸'."
    expected: "Sheet shows 'Start Block?' heading and body 'Ends **{activeBlockName}** — its config freezes to history.' with the block name rendered bold via SwiftUI Markdown."
    why_human: "Verbatim string is source-pinned, but SwiftUI Markdown bold rendering of the interpolated name is a visual confirmation."
---

# Phase 9: Program Surfaces Verification Report

**Phase Goal:** The program graph is visible and operable: ProgramView rebuilt with BLOCKS (status-badged cards, DONE collapse) and ROUTINES (split rows with live-block usage tags) sections preserving the guarded empty-state design; new SplitDetailView (ordered slots, drag-reorder reindex-on-write, template picker, usage, live-edit banner); BlockOverviewScreen live + archived modes (archived renders from ArchivedBlockConfig, hides attach/swap/mode/Start); block builder split band; session template editor live-edit banner; TodayView wired to resolver with empty-split fix-it. All 3 BlockBuilderView copy-guardrail suites stay green.

**Verified:** 2026-06-11T22:06:37Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | Empty-state shown ONLY when zero blocks AND zero splits | ✓ VERIFIED | `ProgramView.swift:130` `if allBlocks.isEmpty && allSplits.isEmpty` |
| 2  | BLOCKS section status-badged cards ordered ACTIVE→READY→DRAFT→DONE | ✓ VERIFIED | `ProgramView.swift:356-361` statusOrder `.active:0,.ready:1,.draft:2,.completed:3` |
| 3  | Active block week + phase progress on card | ✓ VERIFIED | `ProgramView.swift:493,509` `derivedStatus == .active` branch renders progress |
| 4  | Only 3 most recent DONE + ALL HISTORY disclosure | ✓ VERIFIED | `ProgramView.swift:375` `prefix(3)`; `397` shows disclosure only `count > 3`; `408` "ALL HISTORY ▸" |
| 5  | ROUTINES rows ('{name}' + '{N} sessions') + usage tags non-completed only | ✓ VERIFIED | `ProgramView.swift:571-575` `liveBlockNames` filters `derivedStatus != .completed` |
| 6  | Tap block → BlockOverviewScreen; tap routine → SplitDetailView | ✓ VERIFIED | `ProgramView.swift:163,184` both navigationDestinations registered |
| 7  | + NEW BLOCK flow preserved; + NEW ROUTINE opens builder | ✓ VERIFIED | `ProgramView.swift:440-444` "+ NEW ROUTINE" row; NewBlockBuilderFidelityTests green |
| 8  | Editing block from BlockOverviewScreen presents builder (.edit(Block)) | ✓ VERIFIED | `ProgramView.swift:331` `case edit(Block)` |
| 9  | SplitDetailView shows slots in order (position 1..N) | ✓ VERIFIED | `SplitDetailView.swift:84` `sorted { position < position }`, display `position+1` |
| 10 | Drag/move reorder keeps positions contiguous 0..<n | ✓ VERIFIED | `SplitDetailView.swift:299,342,359,583` reindexSlots after every mutation; test `reorderKeepsPositionsContiguous` passes |
| 11 | Add session via picker over SessionTemplates or new | ✓ VERIFIED | `SplitDetailView.swift:562 addSlot`; SlotPickerSheet; test `addSlotAppendsContiguously` passes |
| 12 | Remove slot (not template); positions reindex | ✓ VERIFIED | `SplitDetailView.swift:335 removeSlot` + `342 reindexSlots`; test `removeSlotDeletesSlotNotTemplateAndReindexes` passes |
| 13 | Live-edit banner when routine on active block | ✓ VERIFIED | LiveEditBanner wired; usage section filters live blocks |
| 14 | Archive denied when non-completed block references routine | ✓ VERIFIED | `SplitDetailView.swift:250` `BlockLifecycleService.assertSplitDeletable` |
| 15 | Usage section lists non-completed referencing blocks | ✓ VERIFIED | `ProgramView.swift:573` `derivedStatus != .completed` |
| 16 | TodayView empty-split → fix-it surface (not rest-day) | ✓ VERIFIED | `TodayView.swift:583` "ROUTINE HAS NO SESSIONS"; test `emptySplitFixItCopyVerbatim` passes |
| 17 | Fix-it reads "ROUTINE HAS NO SESSIONS" + "GO TO ROUTINE ▸" CTA | ✓ VERIFIED | `TodayView.swift:583,593` verbatim |
| 18 | GO TO ROUTINE navigates within Today's own stack | ✓ VERIFIED | `TodayView.swift:232 navigationDestination`, `348 navigationPath.append(SplitDetailRoute.detail)` |
| 19 | Rest-day / noBlock copy unchanged | ✓ VERIFIED | test `restDayEmptyStateCopyPreserved` passes |
| 20 | Attach/swap on draft/ready; hidden on active | ✓ VERIFIED | `BlockOverviewScreen.swift:162` splitAttachSwapBand only when `.draft || .ready` |
| 21 | Mode picker (ROTATION / FIXED WEEKLY) on live block | ✓ VERIFIED | `BlockOverviewScreen.swift:166 modePickerSection` (non-completed) |
| 22 | FIXED WEEKLY day-chip grid + amber mismatch hint | ✓ VERIFIED | `BlockOverviewScreen.swift:168 dayChipSection`; builder hint `BlockBuilderView.swift:1964` |
| 23 | Day/mode changes write trainingDays ONLY via TrainingDaysWriter.sort | ✓ VERIFIED | `BlockOverviewScreen.swift:670,675,712` + `BlockDraft.swift:148`; no other live writes |
| 24 | Ready block START BLOCK; swap-confirm verbatim copy | ✓ VERIFIED | `BlockOverviewScreen.swift:983 "START BLOCK ▸"`, `1138` "config freezes to history" |
| 25 | Active block END | ✓ VERIFIED | `BlockOverviewScreen.swift:1022 "END BLOCK"` → `191 BlockLifecycleService.end` |
| 26 | Completed renders from decoded archive; attach/swap/mode/Start/End/Edit hidden; decode fail → ARCHIVE UNREADABLE | ✓ VERIFIED | `BlockOverviewScreen.swift:141,160,855-887,1226`; zero live block.split reads in archived path |
| 27 | Builder: attach/swap routine + mode + (fixedWeekly) day toggles | ✓ VERIFIED | `BlockBuilderView.swift:153-155 NewBlockSplitBand` |
| 28 | Save without routine yields draft (no validation error) | ✓ VERIFIED | `BlockDraft.swift:144` direct split write (nil allowed); test `savedDraftWithSplitAndRotationIsReady` passes |
| 29 | Saved draft/ready classified by derivedStatus (NOT completed); endDate not written by builder | ✓ VERIFIED | `BlockDraft.swift:133-137` endDate stays nil; BlockDraftSaveTests pass |
| 30 | block.split written directly inside BlockDraft transaction | ✓ VERIFIED | `BlockDraft.swift:144 block.split = split` |
| 31 | All 3 BlockBuilderView copy-guardrail suites green; ROUTINES·N LINKED pin replaced | ✓ VERIFIED | BlockBuilderViewCopyTests + NewBlockBuilderFidelityTests + ProgramViewFidelityTests all pass |
| 32 | Session editor live-edit banner when template reachable via slots→split→active block | ✓ VERIFIED | `RoutineBuilderView.swift:173 LiveEditBanner` under header |
| 33 | Banner reads "ACTIVE BLOCK" / "Part of active block — edits apply to upcoming workouts." | ✓ VERIFIED | `LiveEditBanner.swift:62`; copy pinned in tests |
| 34 | Banner hidden for create mode + templates not on active block | ✓ VERIFIED | `RoutineBuilderView.swift:170 if isOnActiveBlock`; RoutineBuilderLiveEditTests pass |
| 35 | Reachability computed in Swift (not multi-level #Predicate) | ✓ VERIFIED | `RoutineBuilderView.swift:65-78` single-level #Predicate + Swift post-filter on `derivedStatus == .active` |
| 36 | All phase suites + full target: zero NEW failures vs documented 11-baseline | ✓ VERIFIED | Phase suites 144 passes / 0 fail; full target failures = exactly the 11 baseline |

**Score:** 36/36 truths verified

### Copy Contract Source Assertions (UI-SPEC + §8)

| String | Location | Status |
|--------|----------|--------|
| "ROUTINE HAS NO SESSIONS" | TodayView.swift:583 | ✓ |
| "GO TO ROUTINE ▸" | TodayView.swift:593 | ✓ |
| "...config freezes to history." | BlockOverviewScreen.swift:1138 | ✓ |
| "Remove Session?" / "Remove Session" | SplitDetailView.swift:140,147 | ✓ |
| "ARCHIVE UNREADABLE" (decode fail) | BlockOverviewScreen.swift:1226 | ✓ |
| "NO ARCHIVE AVAILABLE" (nil archive) | BlockOverviewScreen.swift:871 | ✓ |
| "ALL HISTORY ▸" | ProgramView.swift:408 | ✓ |
| "Part of active block — edits apply to upcoming workouts." | LiveEditBanner.swift:62 | ✓ |
| "START BLOCK ▸" / "END BLOCK" | BlockOverviewScreen.swift:983,1022 | ✓ |
| "+ NEW ROUTINE" | ProgramView.swift:444, TodayView.swift:327 | ✓ |

Note: the verification request listed "NO ARCHIVE AVAILABLE" as a copy contract; UI-SPEC §line 182/551 names the decode-failure state "ARCHIVE UNREADABLE". The codebase implements BOTH — a distinct "NO ARCHIVE AVAILABLE" state for nil archiveJSON (pre-archive-support blocks) and "ARCHIVE UNREADABLE" for corrupt/undecodable JSON. Both strings present; no gap.

### Invariant Verification

| Invariant | Status | Evidence |
|-----------|--------|----------|
| Empty-state gate (blocks AND splits empty) | ✓ VERIFIED | ProgramView.swift:130 |
| Usage tags non-completed post-filter | ✓ VERIFIED | ProgramView.swift:573 `derivedStatus != .completed` |
| Attach/swap hidden on active | ✓ VERIFIED | BlockOverviewScreen.swift:162 gated to .draft/.ready |
| Archived render path zero live block.split reads | ✓ VERIFIED | archiveContentSection/archivedConfigView read only decoded `config`; weekCarousel scheduledCount branches completed→archive (CR-03 fix, lines 486-499) |
| trainingDays written ONLY via TrainingDaysWriter.sort | ✓ VERIFIED | All live writes via writer; remaining `trainingDays =` matches are DTO/local reads (BlockDraft:83 read, TodayResolver:169 local, ArchivedBlockConfig:68 DTO init, Block.swift:103 canonical accessor) |
| No "Split"/"SessionTemplate" in user-facing strings | ✓ VERIFIED | rg over all 7 surfaces — none in Text()/literals |
| Reindex-on-write after add/remove/reorder + do/catch saves | ✓ VERIFIED | reindexSlots @ 299/342/359/583; do/catch @ 249/260/300/343/360. addSlot:584 try? is the documented WA-02 out-of-scope exception |

### Key Link Verification

| From | To | Via | Status |
|------|----|----|--------|
| ProgramView | BlockOverviewRoute / SplitDetailRoute | navigationDestination on own stack | ✓ WIRED (163,184) |
| ProgramView | Block.derivedStatus | post-filter status ordering | ✓ WIRED (356-361, 373-374) |
| SplitDetailView | BlockLifecycleService.assertSplitDeletable | archive action | ✓ WIRED (250) |
| SplitDetailView | slot.position reindex | reindex-on-write + single save | ✓ WIRED (45, reindexSlots calls) |
| TodayView | SplitDetailRoute.detail | navigationPath.append on own stack | ✓ WIRED (348) |
| BlockOverviewScreen | BlockLifecycleService.{start,end,attach,swap,decodeArchive} | service seam | ✓ WIRED (191,495,860,1002,1214,1216) |
| BlockOverviewScreen | TrainingDaysWriter.sort | only trainingDays write path | ✓ WIRED (670,675,712) |
| BlockDraft | block.split / trainingDays | direct split write in txn; days via writer | ✓ WIRED (144,148) |
| BlockBuilderView | BlockDraft split/mode/days bindings | split band reads/writes draft fields | ✓ WIRED (153-155, 1877, 1963) |
| RoutineBuilderView | LiveEditBanner | conditional render below header | ✓ WIRED (173) |
| RoutineBuilderView | SessionTemplate → slots → split → active Block | Swift post-filter reachability | ✓ WIRED (65-78, derivedStatus == .active) |

### Behavioral Spot-Checks (test execution)

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Reindex contiguity after reorder | SplitDetailViewTests/reorderKeepsPositionsContiguous | passed | ✓ PASS |
| Add slot contiguity | SplitDetailViewTests/addSlotAppendsContiguously | passed | ✓ PASS |
| Remove slot deletes slot not template + reindex | SplitDetailViewTests/removeSlotDeletesSlotNotTemplateAndReindexes | passed | ✓ PASS |
| Draft save with split → ready | BlockDraftSaveTests/savedDraftWithSplitAndRotationIsReady | passed | ✓ PASS |
| Reachability on/off active block | RoutineBuilderLiveEditTests | passed | ✓ PASS |
| emptySplit fix-it copy verbatim | TodayViewBRUCopyTests/emptySplitFixItCopyVerbatim | passed | ✓ PASS |
| 3 copy-guardrail suites green | BlockBuilderViewCopyTests + NewBlockBuilderFidelityTests + ProgramViewFidelityTests | passed | ✓ PASS |

### Probe Execution

No probe scripts declared (`scripts/*/tests/probe-*.sh`) — phase verified via Swift Testing/XCTest suites instead. SKIPPED (no probes for this phase).

### Test Suite Results

**Phase-9 named suites** (iPhone 17 Pro): `** TEST SUCCEEDED **` — 144 case passes, 0 failures across SplitDetailViewTests, BlockDraftSaveTests, BlockOverviewScreenCopyTests, TodayViewBRUCopyTests, RoutineBuilderLiveEditTests, ProgramViewFidelityTests, BlockBuilderViewCopyTests, NewBlockBuilderFidelityTests.

**Full unit target** (`-only-testing:fitbodTests -parallel-testing-enabled NO`): failures = EXACTLY the documented 11 baseline:

| Suite | Failed | Baseline | Match |
|-------|--------|----------|-------|
| FatigueSurfaceViewBRU | 4 | 4 | ✓ |
| SessionLoggerBRUCopy | 4 | 4 | ✓ |
| PrescriptionEditorBlockCaseFilter | 1 | 1 | ✓ |
| TodayViewBlockStacking | 1 | 1 | ✓ |
| BlocksSection | 1 | 1 | ✓ |
| **Total** | **11** | **11** | **✓** |

All 5 baseline-failing suites/tests are source-introspection BRU-copy-drift checks on screens NOT touched by Phase 9 (FatigueSurfaceView, SessionLogger components, PrescriptionEditor, RoutinesListView, StartBlockCTA). git confirms none modified on 2026-06-11. **Zero NEW deterministic failures introduced by Phase 9.**

**SchemaV7Migration crash (adjudicated NOT a phase-9 regression):** During the serial run the runner hit `Fatal error: Failed to cast model fitbod.SchemaV6.Routine` in `SchemaV7MigrationTests.swift` (test `stashV6Routines + materializeSessionTemplates remaps Session.template via sourceRoutineID`), then auto-restarted (`Restarting after unexpected exit, crash, or test timeout`) and the SchemaV7Migration suite re-ran to `✔ Suite "SchemaV7Migration" passed`. This is a pre-existing, non-deterministic SwiftData schema-registry-contamination flake in the Phase-7 V6→V7 migration suite — git history shows prior commits explicitly addressing it (`ebe4755 fix(07-06): redesign tests 8-9 resilient to SwiftData schema-registry contamination`, `962d478 fix(07-07): make migration suite deterministic`). The file has NO Phase-9 (June-11) commits. Not in scope of Phase 9 and recovered to pass; not counted as a phase failure.

**UI smoke (env-blocked):** `fitbodUITests/NewBlockModalUITests/testProgramNewBlockOpensBlankBuilder` failed with the documented xctrunner environment launch failure (`FBSOpenApplicationServiceErrorDomain Code=1 ... RequestDenied by SBMainWorkspace ... The process failed to launch`). Per verdict rules this is env-blocked, NOT a phase failure. Navigation wiring is source-verified; live launch confirmation moved to human verification.

### Requirements Coverage

Phase requirement contract is `program-graph-spec.md §5 (edge surfaces) + §8 (surfaces)`. UI glossary: "Session"=SessionTemplate, "Routine"=Split.

| Requirement | Source | Status | Evidence |
|-------------|--------|--------|----------|
| §8 ProgramView rebuild (empty gate, BLOCKS, ROUTINES) | spec §8 | ✓ SATISFIED | Truths 1-8 |
| §8 SplitDetailView (slots, reorder, picker, usage, banner) | spec §8 | ✓ SATISFIED | Truths 9-15 |
| §8 BlockOverviewScreen live + archived | spec §8 | ✓ SATISFIED | Truths 20-26 |
| §8 Block builder split band | spec §8 | ✓ SATISFIED | Truths 27-31 |
| §8 Session editor live-edit banner | spec §8 | ✓ SATISFIED | Truths 32-35 |
| §5 Today empty-split fix-it (zero-slot edge) | spec §5 | ✓ SATISFIED | Truths 16-19 |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| BlockOverviewScreen.swift | 111, 272 | FIXME(v2) day-rollover re-init | ℹ️ Info | Pre-existing (commit 8183908, Phase 04.1, 2026-05-25); references v2 deferral; not phase-9 |
| BlockOverviewScreen.swift | 211 | "placeholder" PR detection (Phase 6 scope) | ℹ️ Info | Pre-existing (commit 9a1f3b1, Phase 04.1); scoped to Phase 6 |
| RoutineBuilderView.swift | 300,303 | "placeholder" chips (days/duration not modeled) | ℹ️ Info | Pre-existing (commit 23313bf, Phase 02.1, 2026-05-23); not phase-9 |
| SplitDetailView.swift | 584 | `try? ctx.save()` in addSlot | ℹ️ Info | Documented WA-02 out-of-scope exception in 09-REVIEW; all cited save paths use do/catch |

No phase-9-introduced debt markers (TBD/FIXME/XXX). All FIXME markers are pre-existing Phase-02.1/04.1 code with v2/Phase-6 deferral references; debt-marker gate not triggered for Phase 9.

### Code Review Reconciliation

09-REVIEW.md: 11 findings — 10 FIXED (CR-01/02/03 + WA-01..05 + IN-02/03), 1 ACCEPTED (IN-01: `.confirmationDialog` vs spec `.alert` for remove-slot — documented as acceptable/better iOS UX). All fix commits verified present in source:
- CR-01 BlockDraftSaveTests on SchemaV7 — BlockDraftSaveTests pass ✓
- CR-03 archived weekCarousel reads decoded archive only — verified lines 486-499 ✓
- WA-02 do/catch saves on cited paths — verified lines 249/260/300/343/360 ✓
- IN-01 confirmationDialog accepted — verified SplitDetailView.swift:139 ✓

### Gaps Summary

No gaps. All 36 observable truths verified against source, all key links wired, all copy contracts and structural invariants source-asserted, all 8 phase-9 test suites green (144 passes / 0 fail), and full-target failures match the documented 11-baseline exactly with zero new phase-9 regressions. The SchemaV7Migration crash is a pre-existing Phase-7 flake that recovered to pass; the UI smoke failure is the documented env-blocked xctrunner launch failure.

Status is **human_needed** (not passed) because six items require visual/interactive/device confirmation that grep and source-introspection tests cannot cover: DONE-collapse animation, slot-reorder move-control feel, 390pt overflow at the device floor, rotation-advance device smoke (carried from Phase 8), the env-blocked Program tab New Block launch flow, and the swap-confirm Markdown-bold rendering.

---

_Verified: 2026-06-11T22:06:37Z_
_Verifier: Claude (gsd-verifier)_
