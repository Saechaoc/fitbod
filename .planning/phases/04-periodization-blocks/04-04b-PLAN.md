---
phase: 04-periodization-blocks
plan: 04b
type: execute
wave: 3
depends_on: ["04-01", "04-02", "04-04a"]
files_modified:
  - fitbod/Periodization/DeloadWeekBanner.swift
  - fitbod/Periodization/ConsiderDeloadBanner.swift
  - fitbod/Periodization/StartBlockCTA.swift
  - fitbod/App/RootView.swift
  - fitbodTests/TodayViewBlockStackingTests.swift
autonomous: true
requirements: [BLOCK-05, BLOCK-06a]

must_haves:
  truths:
    - "DeloadWeekBanner renders at the TOP of Today scroll (above BlockCard) when the current week of the active block resolves to a deload phase; UI-SPEC verbatim copy 'Deload week — recover, don't load.' + secondary 'Working sets cut by ~50%. Weights held to phase intensity.'"
    - "ConsiderDeloadBanner is wired above BlockCard but never renders in Phase 4 because StubFatigueAdvisory.shouldSuggest returns false; BLOCK-06b (Phase 5) fills the real signal without modifying this UI scaffold (D-24 + D-25)"
    - "When no active Block exists, StartBlockCTA renders in place of BlockCard with UI-SPEC verbatim 'No active block.' + body + 'Start a Block' accent text button that presents BlockBuilderView seeded with .blank template"
    - "TodayView stacking order is: (1) DeloadWeekBanner [conditional], (2) ConsiderDeloadBanner [conditional — Phase 4 stub never], (3) BlockCard OR StartBlockCTA, (4) ResumeWorkoutBanner, (5) existing 'No workout in progress' content"
    - "TodayViewBlockStackingTests turn GREEN; stacking-order contract + verbatim banner copy + StartBlockCTA copy + deload-condition predicate are all pinned via source-anchor positional assertions"
  artifacts:
    - path: "fitbod/Periodization/DeloadWeekBanner.swift"
      provides: "Top-of-Today pinned non-dismissible banner; UI-SPEC verbatim copy; deload-color tint background; takes `currentPhaseKind: BlockPhaseKind` value-type input (does NOT hold a BlockPhase @Model reference — respects MesocycleWeekContext Sendable snapshot pattern)"
      contains: "struct DeloadWeekBanner"
    - path: "fitbod/Periodization/ConsiderDeloadBanner.swift"
      provides: "Advisory banner with DI default StubFatigueAdvisory; dismissible via xmark; 'Adjust block' CTA wires to BlockBuilderView (action no-op in Phase 4); never renders in Phase 4 because Stub returns false"
      contains: "struct ConsiderDeloadBanner"
    - path: "fitbod/Periodization/StartBlockCTA.swift"
      provides: "No-active-block empty-state CTA; UI-SPEC verbatim 'No active block.' + body; accent 'Start a Block' button calls injected onStart closure"
      contains: "struct StartBlockCTA"
    - path: "fitbod/App/RootView.swift"
      provides: "TodayView extended to insert the full Phase 4 banner stack (DeloadWeekBanner / ConsiderDeloadBanner / StartBlockCTA) around the BlockCard insertion from plan 04-04a; .sheet(item: $pendingBlockBuilder) presents BlockBuilderView when StartBlockCTA tapped; ScrollView wrap added to fit the full stack vertically"
      contains: "DeloadWeekBanner"
  key_links:
    - from: "fitbod/Periodization/ConsiderDeloadBanner.swift"
      to: "fitbod/Prescription/FatigueAdvisory.swift"
      via: "init(advisory: FatigueAdvisory = StubFatigueAdvisory()) DI default; body guards on advisory.shouldSuggest(context: .init())"
      pattern: "advisory.shouldSuggest"
    - from: "fitbod/Periodization/DeloadWeekBanner.swift"
      to: "fitbod/Periodization/BlockPhaseColors.swift"
      via: "background uses BlockPhaseColors.tint(for: .deload)"
      pattern: "BlockPhaseColors.tint"
    - from: "fitbod/App/RootView.swift"
      to: "fitbod/Periodization/StartBlockCTA.swift"
      via: "TodayView body conditionally renders StartBlockCTA(onStart: { pendingBlockBuilder = .template(BlockTemplates.blank) }) when activeBlocks.isEmpty"
      pattern: "StartBlockCTA"
---

<objective>
Ship the rest of the Today-tab banner stack that wraps BlockCard from plan 04-04a: DeloadWeekBanner (top-pinned during deload weeks), ConsiderDeloadBanner (UI scaffold; Phase 4 stub never renders), StartBlockCTA (no-active-block empty state), and the TodayView rewire that stacks them in the locked order. Closes BLOCK-05 (deload weeks visually distinct via banner + tint) and BLOCK-06a (advisory scaffold present; stub returns false so banner stays hidden until Phase 5 BLOCK-06b ships the real signal).

Purpose: this plan is the second half of the original plan 04-04 (split per checker warning #7 — original was 3 tasks with 5 new views + tests; split rebalances to 2 tasks each). The locked stacking order (`DeloadWeekBanner` → `ConsiderDeloadBanner` → `BlockCard` → `ResumeWorkoutBanner` → fallback) is the contract Phase 5 inherits without restructuring.

Output: Three new SwiftUI views in `fitbod/Periodization/`, TodayView body rewrite (preserves the BlockCard insertion from 04-04a + adds the surrounding banners + ScrollView wrap), one new test suite that pins the stacking-order contract via source-anchor positional asserts.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/STATE.md

@.planning/phases/04-periodization-blocks/04-CONTEXT.md
@.planning/phases/04-periodization-blocks/04-RESEARCH.md
@.planning/phases/04-periodization-blocks/04-UI-SPEC.md
@.planning/phases/04-periodization-blocks/04-PATTERNS.md
@.planning/phases/04-periodization-blocks/04-01-PLAN.md
@.planning/phases/04-periodization-blocks/04-02-PLAN.md
@.planning/phases/04-periodization-blocks/04-04a-PLAN.md

@fitbod/App/RootView.swift
@fitbod/Models/UserSettings.swift
@fitbod/Sessions/ResumeWorkoutBanner.swift

<interfaces>
<!-- Phase 4 types from plans 04-01, 04-02, 04-04a this plan consumes. -->

From plan 04-01 (shipped):
- `enum BlockPhaseColors` with `.tint(for: BlockPhaseKind) -> Color`.
- `protocol FatigueAdvisory: Sendable` + `struct FatigueSuggestion: Sendable` + `struct SessionContext: Sendable`.
- `struct StubFatigueAdvisory: FatigueAdvisory` returning false / empty reason.
- `enum PeriodizationEngine` with `.phase(for: Block, on: Date) -> BlockPhase?`, `.weekContext(for:weekIndex:on:) -> MesocycleWeekContext?` returning Sendable snapshot with `phaseKind` scalar field.
- `BlockTemplates.blank` for StartBlockCTA's "Start a Block" tap.

From plan 04-02 (shipped):
- `BlockDraft(template: BlockTemplate)` and `BlockBuilderView(draft: BlockDraft, editing: Block?)` presentable as .sheet(item:).

From plan 04-04a (shipped):
- `struct BlockCard: View` with `public init(block: Block)`.
- TodayView already has `@Query(filter: #Predicate<Block> { $0.isActive == true }) private var activeBlocks: [Block]` hoisted at the top + `BlockCard(block: active)` inserted above ResumeWorkoutBanner. This plan extends the surrounding structure.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: DeloadWeekBanner + ConsiderDeloadBanner + StartBlockCTA</name>
  <read_first>
    fitbod/Sessions/ResumeWorkoutBanner.swift (banner shape analog),
    fitbod/Periodization/BlockPhaseColors.swift (from plan 04-01),
    fitbod/Prescription/FatigueAdvisory.swift (from plan 04-01),
    fitbod/Prescription/StubFatigueAdvisory.swift (from plan 04-01),
    fitbod/Models/UserSettings.swift (for deloadAlertEnabled gate — verify field already exists per CONTEXT line 149),
    .planning/phases/04-periodization-blocks/04-UI-SPEC.md (lines 156-189 deload banner + advisory + StartBlockCTA copy),
    .planning/phases/04-periodization-blocks/04-PATTERNS.md (lines 741-813 DeloadWeekBanner / ConsiderDeloadBanner / StartBlockCTA)
  </read_first>
  <files>fitbod/Periodization/DeloadWeekBanner.swift, fitbod/Periodization/ConsiderDeloadBanner.swift, fitbod/Periodization/StartBlockCTA.swift</files>
  <action>
    (1) Create fitbod/Periodization/DeloadWeekBanner.swift as `public struct DeloadWeekBanner: View`:
      - `public let currentPhaseKind: BlockPhaseKind` (value-type input — does NOT hold a BlockPhase @Model reference; the caller resolves the phase via PeriodizationEngine and passes only the kind down per the MesocycleWeekContext Sendable snapshot contract from plan 04-01)
      - `public init(currentPhaseKind: BlockPhaseKind)`
      - Body: VStack(alignment: .leading, spacing: 4) {
          Text("Deload week — recover, don't load.").font(.headline)
          Text("Working sets cut by ~50%. Weights held to phase intensity.").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(BlockPhaseColors.tint(for: .deload))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Deload week active. Working sets are cut by approximately fifty percent. Weights are held at deload phase intensity.")
      Non-dismissible — no @State, no trailing button.
      (NB: `currentPhaseKind` is kept as an init param for API future-proofing — Phase 5 may need to vary copy by phase variant; today the banner only renders when kind == .deload.)
    
    (2) Create fitbod/Periodization/ConsiderDeloadBanner.swift as `public struct ConsiderDeloadBanner: View`:
      - `public let advisory: any FatigueAdvisory`
      - `@State private var dismissed: Bool = false`
      - `public init(advisory: any FatigueAdvisory = StubFatigueAdvisory()) { self.advisory = advisory }`
      - Body:
        ```
        let sessionCtx = SessionContext()
        if dismissed || !advisory.shouldSuggest(context: sessionCtx) {
            EmptyView()
        } else {
            let suggestion = advisory.suggestion(context: sessionCtx)
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(Color.yellow)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Consider a deload this week.").font(.body)
                    Text(suggestion.reason).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Adjust block") {
                    // Phase 4: no-op stub; Phase 5 (BLOCK-06b) wires real action
                }
                .foregroundStyle(Color.accentColor)
                Button { dismissed = true } label: { Image(systemName: "xmark").foregroundStyle(.secondary) }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Dismiss deload advisory")
            }
            .padding(16)
            .background(Color(.systemYellow).opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Advisory: consider a deload this week. \\(suggestion.reason).")
            .accessibilityHint("Tap to adjust your block, or swipe right to dismiss.")
        }
        ```
      Phase 4 stub returns false → body is always EmptyView() at runtime. Phase 5 BLOCK-06b swaps the advisory injection (without UI change).
    
    (3) Create fitbod/Periodization/StartBlockCTA.swift as `public struct StartBlockCTA: View`:
      - `public let onStart: () -> Void`
      - `public init(onStart: @escaping () -> Void)`
      - Body: VStack(spacing: 8) {
          Text("No active block.").font(.headline)
          Text("Define a training block to see your phase, week, and deloads here.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
          Button("Start a Block", action: onStart).foregroundStyle(Color.accentColor).padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
  </action>
  <verify>
    <automated>xcodebuild build -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' 2>&amp;1 | grep -E 'BUILD SUCCEEDED|error:'</automated>
  </verify>
  <done>
    DeloadWeekBanner + ConsiderDeloadBanner + StartBlockCTA compile against Swift 6 strict concurrency; DeloadWeekBanner takes `currentPhaseKind: BlockPhaseKind` (value type, no @Model handle); ConsiderDeloadBanner's stub returns false so its body is EmptyView at runtime; StartBlockCTA's onStart closure is callable.
  </done>
</task>

<task type="auto">
  <name>Task 2: TodayView rewire with full banner stack + StartBlockCTA sheet wiring + TodayViewBlockStackingTests</name>
  <read_first>
    fitbod/App/RootView.swift (TodayView body as modified by plan 04-04a — confirm BlockCard insertion + activeBlocks @Query),
    fitbod/Sessions/ResumeWorkoutBanner.swift,
    fitbod/Periodization/BlockCard.swift (from plan 04-04a),
    fitbod/Periodization/BlockPhaseColors.swift,
    fitbod/Prescription/PeriodizationEngine.swift (from plan 04-01 — phase resolution),
    .planning/phases/04-periodization-blocks/04-UI-SPEC.md (lines 381-405 stacking order),
    .planning/phases/04-periodization-blocks/04-PATTERNS.md (lines 1374-1455 TodayView rewrite pattern)
  </read_first>
  <files>fitbod/App/RootView.swift, fitbodTests/TodayViewBlockStackingTests.swift</files>
  <action>
    (1) Modify fitbod/App/RootView.swift's TodayView struct (already has `activeBlocks` @Query and `BlockCard(block: active)` inserted by plan 04-04a):
      - Add `@State private var pendingBlockBuilder: PendingBlockBuilder? = nil` where `private enum PendingBlockBuilder: Identifiable { case template(BlockTemplate); var id: String { "template" } }`. (Simple enum scoped to TodayView — separate from RoutinesListView's enum to avoid coupling.)
      - Wrap the existing VStack in a ScrollView (so the full banner stack fits vertically without flexible-layout collisions). The structure becomes:
        ```
        ScrollView {
            VStack(spacing: 0) {
                // (1) Deload-week banner — conditional on current week being deload
                if let active = activeBlocks.first,
                   let phase = PeriodizationEngine.phase(for: active, on: .now),
                   phase.kind == .deload {
                    DeloadWeekBanner(currentPhaseKind: phase.kind)
                }
                // (2) ConsiderDeloadBanner — Phase 4 stub never renders
                ConsiderDeloadBanner()
                // (3) BlockCard OR StartBlockCTA
                if let active = activeBlocks.first {
                    BlockCard(block: active)
                } else {
                    StartBlockCTA(onStart: { pendingBlockBuilder = .template(BlockTemplates.blank) })
                }
                // (4) ResumeWorkoutBanner (existing)
                ResumeWorkoutBanner(
                    onResume: { session in navigationPath.append(SessionRoute.logger(session)) },
                    onDiscard: { session in ctx.delete(session); try? ctx.save() }
                )
                // (5) Existing 'No workout in progress' fallback content — only when no active block
                if activeBlocks.isEmpty {
                    Spacer().frame(height: 24)
                    Text("No workout in progress").font(.title2).fontWeight(.semibold)
                    Text("Start a workout from your Routines tab.").foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
                }
            }
        }
        .navigationTitle("Today")
        .navigationDestination(for: SessionRoute.self) { ... }
        .sheet(item: $pendingBlockBuilder) { pending in
            switch pending {
            case .template(let template):
                BlockBuilderView(draft: BlockDraft(template: template))
            }
        }
        ```
      - Preserve every navigation modifier and existing fallback copy unchanged.
      
      Defer the BlockReviewView sheet trigger to plan 04-08 — this plan ships only the BlockCard surface + banner stack.
    
    (2) Create fitbodTests/TodayViewBlockStackingTests.swift as `@MainActor @Suite("TodayViewBlockStacking", .serialized)`. Pure-source string-anchor tests on RootView.swift (since the SwiftUI body is not unit-renderable, the tests pin the source contract):
      - `todayViewSourceContainsBannerStackingOrder`: read RootView.swift source; assert ordering of substring positions: `"DeloadWeekBanner"` appears BEFORE `"ConsiderDeloadBanner"` AND `"ConsiderDeloadBanner"` appears BEFORE `"BlockCard"` AND `"BlockCard"` appears BEFORE `"ResumeWorkoutBanner"` AND `"ResumeWorkoutBanner"` appears BEFORE `"No workout in progress"`. Use `source.range(of: substring)?.lowerBound` to compare positions.
      - `todayViewHasActiveBlockQuery`: assert source contains `"$0.isActive"` AND `"activeBlocks"`.
      - `todayViewConditionallyRendersStartBlockCTA`: assert source contains `"StartBlockCTA"` AND `"activeBlocks.isEmpty"` close together (within 300 chars of each other).
      - `todayViewConditionallyRendersDeloadBannerWhenPhaseIsDeload`: assert source contains both `"DeloadWeekBanner"` AND `"phase.kind == .deload"`.
      - `startBlockCTACopyVerbatim`: read StartBlockCTA.swift source; assert it contains `"No active block."`, `"Define a training block to see your phase, week, and deloads here."`, `"Start a Block"`.
      - `deloadBannerCopyVerbatim`: read DeloadWeekBanner.swift source; assert it contains `"Deload week — recover, don't load."` AND `"Working sets cut by ~50%. Weights held to phase intensity."`.
      - `considerDeloadBannerCopyVerbatim`: read ConsiderDeloadBanner.swift source; assert it contains `"Consider a deload this week."` AND `"Adjust block"`.
      - `noWorkoutFallbackPreserved`: assert RootView.swift still contains the original `"No workout in progress"` and `"Start a workout from your Routines tab."` strings (no regression in the existing fallback content).
      - `blockCardReceivesBlockValue`: assert RootView.swift contains `"BlockCard(block:"` — pins the value-driven init contract from plan 04-04a (no @Query duplication).
  </action>
  <verify>
    <automated>xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing fitbodTests/TodayViewBlockStacking 2>&amp;1 | grep -E 'Test Suite.*passed|FAIL|error'</automated>
  </verify>
  <done>
    TodayView builds with the full stack ordering (Deload / Consider / Card-or-CTA / Resume / Fallback); StartBlockCTA tap presents BlockBuilderView with .blank template; ConsiderDeloadBanner stub returns false so body is EmptyView at runtime (UI scaffold present for Phase 5); TodayViewBlockStackingTests passes all 9 source-anchor assertions; Phase 2 ResumeWorkoutBanner / TodayView regression tests still GREEN; plan 04-04a's BlockCardWeekNavigationTests still GREEN.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| TodayView ScrollView body → banner conditional renders | Read-only — each banner reads from `activeBlocks.first` and engine pure functions. No mutation. |
| `Start a Block` CTA → BlockBuilderView | StartBlockCTA tap presents the builder; user must explicitly fill + save. No auto-create. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-04-04b-01 | Tampering | StubFatigueAdvisory cannot mutate Block (BLOCK-08 type-level enforcement from plan 04-01) | mitigate | Compiler refuses an impl that returns a Block-mutating value. Phase 5's BLOCK-06b real advisory inherits the same contract. |
| T-04-04b-02 | Information Disclosure | DeloadWeekBanner + ConsiderDeloadBanner copy visible without auth | accept | Single-user offline app per PROJECT.md. |
| T-04-04b-03 | Denial of Service | ScrollView with multiple conditional banners | accept | Even when all banners render, total memory cost is < 1KB — SwiftUI lazy-evaluates conditional body branches. |
</threat_model>

<verification>
- `xcodebuild build -scheme fitbod` succeeds.
- `xcodebuild test -only-testing fitbodTests/TodayViewBlockStacking` exits 0.
- Plan 04-04a's BlockCardWeekNavigationTests still GREEN.
- Phase 1/2/3 tests still GREEN.
- Plans 04-01, 04-02, 04-03 suites still GREEN.
- Manual sim run: launch on iPhone 16 simulator, with no active block; assert StartBlockCTA renders, ResumeWorkoutBanner is empty, fallback copy is visible. Tap "Start a Block"; assert BlockBuilderView appears with .blank template. Create an active block via the builder, save; back at Today, assert BlockCard replaces StartBlockCTA, DeloadWeekBanner only shows if the active block's current week resolves to .deload, ConsiderDeloadBanner is hidden (Stub returns false).
</verification>

<success_criteria>
- BLOCK-05: deload weeks visually distinct via DeloadWeekBanner (top pinned) + BlockCard background tint (which is already wired by plan 04-04a).
- BLOCK-06a: ConsiderDeloadBanner UI scaffold ships; StubFatigueAdvisory returns false so banner stays hidden (Phase 5 BLOCK-06b swaps the signal without touching UI).
- StartBlockCTA appears when no active block exists.
- TodayView stack ordering is locked in source: Deload → Consider → Card/CTA → Resume → Fallback.
- TodayViewBlockStackingTests passes.
</success_criteria>

<output>
After completion, create `.planning/phases/04-periodization-blocks/04-04b-SUMMARY.md`.
</output>
