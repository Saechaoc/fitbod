# Phase 8: Scheduler Resolver & Block Lifecycle — Pattern Map

**Mapped:** 2026-06-11
**Files analyzed:** 10 new/modified files
**Analogs found:** 10 / 10

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `fitbod/Periodization/TodayResolver.swift` | service | request-response | `fitbod/Sessions/PreviousMatchingIntent.swift` | exact (static enum, broad fetch + Swift post-filter, Pitfall-1-safe) |
| `fitbod/Periodization/BlockLifecycleService.swift` | service | CRUD | `fitbod/Periodization/BlockDraft.swift` (save) + `fitbod/Periodization/BlockCard.swift` (end-block) | exact (context.transaction one-save) |
| `fitbod/Periodization/TrainingDaysWriter.swift` | utility | transform | `fitbod/Fatigue/MondayAtMidnight.swift` | exact (Calendar value injection via default param) |
| `ArchivedBlockConfig.write(from:endedAt:)` extension | service | transform | `fitbodTests/ArchivedBlockConfigTests.swift` (DTO field contract) + RESEARCH §6 write shape | role-match |
| `fitbod/Sessions/SessionFactory.swift` (lines 133, 275) | service | CRUD | `fitbod/Sessions/SessionFactory.swift` itself (lines 105-165, 261-277) | exact (in-place migration of two call sites) |
| `fitbod/Views/TodayView.swift` (`todaysRoutine`) | view | request-response | `fitbod/Views/TodayView.swift` itself (lines 123-165, 365-368) | exact (stub replacement, no new structure) |
| `fitbod/Periodization/BlockOverviewScreen.swift` (TODO sites) | view | request-response | `fitbod/Periodization/BlockOverviewScreen.swift` itself (lines 206-212, 228-235, 508-511) | exact (confirm/refine both OR predicates) |
| `fitbodTests/TodayResolverTests.swift` | test | CRUD | `fitbodTests/Persistence/SplitDeletionGuardTests.swift` + `fitbodTests/PreviousMatchingIntentTests.swift` | exact (@MainActor .serialized, makeContext, V7 schema fixture) |
| `fitbodTests/BlockLifecycleServiceTests.swift` | test | CRUD | `fitbodTests/SingleActiveBlockInvariantTests.swift` | exact (in-memory V7 container, transactional invariant assertions) |
| `fitbodTests/TrainingDaysWriterTests.swift` | test | transform | `fitbodTests/Persistence/SplitDeletionGuardTests.swift` (suite shape) | role-match |

---

## Pattern Assignments

---

### `fitbod/Periodization/TodayResolver.swift` (service, request-response)

**Analog:** `fitbod/Sessions/PreviousMatchingIntent.swift`

**Imports pattern** (`PreviousMatchingIntent.swift` lines 34-36):
```swift
import Foundation
import SwiftData
```

**Service shape — static enum with static funcs** (`PreviousMatchingIntent.swift` lines 54-55):
```swift
public enum PreviousMatchingIntent {
    public static func fetchTopWorkingSet(
        exerciseID: UUID?,
        intentRaw: String,
        context: ModelContext
    ) -> PreviousMatchingIntentHit? {
```

Apply the same `public enum TodayResolver` shape — caseless enum acts as a namespace for static methods, no instantiation needed.

**Pitfall-1-safe broad fetch + Swift post-filter** (`PreviousMatchingIntent.swift` lines 101-112):
```swift
let descriptor = FetchDescriptor<SessionExercise>()
guard let all = try? context.fetch(descriptor) else { return nil }

let recent = all
    .filter { $0.exercise?.id == targetID && $0.session?.intentRaw == targetIntent }
    .sorted { ($0.session?.startedAt ?? .distantPast) > ($1.session?.startedAt ?? .distantPast) }
    .prefix(5)
```

For `TodayResolver`, the broad predicate gates on `completedAt != nil` only; the multi-level chain `session.slot?.split?.id == block.split?.id` lives in the Swift `.first { }` post-filter, NOT inside `#Predicate`. This is the verbatim Pitfall-1 avoidance pattern from `fetchHistoryPoints` (`SessionFactory.swift` lines 421-438).

**`fetchHistoryPoints` Pitfall-1 pattern** (`SessionFactory.swift` lines 421-438):
```swift
let descriptor = FetchDescriptor<SetEntry>(
    predicate: #Predicate { entry in
        entry.isWarmup == false && entry.isComplete == true
    },
    sortBy: [SortDescriptor(\SetEntry.completedAt, order: .reverse)]
)
guard let all = try? context.fetch(descriptor) else { return [] }

let entries = all.filter { entry in
    entry.reps > 0
        && entry.weight > 0
        && entry.sessionExercise?.session?.intentRaw == targetIntent
        && entry.sessionExercise?.exercise?.id == targetID
}
```

**TodayResolution enum** — new type, no direct analog; follows project pattern for exhaustive enum (see `LoadState<T>` in `.claude/rules/swift/patterns.md`):
```swift
public enum TodayResolution {
    case session(SplitSessionSlot)
    case restDay
    case emptySplit
    case noBlock
}
```

---

### `fitbod/Periodization/BlockLifecycleService.swift` (service, CRUD)

**Primary analog — one-save transaction:** `fitbod/Periodization/BlockDraft.swift` lines 86-143

**Imports pattern** (`BlockDraft.swift` lines 9-11):
```swift
import Foundation
import SwiftData
```

**context.transaction one-save pattern** (`BlockDraft.swift` lines 87-141):
```swift
public func save(into context: ModelContext) throws {
    try context.transaction {
        if isActive {
            let myID = id
            let descriptor = FetchDescriptor<Block>(
                predicate: #Predicate<Block> { $0.isActive == true }
            )
            let activeBlocks = try context.fetch(descriptor)
            for block in activeBlocks where block.id != myID {
                block.isActive = false
            }
        }
        // ... mutate fields ...
        try context.save()
    }
}
```

**End-block analog in BlockCard.swift** (`BlockCard.swift` lines 44-55):
```swift
Button("End Block", role: .destructive) {
    if let target = pendingEndConfirm {
        do {
            try ctx.transaction {
                target.isActive = false
                try ctx.save()
            }
        } catch {
            // Offline single-user write; keep the card visible if the save fails.
        }
    }
    pendingEndConfirm = nil
}
```

Phase 8 promotes this into `BlockLifecycleService.end(block:context:now:)` with the archive write added inside the same transaction. The critical invariant: `archivedConfigJSON` string is computed BEFORE entering the transaction (so an encoder throw aborts before any state mutation), then assigned inside the transaction with `endDate` in the same `context.save()`.

**Service shape — static methods on enum/struct** (`SplitDeletionGuard.swift` lines 33-52):
```swift
public enum SplitDeletionGuard {
    public static func canDelete(_ split: Split) -> Bool {
        !(split.blocks ?? []).contains { $0.derivedStatus != .completed }
    }
    public static func assertDeletable(_ split: Split) throws {
        guard canDelete(split) else {
            throw SplitDeletionError.referencedByLiveBlock
        }
    }
}
```

Apply the same `public enum BlockLifecycleService` shape with typed throws.

**Clock injection precedent** (`RestTimerEngine.swift` lines 108-118):
```swift
private let now: () -> Date

public init(
    scheduler: RestTimerNotificationScheduling = LiveNotificationScheduler(),
    activityController: RestTimerActivityControlling = NoopActivityController(),
    now: @escaping () -> Date = { Date.now }
) {
```

For `BlockLifecycleService` static funcs, inject as a value parameter with a default:
```swift
public static func start(block: Block, context: ModelContext, now: Date = .now) throws
public static func end(block: Block, context: ModelContext, now: Date = .now) throws
```

**SplitDeletionGuard wiring** — call `SplitDeletionGuard.assertDeletable(split)` from the lifecycle service's `splitAttach/swap` guard rather than duplicating the predicate.

---

### `fitbod/Periodization/TrainingDaysWriter.swift` (utility, transform)

**Analog:** `fitbod/Fatigue/MondayAtMidnight.swift`

**Calendar value injection** (`MondayAtMidnight.swift` lines 23-33):
```swift
public func mondayAtMidnightForToday(
    weekStartsMonday: Bool,
    calendar: Calendar = .current
) -> Date {
    var cal = calendar          // copy — value type; caller's Calendar.current untouched
    if weekStartsMonday {
        cal.firstWeekday = 2
    }
    let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
    return cal.date(from: components) ?? self
}
```

**TrainingDaysWriter shape** — static method on enum or struct, accepting `Calendar` by value with a `.current` default:
```swift
public enum TrainingDaysWriter {
    public static func sort(weekdays: [Int], using calendar: Calendar = .current) -> [Int] {
        let firstWeekday = calendar.firstWeekday  // 1=Sun, 2=Mon per NSCalendar contract
        return weekdays.sorted { a, b in
            let normA = (a - firstWeekday + 7) % 7
            let normB = (b - firstWeekday + 7) % 7
            return normA < normB
        }
    }
}
```

Locale test shape: construct a `Calendar` with `firstWeekday = 2`, call `sort(weekdays:using:)`, store the result on a `Block`, then read `block.trainingDays` back with a separate `Calendar` where `firstWeekday = 1` — assert stored array is unchanged.

---

### `ArchivedBlockConfig.write(from:endedAt:)` (archive write extension)

**Analog — DTO field contract:** `fitbodTests/ArchivedBlockConfigTests.swift` lines 22-63

This test file is the ground-truth contract for all `ArchivedBlockConfig` fields. The `makeConfig()` helper shows every required property and their types:

```swift
private func makeConfig(startedAt: Date = ..., endedAt: Date = ...) -> ArchivedBlockConfig {
    let exercise = ArchivedExerciseDTO(
        exerciseID: UUID(), exerciseName: "Squat", orderIndex: 0,
        targetSets: 3, targetRepsLow: 5, targetRepsHigh: 8,
        targetRPE: 8.0, targetRIR: nil, prescribedRestSeconds: 180,
        tempo: nil, notes: nil, intentRaw: "strength",
        progressionKindRaw: "double", generateWarmups: true,
        tracksTempo: false, tracksPartialReps: false
    )
    let slot = ArchivedSlotDTO(position: 0, sessionName: "Day A", exercises: [exercise])
    let split = ArchivedSplitDTO(name: "PPL", slots: [slot])
    let phase = ArchivedPhaseDTO(kind: "accumulation", weeks: 4,
        volumeMultiplier: 1.0, intensityMultiplier: 1.0, notes: nil)
    return ArchivedBlockConfig(
        blockName: "Strength Block",
        startedAt: startedAt, endedAt: endedAt,
        mode: "rotation", trainingDays: [2, 4, 6],
        phases: [phase], split: split
    )
}
```

**encode/decode round-trip** (`ArchivedBlockConfigTests.swift` lines 76-80):
```swift
let data = try config.encoded()
let decoded = try ArchivedBlockConfig.decode(from: data)
#expect(config == decoded)
```

The `write` static method must produce a `String` from `config.encoded()` and throw its encoder error outward — never swallow it. Decode failure in readers must throw a typed error, never fall back to live templates (`ArchivedBlockConfigTests.swift` lines 134-148):
```swift
@Test("decode throws on malformed JSON — no live-template fallback")
func decodeThrowsOnBadJSON() {
    let garbage = Data("not valid json at all".utf8)
    #expect(throws: (any Error).self) {
        try ArchivedBlockConfig.decode(from: garbage)
    }
}
```

---

### `fitbod/Sessions/SessionFactory.swift` (MODIFY — lines 133, 275)

**Current code (line 133):**
```swift
session.block = template.block                 // optional; safe to carry forward
```

**Current code (lines 261-277) — `strategy.prescribe(...)` call:**
```swift
let (prescribedWeight, _) = strategy.prescribe(
    history: historyPoints,
    targetRepsLow: re.targetRepsLow,
    targetRepsHigh: re.targetRepsHigh,
    targetRPE: re.targetRPE,
    lastSessionRepsArray: lastRepsArray.isEmpty ? nil : lastRepsArray,
    smallestIncrement: smallestIncrement,
    plates: plates,
    barWeight: barWeight,
    minCalibrationSets: minCalibrationSets,
    lastSessionWeight: lastSessionWeight,
    lastSessionReps: lastSessionReps,
    lastSessionRPE: lastSessionRPE,
    lastSessionDate: lastSessionDate,
    block: template.block,           // <-- line 275: legacy read to migrate
    today: date
)
```

**Current code (lines 165-168) — `scheduledBlockPhase` from template.block:**
```swift
let scheduledBlockPhase = template.block.flatMap { block in
    PeriodizationEngine.phase(for: block, on: date)
}
let scheduledDeloadActive = scheduledBlockPhase?.kind == .deload
```

**`SessionFactory.start` signature** (`SessionFactory.swift` lines 105-109):
```swift
public static func start(
    template: SessionTemplate,
    on date: Date = .now,
    context: ModelContext
) throws -> Session {
```

Post-migration, `start` gains an `activeBlock: Block?` parameter (with default `nil` for backward compatibility in tests not yet passing an active block). All three `template.block` reads — line 133, line 165, and line 275 — become `activeBlock` references:

```swift
// After migration:
public static func start(
    template: SessionTemplate,
    activeBlock: Block? = nil,    // NEW — resolver context, not template edge
    on date: Date = .now,
    context: ModelContext
) throws -> Session {
    // ...
    session.block = activeBlock                    // was: template.block (line 133)
    // ...
    let scheduledBlockPhase = activeBlock.flatMap { block in    // was: template.block (line 165)
        PeriodizationEngine.phase(for: block, on: date)
    }
    // ...
    block: activeBlock,                            // was: template.block (line 275)
```

**`TodayView.startWorkout` call site** (`TodayView.swift` lines 387-395):
```swift
@MainActor
private func startWorkout(_ routine: SessionTemplate) {
    do {
        let session = try SessionFactory.start(template: routine, context: ctx)
        navigationPath.append(SessionRoute.logger(session))
    } catch {
        // ...
    }
}
```

After Phase 8, this becomes:
```swift
let session = try SessionFactory.start(
    template: routine,
    activeBlock: activeBlocks.first,   // pass resolver context
    context: ctx
)
```

---

### `fitbod/Views/TodayView.swift` (`todaysRoutine` stub replacement)

**Current stub** (`TodayView.swift` lines 361-368):
```swift
/// The session template scheduled for today in the active block (nil when none).
///
/// V7: block.routines removed; Phase 8 unified resolver drives this property.
/// Returns nil as a compile stub so the app builds green against V7 models.
private var todaysRoutine: SessionTemplate? {
    // TODO Phase 8: replace with unified resolver predicate (spec §5)
    return nil
}
```

**Consumers of `todaysRoutine`** (`TodayView.swift` lines 123-165):
```swift
} else if let routine = todaysRoutine {
    // Scheduled routine → Black slab CTA
    BlackSlabCTA(
        routine: routine,
        dayIndex: dayIndexInBlock,
        totalDays: totalDaysInBlock,
        onStart: { startWorkout(routine) }
    )
}
// ...
LiftListSection(routine: todaysRoutine)
```

`BlackSlabCTA` receives the `SessionTemplate`; `LiftListSection` receives an optional `SessionTemplate?`. No signature changes required — `slot.sessionTemplate` fulfills the `SessionTemplate?` contract. The `.emptySplit` case from the resolver falls through to `nil` → the existing "No workout scheduled" empty state branch (`TodayView.swift` lines 136-162), with a `// TODO Phase 9: distinguish emptySplit copy` comment.

**Pattern for the replacement:**
```swift
private var todaysRoutine: SessionTemplate? {
    guard let block = activeBlocks.first else { return nil }
    let resolution = TodayResolver.resolve(block: block, context: ctx)
    switch resolution {
    case .session(let slot):
        return slot.sessionTemplate
    case .restDay, .emptySplit, .noBlock:
        // TODO Phase 9: .emptySplit needs a distinct "fix-it" surface
        return nil
    }
}
```

---

### `fitbod/Periodization/BlockOverviewScreen.swift` (TODO Phase 8 sites)

**Three TODO sites** — all use an OR predicate; Phase 8 confirms the OR stays (not becomes AND):

**Lines 206-212** (`dayState(for:)` method):
```swift
let sessionLinked = weekSessions.contains { session in
    cal.isDate(session.startedAt, inSameDayAs: cellDate)
    && (session.block?.id == block.id
        // V7: block.routines removed; use slot→split link as canonical check.
        // TODO Phase 8: replace with slot-based session membership predicate.
        || session.slot?.split?.id == block.split?.id)
}
```

**Lines 228-235** (`routineNameForCell(at:)` method):
```swift
return weekSessions.first { session in
    cal.isDate(session.startedAt, inSameDayAs: cellDate)
    && (session.block?.id == block.id
        // V7: block.routines removed; slot→split link as canonical check.
        // TODO Phase 8: replace with slot-based session membership predicate.
        || session.slot?.split?.id == block.split?.id)
}
```

**Line 508-511** (`phaseRow` helper — summary text computation):
```swift
let done = weekSessions.filter { s in
    // V7: block.routines removed; slot→split link as canonical check.
    // TODO Phase 8: replace with slot-based session membership predicate.
    s.slot?.split?.id == block.split?.id || s.block?.id == block.id
}.count
```

Per RESEARCH Pitfall 7: keep BOTH predicates in the OR condition. The `session.block?.id == block.id` path is the legacy fallback for pre-resolver sessions; the `session.slot?.split?.id == block.split?.id` path is now primary. Phase 8 removes the TODO comments and tightens the OR order (slot-based first, block-ID as fallback). The multi-level optional chain `session.slot?.split?.id` is fine inside a Swift closure — Pitfall 1 only applies to `#Predicate`.

---

## Test Suite Patterns

---

### `fitbodTests/TodayResolverTests.swift` (new)

**Analog:** `fitbodTests/Persistence/SplitDeletionGuardTests.swift` + `fitbodTests/PreviousMatchingIntentTests.swift`

**Suite declaration** (`SplitDeletionGuardTests.swift` lines 21-22):
```swift
@MainActor
@Suite("SplitDeletionGuard", .serialized)
struct SplitDeletionGuardTests {
```

**`makeContext()` — V7 schema, in-memory** (`SplitDeletionGuardTests.swift` lines 24-33):
```swift
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
```

**Fixture helper building a Split with slots** (`SplitDeletionGuardTests.swift` lines 36-51):
```swift
private func makeSplitWithSlot(_ ctx: ModelContext, name: String) -> Split {
    let split = Split()
    ctx.insert(split)
    split.name = name

    let template = SessionTemplate()
    ctx.insert(template)
    template.name = "\(name) session"

    let slot = SplitSessionSlot()
    ctx.insert(slot)
    slot.split = split
    slot.position = 0
    slot.sessionTemplate = template
    return split
}
```

**Insert-before-relate convention** is explicit: `ctx.insert(split)` before `slot.split = split`. Required by CLAUDE.md SwiftData convention.

**@Test shape** (`SplitDeletionGuardTests.swift` lines 53-60):
```swift
@Test("A split with no referencing blocks is deletable")
func unreferencedSplitIsDeletable() throws {
    let ctx = try makeContext()
    let split = makeSplitWithSlot(ctx, name: "Orphan")
    try ctx.save()

    #expect(SplitDeletionGuard.canDelete(split))
    #expect(throws: Never.self) { try SplitDeletionGuard.assertDeletable(split) }
}
```

For `TodayResolverTests`, the `makeBlock(slotCount:mode:context:)` fixture from RESEARCH.md §Code Examples is the exact analog of `makeSplitWithSlot` — a private helper that builds the graph object and calls `try ctx.save()` before assertions.

**`PreviousMatchingIntentTests.makeContext()` uses SchemaV5** (`PreviousMatchingIntentTests.swift` lines 34-43) — for Phase 8 tests use `SchemaV7` (per `SplitDeletionGuardTests`). The `@MainActor @Suite(.serialized)` declaration is identical across both and should be copied verbatim.

---

### `fitbodTests/BlockLifecycleServiceTests.swift` (new)

**Analog:** `fitbodTests/SingleActiveBlockInvariantTests.swift`

**Suite + context shape** (`SingleActiveBlockInvariantTests.swift` lines 13-25):
```swift
@MainActor
@Suite("SingleActiveBlockInvariant", .serialized)
struct SingleActiveBlockInvariantTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV5.models)
        // ...
    }
```

For Phase 8 use `SchemaV7.models` + `InMemoryContainer.makeCurrent()` (already wraps V7). Alternatively use the `SplitDeletionGuardTests.makeContext()` pattern directly.

**Invariant assertion shape** (`SingleActiveBlockInvariantTests.swift` lines 43-46):
```swift
let active = try context.fetch(FetchDescriptor<Block>(predicate: #Predicate { $0.isActive == true }))
#expect(active.count == 1)
#expect(active.first?.name == "Next")
#expect(prior.isActive == false)
```

For atomicity tests: assert NO intermediate state by checking count before and after the single `context.transaction { context.save() }` completes — no mid-save count assertions (impossible in synchronous tests without a second thread). The "no zero-or-two-actives window" is tested by asserting count == 1 after the full operation, and asserting that `endDate` + `archivedConfigJSON` are both non-nil simultaneously (Pitfall 4 guard).

---

### `fitbodTests/TrainingDaysWriterTests.swift` (new)

**Analog:** `fitbodTests/Persistence/SplitDeletionGuardTests.swift` (suite shape, no SwiftData container needed — pure value logic)

Since `TrainingDaysWriter.sort(weekdays:using:)` is a pure function with no model context, tests are simpler:
```swift
@Suite("TrainingDaysWriter")
struct TrainingDaysWriterTests {
    @Test("Sun-first locale: [3,1,6] sorts to [1,3,6]")
    func sunFirstSort() {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1  // Sunday
        let sorted = TrainingDaysWriter.sort(weekdays: [3, 1, 6], using: cal)
        #expect(sorted == [1, 3, 6])
    }

    @Test("Locale change after write does not re-sort stored trainingDays")
    func regionChangeDoesNotResort() throws {
        // ...
    }
}
```

No `@MainActor` or `.serialized` needed — pure value computation.

---

## Shared Patterns

### one-save transaction
**Source:** `fitbod/Periodization/BlockDraft.swift` lines 87-141, `fitbod/Periodization/BlockCard.swift` lines 44-55
**Apply to:** `BlockLifecycleService.start`, `BlockLifecycleService.end`, `BlockLifecycleService.swap`
```swift
try context.transaction {
    // all mutations here
    try context.save()
}
```
The archive JSON string is computed OUTSIDE the transaction (so an encoder error throws before any state is committed), then assigned INSIDE. No `context.save()` call must appear outside the transaction block for lifecycle operations.

### Pitfall-1-safe fetch
**Source:** `fitbod/Sessions/PreviousMatchingIntent.swift` lines 101-112, `fitbod/Sessions/SessionFactory.swift` lines 421-438
**Apply to:** `TodayResolver.resolveRotation`, `TodayResolver.resolveFixedWeekly`
Multi-level optional chains (`session.slot?.split?.id`, `session.block?.id`) must live in Swift `.filter { }` / `.first { }` closures, NEVER inside `#Predicate { }`. The `#Predicate` gate must be a flat, single-level predicate (e.g., `$0.completedAt != nil`).

### Calendar value injection
**Source:** `fitbod/Fatigue/MondayAtMidnight.swift` lines 23-33
**Apply to:** `TrainingDaysWriter.sort(weekdays:using:)`
```swift
func someFunc(calendar: Calendar = .current) {
    var cal = calendar  // copy: value type; mutation doesn't affect caller's .current
    // use cal.firstWeekday
}
```

### SplitDeletionGuard as enforcement seam
**Source:** `fitbod/Models/SplitDeletionGuard.swift` lines 33-52
**Apply to:** `BlockLifecycleService.attachSplit`, `BlockLifecycleService.swapSplit` (call `SplitDeletionGuard.assertDeletable` or `canDelete` for the archive-path guard; call from lifecycle service, not from UI)

### Swift Testing suite shape for SwiftData tests
**Source:** `fitbodTests/Persistence/SplitDeletionGuardTests.swift` lines 21-51
**Apply to:** `TodayResolverTests`, `BlockLifecycleServiceTests`, new `SessionFactoryTests` method
```swift
@MainActor
@Suite("SuiteName", .serialized)
struct SuiteTests {
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
}
```

### Import block for new service files
**Source:** `fitbod/Models/SplitDeletionGuard.swift` lines 24-24, `fitbod/Periodization/BlockDraft.swift` lines 9-11
```swift
import Foundation
import SwiftData
```
No SwiftUI import in service/utility files. `TodayResolver`, `BlockLifecycleService`, `TrainingDaysWriter` are all pure Foundation + SwiftData.

---

## No Analog Found

All files have analogs. No entries required.

---

## Metadata

**Analog search scope:** `fitbod/Periodization/`, `fitbod/Sessions/`, `fitbod/Views/`, `fitbod/Models/`, `fitbod/Fatigue/`, `fitbodTests/`
**Files scanned:** 17 source files read directly; 10+ via targeted grep
**Pattern extraction date:** 2026-06-11
