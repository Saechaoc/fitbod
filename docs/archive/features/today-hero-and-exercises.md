# Today redesign 1.2: hero and exercises

> Historical completed implementation plan, archived 2026-11-08. Current scope/status/acceptance: [RM-058](../../ROADMAP.md#rm-058). Do not execute this plan or treat its checkboxes, GSD/executor instructions, old paths or test mandates as current policy. [DEVELOPMENT.md](../../DEVELOPMENT.md) governs new work.

**Scope:** Shared phase working-set count, calendar propagation into factory/starter, TODAY/NEXT UP hero and EXERCISES/View rows. Session sheet/state slabs (RM-006), review/next-day lines and full release acceptance are excluded.
**Build/commits:** 2026-11-07, `0b2a8187` through `3cb65f6b`; original plan and summary preserved in Git at `ba27f304`.
**Recorded results:** Helper/factory 37/37, factory/starter 21/21 and TodayHero UI 2/2 passed; four 17e light/dark active/deload captures reviewed. Full run `full-20261107-074201`: 1,342 run, 1,339 passed, two failures and one expected failure. Unit target: 1,259 run, 1,258 passed, one expected failure. Swap relaunch and History delete failed in the full run and passed alone; this is not a fully green full-tier result.
**Limits:** SQLite short read 4618 exposed the unsafe store-open classification retained in RM-001. History deletion later received a test fix in `3febe870`. Physical/stability/release checks remain separate. No app checks were rerun while archiving.

**Provenance:** `.planning/quick/261106-he2-hero-and-exercises/261106-he2-PLAN.md` at `ba27f304`. The original text below is retained as design/implementation history; it is not a second actionable plan or evidence dump.

## Preserved plan

---
phase: quick-261106-he2
plan: "01"
type: execute
mode: quick
wave: 1
depends_on: [quick-261106-pl1]
autonomous: true
requirements: [REDESIGN-1.2]
files_modified:
  - fitbod/Prescription/WorkingSetCount.swift
  - fitbod/Sessions/SessionFactory.swift
  - fitbod/Routines/WorkoutStarter.swift
  - fitbod/Views/BlackSlabCTA.swift
  - fitbod/Views/LiftListSection.swift
  - fitbod/Views/LiftListRow.swift
  - fitbod/Views/TodayView.swift
  - fitbod/App/BlockStatesSeed.swift
  - docs/design-map/redesign/changelog.md
  - docs/design-map/screens/img/
  - fitbodTests/WorkingSetCountTests.swift
  - fitbodTests/DeloadVolumeApplicationTests.swift
  - fitbodTests/BlackSlabCTALabelTests.swift
  - fitbodTests/TodayViewBRUCopyTests.swift
  - fitbodUITests/TodayHeroUITests.swift
must_haves:
  truths:
    - "One function, PeriodizationEngine.workingSetCount(targetSets:phase:), decides how many working sets a prescription yields in a phase; the logger, the hero's set count and every exercise subline call it."
    - "The hero's label reads TODAY under a fixed-weekly block and NEXT UP · n OF m under a rotation; the day counter is gone."
    - "In a deload week the hero's set count and the exercise sublines show the cut counts the logger generates, and a second caption reads DELOAD WEEK · LIGHTER SETS; nothing else marks the deload."
    - "The exercise list is headed EXERCISES · n with VIEW ›, which opens the session detail; rows carry no chip and no warm-up count."
    - "The factory, the starter and Today read one calendar: SessionFactory.start and WorkoutStarter.start take a calendar, and Today passes its environment calendar."
  artifacts:
    - {path: fitbod/Prescription/WorkingSetCount.swift, provides: "PeriodizationEngine.workingSetCount(targetSets:phase:) -> Int"}
    - {path: fitbod/Views/BlackSlabCTA.swift, provides: "BlackSlabCTA(routine:label:phase:onStart:onChooseAnother:) and BlackSlabCTA.heroLabel(mode:position:slotCount:)"}
    - {path: fitbod/Views/LiftListSection.swift, provides: "LiftListSection(routine:phase:onView:)"}
    - {path: fitbod/Views/LiftListRow.swift, provides: "LiftListRow(index:routineExercise:phase:) with the n × lo-hi subline"}
  key_links:
    - {from: SessionFactory.start, to: PeriodizationEngine.workingSetCount, via: "plannedWorkingSetCount"}
    - {from: BlackSlabCTA.setCount, to: PeriodizationEngine.workingSetCount, via: "reduce over routine.exercises"}
    - {from: TodayView.startWorkout, to: WorkoutStarter.start, via: "calendar: calendar"}
    - {from: LiftListSection onView, to: SessionTemplateDetailView, via: "openedTemplate = routine in TodayView"}
---

# Today redesign step 1.2: Hero and exercises

> **For agentic workers:** run this plan through `/gsd-quick resume hero-and-exercises`, this repo's workflow.
> Where GSD is unavailable, `superpowers:executing-plans` is the fallback.
> Steps use checkbox (`- [ ]`) syntax for tracking.
> Run it only after step 1.1 (`.planning/quick/261106-pl1-today-state-and-the-plan-line/`) has landed all six of its commits: this plan edits the `TodayView` that 1.1 leaves behind and uses the deload seed 1.1 adds.

**Goal:** land step 1.2 of the Today and Program redesign: the hero relabelled ("TODAY" or "NEXT UP · 2 OF 3", no day counter, a deload caption), the exercise list headed "EXERCISES · 5" with "VIEW ›" and rows that read "3 × 5-8" with no chip, and one working-set rule shared by the logger, the hero and the rows, read with one calendar.

**Architecture:** `PeriodizationEngine.workingSetCount(targetSets:phase:)` holds the deload cut `SessionFactory` applies today, taking the phase rather than computing it, so the hero and the sublines can sum the exact sets the logger will generate.
`SessionFactory.start` and `WorkoutStarter.start` gain a `calendar` parameter that reaches `PeriodizationEngine.phase(for:on:calendar:)`, and Today passes its environment calendar to both its own phase read and the start, so the hero and the logger never disagree about which week it is.
The views stay dumb: TodayView computes the hero's label and the current `BlockPhase` once and hands them down.

**Tech Stack:** Swift 6 strict concurrency, SwiftUI, SwiftData (SchemaV7, unchanged), Swift Testing for unit suites, XCTest for UI suites, BRU design system.

**Spec:** `docs/design-map/redesign/plan.md` step 1.2 (the row that starts "1.2 Hero and exercises"), with `docs/design-map/redesign/hierarchy.md` (the Hero and Exercises rows of the shared pieces table at lines 20-21, the T-TODAY row at line 50, the deload paragraph at line 78 and the Deload row of the "What goes" table at line 132), `docs/design-map/redesign/today-layouts.md` (the T-TODAY wireframe and element table at lines 10-50, and "T-TODAY, rotation block, deload week" at lines 52-73) and `docs/design-map/redesign/open-decisions.md` O-11 (exercise rows open nothing; "View ›" is the one way into the session).

## Global Constraints

- Swift 6 strict concurrency; `@Observable` and `@State` only, `@Query` directly in views, never wrapped (CLAUDE.md Conventions).
- SchemaV7 stays. No model attribute, relationship or migration changes.
- BRU only: `BRUFont` roles, `Color.bru*` tokens, `BRUSectionHead`, `BRUPillButton`, `BRUDisplay`, `BRUDivider`, `BRUCountLabel.text`.
  No `Capsule`, `RoundedRectangle`, `Color.accentColor` or `Image(systemName:)`.
- UI copy never leaks code names: "Routine" for `Split`, "Session" for `SessionTemplate`, "workout" for a logged `Session`.
- Hero copy: label "TODAY" (fixed weekly) or "NEXT UP · 2 OF 3" (rotation: the slot's 1-based position of the routine's slot count); name unchanged; meta line "5 EXERCISES · 15 SETS · ~47 MIN" with the set count from `workingSetCount`; button "Start workout ▸" unchanged; ghost "Choose another session ›" unchanged; in a deload phase a second caption "Deload week · lighter sets", rendered uppercase, muted.
- Duration estimate unchanged: `max(1, sets * 3 + 2)` minutes, with `sets` the working-set sum (today-layouts.md line 62: "5 × 3 + 2 minutes").
- Exercises head: `BRUSectionHead("Exercises · \(count)", right: "View ›", rightAction:)`. Row subline: "3 × 5-8" (working sets × rep range, hyphen), on every row; no "warm-up" text, no chip.
- The working-set rule is `SessionFactory`'s today, unchanged in value: `max(1, Int(floor(Double(targetSets) * phase.volumeMultiplier)))` when `phase?.kind == .deload`, else `targetSets`.
- New `calendar` parameters default to `.current`, so no existing caller changes; the only new argument is Today's.
- No `#Predicate` with multi-level optional chains; broad predicate plus a Swift post-filter.
- No `try? ctx.save()` added anywhere.
- Never the em dash character in any new text; use "-" or "·".
- Commit messages carry no co-author or session trailer (the user's rule in `~/.claude/CLAUDE.md` overrides the harness reminder).
- Prototype stage (`docs/DEVELOPMENT.md`): VoiceOver refinement, AX3 captures and the two-phone run wait for step 3.4. Do not add source-reading copy tests beyond editing the ones that block this change.

## Review Focus

Five inputs the spec implies but no existing test exercises, most likely to bite first. Each has its test added to the owning task.

1. A deload phase whose multiplier the lifter left at 1.0 (as the hand-made seeds do) must cut nothing and still show the caption: the caption follows the phase kind, the count follows the multiplier. Test: `WorkingSetCountTests.aDeloadAtFullVolumeCutsNothing` (Task 1).
2. A prescription of one set in a deload must stay one set, never zero, on the hero and in the logger alike. Test: `WorkingSetCountTests.neverBelowOneSet` (Task 1) and the existing `DeloadVolumeApplicationTests.deloadWeekClampsToOneSetWhenTargetSetsIsOne`.
3. A workout started at 23:30 in a time zone where the deload week has begun, under a test calendar that says it has not, must follow the calendar it was given, not the device's. Test: `DeloadVolumeApplicationTests.theFactoryFollowsTheGivenCalendar` (Task 2).
4. A rotation with one slot reads "NEXT UP · 1 OF 1", not a crash on a zero count and not "TODAY". Test: `BlackSlabCTALabelTests.aOneSlotRotationReadsOneOfOne` (Task 3).
5. The first signal element on Today under an active block is START WORKOUT ▸, visible without a scroll on the dedicated phone. Test: `TodayHeroUITests.testStartWorkoutSitsAboveTheFold` (Task 5).

## Decisions taken in this plan

| Decision | Why |
| --- | --- |
| The helper lives on `PeriodizationEngine` as `workingSetCount(targetSets:phase:)`, in its own file `fitbod/Prescription/WorkingSetCount.swift`. | plan.md names the function and the folder; the engine already owns phase math and is a namespace enum, so no new type is needed. |
| The hero's label is computed by `BlackSlabCTA.heroLabel(mode:position:slotCount:)` from values, not models. | Pure and testable without a SwiftData container; TodayView passes `block.schedulingMode`, `slot.position`, `block.split?.slots?.count ?? 0`. |
| The hero keeps its 3 min per set + 2 estimate. | today-layouts.md pins "~47 min" for 15 sets and "5 × 3 + 2 minutes" for the deload. `SessionTemplateSummary` on the session detail uses rest-based minutes and will differ; that is pre-existing and outside this step (see the Risk line in the summary). |
| The deload caption "Deload week · lighter sets" lands here, not in 1.3. | 1.1 deleted `DeloadWeekBanner` on the promise of the hero's caption (hierarchy.md line 78); until this step lands only the plan line names the deload. |
| `LiftListSection.routine` becomes non-optional; the "Add an exercise to begin." placeholder stays until 1.3. | TodayView only mounts the section with a scheduled routine. plan.md defers the placeholder's deletion to 1.3, whose state slabs make it unreachable. |
| `BlockStatesSeed.makeBlock` gives every deload phase the catalog's 0.5 volume multiplier. | The seed left 1.0, so the deload seed 1.1 added shows no cut. `BlockDraft.swift:54` is the catalog's deload value. No UI test reads the multiplier (checked `BlockOverviewStatesUITests`, `BlockWeekCountsUITests`). |
| The "Add an exercise" row count on the head reads the template's exercise count, including a count of 0. | One expression; the state that would show 0 is unreachable from Today after 1.3. |
| `SessionFactory.holdingDeloadWeight` keeps `.current`. | plan.md scopes the calendar to `start` (`SessionFactory.swift:188-190`); the WHY sheet's read is a separate step if ever. |

<objective>
Land redesign step 1.2 on Today: the relabelled hero, the exercises head with VIEW ›, chip-free rows with working-set sublines, one shared working-set rule and one calendar from Today through the factory.

Purpose: after 1.1 Today has one line of block context; this step makes the hero and the list say exactly what the logger will do, in the deload week too, and removes the counters and chips the redesign drops.
Output: six commits (one per task), unit suites green, the two UI tests green, four refreshed 17e captures and a changelog entry.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@docs/design-map/redesign/plan.md
@docs/design-map/redesign/hierarchy.md
@docs/design-map/redesign/today-layouts.md
@docs/design-map/redesign/open-decisions.md
@docs/DEVELOPMENT.md

<interfaces>
Existing, read only:

- `PeriodizationEngine.phase(for: Block, on: Date, calendar: Calendar = .current) -> BlockPhase?` (`fitbod/Prescription/PeriodizationEngine.swift:21`). `BlockPhase.kind: BlockPhaseKind`, `.volumeMultiplier: Double` (default 1.0).
- `SessionFactory.start(template:slot:activeBlock:on:context:) throws -> Session` (`fitbod/Sessions/SessionFactory.swift:123-129`); the phase read at `:188-190`; the cut at `:290-296` (`plannedWorkingSetCount`).
- `WorkoutStarter.start(_:slot:context:now:) -> WorkoutStartOutcome` (`fitbod/Routines/WorkoutStarter.swift:31-36`) calling the factory at `:42-48`.
- `Block.schedulingMode: SchedulingMode` (`.rotation` | `.fixedWeekly`), `Block.split: Split?`, `Split.slots: [SplitSessionSlot]?`, `SplitSessionSlot.position: Int` (0-based; `TodayResolver.swift:115`), `SplitSessionSlot.sessionTemplate`.
- `SessionExerciseTemplate.targetSets/targetRepsLow/targetRepsHigh/orderIndex/exercise` (`fitbod/Models/SessionExerciseTemplate.swift:44-46`).
- `BRUSectionHead(_ title: String, right: String? = nil, rightAction: (() -> Void)? = nil)` (`fitbod/Design/BRUSectionHead.swift:55`): with an action the right label is a `.plain` button in `bruSignalText` with `.bruHitArea()`; both texts render uppercase.
- `BRUCountLabel.text(_ count: Int, _ singular: String) -> String` ("1 SET", "15 SETS" after `.textCase(.uppercase)`).
- TodayView after 1.1: `@Environment(\.calendar) private var calendar`, `@State private var now`, `let resolution = todaysResolution`, `let todaysRoutine = Self.scheduledRoutine(in: resolution)`, `let state = TodayState.resolve(...)`, `let doneToday`, `currentPhase: BlockPhaseKind?` (`PeriodizationEngine.phase(for: $0, on: now)?.kind`), `currentTotalWeeks`, `isPastPlan`, `dayIndexInBlock`, `totalDaysInBlock`, `canChooseSession`, `startWorkout(_:slot:)` calling `WorkoutStarter.start(routine, slot: slot, context: ctx)`, `@State private var openedTemplate: SessionTemplate?` with `.navigationDestination(item: $openedTemplate) { SessionTemplateDetailView(template: $0) }`, the hero under `case .session(let slot): if let routine = slot.sessionTemplate { BlackSlabCTA(routine: routine, dayIndex: dayIndexInBlock, totalDays: totalDaysInBlock, onStart: { startWorkout(routine, slot: slot) }, onChooseAnother: ...) }`, and `if todaysRoutine != nil && doneToday == nil { LiftListSection(routine: todaysRoutine) }`.
- Seeds: `-fitbod-seed-active-block` (Live Block, rotation, one slot "Live Push", bench 3 × 5-8, accumulation 4 weeks started today); `-fitbod-seed-block-states-deload` (added by 1.1: Spring Block, rotation, slots Upper A then Upper B, each 3 × 5-8, phases accumulation 2 + intensification 1 + deload 1, started 22 days ago; Upper A logged two days ago, Upper B finished empty yesterday, so the rotation's next slot is Upper A, position 0 of 2).
- UI helpers: `UITestNavigation.launch(_ arguments:)`, `.appears(_:within:)`, `.hittable(_ query, _ label, exactLabel:)`, `.tab(_:in:)`, `XCUIElementQuery.labeled(_:)` (case-insensitive label match), `BlockLifecycleEntryPointsUITests.activeBlock`, `UITestNavigation.resetFlag`.

New in this plan:

```swift
// fitbod/Prescription/WorkingSetCount.swift
extension PeriodizationEngine {
    /// Working sets a prescription yields in `phase`: in a deload, floor(targetSets × volume multiplier), at least one; otherwise targetSets.
    public static func workingSetCount(targetSets: Int, phase: BlockPhase?) -> Int
}

// fitbod/Sessions/SessionFactory.swift
public static func start(template:slot:activeBlock:on date: Date = .now, calendar: Calendar = .current, context:) throws -> Session

// fitbod/Routines/WorkoutStarter.swift
public static func start(_ template:, slot: = nil, context:, now: Date = .now, calendar: Calendar = .current) -> WorkoutStartOutcome

// fitbod/Views/BlackSlabCTA.swift
public struct BlackSlabCTA: View {
    let routine: SessionTemplate
    let label: String            // "TODAY" or "NEXT UP · 2 OF 3"
    let phase: BlockPhase?       // the active block's current phase; nil without one
    let onStart: @MainActor () -> Void
    var onChooseAnother: (@MainActor () -> Void)? = nil
    static func heroLabel(mode: SchedulingMode, position: Int, slotCount: Int) -> String
}

// fitbod/Views/LiftListSection.swift
public struct LiftListSection: View {
    let routine: SessionTemplate
    let phase: BlockPhase?
    let onView: () -> Void
}

// fitbod/Views/LiftListRow.swift
public struct LiftListRow: View {
    let index: Int
    let routineExercise: SessionExerciseTemplate
    let phase: BlockPhase?
}
```
</interfaces>
</context>

## Execution boundaries

- Work on the branch 1.1 landed on, from its last commit ("docs(redesign): step 1.1 captures and changelog"). Never push; the user pushes `main`.
- Before editing any symbol, run `gitnexus_impact({target: "<symbol>", direction: "upstream"})` and note the result in the task summary. Known at planning time: `BlackSlabCTA`, `LiftListRow`, `LiftListSection` report CRITICAL with 2 direct callers each (TodayView and their own previews); `SessionFactory` reports CRITICAL with 537 upstream references, almost all tests, and this plan only adds a defaulted parameter and swaps the cut for a call that returns the same numbers; `WorkoutStarter` is LOW. Proceed on those; stop and report if the index shows anything beyond them.
- Run `gitnexus_detect_changes()` before each commit.
- Executors: A runs Tasks 1-2, B runs Tasks 3-4, C runs Tasks 5-6. Each starts from the previous commit. Keep CLAUDE.md out of the executor prompt; it is long and this plan carries what matters.
- `export FITBOD_TEST_DEVICE=D409C89C-DE67-4970-A801-AE3A71378E56` (the `fitbod-logger iPhone 17` simulator) and `FITBOD_TEST_WORKERS=1` for every run. Filter xcodebuild output through `rg "error:|Executed|passed|failed"`.
- Leave alone: `ResumeWorkoutSlab`, `DoneTodaySlab`, `TodaySessionPicker`, `StartBlockCTA`, `ReadyBlockCard`, `TodayPlanLine`, `TodayState`, the advisory row, `FatigueSurfaceView`, `SessionTemplateDetailView` (1.3 passes the slot through it), `SessionFactory.holdingDeloadWeight`, `SessionTemplateSummary`, the volume row (step 1.4), `BRUChip` (still used by `RoutineBuilderView`).
- Do not add source-reading copy tests. Edit `TodayViewBRUCopyTests` only where it blocks the change.

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: PeriodizationEngine.workingSetCount holds the deload cut</name>
  <files>fitbod/Prescription/WorkingSetCount.swift, fitbod/Sessions/SessionFactory.swift:286-296, fitbodTests/WorkingSetCountTests.swift</files>
  <behavior>
    - `workingSetCount(targetSets: 4, phase: deload 0.5)` is 2; `(3, deload 0.5)` is 1; `(5, deload 0.6)` is 3 (floor, not round).
    - `(1, deload 0.5)` is 1 and `(2, deload 0.4)` is 1: never below one.
    - `(4, accumulation 0.5)` is 4 and `(4, nil)` is 4: only a deload cuts.
    - `(3, deload 1.0)` is 3: a deload at full volume cuts nothing.
    - The factory's `plannedWorkingSetCount` is this function's result, so `DeloadVolumeApplicationTests`, `SessionFactoryTests.prescriptionResolvesFromActiveBlockNotTemplateBlock` and `WarmupDeloadIntegrationTests` pass unchanged.
  </behavior>
  <action>
- [ ] **Step 1: Write the failing tests** in `fitbodTests/WorkingSetCountTests.swift`: `@MainActor @Suite("WorkingSetCount")`, a `phase(_ kind: BlockPhaseKind, volume: Double) -> BlockPhase` helper that sets `nameRaw = kind.rawValue` and `volumeMultiplier` on an un-inserted `BlockPhase()` (the form `PeriodizationEngineTests.makeBlock` uses). Tests: `aDeloadFloorsTheProduct` (parameterized over `[(4, 0.5, 2), (3, 0.5, 1), (5, 0.6, 3)]`), `neverBelowOneSet` (`[(1, 0.5), (2, 0.4)]` both 1), `onlyADeloadCuts` (accumulation at 0.5 and `nil` both return 4), `aDeloadAtFullVolumeCutsNothing` (3 at 1.0 is 3).

- [ ] **Step 2: Run them to see them fail**

Run: `scripts/test.sh fast -only-testing:fitbodTests/WorkingSetCountTests 2>&1 | rg "error:|Executed|passed|failed" | tail -5`
Expected: a compile error naming `workingSetCount`.

- [ ] **Step 3: Implement** `fitbod/Prescription/WorkingSetCount.swift`: `extension PeriodizationEngine { public static func workingSetCount(targetSets: Int, phase: BlockPhase?) -> Int }` with the rule from Global Constraints, one guard and one return. Not `@MainActor`: `SessionFactory` is a plain `public enum` and calls it from wherever it runs today, as it calls `PeriodizationEngine.phase`. File header in the project's style (name, target, one paragraph: what it is and that the factory, the hero and the exercise rows all call it).

- [ ] **Step 4: Point the factory at it.** In `SessionFactory.start`, replace the `if scheduledDeloadActive, let scheduledBlockPhase { ... } else { ... }` block (`:290-296`) with `let plannedWorkingSetCount = PeriodizationEngine.workingSetCount(targetSets: re.targetSets, phase: scheduledBlockPhase)`. Keep `scheduledDeloadActive`: the warm-up call at `:259` still reads it.

- [ ] **Step 5: Run the helper suite and the factory suites**

Run: `scripts/test.sh fast -only-testing:fitbodTests/WorkingSetCountTests -only-testing:fitbodTests/DeloadVolumeApplicationTests -only-testing:fitbodTests/SessionFactoryTests -only-testing:fitbodTests/SessionFactoryPhase3Tests -only-testing:fitbodTests/WarmupDeloadIntegrationTests 2>&1 | rg "error:|Executed|passed|failed" | tail -6`
Expected: all pass; the factory suites' set counts are unchanged.

- [ ] **Step 6: Commit**

```bash
git add fitbod/Prescription/WorkingSetCount.swift fitbod/Sessions/SessionFactory.swift fitbodTests/WorkingSetCountTests.swift
git commit -m "refactor(prescription): one rule for the working sets a phase yields"
```
  </action>
  <verify>`scripts/test.sh fast -only-testing:fitbodTests/WorkingSetCountTests -only-testing:fitbodTests/DeloadVolumeApplicationTests` green.</verify>
  <done>The deload cut lives in one public function with tests for the floor, the minimum, the non-deload case and full volume; the factory calls it and its suites are unchanged.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: The factory and the starter take a calendar</name>
  <files>fitbod/Sessions/SessionFactory.swift:123-129 and :188-190, fitbod/Routines/WorkoutStarter.swift:31-48, fitbodTests/DeloadVolumeApplicationTests.swift</files>
  <behavior>
    - `SessionFactory.start(..., on: date, calendar: c, ...)` resolves the phase with `PeriodizationEngine.phase(for: block, on: date, calendar: c)`.
    - Started at 23:00 UTC on the last day of a one-week accumulation, the factory under a UTC calendar keeps 4 sets and under a UTC+2 calendar (where it is 01:00 the next day, the first deload day) cuts to 2.
    - The factory's per-exercise working-set counts equal `workingSetCount` over the template's prescriptions for the same phase.
    - `WorkoutStarter.start(..., calendar:)` forwards the calendar; every existing caller compiles unchanged.
  </behavior>
  <action>
- [ ] **Step 1: Write the failing tests** in `DeloadVolumeApplicationTests` (reuse `makeContext`, `makeBlock`, `makeRoutine`, `workingSetCounts`):

  - `theFactoryFollowsTheGivenCalendar`: `var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(identifier: "UTC")!`, `start = utc.date(from: DateComponents(year: 2024, month: 3, day: 4))!`, block phases `[(.accumulation, 1, 1.0, 0.75), (.deload, 1, 0.5, 0.75)]`, routine `targetSets: [4]`, `late = start.addingTimeInterval(7 * day - 3600)`. Build the block and the routine twice, once per `makeContext()` call, since the factory allows one open workout per store. `#expect(workingSetCounts(in: utcSession) == [4])` and, with `var ahead = utc; ahead.timeZone = TimeZone(secondsFromGMT: 7200)!`, `#expect(workingSetCounts(in: aheadSession) == [2])`.
  - `theFactoryCountsWhatTheHelperCounts`: deload day as in `deloadWeekHalvesWorkingSetCount`, routine `targetSets: [4, 3, 1]`; `let phase = PeriodizationEngine.phase(for: block, on: deloadDate)`; `#expect(workingSetCounts(in: session) == [4, 3, 1].map { PeriodizationEngine.workingSetCount(targetSets: $0, phase: phase) })` and `== [2, 1, 1]`.

- [ ] **Step 2: Run them to see them fail**

Run: `scripts/test.sh fast -only-testing:fitbodTests/DeloadVolumeApplicationTests 2>&1 | rg "error:|Executed|passed|failed" | tail -5`
Expected: a compile error on the `calendar:` argument.

- [ ] **Step 3: Add the parameter.** `SessionFactory.start(template:slot:activeBlock:on date: Date = .now, calendar: Calendar = .current, context: ModelContext)`; the phase read becomes `PeriodizationEngine.phase(for: block, on: date, calendar: calendar)`. One sentence in the doc comment: the calendar decides which block day `date` falls on, so a caller that renders a week from one calendar starts the workout with the same one. `WorkoutStarter.start(_:slot:context:now:calendar: Calendar = .current)` passes `calendar: calendar` to the factory. `startEmpty` is untouched.

- [ ] **Step 4: Run the factory and starter suites**

Run: `scripts/test.sh fast -only-testing:fitbodTests/DeloadVolumeApplicationTests -only-testing:fitbodTests/WorkoutStarterTests -only-testing:fitbodTests/DeloadHoldsWeightTests -only-testing:fitbodTests/SessionBlockSnapshotTests 2>&1 | rg "error:|Executed|passed|failed" | tail -6`
Expected: all pass, the two new tests included.

- [ ] **Step 5: Commit**

```bash
git add fitbod/Sessions/SessionFactory.swift fitbod/Routines/WorkoutStarter.swift fitbodTests/DeloadVolumeApplicationTests.swift
git commit -m "feat(sessions): the factory and the starter take the caller's calendar"
```
  </action>
  <verify>`scripts/test.sh fast -only-testing:fitbodTests/DeloadVolumeApplicationTests` green with `theFactoryFollowsTheGivenCalendar` and `theFactoryCountsWhatTheHelperCounts`.</verify>
  <done>Both start functions take a defaulted calendar that reaches the phase read, proven by a start that lands on different block days under two calendars.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: The hero: label, no day counter, working sets, deload caption</name>
  <files>fitbod/Views/BlackSlabCTA.swift, fitbodTests/BlackSlabCTALabelTests.swift, fitbodTests/TodayViewBRUCopyTests.swift:46-56</files>
  <behavior>
    - `BlackSlabCTA.heroLabel(mode: .fixedWeekly, position: 2, slotCount: 3)` is "TODAY"; `(.rotation, 1, 3)` is "NEXT UP · 2 OF 3"; `(.rotation, 0, 1)` is "NEXT UP · 1 OF 1".
    - The slab's top row is the label alone; "DAY %02d / %02d" is gone from the file.
    - The meta line's set count sums `PeriodizationEngine.workingSetCount(targetSets:phase:)` over the routine's exercises; the minutes use that sum.
    - With `phase?.kind == .deload` a second caption "Deload week · lighter sets" (`BRUFont.labelSmall`, tracking 1.2, uppercase, `bruPaper.opacity(0.6)`) sits 6pt under the meta line; otherwise nothing.
  </behavior>
  <action>
- [ ] **Step 1: Write the failing tests** in `fitbodTests/BlackSlabCTALabelTests.swift`: `@Suite("BlackSlabCTA label")` with `aFixedWeeklyBlockReadsToday`, `aRotationReadsItsPlaceInTheCycle` ("NEXT UP · 2 OF 3" for position 1 of 3), `aOneSlotRotationReadsOneOfOne`. Pure function, no container.

- [ ] **Step 2: Update the copy tests that block the change.** In `TodayViewBRUCopyTests` replace `blackSlabNEXTVerbatim` and `blackSlabDAYFormatVerbatim` (`:46-56`) with one test `blackSlabLabelsVerbatim`: the file contains `"TODAY"`, `"NEXT UP · "`, `"Deload week · lighter sets"` and does not contain `"DAY %02d / %02d"` or `"NEXT"` followed by `"` (write it as `!slabSource.contains("Text(\"NEXT\")")`). Update the header comment line 16 to name the new labels.

- [ ] **Step 3: Run both to see them fail**

Run: `scripts/test.sh fast -only-testing:fitbodTests/BlackSlabCTALabelTests -only-testing:fitbodTests/TodayViewBRUCopyTests 2>&1 | rg "error:|Executed|passed|failed" | tail -5`
Expected: a compile error naming `heroLabel(mode:position:slotCount:)`.

- [ ] **Step 4: Rewrite the slab's inputs and body.** Properties per the interfaces block: `label: String`, `phase: BlockPhase?` replace `dayIndex`/`totalDays`. `static func heroLabel(mode:position:slotCount:) -> String` (a static, so it never shadows the `label` property) returns `"TODAY"` for `.fixedWeekly`, else `"NEXT UP · \(position + 1) OF \(slotCount)"`. `setCount` becomes `(routine.exercises ?? []).reduce(0) { $0 + PeriodizationEngine.workingSetCount(targetSets: $1.targetSets, phase: phase) }`. The top `HStack` becomes the single `Text(label)` with the existing label styling (keep `.textCase(.uppercase)`); delete the `Spacer` and the day `Text`. After the `ViewThatFits` add `if phase?.kind == .deload { Spacer().frame(height: 6); Text("Deload week · lighter sets").font(BRUFont.labelSmall).tracking(1.2).textCase(.uppercase).foregroundStyle(Color.bruPaper.opacity(0.6)) }`. Update the file's layout comment (lines 17-35) to the new rows and drop the "With no day, past the block's plan" sentence. Update the DEBUG preview to `BlackSlabCTA(routine: routine, label: "NEXT UP · 1 OF 3", phase: nil, onStart: {})`.

- [ ] **Step 5: Build Today against the new signature.** TodayView's `BlackSlabCTA(` call does not compile yet; Task 4 rewires it. To keep this commit building, make the minimal call change now in TodayView: `label: BlackSlabCTA.heroLabel(mode: block.schedulingMode, position: slot.position, slotCount: block.split?.slots?.count ?? 0), phase: currentBlockPhase` where `block` is `activeBlocks.first` unwrapped in the same `if let` and `currentBlockPhase` is the property Task 4 Step 2 defines; add it now, exactly as written there.

- [ ] **Step 6: Run the two suites and the full unit tier**

Run: `scripts/test.sh fast 2>&1 | rg "error:|Executed|passed|failed" | tail -6`
Expected: builds; every unit test passes bar the one known expected failure (`docs/ROADMAP.md:9-10`).

- [ ] **Step 7: Commit**

```bash
git add fitbod/Views/BlackSlabCTA.swift fitbod/Views/TodayView.swift fitbodTests/BlackSlabCTALabelTests.swift fitbodTests/TodayViewBRUCopyTests.swift
git commit -m "feat(today): the hero names the day or the cycle, counts working sets and marks the deload"
```
  </action>
  <verify>`scripts/test.sh fast -only-testing:fitbodTests/BlackSlabCTALabelTests -only-testing:fitbodTests/TodayViewBRUCopyTests` green; `rg -n "DAY %02d" fitbod/Views/BlackSlabCTA.swift` prints nothing.</verify>
  <done>The slab reads TODAY or NEXT UP · n OF m, has no day counter, sums working sets through the shared rule and carries the deload caption only in a deload phase.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 4: The exercises head, chip-free rows, and Today's wiring</name>
  <files>fitbod/Views/LiftListSection.swift, fitbod/Views/LiftListRow.swift, fitbod/Views/TodayView.swift, fitbodTests/TodayViewBRUCopyTests.swift:60-67</files>
  <behavior>
    - `LiftListSection(routine:phase:onView:)` heads with `BRUSectionHead("Exercises · \(count)", right: "View ›", rightAction: onView)`; `onView` sets TodayView's `openedTemplate`, which already pushes `SessionTemplateDetailView`.
    - `LiftListRow(index:routineExercise:phase:)` sublines read `"\(workingSetCount) × \(lo)-\(hi)"` on every row; the chip, `isFirstCompound`, `firstCompoundIndex` and the `generateWarmups` branch are gone.
    - TodayView computes `currentBlockPhase` once with `now` and `calendar`, derives `currentPhase` from it, hands the phase to the hero and the list, and starts workouts with `calendar: calendar`.
    - `currentTotalWeeks`, `isPastPlan`, `dayIndexInBlock` and `totalDaysInBlock` are deleted; nothing else read them after 1.1.
  </behavior>
  <action>
- [ ] **Step 1: Update the copy test that blocks the change.** In `TodayViewBRUCopyTests.liftListSectionHeadCopyVerbatim` (`:60-67`) expect `"Exercises · "` and `"View ›"` in `LiftListSection.swift` and keep the `!contains("Tap to reorder")` line. Rename the test `exercisesHeadCopyVerbatim` and fix header comment line 17.

Run: `scripts/test.sh fast -only-testing:fitbodTests/TodayViewBRUCopyTests 2>&1 | rg "error:|Executed|passed|failed" | tail -4`
Expected: that one test fails.

- [ ] **Step 2: TodayView's phase and start.** Add

```swift
/// The active block's current phase, read with Today's date and calendar so the hero, the rows and the start agree.
private var currentBlockPhase: BlockPhase? {
    activeBlocks.first.flatMap { PeriodizationEngine.phase(for: $0, on: now, calendar: calendar) }
}
```
and make `currentPhase` return `currentBlockPhase?.kind`. In `startWorkout(_:slot:)` call `WorkoutStarter.start(routine, slot: slot, context: ctx, calendar: calendar)`. Delete `currentTotalWeeks`, `isPastPlan`, `dayIndexInBlock`, `totalDaysInBlock` (confirm first with `rg -n "currentTotalWeeks|isPastPlan|dayIndexInBlock|totalDaysInBlock" fitbod/Views/TodayView.swift` that only their definitions and the old hero call remain). If `PlanWeek` is then unused in TodayView, nothing else changes; it stays in `BlockOverviewScreen.swift`.

- [ ] **Step 3: The section.** `LiftListSection`: `let routine: SessionTemplate`, `let phase: BlockPhase?`, `let onView: () -> Void`. `sortedExercises` reads `routine.exercises`. Delete `firstCompoundIndex`. Head: `BRUSectionHead("Exercises · \(sortedExercises.count)", right: "View ›", rightAction: onView)`. Rows: `LiftListRow(index: offset + 1, routineExercise: re, phase: phase)`. Keep the placeholder branch. Update the file comment (lines 3-4 and 17-18) and the preview (`LiftListSection(routine: routine, phase: nil, onView: {})`); delete the nil-routine preview.

- [ ] **Step 4: The row.** `LiftListRow`: `let phase: BlockPhase?` replaces `isFirstCompound`; `setSubLine` returns `"\(PeriodizationEngine.workingSetCount(targetSets: routineExercise.targetSets, phase: phase)) × \(lo)-\(hi)"`. Delete `chip`, both chip placements, `@Environment(\.dynamicTypeSize)` and the layout comment's chip column. Keep `numberWidth`, the name, the subline and `BRUDivider(.hair)`. Preview: `LiftListRow(index: 1, routineExercise: benchRE, phase: nil)` and the fly row likewise.

- [ ] **Step 5: Mount in TodayView.** Replace `if todaysRoutine != nil && doneToday == nil { LiftListSection(routine: todaysRoutine) }` with `if let routine = todaysRoutine, doneToday == nil { LiftListSection(routine: routine, phase: currentBlockPhase, onView: { openedTemplate = routine }) }`. The hero call from Task 3 Step 5 stays.

- [ ] **Step 6: Run the unit tier and the display-name check**

Run: `scripts/test.sh fast 2>&1 | rg "error:|Executed|passed|failed" | tail -6`
Expected: builds; every unit test passes bar the known expected failure, `ExerciseDisplayNameSourceTests` and `BRUPrimitivesTests` included (neither needs an edit: the row still shows `exercise?.name`, and the primitives test only constructs a `BRUSectionHead`).

- [ ] **Step 7: Commit**

```bash
git add fitbod/Views/LiftListSection.swift fitbod/Views/LiftListRow.swift fitbod/Views/TodayView.swift fitbodTests/TodayViewBRUCopyTests.swift
git commit -m "feat(today): the exercises head opens the session and the rows read working sets"
```
  </action>
  <verify>`scripts/test.sh fast` green; `rg -n "BRUChip|generateWarmups|isFirstCompound|dayIndexInBlock|isPastPlan" fitbod/Views/LiftListRow.swift fitbod/Views/LiftListSection.swift fitbod/Views/TodayView.swift` prints nothing.</verify>
  <done>Today's list is headed EXERCISES · n with VIEW › into the session detail, every row reads working sets × rep range, and Today reads its phase and starts workouts with one calendar.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 5: Two UI tests: above the fold, and the deload week end to end</name>
  <files>fitbod/App/BlockStatesSeed.swift (makeBlock), fitbodUITests/TodayHeroUITests.swift</files>
  <behavior>
    - With `-fitbod-seed-active-block`, Today shows "NEXT UP · 1 OF 1", "LIVE PUSH", the meta parts "1 EXERCISE", "3 SETS", "~11 MIN", and "Start workout ▸" is hittable with its bottom above the tab bar before any scroll; "VIEW ›" opens the session detail (header "Session").
    - With `-fitbod-seed-block-states-deload`, the seed's deload phase carries a 0.5 multiplier, so Today shows "NEXT UP · 1 OF 2", "UPPER A", the meta parts "1 EXERCISE", "1 SET", "~5 MIN", "DELOAD WEEK · LIGHTER SETS" and the row subline "1 × 5-8"; no "DELOAD" badge, chip or banner text other than the plan line's "WEEK 4 OF 4 · DELOAD" and that caption.
  </behavior>
  <action>
- [ ] **Step 1: Seed multiplier.** In `BlockStatesSeed.makeBlock` (`:180-200`), after `phase.weeks = row.weeks` add `if row.kind == .deload { phase.volumeMultiplier = 0.5 }` with the comment `// The catalog's deload volume (BlockDraft.swift), so the deload seed cuts sets as a real block does.`

- [ ] **Step 2: Write the UI tests** in `fitbodUITests/TodayHeroUITests.swift` (`final class TodayHeroUITests: XCTestCase`, `setUpWithError` as in `BlockLifecycleEntryPointsUITests`, `static let blockStatesDeload = [UITestNavigation.resetFlag, "-fitbod-seed-block-states-deload"]`):

  - `testStartWorkoutSitsAboveTheFold`: `let app = UITestNavigation.launch(BlockLifecycleEntryPointsUITests.activeBlock)`; `XCTAssertTrue(UITestNavigation.appears(app.staticTexts.labeled("NEXT UP · 1 OF 1"), within: 10))`; `XCTAssertTrue(app.staticTexts.labeled("3 SETS").exists && app.staticTexts.labeled("~11 MIN").exists)` (each meta part is its own `Text`, so the line is never one label); `let start = app.buttons["Start workout ▸"]`; `XCTAssertTrue(start.exists && start.isHittable)`; `XCTAssertLessThan(start.frame.maxY, UITestNavigation.tab("Today", in: app).frame.minY)`; then `UITestNavigation.hittable(app.buttons, "View ›").tap()` and `XCTAssertTrue(UITestNavigation.appears(app.staticTexts.labeled("Session"), within: 5))`.
  - `testDeloadWeekShowsTheCutSets`: launch `blockStatesDeload`; assert `labeled("NEXT UP · 1 OF 2")`, `labeled("UPPER A")`, `labeled("1 SET")`, `labeled("~5 MIN")`, `labeled("DELOAD WEEK · LIGHTER SETS")`, `labeled("1 × 5-8")` all appear; `XCTAssertFalse(app.staticTexts.labeled("DL").exists)`.

- [ ] **Step 3: Run them**

Run: `scripts/test.sh fast -only-testing:fitbodUITests/TodayHeroUITests 2>&1 | rg "error:|Executed|passed|failed" | tail -5`
Expected: both pass.

- [ ] **Step 4: Run the Today suites 1.1 touched, since the hero and list moved**

Run: `scripts/test.sh fast -only-testing:fitbodUITests/BlockWeekCountsUITests -only-testing:fitbodUITests/BlockLifecycleEntryPointsUITests -only-testing:fitbodUITests/MilestoneOneJourneyUITests -only-testing:fitbodUITests/NumberEntryUITests 2>&1 | rg "error:|Executed|passed|failed" | tail -6`
Expected: all pass ("Start workout ▸" keeps its label; `MilestoneOneJourneyUITests:131,196` and `NumberEntryUITests:101` tap it by label).

- [ ] **Step 5: Commit**

```bash
git add fitbod/App/BlockStatesSeed.swift fitbodUITests/TodayHeroUITests.swift
git commit -m "test(ui): the hero sits above the fold and the deload week shows its cut sets"
```
  </action>
  <verify>`scripts/test.sh fast -only-testing:fitbodUITests/TodayHeroUITests` green.</verify>
  <done>Two UI tests pin the step's acceptance: START WORKOUT ▸ above the fold with the new labels, and a deload week whose hero, caption and rows show the sets the logger will generate.</done>
</task>

<task type="auto">
  <name>Task 6: Evidence: captures, changelog, one full run</name>
  <files>docs/design-map/screens/img/ (four PNGs), docs/design-map/redesign/changelog.md</files>
  <behavior>
    - Light and dark 17e captures of T-TODAY (active block) and of the deload week show the new hero and list and no chip, badge, banner or day counter.
    - The redesign changelog records what 1.2 changed against the draft.
    - The full suite is green bar the known expected failure, with the test count explained.
  </behavior>
  <action>
- [ ] **Step 1: Build once for the 17e simulator** (`E299C90A-F6A1-4324-A35B-FFB5541E0AB7`, `iPhone 17e`):

```bash
SIM=E299C90A-F6A1-4324-A35B-FFB5541E0AB7
xcrun simctl boot $SIM 2>/dev/null; xcrun simctl bootstatus $SIM -b
xcodebuild -project fitbod.xcodeproj -scheme fitbod -destination "id=$SIM" -derivedDataPath /tmp/fitbod-capture build 2>&1 | rg "error:|BUILD" | tail -3
xcrun simctl install $SIM /tmp/fitbod-capture/Build/Products/Debug-iphonesimulator/fitbod.app
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Capture each state in light and dark.** For (`today--active-block`, `-fitbod-seed-active-block`) and (`today--deload-week`, `-fitbod-seed-block-states-deload`), in each appearance:

```bash
xcrun simctl ui $SIM appearance <light|dark>
xcrun simctl launch --terminate-running-process $SIM bodybuilding.fitbod -fitbod-reset-store <seed>
sleep 3
xcrun simctl io $SIM screenshot docs/design-map/screens/img/17e-default-<light|dark>-<name>.png
```
These overwrite 1.1's captures of the same names. Open each PNG and check: label, name, meta line, button, no DAY counter; EXERCISES · n with VIEW ›; rows "3 × 5-8" (deload: "1 × 5-8" and the caption).

- [ ] **Step 3: Changelog entry** at the top of `docs/design-map/redesign/changelog.md`, "## 2026-11-06, step 1.2 landed", one sentence each: what landed; the deload caption landed here because 1.1 removed the banner; the hero keeps its 3 min per set estimate while the session detail's differs (pre-existing); the hand-made block seeds now give deload phases the catalog's 0.5 volume; `SessionFactory.start` and `WorkoutStarter.start` take a calendar.

- [ ] **Step 4: Full run**

Run: `scripts/test.sh full 2>&1 | rg "error:|Executed|passed|failed|enumerat" | tail -12`
Expected: every unit and UI test passes bar the one known expected failure, and the merged result ran exactly the enumerated tests. Explain the delta from 1.1's full-run count: Task 1 adds 4 test functions (two parameterized), Task 2 adds 2, Task 3 adds 3 and folds two copy tests into one, Task 5 adds 2 UI tests; the enumerate check must still hold.

- [ ] **Step 5: Commit**

```bash
git add docs/design-map/screens/img docs/design-map/redesign/changelog.md
git commit -m "docs(redesign): step 1.2 captures and changelog"
```
  </action>
  <verify>Four PNGs updated; the changelog's top entry is 1.2; the full run is green.</verify>
  <done>The step's evidence is in the repo and the whole suite passes.</done>
</task>

</tasks>

<threat_model>
| ID | Threat | Disposition | Mitigation |
| --- | --- | --- | --- |
| T-1.2-01 | The hero promises fewer sets than the logger makes, or more | mitigate | One function for both; `theFactoryCountsWhatTheHelperCounts`; the deload UI test reads the hero and the row from the same seed the factory cuts. |
| T-1.2-02 | Hero and logger disagree on the week around midnight or a time-zone change | mitigate | One calendar from Today through `WorkoutStarter` to the factory; `theFactoryFollowsTheGivenCalendar`. |
| T-1.2-03 | A defaulted parameter is added in the wrong position and silently rebinds a positional call | accept | All call sites use labels; the compiler rejects a mismatch. |
| T-1.2-04 | The seed multiplier change alters a UI suite's expectation | mitigate | Checked: no UI test reads a phase multiplier; `BlockWeekCountsUITests` counts workouts, not sets. Task 5 Step 4 runs the block suites. |
| T-1.2-05 | Dropping the chip loses an accessibility hint | accept | The chip named COMPOUND or WORK, derived from catalog mechanics, not a user setting; the redesign drops it (hierarchy.md line 21). |
</threat_model>

<verification>
1. After Task 2: the factory suites pass with the new calendar tests.
2. After Task 4: `scripts/test.sh fast` green; `rg -n "DAY %02d|BRUChip|warm-up ·|\"Lift list\"" fitbod/Views` prints nothing.
3. After Task 5: `TodayHeroUITests` green on the dedicated simulator.
4. After Task 6: `scripts/test.sh full` green; the four captures opened and checked by eye.
</verification>

## Source coverage audit

| Spec line | Requirement | Task |
| --- | --- | --- |
| plan.md 1.2 | Relabel the slab, drop the day counter | 3 |
| plan.md 1.2 | Drop the chips, add the Exercises head with "View ›" | 4 |
| plan.md 1.2 | `workingSetCount(targetSets:phase:)` holding the factory's rule, taking the phase | 1 |
| plan.md 1.2 | `WorkoutStarter.start` and `SessionFactory.start` take a calendar; Today passes the environment calendar | 2, 4 |
| plan.md 1.2 | Hero sums the helper per exercise; sublines read "3 × 5-8" on every row, no "2 warm-up" | 3, 4 |
| plan.md 1.2 | Placeholder deletion deferred to 1.3 | kept (Decisions) |
| plan.md 1.2 tests | `TodayViewBRUCopyTests`, `BRUPrimitivesTests`, `ExerciseDisplayNameSourceTests`, the factory suites, new helper tests, one helper-equals-factory test | 1, 2, 3, 4 |
| plan.md 1.2 acceptance | START WORKOUT ▸ first signal element above the fold; deload counts equal; no warm-up subline | 5 |
| hierarchy.md 78, 132 | "Deload week · lighter sets" in the hero; no banner, badge or chip | 3, 5 |
| today-layouts.md 52-73 | Deload wireframe: cut counts on the hero and the rows | 1, 3, 4, 5 |
| open-decisions O-11 | Rows open nothing; "View ›" opens the session detail | 4 |
| plan.md Phase 1 note | 17e light and dark captures per touched state | 6 |

<success_criteria>
- One shared working-set rule with tests; the factory, the hero and the rows call it.
- The hero reads TODAY or NEXT UP · n OF m with no day counter, and carries the deload caption only in a deload phase.
- EXERCISES · n with VIEW › into the session detail; rows read "n × lo-hi" with no chip.
- Today, the starter and the factory read one calendar.
- Two UI tests and four captures prove it; the full suite is green.
</success_criteria>

<output>
Six commits on the branch 1.1 landed on, in task order; `.planning/quick/261106-he2-hero-and-exercises/261106-he2-SUMMARY.md` with the GitNexus impact results, the test counts and the capture paths.
</output>
