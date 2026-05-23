---
phase: 04-periodization-blocks
plan: 04a
type: execute
wave: 2
depends_on: ["04-01", "04-02"]
files_modified:
  - fitbod/Periodization/BlockCard.swift
  - fitbod/Periodization/MesocycleWeekPage.swift
  - fitbod/App/RootView.swift
  - fitbodTests/BlockCardWeekNavigationTests.swift
autonomous: true
requirements: [BLOCK-02, BLOCK-03]

must_haves:
  truths:
    - "When the user has an active Block, TodayView passes it down to BlockCard via init (BlockCard receives `block: Block`); BlockCard does NOT re-query the active block (single-source-of-truth at TodayView)"
    - "BlockCard shows the current week's phase chip (BlockPhaseColors.color for ctx.phaseKind), 'Week N of M' linear badge, days-remaining caption ('{N} days remaining' / 'Completed' / 'Starts in {N} days'), and multipliers preview ('×{vol} vol · ×{int} int') sourced from MesocycleWeekContext scalar fields (NOT context.phase.x — there is no phase reference)"
    - "BlockCard's internal TabView with .tabViewStyle(.page(indexDisplayMode: .never)) lets the user swipe horizontally between weeks; selectedWeekIndex initializes to the current-week index per PeriodizationEngine.weekIndex(for: block, on: .now)"
    - "BlockCard renders above the existing ResumeWorkoutBanner in TodayView when activeBlock is non-nil (D-06 stacking order half — the remaining banners DeloadWeekBanner / ConsiderDeloadBanner / StartBlockCTA land in plan 04-04b)"
    - "BlockCardWeekNavigationTests turn GREEN; week-index math + days-remaining math + multiplier formatting are pinned"
  artifacts:
    - path: "fitbod/Periodization/BlockCard.swift"
      provides: "Today-tab card; takes `block: Block` as init param (pure value-driven view per checker warning #9 — no duplicate @Query); internal TabView paging over MesocycleWeekPage (one per week of the block); selectedWeekIndex @State initialized to currentWeekIndex; outer card background tints to the selected week's BlockPhaseColors.tint(for: phaseKind); overflow Menu (Edit Block / End Block)"
      contains: "struct BlockCard"
    - path: "fitbod/Periodization/MesocycleWeekPage.swift"
      provides: "One swipe-pager page rendering MesocycleWeekContext scalar fields (phase chip + 'Week N of M' badge + days-remaining caption + multipliers preview + scheduled routines list); accessibilityElement(children: .combine)"
      contains: "struct MesocycleWeekPage"
    - path: "fitbod/App/RootView.swift"
      provides: "TodayView gets @Query<Block>(filter: #Predicate { $0.isActive }) as the SINGLE source of truth for the active block; passes `activeBlocks.first` down to BlockCard (per warning #9). The DeloadWeekBanner / ConsiderDeloadBanner / StartBlockCTA / .sheet for BlockBuilderView all land in plan 04-04b — this plan only inserts BlockCard above the existing ResumeWorkoutBanner."
      contains: "BlockCard(block:"
  key_links:
    - from: "fitbod/Periodization/BlockCard.swift"
      to: "fitbod/Prescription/PeriodizationEngine.swift"
      via: "PeriodizationEngine.weekIndex / .phase / .weekContext drive initial selection + per-page rendering"
      pattern: "PeriodizationEngine"
    - from: "fitbod/App/RootView.swift"
      to: "fitbod/Periodization/BlockCard.swift"
      via: "TodayView body conditionally renders BlockCard(block: active) above ResumeWorkoutBanner when activeBlocks.first is non-nil"
      pattern: "BlockCard(block:"
---

<objective>
Ship the BlockCard surface and its internal MesocycleWeekPage swipe-pager. After this plan, when the user has an active block, BlockCard renders above the existing ResumeWorkoutBanner on Today and shows the current week's phase chip, "Week N of M", days remaining, and multipliers preview; horizontal swipe browses past or future weeks of the mesocycle. Closes BLOCK-02 (active block visible with phase chip / Week N of M / days remaining / phase color) and BLOCK-03 (swipe between weeks).

Purpose: this plan is the focused half of the original plan 04-04. Per checker warning #7, the original 04-04 was split — the banner stack (DeloadWeekBanner, ConsiderDeloadBanner, StartBlockCTA) and the TodayView stacking-order tests land in plan 04-04b (next wave 2 plan). This plan delivers the BlockCard core. Per checker warning #9, BlockCard receives `block: Block` as init param rather than running its own @Query — TodayView is the single source of truth, BlockCard is a pure value-driven view (eliminates the duplicate-@Query pattern flagged by the checker).

Output: Two new SwiftUI views in `fitbod/Periodization/`, a minimal TodayView edit that hoists the active-block @Query and passes the active block to BlockCard, one new test suite that pins week-navigation math.
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

@fitbod/App/RootView.swift
@fitbod/Models/Block.swift
@fitbod/Models/BlockPhase.swift
@fitbod/Sessions/ResumeWorkoutBanner.swift

<interfaces>
<!-- Phase 4 types from plan 04-01 + 04-02 this plan consumes. -->

From plan 04-01 (shipped):
- `enum PeriodizationEngine` with `.phase(for: Block, on: Date) -> BlockPhase?`, `.weekIndex(for: Block, on: Date) -> Int?`, `.weekContext(for: Block, weekIndex: Int, on: Date = .now) -> MesocycleWeekContext?`, `.recommendedNextKind(after: BlockPhaseKind) -> BlockPhaseKind`.
- `struct MesocycleWeekContext: Sendable` — VALUE SNAPSHOT (no @Model handle). Stored properties (all `public let`): `phaseKind: BlockPhaseKind`, `phaseOrder: Int`, `phaseWeeks: Int`, `weekInPhase: Int`, `phaseVolumeMultiplier: Double`, `phaseIntensityMultiplier: Double`, `weekStartDate: Date`, `weekEndDate: Date`, `daysRemaining: Int`, `isCurrentWeek: Bool`, `isDeloadWeek: Bool`. NO `phase` field — consumers MUST read scalar fields directly (e.g., `ctx.phaseKind`, `ctx.phaseIntensityMultiplier`).
- `enum BlockPhaseColors` with `.color(for:)`, `.tint(for:)`, `.phaseLabel(_:)`.

From plan 04-02 (shipped):
- `BlockDraft(block: Block)` and `BlockBuilderView(draft: BlockDraft, editing: Block?)` presentable as .sheet(item:).

From fitbod/App/RootView.swift (existing TodayView shape — lines 237-274 — the rewrite hoists the active-block @Query but otherwise preserves existing fallback):
```
private struct TodayView: View {
    @Environment(\.modelContext) private var ctx
    @State private var navigationPath = NavigationPath()
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 16) {
                ResumeWorkoutBanner(onResume: ..., onDiscard: ...)
                Spacer()
                Text("No workout in progress").font(.title2).fontWeight(.semibold)
                Text("Start a workout from your Routines tab.").foregroundStyle(.secondary).multilineTextAlignment(.center)
                Spacer()
            }
            .padding(.horizontal, 32)
            .navigationTitle("Today")
            .navigationDestination(for: SessionRoute.self) { ... }
        }
    }
}
```

From fitbod/Sessions/ResumeWorkoutBanner.swift (banner shape analog):
```
public struct ResumeWorkoutBanner: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Session> { $0.completedAt == nil }) private var activeSessions: [Session]
    public var body: some View {
        if let active = activeSessions.first { bannerBody(active: active) } else { EmptyView() }
    }
}
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: BlockCard (value-driven init) + MesocycleWeekPage with TabView page paging</name>
  <read_first>
    fitbod/Sessions/ResumeWorkoutBanner.swift (banner shape — full file),
    fitbod/App/RootView.swift (TabView selection-binding pattern — lines 152-199),
    fitbod/Periodization/BlockPhaseColors.swift (from plan 04-01),
    fitbod/Prescription/PeriodizationEngine.swift (from plan 04-01),
    fitbod/Periodization/MesocycleWeekContext.swift (from plan 04-01 — confirm Sendable scalar-field shape; NO `.phase` accessor),
    fitbod/ExerciseLibrary/IntentFilterChipRow.swift (chip styling — 44pt HIG capsule),
    .planning/phases/04-periodization-blocks/04-UI-SPEC.md (lines 138-156 BlockCard copy + lines 393-405 swipe-pager flow),
    .planning/phases/04-periodization-blocks/04-PATTERNS.md (lines 627-738 BlockCard + MesocycleWeekPage patterns)
  </read_first>
  <files>fitbod/Periodization/BlockCard.swift, fitbod/Periodization/MesocycleWeekPage.swift</files>
  <action>
    (1) Create fitbod/Periodization/BlockCard.swift as `public struct BlockCard: View`:
      - `public let block: Block` (value-driven — per checker warning #9, BlockCard does NOT own its own @Query; TodayView is the single source of truth and passes the active block down via init).
      - `@State private var selectedWeekIndex: Int = 0`
      - `@State private var pendingBuilderForEdit: Block? = nil` (for the overflow Menu Edit Block action).
      - `@State private var pendingEndConfirm: Block? = nil`
      - `@Environment(\.modelContext) private var ctx`
      - `public init(block: Block) { self.block = block }`
      - Body: directly call `cardBody(active: block)` (no `if let` guard — TodayView guarantees the block is present before constructing BlockCard).
      - `private func cardBody(active: Block) -> some View`:
        Build totalWeeks = `(active.phases ?? []).reduce(0) { $0 + $1.weeks }`. If `totalWeeks <= 0` return EmptyView() (defensive — block with no phases should not happen, but no crash).
        Compute the current week's phase kind for the outer card tint via the engine snapshot:
        ```
        let currentPhaseKind: BlockPhaseKind = {
            if let ctx = PeriodizationEngine.weekContext(
                for: active,
                weekIndex: PeriodizationEngine.weekIndex(for: active, on: .now) ?? 0,
                on: .now
            ) {
                return ctx.phaseKind
            }
            return .accumulation
        }()
        ```
        (Reads only scalar fields from MesocycleWeekContext — no `ctx.phase.x` accessor path.)
        VStack(spacing: 0) {
          HStack { Text(active.name).font(.headline); Spacer(); overflowMenu(for: active) }
            .padding(.horizontal, 16).padding(.top, 12)
          TabView(selection: $selectedWeekIndex) {
            ForEach(0..<totalWeeks, id: \.self) { weekIdx in
              MesocycleWeekPage(block: active, weekIndex: weekIdx)
                .tag(weekIdx)
            }
          }
          .tabViewStyle(.page(indexDisplayMode: .never))
          .frame(minHeight: 200)  // ~140 content + chrome per UI-SPEC line 54
        }
        .background(BlockPhaseColors.tint(for: currentPhaseKind))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .accessibilityHint("Swipe horizontally to navigate between weeks of the mesocycle.")
        .onAppear {
          selectedWeekIndex = PeriodizationEngine.weekIndex(for: active, on: .now) ?? 0
        }
      - Overflow Menu (UI-SPEC line 145):
        ```
        @ViewBuilder
        private func overflowMenu(for block: Block) -> some View {
            Menu {
                Button("Edit Block") { pendingBuilderForEdit = block }
                Button("End Block", role: .destructive) { pendingEndConfirm = block }
            } label: {
                Image(systemName: "ellipsis.circle").foregroundStyle(.secondary)
            }
            .accessibilityLabel("Block actions")
        }
        ```
      - End block alert + action (attach the alert to the body chain):
        ```
        .alert("End block?", isPresented: Binding(get: { pendingEndConfirm != nil }, set: { if !$0 { pendingEndConfirm = nil } })) {
            Button("End Block", role: .destructive) {
                if let target = pendingEndConfirm {
                    do { try ctx.transaction { target.isActive = false; try ctx.save() } }
                    catch { /* swallow — defensive, no user-visible error path for single-user offline app */ }
                }
                pendingEndConfirm = nil
            }
            Button("Cancel", role: .cancel) { pendingEndConfirm = nil }
        } message: { Text("End this block now? You can review it from the Routines tab.") }
        ```
        (UI-SPEC line 332 destructive confirmation copy verbatim.)
      - .sheet(item: $pendingBuilderForEdit) { block in BlockBuilderView(draft: BlockDraft(block: block), editing: block) }
    
    (2) Create fitbod/Periodization/MesocycleWeekPage.swift as `public struct MesocycleWeekPage: View`:
      - `public let block: Block`
      - `public let weekIndex: Int`
      - `public init(block: Block, weekIndex: Int)`
      - Body resolves context: `let weekContext = PeriodizationEngine.weekContext(for: block, weekIndex: weekIndex, on: .now)`. If nil, render a defensive fallback Text("Block ended — review pending.").font(.caption).foregroundStyle(.secondary). Otherwise:
        ```
        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 4) {
              // phase chip — reads ctx.phaseKind directly (scalar Sendable field)
              Text(BlockPhaseColors.phaseLabel(weekContext.phaseKind))
                  .font(.caption)
                  .padding(.horizontal, 12).padding(.vertical, 6)
                  .background(BlockPhaseColors.color(for: weekContext.phaseKind))
                  .foregroundStyle(Color.white)
                  .clipShape(Capsule())
                  .frame(minWidth: 44, minHeight: 44, alignment: .leading)
          }
          // week badge — Color(.systemGray6) capsule, primary text
          Text("Week \(weekIndex + 1) of \(totalWeeks(of: block))")
              .font(.headline)
              .padding(.horizontal, 8).padding(.vertical, 4)
              .background(Color(.systemGray6))
              .clipShape(Capsule())
          // days remaining caption
          Text(daysRemainingText(weekContext: weekContext))
              .font(.caption).foregroundStyle(.secondary)
          // multipliers preview — reads scalar fields directly
          Text(String(format: "×%.2f vol · ×%.2f int", weekContext.phaseVolumeMultiplier, weekContext.phaseIntensityMultiplier))
              .font(.caption).foregroundStyle(.secondary)
          Divider()
          // scheduled routines list
          if let routines = scheduledRoutines(for: block), !routines.isEmpty {
              Text("Routines this week").font(.caption).foregroundStyle(.secondary)
              ForEach(routines) { routine in
                  HStack { Text(routine.name).font(.body); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary) }
              }
          } else {
              Text("No routines linked to this block.").font(.caption).foregroundStyle(.secondary)
          }
        }
        .padding(16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(weekContext: weekContext))
        ```
      - Helpers (mark `internal` rather than `private` so plan 04-04's tests can call them directly per checker warning #7 split — actual test wiring lives in plan 04-04b):
        - `func totalWeeks(of block: Block) -> Int { (block.phases ?? []).reduce(0) { $0 + $1.weeks } }`
        - `func daysRemainingText(weekContext: MesocycleWeekContext) -> String`: per UI-SPEC line 148 — if `weekContext.isCurrentWeek` return "\(weekContext.daysRemaining) days remaining"; if the week is in the past (compare weekContext.weekEndDate < .now) return "Completed"; else return "Starts in \(daysUntilWeekStart) days" where daysUntilWeekStart = max(0, Int(floor(weekContext.weekStartDate.timeIntervalSince(.now) / 86400))).
        - `func scheduledRoutines(for block: Block) -> [Routine]?`: return `block.routines?.sorted { $0.name < $1.name }`.
        - `private func accessibilityLabel(weekContext: MesocycleWeekContext) -> String`: per UI-SPEC line 528 — "Week \(weekIndex + 1) of \(totalWeeks(of: block)), \(BlockPhaseColors.phaseLabel(weekContext.phaseKind)) phase, volume multiplier \(weekContext.phaseVolumeMultiplier), intensity multiplier \(weekContext.phaseIntensityMultiplier), \(routinesCount) routines this week.".
    
    (3) Modify fitbod/App/RootView.swift's private TodayView struct — ONLY hoist the active-block @Query and insert BlockCard above ResumeWorkoutBanner. The full banner stack (DeloadWeekBanner / ConsiderDeloadBanner / StartBlockCTA / BlockBuilderView .sheet) lands in plan 04-04b.
      - Add at the top of TodayView's properties: `@Query(filter: #Predicate<Block> { $0.isActive == true }) private var activeBlocks: [Block]`.
      - Inside the existing VStack body, immediately above the existing `ResumeWorkoutBanner(...)` call, insert:
        ```
        if let active = activeBlocks.first {
            BlockCard(block: active)
        }
        ```
      - Do NOT remove the existing "No workout in progress" / "Start a workout from your Routines tab." fallback content — it still renders when there is no active session, regardless of whether a block is active. Plan 04-04b restructures the surrounding container if needed (likely a ScrollView wrap for the full banner stack).
      - Preserve `.navigationTitle("Today")` and `.navigationDestination(for: SessionRoute.self) { ... }` exactly as before.
  </action>
  <verify>
    <automated>xcodebuild build -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' 2>&amp;1 | grep -E 'BUILD SUCCEEDED|error:'</automated>
  </verify>
  <done>
    BlockCard.swift + MesocycleWeekPage.swift compile against Swift 6 strict concurrency; BlockCard takes `block: Block` as init param (no internal @Query); TabView pager initializes selectedWeekIndex to current-week index; tint background swaps per current phase kind sourced from MesocycleWeekContext scalar fields; overflow Menu wires Edit Block (.sheet) + End Block (.alert + transaction); MesocycleWeekPage renders the phase chip / Week badge / days-remaining caption / multipliers preview via ctx.phaseKind / ctx.phaseVolumeMultiplier / ctx.phaseIntensityMultiplier (no ctx.phase.x access); TodayView hoists the active-block @Query and passes activeBlocks.first into BlockCard via init.
  </done>
</task>

<task type="auto">
  <name>Task 2: BlockCardWeekNavigationTests turn GREEN</name>
  <read_first>
    fitbod/Periodization/BlockCard.swift (just shipped),
    fitbod/Periodization/MesocycleWeekPage.swift (just shipped),
    fitbod/App/RootView.swift (just modified — TodayView active-block @Query + BlockCard insertion),
    fitbodTests/SchemaV2MigrationTests.swift (in-memory fixture template),
    fitbodTests/PeriodizationEngineTests.swift (helper makeBlock pattern from plan 04-01)
  </read_first>
  <files>fitbodTests/BlockCardWeekNavigationTests.swift</files>
  <action>
    Create fitbodTests/BlockCardWeekNavigationTests.swift as `@MainActor @Suite("BlockCardWeekNavigation", .serialized)` struct using the in-memory ModelContainer fixture. These tests exercise the engine + view helpers BlockCard / MesocycleWeekPage call into. Since SwiftUI views can't be unit-rendered headlessly with Swift Testing, the tests target the pure-function pathways (PeriodizationEngine + MesocycleWeekContext) and the internal helpers from MesocycleWeekPage that Task 1 marked `internal`.
    
    Required @Test functions:
    - `initialSelectedWeekIndexIsCurrentWeek`: build an 8-week block starting 14 days ago; assert `PeriodizationEngine.weekIndex(for: block, on: .now) == 2` (which BlockCard uses for initial selection).
    - `daysRemainingForCurrentWeek`: 8-week block startDate -3 days ago; `weekContext(for: block, weekIndex: 0, on: .now)` returns daysRemaining == 4 (week 0 ends at day 7; 7 - 3 = 4); assert isCurrentWeek == true.
    - `daysRemainingForFutureWeekIsZero`: 8-week block startDate now; `weekContext(for: block, weekIndex: 3, on: .now)` returns daysRemaining == 0 and isCurrentWeek == false (used by MesocycleWeekPage.daysRemainingText to fall into the "Starts in N days" branch).
    - `pastWeekContextResolvesPhase`: 8-week block startDate -28 days; `weekContext(for: block, weekIndex: 0, on: .now)` returns phaseKind == .accumulation; weekIndex 3 returns next phase kind based on the synthetic chain.
    - `deloadWeekDetected`: 4-week block with [accumulation 3, deload 1]; `weekContext(for: block, weekIndex: 3, on: .now)` returns isDeloadWeek == true AND phaseKind == .deload.
    - `weekBadgeFormatIsOneIndexed`: weekIndex 4 (0-based) renders as "Week 5 of 8" — assert MesocycleWeekPage's `totalWeeks(of:)` + the (weekIndex + 1) format produce the expected string for an 8-week block.
    - `scheduledRoutinesSortedByName`: insert 3 Routines linked to the block (block.routines populated via inverse); MesocycleWeekPage.scheduledRoutines returns them in alphabetical order by name.
    - `daysRemainingTextCurrentWeekFormat`: synthetic weekContext with isCurrentWeek=true + daysRemaining=4; MesocycleWeekPage.daysRemainingText returns "4 days remaining".
    - `daysRemainingTextCompletedWeekFormat`: synthetic weekContext with weekEndDate in the past + isCurrentWeek=false; daysRemainingText returns "Completed".
    - `daysRemainingTextFutureWeekFormat`: synthetic weekContext with weekStartDate 21 days in the future + isCurrentWeek=false; daysRemainingText returns "Starts in 21 days".
    - `multiplierPreviewFormatUsesScalarFields`: directly construct a MesocycleWeekContext value with phaseVolumeMultiplier=0.85 and phaseIntensityMultiplier=0.88; assert that `String(format: "×%.2f vol · ×%.2f int", weekContext.phaseVolumeMultiplier, weekContext.phaseIntensityMultiplier)` produces "×0.85 vol · ×0.88 int" (pins the scalar-field read path — any reintroduction of `weekContext.phase.x` would break this test).
  </action>
  <verify>
    <automated>xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing fitbodTests/BlockCardWeekNavigation 2>&amp;1 | grep -E 'Test Suite.*passed|FAIL|error'</automated>
  </verify>
  <done>
    BlockCardWeekNavigationTests passes; week-index math, days-remaining math, and the scalar-field multiplier-format path are all pinned; Phase 2 ResumeWorkoutBanner / TodayView regression tests still GREEN.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Today-tab @Query → SwiftData | Read-only single-row predicate (`isActive == true`) — cached and cheap. Hoisted to TodayView; BlockCard is value-driven. |
| Block.routines inverse → BlockCard | Reading `block.routines` requires the relationship to be loaded; SwiftData lazy-loads on access. No mutation. |
| `End Block` overflow action → Block write | Writes `isActive = false` via `ctx.transaction`. Confirmation alert is the user gate. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-04-04a-01 | Tampering | `End Block` write is wrapped in `ctx.transaction` to honor the BLOCK-08 single-writer contract (only PeriodizationEngine.advance OR explicit user intent via BlockDraft.save / BlockCard.endBlock / BlockReviewView.acknowledgeAndDismiss) | mitigate | Confirmation alert + transactional save. No advisory code path can reach this write surface. |
| T-04-04a-02 | Information Disclosure | Block name + phase + multipliers visible on the home screen even with no auth | accept | Single-user offline app per PROJECT.md. Phone lock is the OS security layer. |
| T-04-04a-03 | Denial of Service | A pathological block with totalWeeks = 1000 would create 1000 TabView pages | mitigate | Stepper range 1-12 weeks per phase (plan 04-02); even a 100-phase block tops out at 1200 weeks. TabView with `.page` style lazy-renders pages so memory cost is bounded. No further mitigation. |
</threat_model>

<verification>
- `xcodebuild build -scheme fitbod` succeeds.
- `xcodebuild test -only-testing fitbodTests/BlockCardWeekNavigation` exits 0.
- Phase 1/2/3 tests still GREEN (no regression in RootView TabView wiring or ResumeWorkoutBanner behavior).
- Plan 04-01, 04-02, 04-03 suites still GREEN.
- Manual sim run (developer verification — not gated by this plan): launch on iPhone 16 simulator, create an active block via Routines → +Block → save; navigate to Today; assert BlockCard renders above ResumeWorkoutBanner with the right phase chip, week badge, days remaining, multipliers preview. Swipe horizontally; assert week pages advance. Toggle the active-block off via End Block; assert BlockCard disappears (plan 04-04b adds StartBlockCTA in its place).
</verification>

<success_criteria>
- BLOCK-02: active block visible on home screen with phase chip + Week N of M + days remaining + phase color coding.
- BLOCK-03: user can navigate weeks within a block via horizontal swipe.
- BlockCard receives `block: Block` via init (single-source-of-truth at TodayView; no duplicate @Query per warning #9).
- All consumer reads of MesocycleWeekContext use scalar fields (`ctx.phaseKind`, `ctx.phaseIntensityMultiplier`); no `ctx.phase.x` access path exists (per Sendable snapshot contract from plan 04-01).
- BlockCardWeekNavigationTests passes.
</success_criteria>

<output>
After completion, create `.planning/phases/04-periodization-blocks/04-04a-SUMMARY.md`.
</output>
