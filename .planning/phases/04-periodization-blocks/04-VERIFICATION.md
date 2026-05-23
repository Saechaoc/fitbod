---
phase: 04-periodization-blocks
verified: 2026-05-23T15:00:00Z
status: human_needed
score: 5/5 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Today screen visual stacking with active block"
    expected: "On Today tab with an active block, banners render top-to-bottom: DeloadWeekBanner (only if in deload week) → ConsiderDeloadBanner (hidden under StubFatigueAdvisory) → BlockCard with name header + phase chip + 'Week N of M' badge + days-remaining caption + multiplier preview + routines list, with the card's background tinted to the current phase color (accentColor for accumulation; orange for intensification; red-orange for realization; gray for deload)"
    why_human: "Visual color, layout spacing, font weight, and phase-color tint pass cannot be programmatically verified — Swift Charts and SwiftUI rendering decisions need an eyeballed pass on device or simulator. Tests confirm view source contains the banners in order, but not how they look."

  - test: "Block builder save flow on device"
    expected: "Tapping 'Start a Block' on Today (empty state) presents the BlockBuilderView in a sheet. User can type a block name, pick a start date, toggle 'Active block', add phases via '+ Phase' menu (accumulation / intensification / realization / deload), reorder phases via drag, delete phases via swipe-left, edit per-phase weeks + volume + intensity multipliers in the phase rows. 'Save' is enabled when name is non-empty AND at least one phase exists; tapping 'Save' persists the block, dismisses the sheet, and the new block immediately appears as a BlockCard on Today (when isActive)"
    why_human: "Multi-step interactive flow involving SwiftUI sheet presentation, form input, drag-to-reorder, swipe-to-delete, and state propagation back through @Query. The individual pieces are unit-tested (BlockDraftSaveTests, BlockBuilderViewCopyTests, SingleActiveBlockInvariantTests) but the end-to-end happy path needs UAT."

  - test: "Mesocycle week swipe navigation"
    expected: "On Today tab with an active multi-week block, the BlockCard hosts a horizontal pager. Swiping left advances to next week (Week 2 of N, then 3, etc.); swiping right returns to earlier weeks. Each week page shows its phase chip, week badge, days-remaining caption, and the phase-color background tint updates as the user swipes through phase boundaries. Current-week indicator and accessibility hint ('Swipe horizontally to navigate between weeks of the mesocycle') are present"
    why_human: "Swipe gesture + page transition + background-color animation between pages is a real-time interactive behavior. BlockCardWeekNavigationTests verifies the math (selectedWeekIndex bounds, totalWeeks) but the touch interaction itself + visual feedback requires a device pass."

  - test: "Deload week banner + volume cut behavior"
    expected: "On a day that falls inside a scheduled deload phase week, opening Today shows the persistent DeloadWeekBanner ('Deload week — recover, don't load. Working sets cut by ~50%. Weights held to phase intensity.') at the top. Starting a new session from a routine linked to that block produces a Session where each working exercise has roughly half the targetSets count, and warm-up ramps are skipped. The 'Why this weight?' sheet for any block- or hybrid-progression exercise shows the deload note ('Working sets cut by ~50%. Weight held at baseline.')"
    why_human: "DeloadVolumeApplicationTests + WarmupDeloadIntegrationTests cover the deterministic math, but verifying the user-visible banner copy + the actual SessionLogger displaying half the rows + the WhyThisWeightSheet rendering the deload note requires running through the session-start flow on device."

  - test: "End-of-block review sheet on first launch after block end-date"
    expected: "When a Block is active AND has an endDate in the past AND has reviewedAt == nil, opening the Today tab automatically presents BlockReviewView as a .large sheet titled '{Block Name} — review' with four sections: 'Total volume' (X kg total / Y working sets across Z sessions, or empty-state copy if no logged sets), 'e1RM deltas' (per-exercise deltas sorted by abs(delta) descending, or 'Not enough sessions logged to compute deltas.'), 'PRs hit' (placeholder: 'Coming in Phase 6...'), and 'Recommended next phase' (CTA 'Start {Recommended} Block' + 'Not now'). Tapping 'Done' marks the block reviewedAt and deactivates it"
    why_human: "Triggering this UAT requires either a real block in the user's store with a past endDate, or in-Xcode manipulation of the dev store. BlockReviewMathTests + BlockReviewTriggerTests pin the math + predicate; the sheet presentation + .large detent + section rendering + button behavior needs a device pass."

  - test: "Progression picker filters .block/.hybrid when routine has no block"
    expected: "In RoutineBuilderView, the Progression header picker shows all 4 cases [.rpe, .double, .block, .hybrid] when a block is linked via BlockPickerMenu. When the user unlinks the block (selects 'No block' in BlockPickerMenu), the picker collapses to [.rpe, .double] and if the current selection was .block or .hybrid, it auto-demotes to .double. Saving such a routine never persists with a .block/.hybrid selection if no block is linked"
    why_human: "PrescriptionEditorBlockCaseFilterTests verifies the filter function returns the correct case set, but the picker UI re-rendering on block-link change + the autodemotion behavior is a stateful @Bindable interaction that benefits from a manual pass."
---

# Phase 4: Periodization & Blocks Verification Report

**Phase Goal:** User can define training blocks with phased mesocycles, see the active block on the home screen, navigate weeks, get scheduled deloads that automatically cut volume/intensity, and pick block-periodized or hybrid progression for relevant exercises.

**Verified:** 2026-05-23T15:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification
**Mode declared:** mvp (ROADMAP.md line 116)

## Mode Note

ROADMAP.md declares this phase as `mode: mvp`, but the phase goal is NOT in the strict User Story format ("As a [user role], I want to [capability], so that [outcome].") required for full MVP-mode verification. Phases 1–3 of this project also shipped with capability-statement goals rather than User Story goals, so I am proceeding with goal-backward verification against the 5 ROADMAP Success Criteria (which is the contract). If you want strict MVP-mode verification going forward, the planner needs to set User Story goals.

## Goal Achievement

### Observable Truths (5 Success Criteria from ROADMAP.md)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can define a training block with ordered phase sequence (accumulation, intensification, realization, deload), per-phase week length, and per-phase volume/intensity multipliers; routines link to a block | ✓ VERIFIED | `BlockBuilderView` (Periodization/BlockBuilderView.swift) presents name + startDate + isActive toggle + phases ForEach with onMove/onDelete + +Phase menu showing all 4 BlockPhaseKind cases. `Block` + `BlockPhase` SwiftData models (Models/Block.swift, BlockPhase.swift) carry `nameRaw`, `weeks`, `volumeMultiplier`, `intensityMultiplier`. `RoutineDraft.blockID` + `BlockPickerMenu` (Routines/RoutineDraft.swift:96, Periodization/BlockPickerMenu.swift) link routines to blocks. 11 tests GREEN: BlockDraftSaveTests (5), BlockBuilderViewCopyTests, BlocksSectionTests, SingleActiveBlockInvariantTests, BlockTemplatesTests, RoutineBlockLinkageTests, PrescriptionEditorBlockCaseFilterTests (6) |
| 2 | Home screen surfaces active block with phase chip, "Week N of M", days remaining, phase color coding; user can swipe between weeks | ✓ VERIFIED | `RootView.TodayView` (App/RootView.swift:248) has `@Query(filter: #Predicate<Block> { $0.isActive == true })` and renders `BlockCard(block: active)` when present. `BlockCard` (Periodization/BlockCard.swift:77) hosts `TabView(selection: $selectedWeekIndex).tabViewStyle(.page)` for swipe paging. `MesocycleWeekPage` renders phase chip via `BlockPhaseColors.color(for:)`, week badge "Week N of M", "X days remaining" caption, and multiplier preview. `BlockPhaseColors` provides distinct colors per phase kind. Tests: BlockCardWeekNavigationTests, TodayViewBlockStackingTests (9 each) — pin both the @Query, the conditional rendering, and the swipe pager structure |
| 3 | BlockPeriodizedStrategy and HybridStrategy are live as the 3rd and 4th progression options; switching the progression kind changes prescribed weight predictably across all four algorithms; hybrid combines block phase macro context with RPE-driven daily adjustment | ✓ VERIFIED | `ProgressionStrategyFactory.make(for:)` (Prescription/ProgressionStrategyFactory.swift:27-38) routes `.block` → `BlockPeriodizedStrategy()` and `.hybrid` → `HybridStrategy()` (was DoubleProgression stub in Phase 3). `BlockPeriodizedStrategy.prescribe` resolves baseline via D-17 chain → applies `phase.intensityMultiplier` → plate-rounds. `HybridStrategy.prescribe` calls BlockPeriodizedStrategy + RPEAutoregStrategy in parallel, returns `min(blockResult, rpeResult)` with named source ("block ceiling" / "rpe-driven"). `SessionFactory.start` invokes the factory and passes `block: routine.block` (Sessions/SessionFactory.swift:275-277). Tests: BlockPeriodizedStrategyTests, HybridStrategyTests |
| 4 | Scheduled deload weeks auto-reduce prescribed volume (~50%) and adjust intensity per the deload phase definition; visually distinct (banner / calendar tint / volume targets cut); warm-up generation respects them (no ramps on deload weeks) | ✓ VERIFIED | `SessionFactory.start` (Sessions/SessionFactory.swift:326-334) computes `plannedWorkingSetCount = max(1, Int(floor(targetSets * volumeMultiplier)))` when `scheduledDeloadActive`. `WarmupRamp.shouldGenerate` receives `deloadActive: scheduledDeloadActive` (line 287) and returns false on deload (Prescription/WarmupRamp.swift:55). `DeloadWeekBanner` (Periodization/DeloadWeekBanner.swift) renders with copy "Deload week — recover, don't load. Working sets cut by ~50%. Weights held to phase intensity." Banner only rendered when `phase.kind == .deload` (App/RootView.swift:259-262). `BlockPeriodizedStrategy` deload branch holds weight at baseline (BlockPeriodizedStrategy.swift:66-81). Tests: DeloadVolumeApplicationTests (8 cases including 1-set clamp), WarmupDeloadIntegrationTests, BlockPeriodizedStrategyTests |
| 5 | Block schedule is canonical — fatigue-triggered "consider deload" advisories never auto-apply; end-of-block produces a phase-end review (total volume, e1RM deltas, PRs hit, recommended next phase) | ✓ VERIFIED | `FatigueAdvisory` protocol (Prescription/FatigueAdvisory.swift:13-16) returns ONLY `Bool` and `FatigueSuggestion` — no Block-mutating type. `StubFatigueAdvisory` returns `false` in Phase 4. FatigueAdvisoryCanonicalityTests verifies via Mirror that `FatigueSuggestion` has no Block/BlockPhase fields — type-level BLOCK-08 enforcement. `BlockReviewView` (Periodization/BlockReviewView.swift) renders 4 sections: total volume, e1RM deltas (via E1RMHelper.epley), PRs placeholder (deferred to Phase 6 per BLOCK-07 split), recommended-next CTA. `BlockReviewStatistics.acknowledge` wraps `block.reviewedAt = now; block.isActive = false` in a single `ctx.transaction`. `TodayView` `.task { pendingBlockReview = pendingReviewBlocks(...).first }` + `.sheet(item: $pendingBlockReview)` (App/RootView.swift:309-318). Tests: BlockReviewMathTests (9), BlockReviewTriggerTests (11), FatigueAdvisoryCanonicalityTests (3) |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `fitbod/Periodization/BlockBuilderView.swift` | Single-screen block builder | ✓ VERIFIED | 175 LOC, hosts Form with name/date/isActive toggle, phases ForEach with onMove/onDelete, +Phase menu, Cancel/Save toolbar, discard confirmation, single-active replacement footnote |
| `fitbod/Periodization/BlockCard.swift` | Active-block Today card with swipe pager | ✓ VERIFIED | 118 LOC, value-driven init, TabView .page style for week swiping, phase-color background tint, overflow Menu for Edit/End block, EndBlockAlert via .alert binding |
| `fitbod/Periodization/MesocycleWeekPage.swift` | One page per week with phase chip, week badge, days remaining, multipliers | ✓ VERIFIED | 114 LOC, renders phase chip via BlockPhaseColors, week badge "Week N of M", daysRemaining text, multiplier preview, routines-this-week list |
| `fitbod/Periodization/PeriodizationEngine.swift` | Pure date/phase math (no ModelContext access) | NOTE | Located at `fitbod/Prescription/PeriodizationEngine.swift` (verifier files_to_read assumed it was in Periodization/ — actual location is Prescription/). Functions: `phase(for:on:)`, `weekIndex(for:on:)`, `weekContext(for:weekIndex:on:)`, `recommendedNextKind(after:)`. Returns Sendable `MesocycleWeekContext` value type. Tests: PeriodizationEngineTests |
| `fitbod/Periodization/MesocycleWeekContext.swift` | Sendable value snapshot | ✓ VERIFIED | 52 LOC, Sendable struct with phaseKind, weekInPhase, multipliers, daysRemaining, isCurrentWeek, isDeloadWeek |
| `fitbod/Periodization/BlockTemplates.swift` | Static stock templates | ✓ VERIFIED | generic / hypertrophy / powerliftingPeak / blank templates + template(for:) selector. Tests: BlockTemplatesTests |
| `fitbod/Periodization/BlockPhaseColors.swift` | Phase color palette | ✓ VERIFIED | 4-case switch returning per-phase Color values; tint(for:) with 0.15 opacity helper; phaseLabel(_:) capitalized name helper |
| `fitbod/Periodization/BlockDraft.swift` | @Observable builder draft | ✓ VERIFIED | Tests: BlockDraftSaveTests (5/5) |
| `fitbod/Periodization/BlockPhaseDraft.swift` | @Observable phase draft | ✓ VERIFIED | Includes defaultMultipliers(for:) helper used by BlockBuilderView.addPhase |
| `fitbod/Periodization/BlockPhaseEditorRow.swift` | Per-phase editor row | ✓ VERIFIED | Exists, used by BlockBuilderView ForEach |
| `fitbod/Periodization/BlockPickerMenu.swift` | Header picker for routine→block link | ✓ VERIFIED | Used by RoutineBuilderView at line 125 |
| `fitbod/Periodization/BlockRow.swift` | Routines tab block row | ✓ VERIFIED | Used by RoutinesListView blocksSection at line 304 |
| `fitbod/Periodization/BlockReviewView.swift` | 4-section phase-end review sheet | ✓ VERIFIED | 342 LOC, 4 sections (total volume / e1RM deltas / PRs placeholder / recommended next), `BlockReviewStatistics` namespace with @MainActor static helpers + `acknowledge` transaction |
| `fitbod/Periodization/E1RMHelper.swift` | Epley e1RM formula | ✓ VERIFIED | 18 LOC, `epley(weight:reps:)`, guards reps ∈ [1,10] |
| `fitbod/Periodization/StartBlockCTA.swift` | Today empty-state CTA | ✓ VERIFIED | 36 LOC, used in TodayView when `activeBlocks.isEmpty` |
| `fitbod/Periodization/DeloadWeekBanner.swift` | Persistent deload banner | ✓ VERIFIED | 34 LOC, only rendered when current phase.kind == .deload (RootView.swift:259) |
| `fitbod/Periodization/ConsiderDeloadBanner.swift` | Advisory deload banner | ✓ VERIFIED | 59 LOC, dismissible, gated on `advisory.shouldSuggest()` which is false in Phase 4 |
| `fitbod/Prescription/BlockPeriodizedStrategy.swift` | Block-aware progression strategy | ✓ VERIFIED | 128 LOC, conforms to ProgressionStrategy, resolves baseline (D-17 chain) → multiplies by `phase.intensityMultiplier` for non-deload, holds baseline for deload, plate-rounds via PlateCalculator |
| `fitbod/Prescription/HybridStrategy.swift` | min(block, RPE) composition | ✓ VERIFIED | 107 LOC, calls BlockPeriodizedStrategy + RPEAutoregStrategy in parallel, chooses lower with named source |
| `fitbod/Prescription/FatigueAdvisory.swift` | Advisory protocol (BLOCK-08 type-enforce) | ✓ VERIFIED | 29 LOC, returns only Bool + FatigueSuggestion(reason: String); no Block-mutating field |
| `fitbod/Prescription/StubFatigueAdvisory.swift` | Phase 4 default impl | ✓ VERIFIED | 22 LOC, returns false always; ConsiderDeloadBanner never renders in Phase 4 |
| `fitbod/Prescription/ProgressionStrategyFactory.swift` | Routes .block/.hybrid | ✓ VERIFIED | 40 LOC, `.block` → BlockPeriodizedStrategy(), `.hybrid` → HybridStrategy() |
| `fitbod/Models/Block.swift` | V5 model with reviewedAt | ✓ VERIFIED | 42 LOC; `reviewedAt: Date? = nil` field present at line 30 |
| `fitbod/Sessions/SessionFactory.swift` | Deload set-count cut + Session.block snapshot | ✓ VERIFIED | `session.block = routine.block` (line 133), `scheduledDeloadActive` flag (line 168), warmup respects deload (line 287), set-count clamp `max(1, floor(targetSets * volumeMultiplier))` (line 326-334) |
| `fitbod/Persistence/SchemaV5.swift` | V5 schema with Block.reviewedAt | ✓ VERIFIED | 82 LOC, 16 entity typealiases, versionIdentifier 5.0.0 |
| `fitbod/Persistence/FitbodSchemaMigrationPlan.swift` | Adds migrateV4toV5 | ✓ VERIFIED | Registers 5 schemas + 4 stages; migrateV4toV5 is lightweight (additive Optional<Date>) |
| `fitbod/App/RootView.swift` | BlockReview trigger + banner stack | ✓ VERIFIED | TodayView (line 245-332) hosts: DeloadWeekBanner (conditional on phase.kind == .deload), ConsiderDeloadBanner, BlockCard (when active block exists), StartBlockCTA (when no active block), ResumeWorkoutBanner. `.sheet(item: $pendingBlockReview) { BlockReviewView(block:).presentationDetents([.large]) }` + `.task { pendingBlockReview = pendingReviewBlocks(...).first }` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| BlockBuilderView | Block (SwiftData) | `try draft.save(into: ctx)` | ✓ WIRED | BlockBuilderView.swift:169 calls BlockDraft.save which projects onto SwiftData Block + phases with single-active enforcement |
| Block (active) | TodayView | `@Query(filter: #Predicate<Block> { $0.isActive == true })` | ✓ WIRED | RootView.swift:248 — reactive query, no manual fetch needed |
| BlockCard | MesocycleWeekPage | `TabView(selection:) { ForEach { MesocycleWeekPage(block:weekIndex:) } }` | ✓ WIRED | BlockCard.swift:77-82, .page style for swipe |
| BlockPeriodizedStrategy | PeriodizationEngine | `PeriodizationEngine.phase(for: block, on: today)` | ✓ WIRED | BlockPeriodizedStrategy.swift:34, returns BlockPhase to read intensityMultiplier |
| HybridStrategy | BlockPeriodizedStrategy + RPEAutoregStrategy | `min(blockResult.weight, rpeResult.weight)` | ✓ WIRED | HybridStrategy.swift:32-67 — direct composition |
| ProgressionStrategyFactory | BlockPeriodizedStrategy / HybridStrategy | `case .block: return BlockPeriodizedStrategy()` / `case .hybrid: return HybridStrategy()` | ✓ WIRED | ProgressionStrategyFactory.swift:33-36 |
| SessionFactory | ProgressionStrategyFactory | `ProgressionStrategyFactory.make(for: session.progressionKind)` invoked once per session (D-14) | ✓ WIRED | SessionFactory.swift:164, passes `block: routine.block` to prescribe(...) at line 275 |
| SessionFactory | Block (deload set cut) | `if scheduledDeloadActive { plannedWorkingSetCount = max(1, floor(targetSets * volumeMultiplier)) }` | ✓ WIRED | SessionFactory.swift:326-334 — D-12 / Pitfall 7 clamp |
| SessionFactory | WarmupRamp (deload skip) | `WarmupRamp.shouldGenerate(deloadActive: scheduledDeloadActive, ...)` | ✓ WIRED | SessionFactory.swift:287; WarmupRamp.swift:55 guard returns false |
| Session.block | Block snapshot | `session.block = routine.block` | ✓ WIRED | SessionFactory.swift:133 — soft snapshot; Block→Session relation is inverse-only (Block.swift:38-39) so deleting block doesn't cascade-delete sessions |
| RoutineDraft.blockID | Block | `FetchDescriptor<Block>(predicate: #Predicate { $0.id == targetID })` | ✓ WIRED | RoutineDraft.swift:230-243 — resolves UUID at save time |
| RoutineBuilderView Progression Picker | RoutineDraft.availableProgressionKinds | `RoutineDraft.availableProgressionKinds(hasBlock: draft.blockID != nil)` | ✓ WIRED | RoutineBuilderView.swift:371, filters .block/.hybrid when no block (D-19 relocated) + `guardedProgressionSelection` save-path guard |
| TodayView | BlockReviewView | `.sheet(item: $pendingBlockReview) { BlockReviewView(block: block).presentationDetents([.large]) }` | ✓ WIRED | RootView.swift:309-312 |
| TodayView | BlockReviewStatistics.pendingReviewBlocks | `.task { pendingBlockReview = pendingReviewBlocks(...).first }` | ✓ WIRED | RootView.swift:313-318 |
| BlockReviewView | BlockReviewStatistics.acknowledge | `try ctx.transaction { block.reviewedAt = now; block.isActive = false; try ctx.save() }` | ✓ WIRED | BlockReviewView.swift:309-319 — single transaction wraps dual-write per BLOCK-08 |
| FatigueAdvisory | (NOT) Block | Protocol returns only Bool + FatigueSuggestion(reason:); no Block field exists | ✓ TYPE-LEVEL ENFORCEMENT | FatigueAdvisory.swift:13-24 + FatigueAdvisoryCanonicalityTests verifies via Mirror that FatigueSuggestion has no Block/BlockPhase children |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|---------------------|--------|
| BlockCard | block: Block | `@Query<Block>` filter `isActive == true` in TodayView, value-passed | ✓ Yes — real SwiftData @Query | ✓ FLOWING |
| MesocycleWeekPage | weekContext | `PeriodizationEngine.weekContext(for: block, weekIndex:, on:)` computed from SwiftData Block + BlockPhase rows | ✓ Yes — block.phases array drives weekContext | ✓ FLOWING |
| BlockReviewView (Total volume) | totalKg | `BlockReviewStatistics.totalVolume(context:start:end:)` runs FetchDescriptor<SetEntry> | ✓ Yes — real DB query over completed working sets | ✓ FLOWING |
| BlockReviewView (e1RM deltas) | deltas | `BlockReviewStatistics.e1RMDeltas(context:start:end:)` runs FetchDescriptor<SetEntry> + groups by exercise+session | ✓ Yes — real DB query | ✓ FLOWING |
| BlockReviewView (PRs placeholder) | static "Coming in Phase 6..." | Hardcoded text — intentional Phase 4 scope per ROADMAP SC #5 | N/A — explicit scope deferral, not stub | ⚠️ INTENTIONAL_PLACEHOLDER (per BLOCK-07 ROADMAP split; PRs deferred to Phase 6 progress views) |
| ConsiderDeloadBanner | advisory.shouldSuggest | `StubFatigueAdvisory.shouldSuggest()` returns false always in Phase 4 | N/A — by design (BLOCK-06b is Phase 5) | ⚠️ INTENTIONAL_STUB (Phase 4 BLOCK-06a scope is UI scaffold only — see ROADMAP line 73; banner intentionally never renders in Phase 4) |
| DeloadWeekBanner | phase.kind | `PeriodizationEngine.phase(for: active, on: .now)?.kind == .deload` | ✓ Yes — real SwiftData read | ✓ FLOWING (renders only on deload weeks) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Build for testing succeeds | `xcodebuild -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17' build-for-testing` | `** TEST BUILD SUCCEEDED **` | ✓ PASS |
| All 18 Phase 4 test suites pass | `xcodebuild test-without-building` against the 18 Phase 4 suites listed in verifier context | Exit 0; 288 `passed` occurrences in log; 0 `failed` occurrences | ✓ PASS |
| Schema V4 migration test suite passes (including the 3 flagged by SUMMARY) | `xcodebuild test-without-building -only-testing:fitbodTests/SchemaV4MigrationTests` | Exit 0; 22 `passed` occurrences; 0 `failed`; explicitly the 3 SUMMARY-flagged tests (`endToEndRoutineBackfill`, `endToEndSessionBackfillWithTieBreak`, `emptyExerciseListKeepsDefaults`) all PASS — they have been simplified to pure modeRaw checks. SUMMARY warning about these tests "failing" is stale | ✓ PASS (but coverage scope reduced — see Anti-Patterns) |
| FatigueAdvisory protocol returns no Block-mutating value | Via FatigueAdvisoryCanonicalityTests which uses `Mirror(reflecting:)` on `FatigueSuggestion` to check for Block/BlockPhase children | All 3 tests pass | ✓ PASS (type-level BLOCK-08 enforced) |
| Deload week set-count clamp | DeloadVolumeApplicationTests covers 8 cases (deload halves working sets, clamps to 1 when targetSets=1, accumulation/intensification/realization keep count, no-block keeps count, past-end-of-block keeps count, multiple exercises all halved) | All pass | ✓ PASS |
| Warmup respects deload | WarmupDeloadIntegrationTests | All pass | ✓ PASS |

### Probe Execution

No `scripts/.../tests/probe-*.sh` declared in PLAN files. Phase 4 uses Swift Testing test suites as its verification surface, which I ran above and all pass. Result: SKIPPED — N/A for this phase.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| BLOCK-01 | 04-02, 04-03, 04-05 | User can define training blocks with phase sequence and week length per phase | ✓ SATISFIED | BlockBuilderView + BlockDraft + Block/BlockPhase models. Tests: BlockDraftSaveTests, BlockBuilderViewCopyTests, BlocksSectionTests |
| BLOCK-02 | 04-04a | Active block visible on home: phase chip, "Week N of M", days remaining, color-coded | ✓ SATISFIED | BlockCard + MesocycleWeekPage + BlockPhaseColors. RootView TodayView @Query Block isActive. Tests: TodayViewBlockStackingTests, BlockCardWeekNavigationTests |
| BLOCK-03 | 04-04a | Swipe between weeks within a block | ✓ SATISFIED | BlockCard TabView(.page) at line 77-82. Tests: BlockCardWeekNavigationTests |
| BLOCK-04 | 04-07 | Scheduled deload auto-reduces volume (~50%) and intensity per deload phase | ✓ SATISFIED | SessionFactory.swift:326-334 (set-count clamp); BlockPeriodizedStrategy deload branch holds weight at baseline. Tests: DeloadVolumeApplicationTests |
| BLOCK-05 | 04-04b, 04-01, 04-06 | Deload weeks visually distinct (banner / tint) | ✓ SATISFIED | DeloadWeekBanner (RootView line 259-263 conditional render) + BlockPhaseColors.tint(.deload). Tests: TodayViewBlockStackingTests includes `deloadBannerCopyVerbatim` |
| BLOCK-06a | 04-04b, 04-01 | UI scaffold + FatigueAdvisory protocol + StubFatigueAdvisory; BLOCK-08 type enforcement | ✓ SATISFIED | ConsiderDeloadBanner + FatigueAdvisory + StubFatigueAdvisory + SessionContext + FatigueSuggestion. Tests: FatigueAdvisoryCanonicalityTests |
| BLOCK-06b | n/a (Phase 5) | Real fatigue/performance signal | ⏸ DEFERRED | Explicitly Phase 5 per ROADMAP line 211 + REQUIREMENTS line 74 |
| BLOCK-07 | 04-08 | End-of-block produces phase-end review (volume, e1RM deltas, PRs, recommended next) | ✓ SATISFIED | BlockReviewView 4-section sheet; PRs placeholder noted as Phase 6 deferral per BLOCK-07 split. Tests: BlockReviewMathTests, BlockReviewTriggerTests |
| BLOCK-08 | 04-01, 04-08 | Block deload canonical; fatigue alerts advisory only | ✓ SATISFIED | FatigueAdvisory protocol returns only Bool + FatigueSuggestion (no Block type). BlockReviewStatistics.acknowledge wraps dual-write in single transaction. Tests: FatigueAdvisoryCanonicalityTests (Mirror-based type check) |
| PRES-05 | 04-05, 04-06 | BlockPeriodizedStrategy resolves weight from active block phase's intensity curve | ✓ SATISFIED | BlockPeriodizedStrategy.swift:83 `rawTarget = baseline * phase.intensityMultiplier`; deload branch holds baseline. Tests: BlockPeriodizedStrategyTests |
| PRES-06 | 04-05, 04-06 | HybridStrategy combines block phase context with RPE-driven daily adjustment | ✓ SATISFIED | HybridStrategy.swift:32-67 returns `min(blockResult, rpeResult)` with named source. Tests: HybridStrategyTests |

Phase 4 declared requirements per ROADMAP line 117: BLOCK-01..06a, BLOCK-07, BLOCK-08, PRES-05, PRES-06 (10 requirements). All 10 SATISFIED. BLOCK-06b correctly deferred to Phase 5 per documented split.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `fitbod/Periodization/BlockReviewView.swift` | 114-120 | `prsHitSectionPlaceholder` — section explicitly displays "Coming in Phase 6. Full PR detection ships with the progress views update." | ℹ️ Info | Intentional scope deferral per ROADMAP SC #5 + BLOCK-07 split note. Not a stub — scoped to Phase 4. Phase 6 owns full PR detection. |
| `fitbod/Periodization/ConsiderDeloadBanner.swift` | 37-39 | `Button("Adjust block") { /* Phase 5 wires the real advisory action. */ }` | ℹ️ Info | Empty handler is intentional — the banner never renders in Phase 4 because StubFatigueAdvisory always returns false. BLOCK-06b (Phase 5) wires both the signal and the action. Banner is dormant by design. |
| `fitbod/Prescription/StubFatigueAdvisory.swift` | 14-20 | Returns false always; FatigueSuggestion(reason: "") | ℹ️ Info | Intentional Phase 4 scope per BLOCK-06a — UI scaffold only. Banner never renders. BLOCK-06b (Phase 5) replaces with real fatigue signal implementation. |
| `fitbodTests/SchemaV4MigrationTests.swift` | 186-222 | The 3 "endToEnd" tests (`endToEndRoutineBackfill`, `endToEndSessionBackfillWithTieBreak`, `emptyExerciseListKeepsDefaults`) have been REDUCED to pure `modeRaw` tie-break checks rather than end-to-end migration tests | ⚠️ Warning | SUMMARY notes this as a "Phase 3.1 migration-design issue exposed by Phase 4's V5 bump." Tests as written pass cleanly, but the test names suggest end-to-end V3→V5 migration coverage that they no longer provide. Since the user has a freshly-seeded V5 store and v1 hasn't shipped, this is not goal-blocking for Phase 4, but the test coverage for V3→V5 migration is weaker than the test names imply. Phase 4 SUMMARY explicitly acknowledges this and labels it Phase 3.1 territory. Recommend: rename the 3 tests to reflect actual coverage, OR file a Phase 5+ follow-up to restore true end-to-end migration coverage. |
| (no TBD/FIXME/XXX markers found in any Phase 4 implementation file) | — | Debt-marker scan | ✓ Clean | Per the Step 7 debt-marker gate, zero unreferenced TBD/FIXME/XXX markers means completion is auditable. |
| (no TODO/HACK/PLACEHOLDER markers found in any Phase 4 implementation file outside the explicitly-scoped PRs section) | — | Anti-pattern scan | ✓ Clean | The single placeholder is the BLOCK-07-split intentional deferral. |

### Human Verification Required

Per Step 8, the following items need human testing (also captured in frontmatter `human_verification:`):

#### 1. Today screen visual stacking with active block

**Test:** Open Today tab when an active block exists and verify the visual banner stack.
**Expected:** Banners render top-to-bottom: DeloadWeekBanner (only if in deload week) → ConsiderDeloadBanner (hidden in Phase 4) → BlockCard with name header + phase chip + "Week N of M" badge + days-remaining caption + multiplier preview + routines list. The card's background is tinted to the current phase color (accentColor / orange / red-orange / gray for accumulation / intensification / realization / deload).
**Why human:** Visual color, layout spacing, font weight, and phase-color tint pass cannot be programmatically verified. Tests confirm view source contains the banners in order, but not how they look on device.

#### 2. Block builder save flow on device

**Test:** From Today (empty state), tap "Start a Block", build a new block end-to-end.
**Expected:** Sheet presents BlockBuilderView. User types name, picks date, toggles 'Active block', adds phases via '+ Phase' menu (all 4 kinds), reorders via drag, deletes via swipe-left, edits per-phase weeks/multipliers. 'Save' enabled when name non-empty AND ≥ 1 phase. Tapping 'Save' persists, dismisses, new block appears as BlockCard on Today.
**Why human:** Multi-step interactive flow involving sheet presentation, form input, drag-to-reorder, swipe-to-delete, and state propagation back through @Query. Individual pieces are unit-tested; end-to-end happy path needs UAT.

#### 3. Mesocycle week swipe navigation

**Test:** On Today with an active multi-week block, swipe horizontally on the BlockCard.
**Expected:** Swipe left advances week (Week 2 of N, etc.); swipe right goes back. Each week shows its phase chip, week badge, days-remaining, multipliers. Background tint updates as user crosses phase boundaries.
**Why human:** Swipe gesture + page transition + background animation is real-time interactive behavior. Math is unit-tested; gesture feel + visual transition needs device pass.

#### 4. Deload week banner + volume cut behavior

**Test:** On a day inside a scheduled deload week, open Today and start a session from a block-linked routine.
**Expected:** DeloadWeekBanner persistent banner at top of Today. New session has ~half the working sets per exercise. Warm-up ramps skipped. "Why this weight?" sheet shows deload note for block/hybrid-progression exercises.
**Why human:** Tests cover math + warmup logic; user-visible banner copy + SessionLogger showing half the rows + WhyThisWeightSheet rendering needs session-start flow on device.

#### 5. End-of-block review sheet trigger

**Test:** With an active block whose endDate is in the past AND reviewedAt is nil, open Today.
**Expected:** BlockReviewView auto-presents as .large sheet titled "{Block Name} — review" with 4 sections (total volume / e1RM deltas / PRs placeholder / recommended next). Tapping 'Done' marks reviewedAt + deactivates.
**Why human:** Triggering requires either a real block in store with past endDate, or in-Xcode dev store manipulation. Math is unit-tested; sheet presentation + .large detent + section rendering + button behavior needs device pass.

#### 6. Progression picker filter on block link change

**Test:** In RoutineBuilderView, link/unlink a block via BlockPickerMenu and observe the Progression picker.
**Expected:** Linked → picker shows all 4 cases. Unlinked → picker collapses to [.rpe, .double]; if current selection was .block or .hybrid, auto-demotes to .double. Saving never persists .block/.hybrid without a block link.
**Why human:** Filter function is unit-tested; the picker UI re-rendering on block-link change + auto-demotion behavior is a stateful @Bindable interaction that benefits from manual pass.

### Gaps Summary

No gaps blocking phase goal achievement. All 5 ROADMAP success criteria are observably satisfied in the codebase:

- The block-definition flow (SC-1) exists end-to-end with BlockBuilderView + BlockDraft + Block/BlockPhase + transactional save.
- The active block surface on Today (SC-2) is wired via @Query on isActive and rendered through BlockCard + MesocycleWeekPage with swipe pager and phase-color coding.
- Both new progression strategies (SC-3) are live in the factory + protocol surface and have dedicated test suites.
- Deload behavior (SC-4) cuts working sets via the SessionFactory clamp, skips warmup, and holds weight via BlockPeriodizedStrategy's deload branch; the banner renders conditionally.
- BLOCK-08 canonical-block-deload (SC-5) is enforced at the type level (FatigueAdvisory returns only FatigueSuggestion, never a Block-mutating value) and the phase-end review sheet is fully wired through TodayView .task + .sheet.

The status is **human_needed** because the goal involves visible UI behavior (banner stacking, swipe gestures, sheet presentation, color coding, picker filtering) that I can only verify by code-reading the wiring — the actual user-facing experience requires a UAT pass on device or simulator. All grep-checkable wiring is correct; all unit tests pass (288/288 Phase 4 test passes + 22/22 SchemaV4MigrationTests pass).

One **non-blocking warning**: the 3 SchemaV4MigrationTests named `endToEndRoutineBackfill`, `endToEndSessionBackfillWithTieBreak`, `emptyExerciseListKeepsDefaults` have been simplified to pure `modeRaw` checks. They pass cleanly, but the test names suggest end-to-end V3→V5 migration coverage they no longer provide. SUMMARY-04-08 documents this as a Phase 3.1 design issue exposed by Phase 4's V5 bump, with the rationale that the user has a freshly-seeded V5 store and v1 hasn't shipped. This is not goal-blocking for Phase 4. Recommend a Phase 5+ follow-up to either (a) restore true end-to-end migration coverage, or (b) rename the tests to reflect actual coverage.

---

_Verified: 2026-05-23T15:00:00Z_
_Verifier: Claude (gsd-verifier)_
