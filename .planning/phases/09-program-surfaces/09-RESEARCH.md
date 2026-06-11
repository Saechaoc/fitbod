# Phase 9: Program Surfaces — Research

**Researched:** 2026-06-11
**Domain:** SwiftUI + SwiftData navigation wiring, BRU design system, drag-reorder, Phase 8 service seams
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

All locked by spec §8 (+ §1 glossary, §5 edge surfaces):

- UI terminology: "Session" = `SessionTemplate`, "Routine" = `Split`, "Block" = `Block`. Never leak code names into UI copy.
- ProgramView rebuild: Empty state (guardrail-pinned) ONLY when zero blocks AND zero splits. Otherwise BLOCKS section (status-badged cards, ACTIVE first → READY → DRAFT → DONE, 3 most recent DONE + collapse) and ROUTINES section (rows with usage tags for non-completed blocks only). Tap BLOCK → `BlockOverviewScreen`. Tap ROUTINE → `SplitDetailView`. "+ NEW BLOCK" keeps existing choice/template/builder flow. No top-level session-template list.
- SplitDetailView (new): ordered slot list, drag-reorder with reindex-on-write, add slot via picker over `SessionTemplate`s or "new session" → `RoutineBuilderView`, remove slot, usage section (non-completed blocks). Live-edit banner when split sits on active block. Archive routes through `BlockLifecycleService.assertSplitDeletable`. Split archive = UI-level delete (archive-only from UI).
- BlockOverviewScreen live modes: split attach/swap (draft/ready ONLY — hidden on active), mode picker, day-chips (`fixedWeekly`; soft mismatch hint), Start CTA (ready), End action (active). Start while another active → confirm sheet → `BlockLifecycleService.start`.
- Block builder split band: existing `NewBlockLinkedRoutinesBand` becomes ONE split picker + mode picker + day-chips. Optional — save without = draft. Any edit → run all 3 copy-guardrail suites.
- Session template editor: live-edit banner when template reachable via slots → split → active block.
- TodayView `.emptySplit`: replace Phase 8 placeholder with real fix-it pointer navigating to `SplitDetailView`.
- Phase 8 service contracts (consume, don't reimplement): `TodayResolver.resolve`, `BlockLifecycleService.{start,end,attachSplit,swapSplit,assertSplitDeletable,decodeArchive}`, `TrainingDaysWriter.sort(weekdays:using:)`, `SessionFactory.start`.
- BlockOverviewScreen archived mode: rendered from `BlockLifecycleService.decodeArchive`; decode failure → `ArchiveUnreadableError` explicit error state, no live-template fallback.

### Claude's Discretion

- BRU component composition for new surfaces (reuse `BRUHeaderBar`, `BRUSectionHead`, `BRURow`, `BRUDivider`, `BRUActionPopover`, `BlockCard`, etc.), exact badge styling, collapse animation, day-chip layout.
- Drag-reorder implementation (note: New Block phase cards already shipped a hysteresis-gated row-local drag — reuse that pattern, NOT `List .onMove`, unless `List` fits BRU styling).

### Deferred Ideas (OUT OF SCOPE)

- Per-phase routine overrides; Progress charts over archives; top-level session-template library; V8 legacy-edge removal; device UAT items.
</user_constraints>

---

## Summary

Phase 9 is a pure UI/wiring phase: it makes the program graph visible and operable by rebuilding `ProgramView`, adding `SplitDetailView`, extending `BlockOverviewScreen` with live-edit controls, wiring `BlockBuilderView`'s split band, and replacing the `TodayView` `.emptySplit` placeholder. Every data layer (schema V7, Phase 8 services) is already shipped; no schema change is needed.

The critical mechanic to understand is the navigation architecture: `ProgramView` owns its own `NavigationStack` with a typed route enum that must expand from the current `BlockOverviewRoute` pattern to include a `SplitDetail` route. `TodayView` has its own `NavigationStack` with a separate `BlockOverviewRoute` `navigationDestination` already wired; it needs a matching `SplitDetailRoute` destination to support the `.emptySplit` fix-it CTA. Both tabs navigate independently per the one-NavigationStack-per-tab rule.

The drag-reorder pattern in `NewBlockPhaseListSection` / `NewBlockPhaseEditorRow` is the exact model to reuse for `SplitSlotRow` — hysteresis at 0.55 pitch, `@GestureState` row-local translation, long-press gate, parent aggregates boundary crossings only via `onReorderBegan/Target/Ended` callbacks, sibling gap shift via `.offset(y:)` with spring animation, commit-on-drop single `context.save()`. The pattern is copy-adapt, not extract-to-shared (BRU token names differ between BlockBuilderView's `NewBlockScreenTokens` and the new surfaces' `Color.bru*` tokens).

**Primary recommendation:** Use `BlockOverviewRoute` as the pattern for a new `ProgramRoute` enum in `ProgramView`. The TodayView side registers a separate `navigationDestination(for: SplitDetailRoute.self)`. No cross-tab navigation is needed.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| ProgramView BLOCKS/ROUTINES rendering | ProgramView (client) | SwiftData @Query | Pure read display; data already in store |
| SplitDetailView slot CRUD + drag-reorder | SplitDetailView (client) | `BlockLifecycleService.assertSplitDeletable` for archive guard | Slot mutation is local to the split; reindex-on-write = one `ctx.save()` |
| BlockOverviewScreen edit controls | BlockOverviewScreen (client) | `BlockLifecycleService.{start,end,attachSplit,swapSplit}` + `TrainingDaysWriter.sort` | All mutations routed through Phase 8 service layer |
| Navigation / routing | ProgramView's NavigationStack (program tab); TodayView's NavigationStack (today tab) | — | One stack per tab; no cross-tab navigation |
| Empty-state gate (zero blocks AND zero splits) | ProgramView (client) | Two @Query counts | Conditional in the view body |
| BlockBuilder split band | BlockBuilderView (existing) | Surgical edit to `NewBlockLinkedRoutinesBand` region | In-file replacement; no new file |
| Live-edit banner detection | SplitDetailView / RoutineBuilderView (client) | In-memory post-filter on `split.blocks` / `slot.split.blocks` | Multi-level optional chain — not expressible in SwiftData `#Predicate`; post-filter in Swift |
| Archived block decode | BlockOverviewScreen (client) | `BlockLifecycleService.decodeArchive` | Typed error surface; no live fallback |
| TodayView fix-it CTA | TodayView (client) | `navigationPath.append(SplitDetailRoute)` | TodayView owns its navigationPath |

---

## Standard Stack

### Core (all already installed, no new packages)

| Component | File | Status | Notes |
|-----------|------|--------|-------|
| `BRUButton` | `fitbod/Design/BRUButton.swift` | SHIPPED | Kinds: `.primary`, `.signal`, `.ghost`. Sizes: `.sm`(32pt), `.md`(44pt), `.lg`(52pt). Init: `BRUButton(_ label: String, kind: Kind = .primary, size: Size = .md, action: @escaping () -> Void)` |
| `BRUSectionHead` | `fitbod/Design/BRUSectionHead.swift` | SHIPPED | Init: `BRUSectionHead(_ title: String, right: String? = nil, rightAction: (() -> Void)? = nil)`. Tappable right → `bruSignal`. Display-only right → `bruMuted`. Adds `.isHeader` accessibility trait. 2pt `bruInk` top + bottom rules. |
| `BRUHeaderBar` | `fitbod/Design/BRUHeaderBar.swift` | SHIPPED | Two APIs: legacy `HeaderAction?` init and Phase 04.1 `.slots(left:center:right:)` factory. For new surfaces use `.slots(left: .back, center: "Title", right: .action("LABEL") { ... })`. Height contract: 44pt row + 2pt rule = 46pt. `.back` auto-wires `@Environment(\.dismiss)`. |
| `BRUChip` | `fitbod/Design/BRUChip.swift` | SHIPPED | Init: `BRUChip(_ label: String, color: Color? = nil, fill: Bool = false, textCase: Text.Case? = .uppercase)`. `fill: true` → color background + paper text. Default → outline + color text. |
| `BRUDivider` | `fitbod/Design/BRUDivider.swift` | SHIPPED | `.ink` (2pt bruInk) and `.hair` (1pt bruHair). |
| `BRUActionPopover` | `fitbod/Design/BRUActionPopover.swift` | SHIPPED | Already used in `ProgramView` for the `+ NEW` popover. |
| `ProgramChipFlow` | `fitbod/Periodization/ProgramView.swift` (fileprivate) | SHIPPED | Custom `Layout` for wrapping chip flow. Used by NoProgramHero. Must be accessible for `UsageTagFlow` in ROUTINES section — either promote to internal or extract. |
| `BlockLifecycleService` | `fitbod/Periodization/BlockLifecycleService.swift` | SHIPPED | All block lifecycle mutations. Typed errors: `BlockLifecycleError` (notReady, notActive, splitChangeOnActiveBlock), `ArchiveUnreadableError` (decodeFailed). |
| `TrainingDaysWriter` | `fitbod/Periodization/TrainingDaysWriter.swift` | SHIPPED | `TrainingDaysWriter.sort(weekdays: [Int], using: Calendar = .current) -> [Int]`. ONLY writing path for `block.trainingDays`. |
| `SplitDeletionGuard` | `fitbod/Models/SplitDeletionGuard.swift` | SHIPPED | `assertDeletable(_ split:)` throws `SplitDeletionError.referencedByLiveBlock` if any non-completed block references it. `BlockLifecycleService.assertSplitDeletable` is a thin wrapper. |
| `TodayResolver` | `fitbod/Periodization/TodayResolver.swift` | SHIPPED | Returns `TodayResolution` enum: `.session(SplitSessionSlot)`, `.emptySplit`, `.restDay`, `.noBlock`. |
| `BlockStatus` enum | `fitbod/Models/Block.swift` | SHIPPED | Cases: `.completed`, `.active`, `.ready`, `.draft`. Computed `block.derivedStatus`. |
| `SchedulingMode` enum | `fitbod/Models/Enums/SchedulingMode.swift` | SHIPPED | Cases: `.rotation`, `.fixedWeekly`. `Block.schedulingMode` computed accessor. |
| `ArchivedBlockConfig` | `fitbod/Models/ArchivedBlockConfig.swift` | SHIPPED | `Codable` struct. `decode(from: Data)` and `write(from: Block, endedAt: Date)`. |
| `NewBlockPhaseListSection` | `fitbod/Periodization/BlockBuilderView.swift` (fileprivate) | SHIPPED | Owns drag-reorder state: `draggingPhaseID`, `dragTargetIndex`. Sibling gap = `phasePitch`. |
| `NewBlockPhaseEditorRow` | `fitbod/Periodization/BlockBuilderView.swift` (fileprivate) | SHIPPED | Owns `@GestureState var dragTranslation`. Hysteresis threshold 0.55. Long-press gate `LongPressGesture(minimumDuration: 0.25)`. Reports `onReorderBegan/Target/Ended` up to parent. |
| `NewBlockLinkedRoutinesBand` | `fitbod/Periodization/BlockBuilderView.swift` (fileprivate, line 1836) | SHIPPED — to be replaced | Current: displays "ROUTINES · {count} LINKED" + "+ LINK". Phase 9: replaced in-place with split picker + mode picker + day-chips band. |

**No new packages to install.** Zero third-party dependencies added in this phase. [VERIFIED: UI-SPEC Registry Safety section]

---

## Package Legitimacy Audit

> Not applicable — this phase adds zero new packages. All UI uses existing BRU primitives + SwiftUI standard views.

---

## Architecture Patterns

### Navigation Architecture

```
ProgramView
  NavigationStack(path: $navigationPath)            ← ProgramView owns this
    ProgramChromeHeader (existing, preserved)
    [conditional: no blocks AND no splits]
      NoProgramHero + ProgramTemplateSection         ← preserved verbatim
    [else]
      BLOCKS section (new)
      ROUTINES section (new)
    .navigationDestination(for: BlockOverviewRoute.self)   ← EXISTING (already wired in ProgramView — see below)
    .navigationDestination(for: ProgramRoute.self)         ← NEW for SplitDetailView

TodayView
  NavigationStack(path: $navigationPath)            ← TodayView owns this
    .navigationDestination(for: BlockOverviewRoute.self)   ← EXISTING (line 208 of TodayView.swift)
    .navigationDestination(for: SplitDetailRoute.self)     ← NEW for emptySplit fix-it CTA
```

**Critical finding:** `ProgramView.swift` (as read) does NOT yet have a `navigationDestination(for: BlockOverviewRoute.self)` registered — currently `BlockOverviewScreen` taps originate only from `TodayView`. Phase 9 must add this destination to `ProgramView`'s `NavigationStack` so `BlockStatusCard` taps from the BLOCKS section resolve correctly. TodayView's `BlockOverviewRoute` destination already exists and is complete; it resolves the block by UUID via `FetchDescriptor` and presents `BlockOverviewScreen(block:onEdit:)`.

**BlockOverviewRoute enum** (defined in `BlockOverviewScreen.swift`):
```swift
public enum BlockOverviewRoute: Hashable, Sendable {
    case summary(blockID: UUID)
}
```

**New SplitDetailRoute** (Phase 9 creates this):
```swift
// Parallel to BlockOverviewRoute — UUID identity, not direct model reference
public enum SplitDetailRoute: Hashable, Sendable {
    case detail(splitID: UUID)
}
```

**One-NavigationStack-per-tab rule:** `ProgramView` already wraps its content in `NavigationStack(path: $navigationPath)` (line 89). `TodayView` does the same (line 74). `SplitDetailView` must NOT own its own `NavigationStack` — it pushes onto the parent's stack. Both `SplitDetailView` and `BlockOverviewScreen` already follow this: `BlockOverviewScreen` uses `BRUHeaderBar.slots(left: .back, ...)` which auto-wires `@Environment(\.dismiss)`.

**Cross-tab navigation:** Not needed. The emptySplit fix-it CTA navigates within TodayView's own stack to `SplitDetailView`, not across to the Program tab. Same split is accessible from both tabs independently.

### System Architecture Diagram

```
User taps BLOCKS card
  → navigationPath.append(BlockOverviewRoute.summary(blockID:))
      → ProgramView.navigationDestination resolves block by UUID
          → BlockOverviewScreen(block:, onEdit:)
              [Start CTA] → BlockLifecycleService.start() OR SwapConfirmSheet
              [End action] → BlockLifecycleService.end()
              [Attach/Swap split] → BlockLifecycleService.attachSplit/swapSplit()
              [Day-chip toggle] → TrainingDaysWriter.sort() + ctx.save()

User taps ROUTINES row
  → navigationPath.append(ProgramRoute.splitDetail(splitID:))
      → ProgramView.navigationDestination resolves split by UUID
          → SplitDetailView(split:)
              [Archive action] → BlockLifecycleService.assertSplitDeletable()
                  [denied] → alert "Cannot Archive Routine"
                  [allowed] → split.isArchived = true; ctx.save()
              [Add slot] → sheet: slot picker over SessionTemplates / RoutineBuilderView
              [Remove slot] → alert confirm → reindex-on-write
              [Reorder slots] → drag-reorder → reindex-on-write

TodayView .emptySplit case
  → emptySplitFixItState shows EmptySplitFixIt
      → "GO TO ROUTINE ▸" tapped
          → TodayView.navigationPath.append(SplitDetailRoute.detail(splitID:))
              → TodayView.navigationDestination resolves split by UUID
                  → SplitDetailView(split:)
```

### Recommended Project Structure

```
fitbod/
├── Periodization/
│   ├── ProgramView.swift           (MODIFY — add BLOCKS/ROUTINES sections, new sheet, route destination)
│   ├── BlockOverviewScreen.swift   (MODIFY — add split band, mode picker, day-chips, start/end CTAs, archived mode)
│   ├── BlockBuilderView.swift      (MODIFY — replace NewBlockLinkedRoutinesBand with split band)
│   ├── SplitDetailView.swift       (NEW — slot list, drag-reorder, usage section, archive action)
│   ├── SplitDetailRoute.swift      (NEW — typed route enum, parallel to BlockOverviewRoute)
│   └── (BlockLifecycleService.swift, TrainingDaysWriter.swift — consume, do not modify)
├── Views/
│   └── TodayView.swift             (MODIFY — emptySplitFixItState + SplitDetailRoute navigationDestination)
└── Design/
    (All BRU primitives — no modifications needed)
```

### Pattern 1: Navigation Destination Registration

`ProgramView` must register destinations for BOTH routes. The existing `TodayView` pattern (line 208) is the exact model:

```swift
// EXISTING in TodayView.swift (line 208) — exact pattern to replicate:
.navigationDestination(for: BlockOverviewRoute.self) { route in
    switch route {
    case .summary(let blockID):
        let blockIDCapture = blockID
        let fetchedBlock = (try? ctx.fetch(
            FetchDescriptor<Block>(predicate: #Predicate<Block> { $0.id == blockIDCapture })
        ))?.first
        if let resolvedBlock = fetchedBlock {
            BlockOverviewScreen(block: resolvedBlock, onEdit: { ... })
        } else {
            Text("Block not found").font(BRUFont.bodyDefault).foregroundStyle(Color.bruMuted)
        }
    }
}
```

Phase 9 adds in `ProgramView`:
```swift
.navigationDestination(for: BlockOverviewRoute.self) { route in
    // same UUID-resolve pattern as TodayView
}
.navigationDestination(for: SplitDetailRoute.self) { route in
    switch route {
    case .detail(let splitID):
        let id = splitID
        let fetched = (try? ctx.fetch(
            FetchDescriptor<Split>(predicate: #Predicate<Split> { $0.id == id })
        ))?.first
        if let split = fetched { SplitDetailView(split: split) }
        else { Text("Routine not found").font(BRUFont.bodyDefault).foregroundStyle(Color.bruMuted) }
    }
}
```

**`PendingBlockBuilder` in `ProgramView` does NOT include `.edit(Block)` yet** — `TodayView` has it, but `ProgramView`'s current enum only has `.newBlock(NewBlockPreset?)` and `.template(BlockTemplate)`. Phase 9's BlockOverviewScreen onEdit closure in ProgramView needs to present `BlockBuilderView` from a sheet; the planner must add `.edit(Block)` case to ProgramView's local `PendingBlockBuilder` or inline the sheet presentation differently. [ASSUMED — solution approach not locked]

### Pattern 2: @Query Shapes for ProgramView Sections

**BLOCKS section:**
```swift
// All blocks (no filter — derivedStatus is computed, not stored; sort by startDate desc)
@Query(sort: [SortDescriptor(\Block.startDate, order: .reverse)])
private var allBlocks: [Block]
// Post-filter in Swift (computed property, NOT in @Query predicate):
private var orderedBlocks: [Block] {
    let statusOrder: [BlockStatus: Int] = [.active: 0, .ready: 1, .draft: 2, .completed: 3]
    return allBlocks.sorted { a, b in
        let oa = statusOrder[a.derivedStatus] ?? 4
        let ob = statusOrder[b.derivedStatus] ?? 4
        if oa != ob { return oa < ob }
        return a.startDate > b.startDate
    }
}
// DONE collapse: allBlocks.filter { $0.derivedStatus == .completed }
// Show 3 most recent completed by startDate desc unless showAllDone == true
```

**ROUTINES section:**
```swift
@Query(filter: #Predicate<Split> { !$0.isArchived }, sort: [SortDescriptor(\Split.name)])
private var splits: [Split]
// Usage tags = post-filter in Swift (multi-level optional chain NOT expressible in #Predicate):
// split.blocks?.filter { $0.derivedStatus != .completed }.map { $0.name } ?? []
```

**Pitfall:** Never use multi-level optional chains in `#Predicate`. The predicate `$0.blocks?.contains { $0.derivedStatus != .completed }` will crash or be rejected by SwiftData's predicate compiler. Always post-filter in Swift. [VERIFIED: CONTEXT.md "Established Patterns" + Block.derivedStatus is computed not stored]

### Pattern 3: Drag-Reorder (SplitSlotRow — reuse BlockBuilderView pattern)

The June 10 perf work (`NewBlockPhaseListSection` + `NewBlockPhaseEditorRow`) is the definitive precedent. Key pieces:

**Parent (SplitDetailView equivalent of `NewBlockPhaseListSection`):**
```swift
@State private var draggingSlotID: UUID? = nil
@State private var dragTargetIndex: Int? = nil
private var slotPitch: CGFloat { 44 + rowSpacing }   // row height + gap

// beginReorder, retarget (guarded: guard dragTargetIndex != target), endReorder
// gapOffset(rowIndex:slotID:) — sibling gap animation
// Each ForEach row: .offset(y: gapOffset(...)).scaleEffect(...).zIndex(...)
// .sensoryFeedback(trigger: draggingSlotID) { _, newValue in newValue != nil ? .impact(weight: .medium) : nil }
```

**Row (SplitSlotRow equivalent of `NewBlockPhaseEditorRow`):**
```swift
@GestureState(resetTransaction: Transaction(animation: .spring(response: 0.3, dampingFraction: 0.85)))
private var dragTranslation: CGFloat = 0
@State private var liveTarget: Int? = nil

// reorderGesture:
LongPressGesture(minimumDuration: 0.25)
    .sequenced(before: DragGesture(minimumDistance: 0))
    .updating($dragTranslation) { ... }
    .onChanged { value in
        // hysteresis: re-target only when abs(raw - current) > 0.55
    }
    .onEnded { _ in liveTarget = nil; onReorderEnded() }
```

**Key differences from BlockBuilderView for SplitSlotRow:**
- Tokens: use `Color.bruMuted`, `Color.bruPaper`, `BRUFont.*` (not `NewBlockScreenTokens.*`)
- `commitMove` = reindex-on-write: after `draft.slots.move(fromOffsets:toOffset:)`, set `slot.position = index` for all slots, then `ctx.save()` once
- Reduced motion: `@Environment(\.accessibilityReduceMotion)` — disable drag gesture; show informational text
- VoiceOver: `AccessibilityAction(.moveUp)` / `.moveDown` on each row

**Do NOT extract to shared module** — the drag pattern is simple enough to copy-adapt; token differences between `NewBlockScreenTokens.*` (BlockBuilderView) and `Color.bru*` (new surfaces) make a shared abstraction more complex than copy-adapt.

### Pattern 4: NewBlockLinkedRoutinesBand Surgical Replacement

**Current location:** `BlockBuilderView.swift` line ~1836, `fileprivate struct NewBlockLinkedRoutinesBand`.

**Current conditional guard (line 75–80):**
```swift
// Conditional linked-routines band
if draft.isValid {
    // V7: block.routines removed; split.slots is the new count source.
    // Phase 9 replaces this band with the split picker component.
    NewBlockLinkedRoutinesBand(count: editing?.split?.slots?.count ?? 0)
}
```

**Phase 9 replacement — three surgical changes in `BlockBuilderView.swift`:**
1. Change the guard condition: `if draft.isValid` → always show (per spec "optional — save without = draft") OR keep `if draft.isValid`. Decision: keep guard for now since spec says "Optional — save without = draft" — show band always (remove the `if draft.isValid` wrapper) since the band itself expresses optionality via "None — saves as draft" copy.
2. Replace `NewBlockLinkedRoutinesBand(...)` call with a new `NewBlockSplitBand(draft: draft)` call (or inline the band).
3. Replace or repurpose the `NewBlockLinkedRoutinesBand` struct with the new split band anatomy (split picker row + mode picker row + day-chips row + ink divider).

**BlockDraft extension needed:** `BlockDraft` (line 14) currently has no `split`, `schedulingMode`, or `trainingDays` properties. Phase 9 must add these to `BlockDraft` so the builder can set them and save them via `BlockDraft.save(into:)`. [ASSUMED — BlockDraft.save does not currently write split/schedulingMode/trainingDays to Block]

**Guardrail constraints on BlockBuilderView — pinned copy that MUST survive:**

Three source-introspection suites pin copy in `BlockBuilderView.swift`:

| Suite | File | Pinned string near linked-routines band |
|-------|------|----------------------------------------|
| `BlockBuilderViewCopyTests` | `fitbodTests/BlockBuilderViewCopyTests.swift` | `"ROUTINES · \(count) LINKED"` (line 35) |
| `NewBlockBuilderFidelityTests` | `fitbodTests/NewBlockBuilderFidelityTests.swift` | struct names: `NewBlockScreenTokens`, `NewBlockTopBar`, `NewBlockNameBand`, `NewBlockPresetChip`, `NewBlockMetricsBand`, `NewBlockProgressionChart`, `NewBlockPhaseEditorRow`, `NewBlockBottomActionBar`, `NewBlockTemplateSheet` + all copy strings in the requiredCopy array |
| `ProgramViewFidelityTests` | `fitbodTests/ProgramViewFidelityTests.swift` | `ProgramChromeHeader`, `ProgramTemplateHeader`; checks `ProgramView.swift` NOT `BlockBuilderView.swift` |

**Critical:** `BlockBuilderViewCopyTests` line 35 pins `"ROUTINES · \(count) LINKED"`. When `NewBlockLinkedRoutinesBand` is replaced, this test WILL FAIL unless the planner either: (a) removes/updates the test as part of the migration task, or (b) keeps the old string present somewhere. Since the spec replaces this band, the test must be updated to reflect the new band's pinned copy. Plan must include a task to update `BlockBuilderViewCopyTests` alongside the band replacement.

**Struct names pinned by `NewBlockBuilderFidelityTests`** (must NOT be renamed):
- `NewBlockScreenTokens`, `NewBlockTopBar`, `NewBlockNameBand`, `NewBlockPresetChip`, `NewBlockMetricsBand`, `NewBlockProgressionChart`, `NewBlockPhaseEditorRow`, `NewBlockBottomActionBar`, `NewBlockTemplateSheet`

### Pattern 5: ProgramView Empty-State Gate

**Current:** `ProgramView.body` always shows `NoProgramHero` + `ProgramTemplateSection` (no `@Query` for blocks or splits yet).

**Phase 9 gate:**
```swift
// Two new @Query properties needed:
@Query private var allBlocks: [Block]
@Query(filter: #Predicate<Split> { !$0.isArchived })
private var allSplits: [Split]

// In body:
if allBlocks.isEmpty && allSplits.isEmpty {
    NoProgramHero(defineAction: { presentingStartChoice = true })
    ProgramTemplateSection(...)
} else {
    // BLOCKS section
    // ROUTINES section
}
```

`NoProgramHero` and `ProgramTemplateSection` structs are `fileprivate` — they stay in `ProgramView.swift`. They must not be renamed (guardrails in `ProgramViewFidelityTests` pin `ProgramChromeHeader` and `ProgramTemplateHeader` but NOT `NoProgramHero` or `ProgramTemplateSection` by struct name — however the copy strings inside them ARE pinned by `ProgramViewFidelityTests.programViewPinsExactMockupCopy`).

**Pinned copy in NoProgramHero** (must survive the rebuild):
- `"+ DEFINE BLOCK ▶"` (CTA text)
- `ProgramFeatureChip(label: "WEEKS · 4-12")`
- `ProgramFeatureChip(label: "PHASES · 1-4")`
- `ProgramFeatureChip(label: "DELOAD OPTIONAL")`
- `ProgramFeatureChip(label: "CUSTOM")`
- `"A block schedules routines across weeks and phases — "`
- `"accumulation, intensification, peak, deload."`
- `"You can also lift without a block, but Fitbod really earns its keep when you're running one."`

**BRUSectionHead exclusion in ProgramView:** `ProgramViewFidelityTests.programViewUsesCompactMockupChrome` asserts `!codeOnly.contains("BRUSectionHead(")`. This test checks `ProgramView.swift` code — BLOCKS/ROUTINES sections CANNOT use `BRUSectionHead` directly inside `ProgramView.swift` WITHOUT breaking this test. Options: (a) the test was written for the empty-state era and needs updating, or (b) the BLOCKS/ROUTINES sections move into child views. The planner must include a task to update `ProgramViewFidelityTests` to allow `BRUSectionHead` in `ProgramView.swift`'s new list sections.

### Pattern 6: TodayView emptySplit Fix-It

Current `emptySplitFixItState` (lines 316–330 of TodayView.swift):
```swift
@ViewBuilder
private var emptySplitFixItState: some View {
    VStack(spacing: 12) {
        Text("Routine has no sessions")
            .font(BRUFont.displayLarge)
            .foregroundStyle(Color.bruInk)
            .multilineTextAlignment(.center)
        Text("Add sessions in the Program tab.")
            .font(BRUFont.bodyDefault)
            .foregroundStyle(Color.bruMuted)
            .multilineTextAlignment(.center)
    }
    .padding(.vertical, 32)
    .padding(.horizontal, 16)
}
```

Phase 9 replaces this with `EmptySplitFixIt` view. The CTA needs the resolved block's split ID:
```swift
// todaysResolution gives us the .emptySplit case; to navigate, we need block.split
// block = activeBlocks.first (already available in TodayView)
case .emptySplit:
    if let split = activeBlocks.first?.split {
        EmptySplitFixIt {
            navigationPath.append(SplitDetailRoute.detail(splitID: split.id))
        }
    } else {
        noWorkoutScheduledEmptyState  // fallback if split somehow nil
    }
```

TodayView must also add `.navigationDestination(for: SplitDetailRoute.self)` alongside the existing `BlockOverviewRoute` destination (line 208). The destination resolves the split by UUID via `FetchDescriptor<Split>` and presents `SplitDetailView`.

**noWorkoutScheduledEmptyState is pinned** — its copy `"No workout scheduled"` and `"Build a routine or pick one from your library."` are used in `TodayViewBRUCopyTests.swift`. Do not modify that branch. Only `.emptySplit` changes.

### Anti-Patterns to Avoid

- **Multi-level optional chains in #Predicate:** `$0.split?.blocks?.contains(...)` will crash or be rejected. Always post-filter in Swift. [VERIFIED: CONTEXT.md "Established Patterns"]
- **Direct field mutation for lifecycle operations:** Never set `block.isActive`, `block.endDate`, `block.archivedConfigJSON` directly from a view. All such mutations go through `BlockLifecycleService`. [VERIFIED: BlockLifecycleService.swift header comment]
- **List .onMove for drag-reorder:** `List .onMove` adds system separators and background that violate BRU contract. Use the custom `DragGesture` + `@GestureState` pattern from `NewBlockPhaseEditorRow`.
- **Direct position writes without reindex:** After any slot add/remove/reorder, positions must be renumbered `0..<n` contiguous. Never leave gaps. [VERIFIED: SplitSessionSlot.swift comment "No #Unique on (split, position)... Contiguity is enforced via test invariant"]
- **Renaming pinned structs in BlockBuilderView:** `NewBlockPhaseEditorRow`, `NewBlockBottomActionBar`, etc. are pinned by source-introspection tests. Never rename them.
- **Hard-delete of splits from UI:** `Split.isArchived = true` is the only UI-level action. Hard-delete is refused by `SplitDeletionGuard.assertDeletable` when live blocks reference the split.
- **Live-template fallback for archived blocks:** When `BlockLifecycleService.decodeArchive` throws `ArchiveUnreadableError`, always show the explicit `ArchiveUnreadableView`. Never fall back to live template data.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Block lifecycle mutations | Custom `block.isActive = true` in view | `BlockLifecycleService.{start,end}` | Atomicity invariants: no zero-or-two-actives window, archive always co-written with endDate |
| Split deletability check | Inline block-count check | `BlockLifecycleService.assertSplitDeletable` → `SplitDeletionGuard.assertDeletable` | Single enforcement seam (T-08-07); changing guard in one place changes all callers |
| Training days sorting | `weekdays.sorted { $0 < $1 }` | `TrainingDaysWriter.sort(weekdays:using:)` | Locale-aware week-start; spec requirement that sort happens at write time only |
| Archive decode | Custom JSON decode | `BlockLifecycleService.decodeArchive` | Typed `ArchiveUnreadableError`; no fallback contract |
| Chip flow layout | Custom `HStack` wrapping | `ProgramChipFlow` (already in ProgramView.swift) | Handles multi-line wrap at 390pt; already tested |
| Today schedule resolution | Re-reading `block.split.slots` directly | `TodayResolver.resolve(block:context:)` | Handles rotation vs fixedWeekly, slot position tracking, emptySplit detection |

---

## Common Pitfalls

### Pitfall 1: BlockOverviewRoute Not Registered in ProgramView

**What goes wrong:** Tapping a BLOCKS card in `ProgramView` pushes `BlockOverviewRoute.summary(blockID:)` but ProgramView has no `navigationDestination(for: BlockOverviewRoute.self)` — the push silently falls through with no navigation.

**Why it happens:** `BlockOverviewRoute` was originally wired only in `TodayView` (line 208). `ProgramView.swift` currently has `navigationDestination(for: SessionRoute.self)` but not `BlockOverviewRoute`.

**How to avoid:** Task Wave A must add `navigationDestination(for: BlockOverviewRoute.self)` to `ProgramView`'s `NavigationStack` before any BLOCKS section task that taps to `BlockOverviewScreen`.

**Warning signs:** Tapping block card does nothing / navigation path increments but screen doesn't change.

### Pitfall 2: derivedStatus Post-Filter Required

**What goes wrong:** `@Query(filter: #Predicate<Block> { $0.derivedStatus != .completed })` — `derivedStatus` is a computed property, not a stored `@Attribute`. SwiftData predicates only operate on stored attributes.

**Why it happens:** `derivedStatus` is defined as a `var` computed from `endDate`, `isActive`, `split`, `trainingDays`, `schedulingMode` — none of which are directly `#Predicate`-addressable with derived logic.

**How to avoid:** `@Query` all blocks (or with a simple stored-attribute filter like `@Query(filter: #Predicate<Block> { $0.endDate == nil })` for non-completed), then post-filter in a computed property for ordering/section assignment.

**Warning signs:** Compile error "Expression not supported in predicate" or runtime crash in predicate evaluation.

### Pitfall 3: BlockBuilderViewCopyTests Fails After Band Replacement

**What goes wrong:** Replacing `NewBlockLinkedRoutinesBand` breaks `BlockBuilderViewCopyTests` line 35: `#expect(builder.contains("\"ROUTINES · \\(count) LINKED\""))`.

**Why it happens:** The test pins the old string verbatim. The new band has different copy ("None — saves as draft", "ROUTINE", "SWAP ▸", etc.).

**How to avoid:** The plan must include a dedicated task to update `BlockBuilderViewCopyTests` alongside the band replacement. The updated test should pin the new band's key copy strings.

**Warning signs:** `BlockBuilderViewCopyTests.verbatimCopyStringsArePresentInSource` fails in CI after the band replacement task.

### Pitfall 4: ProgramViewFidelityTests BRUSectionHead Assertion

**What goes wrong:** `ProgramViewFidelityTests.programViewUsesCompactMockupChrome` asserts `!codeOnly.contains("BRUSectionHead(")` — adding `BRUSectionHead` calls to `ProgramView.swift` breaks this test.

**Why it happens:** The test was written during the empty-state phase to ensure the template section used custom compact chrome instead of `BRUSectionHead`. The new BLOCKS/ROUTINES sections legitimately use `BRUSectionHead`.

**How to avoid:** Update `ProgramViewFidelityTests` to allow `BRUSectionHead` in the new list sections (e.g. scope the check to the template section only, or remove/narrow the assertion). This update is a prerequisite for adding BLOCKS/ROUTINES sections.

**Warning signs:** `ProgramViewFidelityTests.programViewUsesCompactMockupChrome` fails after adding BLOCKS/ROUTINES sections.

### Pitfall 5: SplitSessionSlot .deny Delete Rule

**What goes wrong:** Attempting `ctx.delete(slot.sessionTemplate)` while the slot references it throws a SwiftData constraint violation.

**Why it happens:** `SplitSessionSlot.sessionTemplate` has `@Relationship(deleteRule: .deny)`. Hard-deleting a `SessionTemplate` that is slotted is refused.

**How to avoid:** "Remove slot" UI removes the `SplitSessionSlot`, not the `SessionTemplate`. The `SessionTemplate` remains in the store. `removeSlot()` = `ctx.delete(slot)` + reindex remaining slots + `ctx.save()`.

**Warning signs:** `SwiftData.SwiftDataError` at runtime on slot removal.

### Pitfall 6: BlockDraft Missing split/schedulingMode Fields

**What goes wrong:** `BlockBuilderView`'s new split band writes `draft.split`, `draft.schedulingMode`, `draft.trainingDays` but `BlockDraft` has no such properties. `BlockDraft.save(into:)` also doesn't write them to `Block`.

**Why it happens:** `BlockDraft` was designed before Phase 7 V7 split graph. Current `BlockDraft.save(into:)` (line 86–143) does not set `block.split`, `block.schedulingMode`, or `block.trainingDays`.

**How to avoid:** Phase 9 must add these properties to `BlockDraft` and extend `save(into:)` to write them. Use `BlockLifecycleService.attachSplit` for split attachment (respects active-block guard) OR write `block.split = draft.split` directly inside the existing `context.transaction` (BlockBuilderView is only called for draft/ready blocks, so the guard is not needed here). The planner must decide which path.

**Warning signs:** Block saves without preserving split/mode/days; split picker state lost on save.

### Pitfall 7: UsageTagFlow ProgramChipFlow Access

**What goes wrong:** `ProgramChipFlow` is `fileprivate` in `ProgramView.swift`. `RoutineSplitRow` uses `UsageTagFlow` which needs the same chip-flow layout — but if `RoutineSplitRow` is a separate struct or file, it can't access `ProgramChipFlow`.

**Why it happens:** `ProgramChipFlow` was written as a local implementation detail of `NoProgramHero`.

**How to avoid:** Either: (a) move `ProgramChipFlow` to `internal` access in its own file, (b) promote it within `ProgramView.swift` to `internal`, or (c) inline `RoutineSplitRow` inside `ProgramView.swift` as `fileprivate` where it can access `ProgramChipFlow`. Option (c) is lowest risk given the test that guards ProgramView's structure.

---

## Code Examples

### BRUSectionHead with tappable right slot

```swift
// Source: fitbod/Design/BRUSectionHead.swift
BRUSectionHead("Sessions", right: "+ ADD SESSION", rightAction: { presentingSlotPicker = true })
// right = nil:
BRUSectionHead("Blocks", right: nil)
// display-only right:
BRUSectionHead("Phase progression", right: "WHAT'S NEXT")
```

### BRUButton kinds

```swift
// Source: fitbod/Design/BRUButton.swift
BRUButton("START BLOCK ▸", kind: .signal) { onStartTapped() }   // signal (bruSignal fill)
BRUButton("END BLOCK", kind: .ghost) { presentingEndConfirm = true }  // ghost (outline)
BRUButton("EDIT BLOCK ▸", kind: .primary) { onEdit() }          // primary (ink fill)
// Size default is .md (44pt). Use .lg (52pt) for prominent full-width CTAs.
```

### BRUHeaderBar.slots factory

```swift
// Source: fitbod/Design/BRUHeaderBar.swift — Phase 04.1 API
BRUHeaderBar.slots(
    left: .back,           // auto-wires @Environment(\.dismiss)
    center: "Routine · \(split.name)",
    right: .action("ARCHIVE", archiveAction)
)
```

### BlockOverviewRoute push (model for SplitDetailRoute)

```swift
// Source: fitbod/Views/TodayView.swift line 108-109
BlockContextBand(block: block, onTap: {
    navigationPath.append(BlockOverviewRoute.summary(blockID: block.id))
})
// Destination registration (line 208-224):
.navigationDestination(for: BlockOverviewRoute.self) { route in
    switch route {
    case .summary(let blockID):
        let blockIDCapture = blockID
        let fetchedBlock = (try? ctx.fetch(
            FetchDescriptor<Block>(predicate: #Predicate<Block> { $0.id == blockIDCapture })
        ))?.first
        if let resolvedBlock = fetchedBlock {
            BlockOverviewScreen(block: resolvedBlock, onEdit: { ... })
        }
    }
}
```

### derivedStatus-based ordering (post-filter pattern)

```swift
// Source: fitbod/Models/Block.swift — derivedStatus is computed, not stored
// WRONG: @Query(filter: #Predicate<Block> { $0.derivedStatus == .active }) — compile error
// CORRECT:
@Query(sort: [SortDescriptor(\Block.startDate, order: .reverse)])
private var allBlocks: [Block]

private var blocksForDisplay: [Block] {
    let order: [BlockStatus: Int] = [.active: 0, .ready: 1, .draft: 2, .completed: 3]
    return allBlocks.sorted { order[$0.derivedStatus, default: 4] < order[$1.derivedStatus, default: 4] }
}
```

### Hysteresis drag gesture (from NewBlockPhaseEditorRow, line 1511–1543)

```swift
// Source: fitbod/Periodization/BlockBuilderView.swift lines 1511-1543
private var reorderGesture: some Gesture {
    LongPressGesture(minimumDuration: 0.25)
        .sequenced(before: DragGesture(minimumDistance: 0))
        .updating($dragTranslation) { value, state, _ in
            if case .second(true, let drag?) = value { state = drag.translation.height }
        }
        .onChanged { value in
            switch value {
            case .first(true):
                liveTarget = rowIndex; onReorderBegan()
            case .second(true, let drag?):
                let raw = Double(rowIndex) + Double(drag.translation.height / reorderPitch)
                let current = liveTarget ?? rowIndex
                if abs(raw - Double(current)) > 0.55 {   // hysteresis threshold
                    let next = min(max(Int(raw.rounded()), 0), rowCount - 1)
                    if next != current { liveTarget = next; onReorderTarget(next) }
                }
            default: break
            }
        }
        .onEnded { _ in liveTarget = nil; onReorderEnded() }
}
```

### BlockLifecycleService.start with swap

```swift
// Source: fitbod/Periodization/BlockLifecycleService.swift
// Start with potential swap (another block active):
do {
    try BlockLifecycleService.start(block: block, context: ctx)
} catch BlockLifecycleError.notReady {
    // block not ready — should not happen if Start CTA only shown when derivedStatus == .ready
}
// The service handles swap atomically — no view-level check needed for "another active block"
// UI shows SwapConfirmSheet to warn user; confirms by calling the same start()
```

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|-----------------|--------|
| `Block.routines` (V6) | `Block → Split → SplitSessionSlot → SessionTemplate` (V7) | All session template references go through the split graph; direct `block.routines` is gone |
| `BlockOverviewScreen` read-only | Phase 9: BlockOverviewScreen gets live-edit controls (split band, mode picker, day-chips, Start/End) | Significant extension of existing screen |
| `NewBlockLinkedRoutinesBand` ("ROUTINES · N LINKED") | Phase 9: split picker + mode picker + day-chips band | In-place struct replacement; test update required |
| TodayView `.emptySplit` placeholder copy | Phase 9: `EmptySplitFixIt` with navigation CTA to `SplitDetailView` | Replaces 2-line placeholder with real repair surface |
| `ProgramView` always shows empty-state | Phase 9: conditional gate on `blocks.count > 0 || splits.count > 0` | Empty-state preserved when no data |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `ProgramView.swift` does not yet have `navigationDestination(for: BlockOverviewRoute.self)` registered | Architecture Patterns — Navigation | If it is registered (in a part of the file not visible), the plan would add a duplicate destination, causing a SwiftUI warning but not a crash |
| A2 | `BlockDraft` does not currently have `split`, `schedulingMode`, or `trainingDays` properties, and `save(into:)` does not write them | Pitfall 6 + Pattern 4 | If BlockDraft already has these, the "add to BlockDraft" task is a no-op (harmless) |
| A3 | The `.edit(Block)` case is missing from `ProgramView`'s local `PendingBlockBuilder` enum | Pattern 1 | If it is present, BlockOverviewScreen's `onEdit` in ProgramView already works |
| A4 | `ProgramChipFlow` is `fileprivate` in ProgramView.swift and not accessible from a new SplitDetailView file | Pitfall 7 | If it was promoted to `internal` in a recent edit, no action needed |

---

## Open Questions

1. **BlockDraft: direct write vs. attachSplit in builder save path**
   - What we know: `BlockLifecycleService.attachSplit` refuses on active blocks; `BlockBuilderView` is only accessible for non-active blocks (fullScreenCover from ProgramView / sheet from TodayView)
   - What's unclear: Should Phase 9 use `BlockLifecycleService.attachSplit` inside `BlockDraft.save(into:)`, or write `block.split = draft.split` directly within the existing `context.transaction`?
   - Recommendation: Write directly in the transaction (BlockBuilderView is pre-activation, so the guard is not needed); add a comment documenting why the service path is not used here.

2. **ProgramViewFidelityTests BRUSectionHead assertion scope**
   - What we know: The test was written for the empty-state era and will fail when BLOCKS/ROUTINES sections are added.
   - What's unclear: Should the test be narrowed (check only the template section file range) or replaced with new assertions for the populated state?
   - Recommendation: Replace with a new test that: (a) still asserts the template section uses compact chrome (check for `ProgramTemplateHeader`), AND (b) asserts the new sections use `BRUSectionHead`.

3. **SplitDetailView as new file vs. extension of existing files**
   - What we know: ProgramView.swift is already large (958 lines); SplitDetailView will add ~200-300 lines of new code.
   - What's unclear: Whether `SplitDetailRoute` belongs in `BlockOverviewScreen.swift` (alongside `BlockOverviewRoute`) or in its own `SplitDetailRoute.swift`.
   - Recommendation: `SplitDetailRoute.swift` as a new file (parallel to `BlockOverviewScreen.swift`'s route); `SplitDetailView.swift` as its own file in `fitbod/Periodization/`.

---

## Environment Availability

> No external dependencies. Pure SwiftUI + SwiftData + BRU primitives. All libraries are part of the Xcode toolchain.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (`@Test`, `#expect`) for unit/model; XCTest for UI tests |
| Config file | Xcode test target — no external config file |
| Quick run command | Build + test `fitbodTests` target in Xcode |
| Full suite command | `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,...'` |

### Phase Requirements → Test Map

| Req | Behavior | Test Type | Notes |
|-----|----------|-----------|-------|
| PV-01 | ProgramView shows BLOCKS/ROUTINES sections when data exists | unit (source audit) | New guardrail test in `ProgramViewFidelityTests` |
| PV-02 | Empty-state preserved verbatim when no blocks AND no splits | unit (existing) | `ProgramViewFidelityTests` copy pins already protect this |
| PV-03 | BlockBuilderView split band replaces old linked-routines band | unit (source audit) | `BlockBuilderViewCopyTests` must be updated to pin new copy |
| SD-01 | SplitDetailView slot reindex-on-write contiguity | unit | New test in `fitbodTests/` verifying positions are 0..<n after add/remove/reorder |
| SD-02 | Archive action denied when live block references split | unit (existing) | `BlockLifecycleServiceTests` covers `assertSplitDeletable` |
| BO-01 | BlockOverviewScreen Start → swap confirm when another block active | unit (existing) | `BlockLifecycleServiceTests.testStartSwapsActiveBlock` |
| TV-01 | TodayView `.emptySplit` shows EmptySplitFixIt (not rest-day copy) | unit (source audit) | New assertion in `TodayViewBRUCopyTests` |

### Wave 0 Gaps

- [ ] `fitbodTests/SplitDetailViewTests.swift` — slot CRUD + reindex-on-write invariant (REQ SD-01)
- [ ] Update `fitbodTests/BlockBuilderViewCopyTests.swift` — remove old `"ROUTINES · \(count) LINKED"` pin, add new split-band copy pins (REQ PV-03)
- [ ] Update `fitbodTests/ProgramViewFidelityTests.swift` — narrow/replace `BRUSectionHead` assertion (REQ PV-01)

---

## Security Domain

> `security_enforcement` not set to false in config.json — section included.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Local-only, single user |
| V3 Session Management | No | Not applicable |
| V4 Access Control | No | Single user, no multi-tenant |
| V5 Input Validation | Minimal | Block/split/slot names are user strings — rendered as `Text(name)`, not executed; no injection risk in SwiftUI |
| V6 Cryptography | No | No new crypto in this phase |

No new security threat patterns introduced. All data is local SwiftData; no network calls, no auth tokens.

---

## Project Constraints (from CLAUDE.md)

Directives that apply to Phase 9 implementation:

- `@Observable` + `@State`/`@Bindable`/`.environment(_:)` only. No `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject` in new code.
- `@Query` directly in views. Never wrapped in a view model.
- One `NavigationStack` per tab. `SplitDetailView` must NOT own its own `NavigationStack`.
- No Core Data / Realm / GRDB — SwiftData only.
- No CloudKit / HealthKit.
- Swift Testing (`@Test`, `#expect`) for unit tests; XCTest only for UI tests in `fitbodUITests/`.
- Don't assign relationships in initializers — insert into context first.
- No `Codable` on `@Model` types.
- Cascade: Session→SessionExercise→SetLog cascade; Exercise→history nullify. Split→SplitSessionSlot cascade (already defined in `Split.swift`).
- Swift Charts for data charts, Canvas for muscle heatmap — not applicable this phase.
- BRU contract: NO `Capsule()` / NO `RoundedRectangle` / NO `accentColor` / NO `Image(systemName:)` / NO `.font(.body/.headline/.title*)` in new views.
- Device floor: iPhone 15+ (390pt wide). Flexible over fixed widths. Verify at 390–393pt.
- Run all 3 copy-guardrail suites on ANY `BlockBuilderView.swift` edit.
- `gitnexus_impact` before editing any symbol; `gitnexus_detect_changes` before committing.

---

## Sources

### Primary (HIGH confidence)

- `fitbod/Periodization/ProgramView.swift` — full anatomy: ProgramChromeHeader, NoProgramHero, ProgramTemplateSection, sheets/fullScreenCovers, PendingBlockBuilder, BRUActionPopover, ProgramChipFlow layout
- `fitbod/Views/TodayView.swift` — navigationPath, BlockOverviewRoute destination pattern, emptySplitFixItState placeholder, todaysResolution switch
- `fitbod/Periodization/BlockOverviewScreen.swift` — BlockOverviewRoute enum definition, BRUHeaderBar.slots usage, heroBand, weekCarousel (dayCell pattern), phaseProgressionList, editBlockButton
- `fitbod/Periodization/BlockBuilderView.swift` — NewBlockPhaseListSection (drag-reorder parent), NewBlockPhaseEditorRow (hysteresis gesture, line 1511–1543), NewBlockLinkedRoutinesBand (line 1836, current band to replace)
- `fitbod/Design/BRUButton.swift` — confirmed `.primary`, `.signal`, `.ghost` kinds; `.sm`(32pt), `.md`(44pt), `.lg`(52pt) sizes
- `fitbod/Design/BRUSectionHead.swift` — confirmed `right:` + `rightAction:` API; signal color for tappable right
- `fitbod/Design/BRUHeaderBar.swift` — confirmed `.slots(left:center:right:)` factory + `HeaderSlot.back` auto-dismiss
- `fitbod/Design/BRUChip.swift` — confirmed `color:` + `fill:` parameters
- `fitbod/Models/Block.swift` — `BlockStatus` enum (.completed/.active/.ready/.draft), `derivedStatus` computed property, V7 fields (split, schedulingMode, trainingDays)
- `fitbod/Models/Split.swift` — `isArchived`, cascade rules, blocks inverse
- `fitbod/Models/SplitSessionSlot.swift` — `.deny` delete rule for sessionTemplate, position field, reindex-on-write requirement
- `fitbod/Periodization/BlockLifecycleService.swift` — all method signatures, typed errors, `assertSplitDeletable` delegation
- `fitbod/Periodization/TrainingDaysWriter.swift` — `sort(weekdays:using:)` signature
- `fitbodTests/BlockBuilderViewCopyTests.swift` — pinned copy including `"ROUTINES · \(count) LINKED"` (line 35)
- `fitbodTests/NewBlockBuilderFidelityTests.swift` — pinned struct names + copy arrays
- `fitbodTests/ProgramViewFidelityTests.swift` — BRUSectionHead exclusion assertion, pinned copy, font assertions
- `fitbodTests/BlocksSectionTests.swift` — existing block sort tests
- `fitbodUITests/NewBlockModalUITests.swift` — launch arg `-fitbod-start-program`, asserted element labels
- `fitbod/Periodization/BlockDraft.swift` — confirmed no split/schedulingMode/trainingDays properties (A2)
- `fitbod/App/RootView.swift` — confirmed `-fitbod-start-program` launch argument handling (line 94)

### Secondary (MEDIUM confidence)

- `09-CONTEXT.md` + `09-UI-SPEC.md` — design contract; both read in full

---

## Metadata

**Confidence breakdown:**
- Navigation architecture: HIGH — read exact source of all involved files
- BRU primitive APIs: HIGH — read all relevant primitive files
- Drag-reorder pattern: HIGH — read hysteresis implementation verbatim
- Guardrail test constraints: HIGH — read all 3 suites
- BlockDraft split fields: HIGH (confirmed absent) — read BlockDraft.swift fully
- ProgramView BRUSectionHead constraint: HIGH — read test assertion verbatim
- BlockOverviewRoute in ProgramView: MEDIUM — read ProgramView.swift but `navigationDestination` for BlockOverviewRoute not found; flagged as A1

**Research date:** 2026-06-11
**Valid until:** 2026-07-11 (stable domain — SwiftUI/SwiftData APIs, all internal code)
