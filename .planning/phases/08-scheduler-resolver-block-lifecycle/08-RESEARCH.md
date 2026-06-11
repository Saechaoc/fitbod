# Phase 8: Scheduler Resolver & Block Lifecycle - Research

**Researched:** 2026-06-11
**Domain:** SwiftData one-save transactions, block lifecycle service, unified rotation resolver, SessionFactory block-phase migration, Calendar injection, ArchivedBlockConfig write
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

All locked by spec (§ refs to program-graph-spec.md):

**Resolver (§5)**
- Unified rotation predicate: latest **completed** session in this block whose `slot` is non-nil AND `slot.split == block.split` → next slot = `(slot.position + 1) % slotCount`; no matching session → slot 0. Ad-hoc (nil slot), deleted-slot (nullified → reads ad-hoc), swapped-split sessions, and abandoned in-progress workouts all fall out of the scan identically.
- Zero-slot guard: resolver runs only when `slotCount >= 1`. Returns `TodayResolution.emptySplit` case (not rest-day) when mid-block split is emptied.
- fixedWeekly: today's weekday ∈ `trainingDays` (stored order canonical) → slot at `index(of: weekday in trainingDays as stored) % slotCount`; absent → rest day. Missed day = skipped, not shifted.
- trainingDays sort-at-write: service sorts once via the user's `Calendar.firstWeekday` when writing trainingDays. Region change later must NOT remap days to slots.
- Resolver output enum: `TodayResolution { case session(SplitSessionSlot), restDay, emptySplit, noBlock }`.

**Lifecycle (§4)**
- Start (status == ready): `isActive = true`, `startDate = .now`. Swap is ONE save: current.endDate + current.archivedConfigJSON + new.isActive/startDate atomically.
- End: endDate + archive write in one save.
- Split swap/attach gated to draft/ready — service refuses on active.
- Conditional deny: refuse split delete/archive while any non-completed block references it. `SplitDeletionGuard` (exists, 5 passing tests) is the enforcement seam.
- Status stays derived (`Block.derivedStatus`); transition-site assertions: `isActive ⇒ split != nil ∧ endDate == nil`.

**Archive (§6)**
- Phase 8 ships the WRITE: serialize at end-block inside the same save (ArchivedBlockConfig DTO already exists). Content: block name, dates, mode, trainingDays, full phase mirror, split name, position-ordered slots with session names + full prescription mirrors, `"v": 1`.
- Decode failure → explicit error case ("Archive unreadable"); never a live-template fallback.

**Phase 7 carry-overs (MUST address)**
- CR-02 legacy edge: `SessionTemplate.block` + `Block.legacyTemplates` survive; Phase 8 migrates `SessionFactory` to resolve the current BlockPhase from the ACTIVE block (via `Session.block` + resolver context), not `template.block`. After migration, the legacy edge is write-orphaned — leave the field in place (removal = V8 migration, defer), document as deprecated, nothing should read it for prescription resolution.
- Stubs to replace: `TodayView.todaysRoutine` (returns nil), `MesocycleWeekPage.scheduledSlots` (already wired via `block.split?.slots`), `BlockOverviewScreen` membership checks (TODO Phase 8 comments).

### Claude's Discretion
- Resolver/service file placement (`fitbod/Periodization/` or new `fitbod/Scheduling/`)
- Naming (`TodayResolver`, `BlockLifecycleService` or similar)
- Whether resolution returns slot or `(slot, sessionTemplate)` pair

### Deferred Ideas (OUT OF SCOPE)
- All Phase 9 surfaces; legacy-edge field removal (V8); per-phase routine overrides; Progress-over-archives (v2+); device UAT items; `MesocycleWeekPage.scheduledSlots` if not cheap.
</user_constraints>

---

## Summary

Phase 8 is a pure engine layer: it replaces three stubs (`todaysRoutine`, block-membership checks in BlockOverviewScreen) and one legacy data path (`SessionFactory` reading `template.block`) with spec-compliant service code. The codebase already ships the full V7 schema (Split, SplitSessionSlot, Session.slot, Block.archivedConfigJSON, ArchivedBlockConfig DTO + decoder, SplitDeletionGuard). No new persistence schema work is needed.

The critical insight for planning is the **transaction boundary**. SwiftData's `context.transaction { }` is established project pattern (BlockDraft.save, BlockReviewView.pendingReviewBlocks, BlockCard end-block) and provides the atomicity needed for the start-swap (two Block mutations + archive JSON string + one `context.save()` inside the closure). The app uses `isAutosaveEnabled` at its default (`true`), but autosave fires on RunLoop cycle boundaries — a synchronous `context.transaction` block executes and calls `context.save()` before the RunLoop yields, so no autosave can interpose a partial state window. This is the same pattern BlockDraft.save already uses for the single-active-block invariant.

The `SessionFactory` migration is straightforward: lines 133 and 275 read `template.block` to populate `session.block` and to pass a `Block?` into `strategy.prescribe(...)`. The fix is to pass `nil` for the block to `prescribe()` (removing the legacy-edge dependency) and instead set `session.block` from the active block fetched via `SessionFactory.active(in:)` lookup or resolver context at call time — see architecture map below.

**Primary recommendation:** Ship three new types in `fitbod/Periodization/` (co-locate with Block code): `TodayResolver` (static methods returning `TodayResolution`), `BlockLifecycleService` (static methods for start/end/swap transactions), and `TrainingDaysWriter` (sort-at-write service taking an injectable `Calendar`). Tests use `SchemaV7` + `InMemoryContainer.makeCurrent()` pattern already established by Phase 7 tests.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Today session resolution | Service layer (`TodayResolver`) | TodayView (wires result to CTA) | Resolver is pure logic; view reads result |
| Block start/end/swap atomicity | Service layer (`BlockLifecycleService`) | BlockCard / Phase 9 UI (calls service) | Transactions belong in service, not in view |
| trainingDays sort-at-write | Service layer (`TrainingDaysWriter`) | Block (stores verbatim) | Sorting logic must be injectable for locale tests |
| ArchivedBlockConfig write | Service layer (`BlockLifecycleService.end`) | Block.archivedConfigJSON (storage) | Write co-located with end-block transaction |
| Split conditional deny | `SplitDeletionGuard` (exists) | Phase 9 SplitDetailView (calls guard) | Guard already wired; Phase 8 adds call sites |
| BlockPhase resolution in prescribe() | SessionFactory (active-block lookup) | PeriodizationEngine (computes phase) | Remove template.block dependency; use session.block |
| TodayView CTA render | TodayView (reads `TodayResolution`) | — | View branching on resolver output enum |
| BlockOverviewScreen membership | BlockOverviewScreen.dayState(for:) | Session.slot / Session.block | Replace TODO-comment heuristics with slot predicate |

---

## Standard Stack

### Core (all existing — no new packages)

| Library/Type | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftData (`ModelContext.transaction`) | iOS 26.4 SDK | Atomic multi-object mutation | Established project pattern; no intermediate autosave can interpose |
| Swift Testing (`@Test`, `#expect`) | Swift 6 bundled | All unit tests | Project rule: Swift Testing for model/unit tests |
| Foundation (`Calendar`, `JSONEncoder`) | iOS 26.4 SDK | Weekday math, archive serialization | Standard library; `Calendar` injection via value copy |
| `PeriodizationEngine` (existing) | internal | Block-phase resolution from block + date | Already used by BlockPeriodizedStrategy, BlockOverviewScreen |
| `ArchivedBlockConfig` (existing V7 DTO) | internal | Freeze #2 archive target | Phase 7 shipped DTO + decoder; Phase 8 ships writer |
| `SplitDeletionGuard` (existing) | internal | Conditional deny enforcement | Phase 7 shipped with 5 passing tests; wire into lifecycle |

### No New External Packages

This phase installs zero external packages. All dependencies are either iOS SDK or existing internal types.

---

## Package Legitimacy Audit

> **Not applicable** — this phase installs no external packages.

---

## Architecture Patterns

### System Architecture Diagram

```
TodayView
  │ todaysRoutine (was: nil stub)
  ▼
TodayResolver.resolve(block:context:today:calendar:)
  ├─ .noBlock          → StartBlockCTA (existing branch)
  ├─ .restDay          → empty-state (existing branch)
  ├─ .emptySplit       → fix-it surface (Phase 9 renders; Phase 8 returns enum case)
  └─ .session(slot)    → BlackSlabCTA (existing branch, passes slot.sessionTemplate)
         │
         └─► SessionFactory.start(template: slot.sessionTemplate, block: activeBlock, context:)
                  │  [Phase 8 migration: block param from resolver, NOT template.block]
                  ▼
         PeriodizationEngine.phase(for: activeBlock, on: date)
                  │
                  └─► strategy.prescribe(..., block: activeBlock, ...)

BlockLifecycleService.start(block:context:now:)
  │  [status == .ready guard]
  │  if another block active:
  │    currentBlock.endDate = now
  │    currentBlock.archivedConfigJSON = ArchivedBlockConfig.write(currentBlock)
  │  block.isActive = true
  │  block.startDate = now
  └─► context.transaction { context.save() }  ← single save, no zero-or-two window

BlockLifecycleService.end(block:context:now:)
  │  block.isActive = false  (via isActive false, not an explicit field write)
  │  block.endDate = now
  │  block.archivedConfigJSON = try ArchivedBlockConfig.write(block)
  └─► context.transaction { context.save() }

TrainingDaysWriter.sort(weekdays:using:)
  │  calendar.firstWeekday determines canonical order
  └─► returns [Int] sorted Sun-first or Mon-first depending on locale
      (stored verbatim; sort is only called at write time, never at read time)
```

### Recommended Project Structure

```
fitbod/Periodization/
├── TodayResolver.swift          # NEW — static funcs, TodayResolution enum
├── BlockLifecycleService.swift  # NEW — start / end / swap static funcs
├── TrainingDaysWriter.swift     # NEW — sort-at-write, injectable Calendar
├── BlockDraft.swift             # existing — saveIfValid stays draft-only
├── BlockOverviewScreen.swift    # MODIFY — replace dayState TODO with slot predicate
└── (all other existing files unchanged)

fitbod/Sessions/
└── SessionFactory.swift         # MODIFY — lines 133, 275 — remove template.block reads

fitbod/Views/
└── TodayView.swift              # MODIFY — todaysRoutine wired to TodayResolver

fitbodTests/
├── TodayResolverTests.swift     # NEW — spec §9 scheduler suite
├── BlockLifecycleServiceTests.swift  # NEW — start/end/swap atomicity + deny
└── TrainingDaysWriterTests.swift     # NEW — locale + sort invariant
```

### Pattern 1: One-Save Transaction (established project pattern)

**What:** Mutate multiple `@Model` objects, then call a single `context.save()` inside `context.transaction { }`.
**When to use:** Any operation that must be atomic — start-block swap, end-block archive write.

```swift
// Source: BlockDraft.swift:86-143 (established pattern)
// Source: BlockReviewView.swift:496-500 (established pattern)
public static func end(block: Block, context: ModelContext, now: Date = .now) throws {
    let archiveJSON = try ArchivedBlockConfig.write(from: block, endedAt: now)
    try context.transaction {
        block.isActive = false
        block.endDate = now
        block.archivedConfigJSON = archiveJSON
        try context.save()
    }
}
```

**Key invariant:** `archivedConfigJSON` is written inside the same `context.transaction` as `endDate`. A block cannot have `endDate != nil` without `archivedConfigJSON != nil` after Phase 8.

### Pattern 2: Unified Rotation Resolver Predicate

**What:** Find the latest completed session in the block whose `slot` is non-nil and `slot.split == block.split`. Advance by one position modulo slotCount.
**When to use:** `schedulingMode == .rotation` and `slotCount >= 1`.

```swift
// Source: program-graph-spec.md §5 (locked decision)
// [ASSUMED] — implementation shape; spec defines semantics precisely.
static func resolveRotation(block: Block, context: ModelContext) -> TodayResolution {
    let slotCount = block.split?.slots?.count ?? 0
    guard slotCount >= 1 else { return .emptySplit }

    // Fetch completed sessions in block, descending by startedAt.
    // Post-filter in Swift (multi-level optional chain — Pitfall 1 rule).
    let targetBlockID = block.id
    let descriptor = FetchDescriptor<Session>(
        predicate: #Predicate { $0.completedAt != nil },
        sortBy: [SortDescriptor(\Session.startedAt, order: .reverse)]
    )
    let allCompleted = (try? context.fetch(descriptor)) ?? []

    // Pitfall 1: multi-level optional chain (slot?.split?.id) must be
    // post-filtered in Swift, not inside #Predicate.
    let seed = allCompleted.first { session in
        session.block?.id == targetBlockID
            && session.slot != nil
            && session.slot?.split?.id == block.split?.id
    }

    let slots = (block.split?.slots ?? []).sorted { $0.position < $1.position }
    let nextPosition: Int
    if let lastSlot = seed?.slot {
        nextPosition = (lastSlot.position + 1) % slotCount
    } else {
        nextPosition = 0
    }
    guard let slot = slots.first(where: { $0.position == nextPosition }) else {
        return .emptySplit
    }
    return .session(slot)
}
```

### Pattern 3: Calendar Injection for Sort-at-Write

**What:** Accept a `Calendar` value as a parameter (copy, not reference) so tests can override `firstWeekday` without mutating `Calendar.current`.
**When to use:** Any code that sorts weekdays. Established precedent: `mondayAtMidnightForToday(weekStartsMonday:calendar:)` in `MondayAtMidnight.swift`.

```swift
// Source: MondayAtMidnight.swift (established pattern)
public static func sort(weekdays: [Int], using calendar: Calendar = .current) -> [Int] {
    let firstWeekday = calendar.firstWeekday  // 1 = Sun, 2 = Mon
    return weekdays.sorted { a, b in
        let normA = (a - firstWeekday + 7) % 7
        let normB = (b - firstWeekday + 7) % 7
        return normA < normB
    }
}
```

**Locale test shape:** Pin `calendar.firstWeekday = 2` (Monday-first) at write time, then simulate a "region change" by reading `trainingDays` directly from the Block (no re-sort). Assert stored order is unchanged.

### Pattern 4: SessionFactory Block-Phase Migration

**What:** Remove `template.block` reads from SessionFactory lines 133 and 275. Supply the active block from the resolver context instead.
**When to use:** Phase 8 ONLY. This is the CR-02 carry-over from Phase 7.

Current code (line 133):
```swift
session.block = template.block  // legacy: reads template.block
```
Current code (line 275):
```swift
block: template.block,          // legacy: reads template.block
```

Post-migration:
```swift
// Caller (TodayView.startWorkout or BlockLifecycleService) passes the active Block explicitly.
// SessionFactory.start gains an optional `activeBlock: Block?` parameter.
session.block = activeBlock     // from resolver context, not template edge
...
block: activeBlock,             // same
```

`SessionExerciseCard.currentExplanation()` (line 436) reads `se.session?.block` which is populated at start time — no change needed there as long as `session.block` is set correctly from the active block.

**Readers inventory for `template.block`:**

| Call site | File | Action |
|-----------|------|--------|
| `session.block = template.block` | SessionFactory.swift:133 | Migrate to `activeBlock` param |
| `block: template.block` | SessionFactory.swift:275 | Migrate to `activeBlock` param |
| `self.blockID = routine.block?.id` | RoutineDraft.swift:126 | No change — RoutineDraft.blockID is for template-attachment UI, not prescription resolution |
| `routine.block = resolvedBlock` | RoutineDraft.swift:241 | No change — draft write path, still valid |
| `copy.block = routine.block` | RoutineDuplicator.swift:83 | No change — duplication carries legacy edge; safe write-orphan |
| `r.block = block` | BackupRestorer.swift:429 | No change — restore path writes the legacy edge; fine as deprecated-but-present |
| `s.block = block` | BackupRestorer.swift:488 | No change — same |

**All prescription-resolution reads of `template.block` are exactly lines 133 and 275 of SessionFactory.swift.** All other `.block` writes are non-resolution paths (draft saves, restore, duplication) that can stay as-is since the field remains in the schema.

### Anti-Patterns to Avoid

- **Calling `context.save()` twice in a start-swap:** Do NOT save after mutating currentBlock, then again after mutating newBlock. One `context.transaction { context.save() }` covers all mutations atomically.
- **Re-sorting `trainingDays` at read time:** `Block.trainingDays` getter is verbatim (see Block.swift:97-104). The sort must happen only at write in `TrainingDaysWriter.sort(...)`. A mid-block region change must NOT reorder stored weekdays.
- **Using `#Predicate` with multi-level optional chains for resolver:** `session.slot?.split?.id` inside `#Predicate` triggers Pitfall 1 (silent empty results on iOS 17/18). Post-filter in Swift, same as `fetchHistoryPoints` / `lastSessionWorkingReps` precedent.
- **Returning `restDay` when the split is emptied:** The `emptySplit` case is distinct from `restDay` — Phase 9 renders them differently. The resolver must not collapse them.
- **Passing `block: template.block` to `strategy.prescribe()` after migration:** After Phase 8, `template.block` is write-orphaned. Passing it to strategies silently continues reading the legacy edge. The fix must be passing `session.block` (set from the active-block resolver context).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Atomic multi-object mutation | Manual `context.save()` + rollback logic | `context.transaction { }` | SwiftData transaction is the project-standard atomicity primitive; BlockDraft.save, BlockReviewView all use it |
| Block-phase resolution from block + date | Custom weekday/week math | `PeriodizationEngine.phase(for:on:)` + `PeriodizationEngine.weekIndex(for:on:)` | Already used by BlockPeriodizedStrategy, BlockOverviewScreen, TodayView |
| Archive JSON serialization | Custom String formatting | `ArchivedBlockConfig.encoded()` (exists, ISO-8601) | DTO + encoder already shipped in Phase 7 with full tests |
| Weekday-order normalization | Raw arithmetic on weekday ints | `TrainingDaysWriter.sort(weekdays:using:)` (new, wraps Calendar.firstWeekday) | Calendar.firstWeekday handles locale correctly; raw `% 7` math breaks at locale boundary |
| Split conditional deny | Schema `@Relationship(deleteRule: .deny)` | `SplitDeletionGuard.assertDeletable(_:)` (exists) | SwiftData deny is unconditional; spec requires allowing delete when only completed blocks remain |

**Key insight:** Every hard problem in this phase (atomicity, phase math, archive serialization, delete guards) already has a project-standard solution. Phase 8 wires existing pieces together, not builds new algorithms.

---

## Runtime State Inventory

> Not a rename/refactor/migration phase. No stored data migration required. The V7 schema is already live.

---

## Common Pitfalls

### Pitfall 1: Autosave Interposing Between Two Mutations
**What goes wrong:** If `currentBlock.isActive = false` is saved by autosave before `newBlock.isActive = true` is written, there is a window with zero active blocks. Conversely, if autosave fires after writing `newBlock.isActive = true` but before writing `currentBlock.endDate`, there is a window with two active blocks.
**Why it happens:** SwiftData autosave (`isAutosaveEnabled` defaults to `true`) fires on RunLoop boundaries. The app has no explicit `isAutosaveEnabled = false` in `fitbodApp.swift`.
**How to avoid:** Wrap ALL mutations for a lifecycle transition in a single `context.transaction { context.save() }` block. The transaction flushes synchronously before the RunLoop yields. Established precedent: `BlockDraft.save(into:)` (lines 87-142), `BlockReviewView.pendingReviewBlocks` (line 496).
**Warning signs:** Test that checks `isActive` count between two property writes — if you see `count == 0` or `count == 2` flickers, a transaction is missing.

### Pitfall 2: Predicate Multi-Level Optional Chain (Pitfall 1 from SessionFactory research)
**What goes wrong:** `#Predicate { session in session.slot?.split?.id == targetID }` silently returns empty on iOS 17/18 even when matching rows exist.
**Why it happens:** The `#Predicate` macro expansion does not handle multi-level optional chains in cross-relationship comparisons.
**How to avoid:** Use a broad `#Predicate` (e.g., `completedAt != nil`) and post-filter in Swift with the multi-level chain. Already established in `SessionFactory.fetchHistoryPoints` and `lastSessionWorkingReps`.
**Warning signs:** Resolver always returns `session(slot: position 0)` even after multiple completed sessions.

### Pitfall 3: Mod-by-Zero in Resolver
**What goes wrong:** `(slot.position + 1) % slotCount` crashes when `slotCount == 0`.
**Why it happens:** A split can be emptied mid-block (slots are on the split, not the block; split is live-editable while block is active per spec §2).
**How to avoid:** Guard `slotCount >= 1` before any modulo operation. Return `TodayResolution.emptySplit` (not `.restDay`) for the zero-slot case.
**Warning signs:** Fatal crash in resolver with "Division by zero" during an in-progress block after the linked split loses its last slot.

### Pitfall 4: ArchivedConfigJSON Written Without endDate (or Vice Versa)
**What goes wrong:** A block has `endDate != nil` but `archivedConfigJSON == nil` (or the reverse). Phase 9 archive-mode `BlockOverviewScreen` cannot render.
**Why it happens:** Two separate `context.save()` calls, one for endDate and one for the JSON string. A crash or error between them leaves the block in a half-baked state.
**How to avoid:** Set both `block.endDate` and `block.archivedConfigJSON` in the same `context.transaction { context.save() }` block. The archive string must be constructed (via `ArchivedBlockConfig.write(from:)`) BEFORE entering the transaction so the encoder error can be thrown before the state is committed.
**Warning signs:** A test that crashes the app mid-end-transaction and finds `block.endDate != nil && block.archivedConfigJSON == nil`.

### Pitfall 5: In-Progress Session Counted by Resolver
**What goes wrong:** An abandoned in-progress session (`completedAt == nil`) is returned by the rotation predicate as the "latest completed session", causing the resolver to use its slot position as the anchor. Result: block rotation appears to advance (or not advance) incorrectly.
**Why it happens:** The predicate scans for `completedAt != nil` but the fetch might inadvertently include in-progress rows if the nil check is omitted.
**How to avoid:** The resolver predicate MUST gate on `session.completedAt != nil`. `SessionFactory.active(in:)` provides a separate check for in-progress session detection (resume-state wins the CTA — resolver only scans completed sessions).
**Warning signs:** `TodayResolution.session(slot:)` returns slot 1 when slot 0 is in-progress and slot 0 was the last completed workout.

### Pitfall 6: trainingDays Sorted at Read Rather Than Write
**What goes wrong:** If `Block.trainingDays` getter re-sorts weekdays using `Calendar.current.firstWeekday`, a user who changes their region after a block starts gets different slot assignments mid-block.
**Why it happens:** It seems "correct" to sort on read for display. The spec explicitly forbids this.
**How to avoid:** `Block.trainingDays` getter is verbatim (stores comma-joined ints, parses back). Sorting happens ONLY in `TrainingDaysWriter.sort(weekdays:using:)` at write time. Locale test: write with `firstWeekday=2`, then read with `firstWeekday=1` and assert stored order is unchanged.

### Pitfall 7: BlockOverviewScreen.dayState TODO Replacement
**What goes wrong:** The existing `dayState(for:)` method checks both `session.block?.id == block.id` and `session.slot?.split?.id == block.split?.id` (with a `// TODO Phase 8` comment). After Phase 8, sessions launched via the resolver will have `session.slot` set — the slot-based check is correct. But the `session.block?.id == block.id` fallback keeps sessions launched via the legacy path visible.
**Why it happens:** Both lines read from `weekSessions` (a `@Query` over the current week). The TODO comment indicates both checks should remain until Phase 9 cleans up the legacy-block sessions.
**How to avoid:** Keep both predicates in the OR condition — do not remove `session.block?.id == block.id`. The TODO comment instructs Phase 8 to "confirm or refine", not to remove. The slot-based check is now primary; the block-ID check is the legacy fallback.

---

## Code Examples

### ArchivedBlockConfig.write (new static func needed)

```swift
// Pattern derived from ArchivedBlockConfig.swift (Phase 7 DTO)
// and ArchivedBlockConfigTests.swift (existing test contract)
// [ASSUMED] — exact implementation shape; spec §6 defines required fields.
extension ArchivedBlockConfig {
    public static func write(from block: Block, endedAt: Date) throws -> String {
        let phases = (block.phases ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { phase in
                ArchivedPhaseDTO(
                    kind: phase.nameRaw,
                    weeks: phase.weeks,
                    volumeMultiplier: phase.volumeMultiplier,
                    intensityMultiplier: phase.intensityMultiplier,
                    notes: nil
                )
            }
        let slots = (block.split?.slots ?? [])
            .sorted { $0.position < $1.position }
            .map { slot in
                let exercises = (slot.sessionTemplate?.exercises ?? [])
                    .sorted { $0.orderIndex < $1.orderIndex }
                    .map { ex in
                        ArchivedExerciseDTO(
                            exerciseID: ex.exercise?.id ?? UUID(),
                            exerciseName: ex.exercise?.name ?? "",
                            orderIndex: ex.orderIndex,
                            targetSets: ex.targetSets,
                            targetRepsLow: ex.targetRepsLow,
                            targetRepsHigh: ex.targetRepsHigh,
                            targetRPE: ex.targetRPE,
                            targetRIR: ex.targetRIR,
                            prescribedRestSeconds: ex.prescribedRestSeconds,
                            tempo: ex.tempo,
                            notes: nil,
                            intentRaw: slot.sessionTemplate?.intentRaw ?? "strength",
                            progressionKindRaw: slot.sessionTemplate?.progressionKindRaw ?? "double",
                            generateWarmups: false,
                            tracksTempo: ex.tracksTempo,
                            tracksPartialReps: ex.tracksPartialReps
                        )
                    }
                return ArchivedSlotDTO(
                    position: slot.position,
                    sessionName: slot.sessionTemplate?.name ?? "Slot \(slot.position + 1)",
                    exercises: exercises
                )
            }
        let config = ArchivedBlockConfig(
            blockName: block.name,
            startedAt: block.startDate,
            endedAt: endedAt,
            mode: block.schedulingModeRaw,
            trainingDays: block.trainingDays,
            phases: phases,
            split: ArchivedSplitDTO(name: block.split?.name ?? "", slots: slots)
        )
        let data = try config.encoded()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
```

### InMemoryContainer pattern for Phase 8 tests

```swift
// Pattern from InMemoryContainer.makeCurrent() + FatigueTestFixtures.makeContext()
// [VERIFIED: existing test file InMemoryContainer.swift]
@MainActor
@Suite("TodayResolver", .serialized)
struct TodayResolverTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV7.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    // Helper: create a block with a split having N slots
    private func makeBlock(slotCount: Int, mode: SchedulingMode = .rotation, context: ModelContext) throws -> (Block, Split, [SplitSessionSlot]) {
        let split = Split()
        split.name = "Test Split"
        context.insert(split)

        let slots: [SplitSessionSlot] = (0..<slotCount).map { i in
            let template = SessionTemplate()
            template.name = "Session \(i)"
            context.insert(template)
            let slot = SplitSessionSlot()
            slot.split = split
            slot.position = i
            slot.sessionTemplate = template
            context.insert(slot)
            return slot
        }
        split.slots = slots

        let block = Block()
        block.name = "Test Block"
        block.isActive = true
        block.split = split
        block.schedulingMode = mode
        context.insert(block)
        try context.save()
        return (block, split, slots)
    }
}
```

### TodayView.todaysRoutine replacement shape

```swift
// Source: TodayView.swift:365-368 (stub to replace)
// [ASSUMED] — implementation wiring; resolver provides the slot
private var todaysRoutine: SessionTemplate? {
    guard let block = activeBlocks.first else { return nil }
    let resolution = TodayResolver.resolve(block: block, context: ctx)
    switch resolution {
    case .session(let slot):
        return slot.sessionTemplate
    case .restDay, .emptySplit, .noBlock:
        return nil
    }
}

// Note: The empty-state branch in TodayView.body already handles
// activeBlocks.isEmpty → StartBlockCTA. TodayResolver.resolve is
// only called when a block IS active. The .emptySplit case maps to
// the existing "No workout scheduled" empty-state text (Phase 9 may
// refine the copy to be fix-it specific; Phase 8 just returns nil
// from todaysRoutine to fall through to the existing empty state).
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `todaysRoutine` returns nil stub | Wired to `TodayResolver` | Phase 8 | Scheduler actually works |
| `template.block` drives BlockPhase in SessionFactory | `session.block` from active block resolver context | Phase 8 | Removes CR-02 legacy read; blocks and templates decouple |
| Manual "one active block" invariant in BlockDraft.save | `BlockLifecycleService.start` handles swap atomically + writes archive | Phase 8 | Start-swap is tested as a unit; no UI code owns the transaction |
| `Block.legacyTemplates` (Block.routines successor) | Write-orphaned (field stays in schema; nothing reads for resolution) | Phase 8 | Field remains for V8 removal; zero prescription reads |

**Deprecated/outdated after Phase 8:**
- `SessionTemplate.block` / `Block.legacyTemplates`: write-orphaned. Document with `// DEPRECATED(Phase 8): write-orphaned; removal in V8 schema migration`. Nothing should read these for prescription resolution.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (`import Testing`) |
| Config file | none (Xcode-native) |
| Quick run command | `xcodebuild test -scheme fitbod -only-testing fitbodTests/TodayResolverTests` |
| Full suite command | `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REQ-01 | Unified rotation predicate: skip, repeat, reorder, ad-hoc, deleted-slot, swapped-split, abandoned-in-progress | unit | `xcodebuild test -only-testing fitbodTests/TodayResolverTests` | ❌ Wave 0 |
| REQ-02 | fixedWeekly: rest days, count drift, mid-block-emptied (zero-slot short-circuit) | unit | `xcodebuild test -only-testing fitbodTests/TodayResolverTests` | ❌ Wave 0 |
| REQ-03 | Locale test: trainingDays stored order stable across simulated region change | unit | `xcodebuild test -only-testing fitbodTests/TrainingDaysWriterTests` | ❌ Wave 0 |
| REQ-04 | One-save handover atomicity for start-swap (no zero-or-two actives window) | unit | `xcodebuild test -only-testing fitbodTests/BlockLifecycleServiceTests` | ❌ Wave 0 |
| REQ-05 | End-block writes archivedConfigJSON in same save as endDate | unit | `xcodebuild test -only-testing fitbodTests/BlockLifecycleServiceTests` | ❌ Wave 0 |
| REQ-06 | Conditional deny: refuse split delete/archive while draft/ready/active block references | unit | `xcodebuild test -only-testing fitbodTests/BlockLifecycleServiceTests` (or SplitDeletionGuard) | ❌ Wave 0 (SplitDeletionGuard tests exist; new lifecycle call-site tests needed) |
| REQ-07 | SessionFactory prescription uses `session.block` (active block) not `template.block` | unit | `xcodebuild test -only-testing fitbodTests/SessionFactoryTests` | ❌ new test needed in existing file |
| REQ-08 | `Session.slot` nullify delete-rule: slot delete leaves session history intact | unit | `xcodebuild test -only-testing fitbodTests/CascadeRuleTests` or new | ❌ Wave 0 |
| REQ-09 | BlockOverviewScreen.dayState membership check (slot-based + block-ID fallback) | unit | `xcodebuild test -only-testing fitbodTests/BlockOverviewScreenWeekCarouselTests` | ❌ new assertion in existing suite |

### Sampling Rate
- **Per task commit:** Run affected test file only (fast, ~5s per suite)
- **Per wave merge:** Full `fitbodTests` suite
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `fitbodTests/TodayResolverTests.swift` — covers REQ-01, REQ-02
- [ ] `fitbodTests/BlockLifecycleServiceTests.swift` — covers REQ-04, REQ-05, REQ-06
- [ ] `fitbodTests/TrainingDaysWriterTests.swift` — covers REQ-03
- [ ] New test method in `fitbodTests/SessionFactoryTests.swift` — covers REQ-07
- [ ] New test method or file for `Session.slot` nullify rule — covers REQ-08

*(Existing `SplitDeletionGuardTests.swift` covers the guard logic itself — 5 passing tests. New lifecycle tests call the guard from lifecycle service call sites.)*
*(Existing `BlockOverviewScreenWeekCarouselTests.swift` exists — may need one new assertion for REQ-09.)*

---

## Security Domain

> `security_enforcement` not explicitly set to `false` — treating as enabled.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | local-only, single user |
| V3 Session Management | no | local-only |
| V4 Access Control | no | single user |
| V5 Input Validation | yes (minimal) | `guard slotCount >= 1` before mod; nil checks on block/split relationships |
| V6 Cryptography | no | archive is plaintext JSON in SwiftData String column |

### Known Threat Patterns for this Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Div-by-zero in `% slotCount` | Tampering (data corruption) | `guard slotCount >= 1` before resolver |
| `archivedConfigJSON` decode failure surfacing raw error to UI | Information Disclosure | Return typed `ArchiveUnreadableError` enum case; no raw `localizedDescription` in UI |
| Two blocks active simultaneously (swap bug) | Tampering (data integrity) | `context.transaction { context.save() }` single-save pattern |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `ArchivedBlockConfig.write(from:endedAt:)` is a new static method on `ArchivedBlockConfig` | Code Examples | Implementation shape could differ (e.g., method on `BlockLifecycleService`); no behavioral risk |
| A2 | `SessionFactory.start` gains an `activeBlock: Block?` parameter for the Phase 8 migration | Architecture Patterns | Alternative: resolver passes block to a separate post-start helper; semantically identical |
| A3 | `TodayResolution.emptySplit` falls through to the existing "No workout scheduled" empty-state in TodayView (Phase 9 refines) | Code Examples | If spec requires a different copy in Phase 8 for empty-split vs rest-day, a new branch is needed |
| A4 | `BlockOverviewScreen.dayState` keeps the `session.block?.id == block.id` OR fallback alongside the new slot-based check | Common Pitfalls | If Phase 8 is supposed to remove the legacy fallback entirely, the OR becomes an AND — behavioral regression for pre-resolver sessions |

---

## Open Questions

1. **TodayView empty-state copy for `emptySplit` case**
   - What we know: `TodayResolution.emptySplit` is a distinct case; Phase 9 "renders the surface"
   - What's unclear: Does Phase 8 need new copy ("Routine has no sessions — fix it in SplitDetailView") or does it fall through to the existing "No workout scheduled" copy until Phase 9?
   - Recommendation: Fall through to existing empty-state (`todaysRoutine = nil`) in Phase 8; add a TODO comment pointing to Phase 9. Low risk — behavior is identical (no CTA shown), and CONTEXT.md says "Phase 8 returns a distinguishable case — Phase 9 renders the surface."

2. **`dayIndexInBlock` / `totalDaysInBlock` math in TodayView**
   - What we know: These properties use raw calendar days from `block.startDate` divided by `currentTotalWeeks * 7`. The spec says "keep behavior unless spec contradicts it."
   - What's unclear: For fixedWeekly blocks, "day N of M" based on calendar-elapsed-days is misleading (rest days count). The spec says "keep" — so this is Phase 9 concern.
   - Recommendation: Leave unchanged in Phase 8 per spec instruction.

3. **`BlackSlabCTA` signature for slot-based CTA**
   - What we know: `BlackSlabCTA(routine:dayIndex:totalDays:onStart:)` currently receives a `SessionTemplate` as `routine`. After Phase 8, `todaysRoutine` returns `slot.sessionTemplate`.
   - What's unclear: Whether `BlackSlabCTA` needs to know about the slot itself (e.g., to show slot position "DAY 1 OF 4" correctly for fixedWeekly).
   - Recommendation: `dayIndexInBlock` and `totalDaysInBlock` are separate computed properties in `TodayView` — `BlackSlabCTA` receives them unchanged. No signature change needed.

---

## Environment Availability

> Phase is purely code/config changes — no new external tools, services, or runtimes required.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode / iOS 26.4 SDK | Swift 6, SwiftData transactions | ✓ | iOS 26.4 (project target) | — |
| Swift Testing | All new unit tests | ✓ | bundled with Swift 6 | — |

---

## Sources

### Primary (HIGH confidence)
- `fitbod/Sessions/SessionFactory.swift` — exact lines 133 and 275 for CR-02 migration; confirmed template.block read sites
- `fitbod/Models/Block.swift` — derivedStatus computed property, legacyTemplates relationship, trainingDays accessor
- `fitbod/Models/Session.swift` — slot field (V7 additive), block field
- `fitbod/Models/SplitDeletionGuard.swift` — existing guard seam
- `fitbod/Periodization/BlockDraft.swift` — `context.transaction` one-save pattern (lines 87-142)
- `fitbod/Periodization/BlockReviewView.swift` — `context.transaction` end-block pattern (line 496)
- `fitbod/Periodization/BlockCard.swift` — `context.transaction` for block deactivation (line 47)
- `fitbod/Views/TodayView.swift` — `todaysRoutine` stub (line 366), `dayIndexInBlock`, `dayState` resolution shape
- `fitbod/Periodization/BlockOverviewScreen.swift` — TODO Phase 8 comments on dayState membership checks (lines 211, 234, 510)
- `fitbod/Sessions/RestTimer/RestTimerEngine.swift` — `now: () -> Date` injectable clock precedent
- `fitbod/Fatigue/MondayAtMidnight.swift` — Calendar injection via value-copy parameter precedent
- `fitbodTests/TestSupport/InMemoryContainer.swift` — `makeCurrent()` uses SchemaV7 + FitbodSchemaMigrationPlan
- `fitbodTests/ArchivedBlockConfigTests.swift` — full DTO field contract (DTOs already exist)
- `.planning/quick/training-block-spec/program-graph-spec.md` §4, §5, §6, §9 — locked spec decisions

### Secondary (MEDIUM confidence)
- `fitbodTests/SingleActiveBlockInvariantTests.swift` — one-active-block invariant test shape (uses SchemaV5, but pattern is identical for V7)
- `fitbod/Backup/BackupRestorer.swift` — confirms `r.block` and `s.block` writes are non-prescription paths (safe to leave as legacy writes)

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all types confirmed in source
- Architecture: HIGH — exact call sites identified, transaction pattern confirmed
- Pitfalls: HIGH — all derived from code-level inspection of existing patterns and project pitfall docs
- Session resolver: HIGH for rotation predicate; MEDIUM for fixedWeekly (spec is unambiguous but implementation not yet coded)

**Research date:** 2026-06-11
**Valid until:** 2026-07-11 (stable internal project; no external deps)
